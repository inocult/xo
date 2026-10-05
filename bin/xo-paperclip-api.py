#!/usr/bin/env python3
# xo-paperclip-api.py - the Paperclip REST reader behind bin/xo-paperclip-check.sh.
#
# Lists the board's tickets, keeps the ones assigned to one agent seat that the
# caller has not delivered yet, writes one ready-to-queue note body per ticket
# into <outdir>, and prints one index line per written note:
#
#   ticket<TAB><issue-id><TAB><identifier><TAB><note-path>
#
# Configuration arrives through the environment only, never through argv, so the
# agent API key never appears in a process listing, a log, or a diagnostic. No
# message this script prints ever carries the key.
#
# Read-only by construction as well as by scope: Paperclip binds agent writes to
# a heartbeat run it started, so a bare agent-key write is refused with
# cross_issue_influence_run_context_required. Nothing here issues one.
#
# WHO MAY DISPATCH. A ticket assigned to the seat becomes work done in the
# captain's own home with his credentials, so the board is only trusted to
# dispatch while the captain is its sole human principal. That is verified
# against the board itself on every poll rather than taken from configuration,
# it gates the whole poll, and a membership read that does not answer stops
# delivery loudly: an unverifiable boundary is not a boundary.
#
# TRANSPORT. The base URL must be https, except for a loopback host so the
# suite's local fixtures keep working, because every request carries the agent
# key in an Authorization header. A redirect to another origin is followed
# WITHOUT that header, so a 302 cannot replay the key to a stranger.
#
# Environment:
#   XO_PAPERCLIP_API_URL      instance base URL, no trailing path.      required
#   XO_PAPERCLIP_API_COMPANY  company id (the UUID, not the prefix).    required
#   XO_PAPERCLIP_API_AGENT    agent seat id whose assignments count.    required
#   XO_PAPERCLIP_API_KEY      agent API key for that seat.              required
#   XO_PAPERCLIP_API_SEEN     file of already-delivered issue ids.      optional
#   XO_PAPERCLIP_API_TIMEOUT  whole-run seconds (default 10).           optional
#   XO_PAPERCLIP_API_MAX      most notes to write this run (default 10). optional
#
# XO_PAPERCLIP_API_TIMEOUT bounds the WHOLE run, not one request, so the caller's
# single outer bound is enough: every request draws from one deadline and the
# optional lookup is skipped rather than overrunning it.
#
# Verified against a live Paperclip instance on 2026-10-05: the agent key reads
# GET /api/companies/{companyId}/issues, whose rows are a bare JSON array and
# carry assigneeAgentId, identifier, title, description, status, and projectId;
# GET /api/companies/{companyId}/projects resolves a project name; GET
# /api/companies/{companyId}/user-directory answers {"users": [...]} with one
# entry per human principal; and a ticket's board page is
# {base}/{identifier-prefix}/issues/{identifier}.
import json
import os
import socket
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

# The instance's issue status enum is backlog, todo, in_progress, in_review,
# done, blocked, cancelled. A ticket in one of these two states is a record of
# finished work, not a dispatch, so an assignment that is already closed never
# becomes a note. It is also not recorded as delivered: if it reopens, the next
# poll treats it as new work.
CLOSED_STATES = frozenset(('done', 'cancelled'))

# The board page carries the whole description; a note only has to carry enough
# to act on, so a pathological body cannot make one dispatch dominate a drain.
MAX_DESCRIPTION = 4000

LOOPBACK_HOSTS = frozenset(('localhost', '127.0.0.1', '::1'))


def fail(message, code=1):
    sys.stderr.write('xo-paperclip: %s\n' % message)
    raise SystemExit(code)


def need(name):
    value = os.environ.get(name, '').strip()
    if not value:
        fail('missing required value: %s' % name, 2)
    return value


def bounded_int(name, default, low, high):
    raw = os.environ.get(name, '').strip()
    if not raw:
        return default
    try:
        value = int(raw, 10)
    except ValueError:
        fail('%s must be a whole number from %d to %d' % (name, low, high), 2)
    if value < low or value > high:
        fail('%s must be a whole number from %d to %d' % (name, low, high), 2)
    return value


