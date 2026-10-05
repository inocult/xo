#!/usr/bin/env python3
# xo-paperclip-api.py - the Paperclip REST reader behind bin/xo-paperclip-check.sh.
#
# One board per invocation. Lists the company's tickets, keeps the ones assigned
# to one agent seat that the caller has not delivered yet, writes one
# ready-to-queue note body per ticket into <outdir>, and prints one index line
# per written note:
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
# Environment:
#   XO_PAPERCLIP_API_URL      instance base URL, no trailing path.      required
#   XO_PAPERCLIP_API_COMPANY  company id (the UUID, not the prefix).    required
#   XO_PAPERCLIP_API_AGENT    agent seat id whose assignments count.    required
#   XO_PAPERCLIP_API_KEY      agent API key for that seat.              required
#   XO_PAPERCLIP_API_SEEN     file of already-delivered issue ids.      optional
#   XO_PAPERCLIP_API_TIMEOUT  per-request seconds (default 10).         optional
#   XO_PAPERCLIP_API_MAX      most notes to write this run (default 10). optional
#
# Verified against a live Paperclip instance on 2026-10-05: the agent key reads
# GET /api/companies/{companyId}/issues, whose rows carry assigneeAgentId,
# identifier, title, description, status, and projectId; GET
# /api/companies/{companyId}/projects resolves a project name; and a ticket's
# board page is {base}/{identifier-prefix}/issues/{identifier}.
import json
import os
import socket
import sys
import urllib.error
import urllib.request

# A ticket in one of these states is a record of finished work, not a dispatch,
# so an assignment that is already closed never becomes a note. It is also not
# recorded as delivered: if it reopens, the next poll treats it as new work.
CLOSED_STATES = frozenset(('done', 'cancelled', 'canceled', 'archived'))

# The board page carries the whole description; a note only has to carry enough
# to act on, so a pathological body cannot make one dispatch dominate a drain.
MAX_DESCRIPTION = 4000


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


def get_json(base, path, key, timeout, soft=False):
    """One authenticated GET, or a diagnostic naming the cause and never the key.

    `soft` is for a lookup that only annotates a delivery: it returns None
    instead of printing, so an optional request can never be mistaken for the
    poll's own failure.
    """
    url = base.rstrip('/') + path
    request = urllib.request.Request(url, headers={
        'Authorization': 'Bearer %s' % key,
        'Accept': 'application/json',
    })
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
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
    except socket.timeout:
        if soft:
            return None
        fail('cannot reach %s: request timed out' % url)
    try:
        return json.loads(body.decode('utf-8', 'replace'))
    except ValueError:
        if soft:
            return None
        fail('%s did not answer JSON' % url)


def issue_rows(payload):
    """The issue list, whichever envelope this instance answers with."""
    if isinstance(payload, list):
        rows = payload
    elif isinstance(payload, dict):
        rows = payload.get('issues')
        if rows is None:
            rows = payload.get('data')
        if rows is None:
            rows = payload.get('items')
    else:
        rows = None
    if not isinstance(rows, list):
        fail('the issue list was not an array')
    return [row for row in rows if isinstance(row, dict)]


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


def project_names(base, company, key, timeout):
    """projectId -> name, or an empty map when the lookup is unavailable."""
    payload = get_json(base, '/api/companies/%s/projects' % company, key, timeout, soft=True)
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
    return '%s/%s/issues/%s' % (base.rstrip('/'), prefix, identifier)


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

    base = need('XO_PAPERCLIP_API_URL')
    if not base.startswith(('http://', 'https://')):
        fail('XO_PAPERCLIP_API_URL must start with http:// or https://', 2)
    company = need('XO_PAPERCLIP_API_COMPANY')
    agent = need('XO_PAPERCLIP_API_AGENT')
    key = need('XO_PAPERCLIP_API_KEY')
    timeout = bounded_int('XO_PAPERCLIP_API_TIMEOUT', 10, 1, 120)
    limit = bounded_int('XO_PAPERCLIP_API_MAX', 10, 1, 100)
    delivered = seen_ids(os.environ.get('XO_PAPERCLIP_API_SEEN', '').strip())

    payload = get_json(base, '/api/companies/%s/issues' % company, key, timeout)
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

    # Only paid for once a dispatch is actually waiting, so a quiet poll is one
    # request. An unavailable lookup degrades to the raw id rather than failing
    # the delivery it only annotates.
    names = project_names(base, company, key, timeout)

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