def checked_base(raw):
    """The base URL, or a refusal naming what is wrong with it.

    Plaintext is refused rather than polled, because the refusal is something
    the operator can act on while a plaintext poll quietly puts the agent key
    on the wire on every cycle.
    """
    parts = urllib.parse.urlsplit(raw)
    if parts.scheme not in ('http', 'https'):
        fail('XO_PAPERCLIP_API_URL must start with http:// or https://', 2)
    host = (parts.hostname or '').lower()
    if parts.scheme == 'http' and host not in LOOPBACK_HOSTS:
        fail('XO_PAPERCLIP_API_URL must be https for a non-loopback board, '
             'because every request carries the agent key: %s' % raw, 2)
    return raw.rstrip('/')


class NoAuthRedirect(urllib.request.HTTPRedirectHandler):
    """Follow a redirect, but never hand the agent key to another origin."""

    def redirect_request(self, req, fp, code, msg, headers, newurl):
        new = super().redirect_request(req, fp, code, msg, headers, newurl)
        if new is None:
            return None
        if origin_of(newurl) != origin_of(req.full_url):
            new.remove_header('Authorization')
        return new


def origin_of(url):
    parts = urllib.parse.urlsplit(url)
    return (parts.scheme, (parts.hostname or '').lower(), parts.port)


OPENER = urllib.request.build_opener(NoAuthRedirect)


class Deadline(object):
    """One wall-clock budget for the whole run.

    Every request draws from it, so the worst case in process is the budget
    rather than the budget once per request. A request gets at least a second,
    because a zero timeout is an instant failure rather than a short attempt.
    """

    def __init__(self, seconds):
        self.until = time.monotonic() + seconds

    def left(self):
        return self.until - time.monotonic()

    def hard(self):
        return max(1.0, self.left())


def get_json(base, path, key, timeout, soft=False):
    """One authenticated GET, or a diagnostic naming the cause and never the key.

    `soft` is for a lookup that only annotates a delivery: it returns None
    instead of printing, so an optional request can never be mistaken for the
    poll's own failure.
    """
    url = base + path
    request = urllib.request.Request(url, headers={
        'Authorization': 'Bearer %s' % key,
        'Accept': 'application/json',
    })
    try:
        with OPENER.open(request, timeout=timeout) as response:
            body = response.read()
    except urllib.error.HTTPError as exc:
        if soft:
            return None
        if exc.code == 401:
            fail('key rejected by %s (401); the agent API key is invalid or revoked' % url)
        if exc.code == 403:
            fail('key refused for this company by %s (403); the key belongs to '
                 'another seat or company' % url)
        fail('%s answered HTTP %s' % (url, exc.code))
    except urllib.error.URLError as exc:
        if soft:
            return None
        fail('cannot reach %s: %s' % (url, exc.reason))
    except (socket.timeout, TimeoutError):
        if soft:
            return None
        fail('cannot reach %s: request timed out' % url)
    try:
        return json.loads(body.decode('utf-8', 'replace'))
    except ValueError:
        if soft:
            return None
        fail('%s did not answer JSON' % url)


def require_sole_principal(base, company, key, deadline):
    """Refuse the whole poll unless this board has exactly one human principal.

    The OpenAPI document declares user-directory as a board-actor endpoint even
    though an agent key is accepted today. If a future instance enforces that
    declaration the read answers 403, which lands here as a loud refusal that
    stops delivery rather than a silent one that keeps delivering.
    """
    path = '/api/companies/%s/user-directory' % company
    payload = get_json(base, path, key, deadline.hard())
    users = payload.get('users') if isinstance(payload, dict) else None
    if not isinstance(users, list):
        fail('cannot tell who may dispatch from %s%s: it did not answer a user '
             'list, and an unverifiable boundary is not a boundary' % (base, path))
    # The endpoint carries one entry per human principal, so the entries ARE
    # the count; anything else here would be a guess about a measured shape.
    count = len([row for row in users if isinstance(row, dict)])
    if count != 1:
        fail('%s (company %s) has %d human principals, so nothing is taken from '
             'it; this intake accepts a dispatch only from a board the captain '
             'is the sole principal of' % (base, company, count))


def issue_rows(payload):
    """The issue list, which this instance answers as a bare JSON array."""
    if not isinstance(payload, list):
        fail('the issue list was not an array')
    return [row for row in payload if isinstance(row, dict)]


def seen_ids(path):
    if not path:
        return frozenset()
    try:
        with open(path, 'r', encoding='utf-8', errors='replace') as handle:
            return frozenset(line.strip() for line in handle if line.strip())
    except FileNotFoundError:
        return frozenset()
    except OSError as exc:
        fail('cannot read the delivered-ticket cursor %s: %s' % (path, exc.strerror))


def sort_key(row):
    number = row.get('issueNumber')
    if isinstance(number, int):
        return (0, number, '')
    return (1, 0, str(row.get('identifier') or row.get('id') or ''))


def text(value):
    return value.strip() if isinstance(value, str) else ''


def project_names(base, company, key, deadline):
    """projectId -> name, or an empty map when the lookup is unavailable.

    Soft in both directions: an unavailable endpoint degrades to the raw
    project id, and so does a deadline with nothing left to spend, so a hanging
    lookup cannot cost the tickets that are already in hand.
    """
    if deadline.left() < 1:
        return {}
    payload = get_json(base, '/api/companies/%s/projects' % company, key,
                       deadline.left(), soft=True)
    rows = payload if isinstance(payload, list) else []
    names = {}
    for row in rows:
        if not isinstance(row, dict):
            continue
        ident = text(row.get('id'))
        name = text(row.get('name'))
        if ident and name:
            names[ident] = name
    return names


def board_url(base, identifier):
    """A ticket's board page, which is keyed by its identifier's own prefix."""
    if '-' not in identifier:
        return ''
    prefix = identifier.rsplit('-', 1)[0]
    if not prefix:
        return ''
    return '%s/%s/issues/%s' % (base, prefix, identifier)


def note_body(row, project, url):
    identifier = text(row.get('identifier')) or text(row.get('id'))
    title = text(row.get('title')) or '(untitled)'
    description = text(row.get('description'))
    if len(description) > MAX_DESCRIPTION:
        description = description[:MAX_DESCRIPTION].rstrip() + \
            '\n\n[description truncated; the whole ticket is on the board]'
    lines = ['Paperclip dispatch: %s - %s' % (identifier, title)]
    lines.append('state: %s' % (text(row.get('status')) or 'unknown'))
    lines.append('project: %s' % (project or 'none'))
    if url:
        lines.append('url: %s' % url)
    lines.append('')
    lines.append(description if description else '(no description on the ticket)')
    return '\n'.join(lines) + '\n'


def main(argv):
    if len(argv) != 2:
        fail('usage: xo-paperclip-api.py <note-output-directory>', 2)
    outdir = argv[1]
    if not os.path.isdir(outdir):
        fail('note output directory does not exist: %s' % outdir, 2)

    base = checked_base(need('XO_PAPERCLIP_API_URL'))
    company = need('XO_PAPERCLIP_API_COMPANY')
    agent = need('XO_PAPERCLIP_API_AGENT')
    key = need('XO_PAPERCLIP_API_KEY')
    timeout = bounded_int('XO_PAPERCLIP_API_TIMEOUT', 10, 1, 120)
    limit = bounded_int('XO_PAPERCLIP_API_MAX', 10, 1, 100)
    delivered = seen_ids(os.environ.get('XO_PAPERCLIP_API_SEEN', '').strip())
    deadline = Deadline(timeout)

    require_sole_principal(base, company, key, deadline)

    payload = get_json(base, '/api/companies/%s/issues' % company, key, deadline.hard())
    candidates = []
    for row in issue_rows(payload):
        ident = text(row.get('id'))
        if not ident or ident in delivered:
            continue
        if text(row.get('assigneeAgentId')) != agent:
            continue
        if text(row.get('status')).lower() in CLOSED_STATES:
            continue
        candidates.append(row)
    candidates.sort(key=sort_key)
    candidates = candidates[:limit]
    if not candidates:
        return 0

    # Only paid for once a dispatch is actually waiting, so a quiet poll never
    # spends a request on it.
    names = project_names(base, company, key, deadline)

    for index, row in enumerate(candidates, start=1):
        ident = text(row.get('id'))
        identifier = text(row.get('identifier')) or ident
        project = names.get(text(row.get('projectId')), '') or text(row.get('projectId'))
        path = os.path.join(outdir, '%d.note' % index)
        try:
            with open(path, 'w', encoding='utf-8') as handle:
                handle.write(note_body(row, project, board_url(base, identifier)))
        except OSError as exc:
            fail('cannot stage the note for %s: %s' % (identifier, exc.strerror))
        sys.stdout.write('ticket\t%s\t%s\t%s\n' % (ident, identifier, path))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
