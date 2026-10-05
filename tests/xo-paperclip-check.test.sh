#!/usr/bin/env bash
# Behavior tests for bin/xo-paperclip-check.sh, the standing Paperclip dispatch
# check, and for the reader behind it.
#
# Everything is exercised through the script's own interface. The board is a
# real HTTP server on 127.0.0.1 answering the endpoints the reader calls, so
# the request path, the bearer header, the JSON shape, and the note the
# delivery queues are all checked for real rather than asserted against the
# implementation's source. No case contacts a Paperclip instance.
#
# The cases that matter are the contract the dispatch direction depends on:
# one assigned ticket becomes exactly one note, a second poll re-delivers
# nothing, a board the captain is not the sole principal of hands over nothing,
# a membership read that does not answer hands over nothing, a board that
# cannot be reached or whose key is rejected keeps reporting on a bounded
# cadence instead of going quiet, broken configuration is an actionable report,
# the agent key never leaves its own origin, and arm/disarm leave no stray shim
# or binding.
#
# The last case covers bin/xo-inbox.sh's note source, which this check is the
# first caller to set: a board dispatch is recorded as source=board, while a
# bare captain-typed note is still recorded as source=text.
set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

CHECK="$ROOT/bin/xo-paperclip-check.sh"
INBOX="$ROOT/bin/xo-inbox.sh"
TMP_ROOT=$(xo_test_tmproot xo-paperclip-check)
BOARD_PIDS=
AGENT=agent-1

# tests/lib.sh owns the fixture-root trap, so this suite's own trap has to call
# that cleanup itself after stopping the fake boards it started.
stop_boards() {
  local pid
  for pid in $BOARD_PIDS; do
    kill "$pid" 2>/dev/null || :
  done
  BOARD_PIDS=
}
trap 'stop_boards; xo_test_cleanup' EXIT
trap 'stop_boards; xo_test_cleanup; exit 130' INT
trap 'stop_boards; xo_test_cleanup; exit 143' TERM

# A fake Paperclip instance driven by a JSON config re-read on every request,
# so a case can change what the board answers between polls.
write_board_server() {
  cat > "$TMP_ROOT/board.py" <<'PY'
import json
import os
import sys
import time
from http.server import BaseHTTPRequestHandler, HTTPServer

CONF = sys.argv[1]
PORTFILE = sys.argv[2]
LOGFILE = sys.argv[3]


def conf():
    with open(CONF, 'r', encoding='utf-8') as handle:
        return json.load(handle)


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def send_json(self, status, payload):
        body = json.dumps(payload).encode()
        self.send_response(status)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        c = conf()
        with open(LOGFILE, 'a', encoding='utf-8') as log:
            log.write('%s\t%s\n' % (self.path, self.headers.get('Authorization', '')))
        for suffix, target in c.get('redirect', {}).items():
            if self.path.endswith(suffix):
                self.send_response(302)
                self.send_header('Location', target)
                self.send_header('Content-Length', '0')
                self.end_headers()
                return
        hang = c.get('hang')
        if hang and self.path.endswith(hang):
            time.sleep(600)
            return
        if self.headers.get('Authorization') != 'Bearer %s' % c['token']:
            self.send_json(401, {'error': 'Unauthorized'})
            return
        if self.path.endswith('/user-directory'):
            users = c.get('users', 1)
            if isinstance(users, int):
                self.send_json(200, {'users': [
                    {'principalId': 'pr%d' % n, 'status': 'active',
                     'user': {'id': 'u%d' % n, 'email': 'u%d@example.test' % n,
                              'name': 'User %d' % n}}
                    for n in range(1, users + 1)
                ]})
            else:
                self.send_json(users.get('status', 200), users.get('body', {}))
            return
        if self.path.endswith('/projects'):
            self.send_json(200, [{'id': 'p1', 'name': 'Onboarding'}])
            return
        if self.path.endswith('/issues'):
            with open(c['issues'], 'r', encoding='utf-8') as handle:
                body = handle.read().encode()
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Content-Length', str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return
        self.send_response(404)
        self.send_header('Content-Length', '0')
        self.end_headers()


server = HTTPServer(('127.0.0.1', 0), Handler)
with open(PORTFILE, 'w', encoding='utf-8') as handle:
    handle.write('%d\n' % server.server_address[1])
os.close(0)
server.serve_forever()
PY
}

# board_conf <name> <key=json-value>...: writes the board's config file.
board_conf() {
  local name=$1
  shift
  python3 -c '
import json, sys
conf = {}
for pair in sys.argv[2:]:
    key, _, raw = pair.partition("=")
    conf[key] = json.loads(raw)
json.dump(conf, open(sys.argv[1], "w"))' "$TMP_ROOT/$name.conf" "$@"
}

# start_board <name>: echoes the base URL of the board configured under <name>.
start_board() {
  local name=$1 portfile pid waited=0 port
  portfile="$TMP_ROOT/$name.port"
  : > "$TMP_ROOT/$name.log"
  python3 "$TMP_ROOT/board.py" "$TMP_ROOT/$name.conf" "$portfile" "$TMP_ROOT/$name.log" \
    >/dev/null 2>&1 &
  pid=$!
  BOARD_PIDS="$BOARD_PIDS $pid"
  while [ ! -s "$portfile" ]; do
    waited=$((waited + 1))
    [ "$waited" -le 100 ] || fail "the fake board at $name never reported a port"
    sleep 0.1
  done
  port=$(tr -d '[:space:]' < "$portfile")
  printf 'http://127.0.0.1:%s\n' "$port"
}

# A closed assignment, and one assigned to another seat, are both present in
# every fixture so no case can pass by accident.
write_issues() {
  local path=$1
  shift
  {
    printf '[\n'
    local first=1 row
    for row in "$@"; do
      [ "$first" = 1 ] || printf ',\n'
      first=0
      printf '%s' "$row"
    done
    printf '\n]\n'
  } > "$path"
}

issue_row() {  # <id> <identifier> <number> <status> <assignee> <title> <description>
  python3 -c '
import json, sys
print(json.dumps({
    "id": sys.argv[1],
    "identifier": sys.argv[2],
    "issueNumber": int(sys.argv[3]),
    "status": sys.argv[4],
    "assigneeAgentId": sys.argv[5],
    "title": sys.argv[6],
    "description": sys.argv[7],
    "projectId": "p1",
}))' "$@"
}

make_home() {
  local name=$1 home
  home="$TMP_ROOT/$name"
  mkdir -p "$home/state"
  printf '%s\n' "$home"
}

write_env() {  # <home> <base-url> <token>
  local home=$1 url=$2 token=$3
  {
    printf 'XO_PAPERCLIP_URL=%s\n' "$url"
    printf 'XO_PAPERCLIP_COMPANY=c1\n'
    printf 'XO_PAPERCLIP_AGENT=%s\n' "$AGENT"
    printf 'XO_PAPERCLIP_KEY=%s\n' "$token"
  } > "$home/.env"
}

# Pin the watcher bound and clear any ambient board configuration so each
# case's outcome comes from its own fixture .env alone.
run_check() {
  local home=$1 out=$2
  shift 2
  local status=0
  env -u XO_PAPERCLIP_URL -u XO_PAPERCLIP_COMPANY -u XO_PAPERCLIP_AGENT \
    -u XO_PAPERCLIP_KEY -u XO_PAPERCLIP_CHECK_BUDGET -u XO_PAPERCLIP_CHECK_MAX \
    -u XO_PAPERCLIP_CHECK_REREPORT -u XO_PAPERCLIP_CHECK_NOW \
    XO_CHECK_TIMEOUT=30 \
    "$@" XO_HOME="$home" \
    "$CHECK" check >"$out" 2>&1 || status=$?
  expect_code 0 "$status" "check exit"
}

count_notes() {
  local home=$1
  find "$home/state/inbox" -maxdepth 1 -name '*.note' 2>/dev/null | wc -l | tr -d '[:space:]'
}

# The inbox note record is the durable capture contract, and its source field is
# what tells a drain which surface handed the body over.
note_field() {  # <home> <field>
  local home=$1 field=$2
  sed -n "s/^$field=//p" "$home"/state/inbox/*.note | head -n1
}

test_help_and_usage() {
  local out rc=0
  out=$("$CHECK" --help 2>&1) || rc=$?
  expect_code 0 "$rc" "--help must exit 0"
  assert_contains "$out" "check" "--help lists the check action"
  assert_contains "$out" "arm" "--help lists the arm action"
  assert_contains "$out" "disarm" "--help lists the disarm action"
  assert_contains "$out" "XO_PAPERCLIP_URL" "--help names the board's base URL setting"
  assert_contains "$out" "XO_PAPERCLIP_KEY" "--help names the board's key setting"
  rc=0
  out=$("$CHECK" bogus 2>&1) || rc=$?
  expect_code 2 "$rc" "unknown action must exit 2"
  assert_contains "$out" "unknown action" "unknown action is refused loudly"
  pass "xo-paperclip-check: help and usage plumbing"
}

test_arm_writes_and_binds_the_check_and_disarm_removes_it() {
  local home out
  home=$(make_home arm)
  out=$(XO_HOME="$home" "$CHECK" arm 2>&1) || fail "arm must succeed: $out"
  assert_contains "$out" "armed: state/paperclip.check.sh" "arm names the shim it wrote"
  assert_present "$home/state/paperclip.check.sh" "arm writes the check shim"
  assert_present "$home/state/paperclip.check-trust" "arm binds the shim for the watcher"
  assert_contains "$(cat "$home/state/paperclip.check.sh")" "xo-paperclip-check.sh check" \
    "shim dispatches the check action"
  assert_contains "$(cat "$home/state/paperclip.check.sh")" "XO_HOME=$home" \
    "shim pins the absolute home"

  out=$(XO_HOME="$home" "$CHECK" arm 2>&1) || fail "re-arm must succeed: $out"
  assert_contains "$out" "armed" "re-arm stays armed"

  out=$(XO_HOME="$home" "$CHECK" disarm 2>&1) || fail "disarm must succeed: $out"
  assert_absent "$home/state/paperclip.check.sh" "disarm removes the check shim"
  assert_absent "$home/state/paperclip.check-trust" "disarm removes the trust binding"
  assert_absent "$home/state/.paperclip-check" "disarm removes the report record"
  [ -z "$(find "$home/state" -maxdepth 1 -name '.xo-paperclip-check.*' 2>/dev/null)" ] \
    || fail "disarm left a staging file behind: $(ls -a "$home/state")"
  pass "xo-paperclip-check: arm writes and binds, re-arm is idempotent, disarm removes"
}

test_arm_refuses_a_symlink_at_the_shim_path() {
  local home target out rc=0
  home=$(make_home arm-symlink)
  target="$TMP_ROOT/outside-shim"
  mkdir -p "$target"
  printf '#!/usr/bin/env bash\n' > "$target/paperclip.check.sh"
  ln -s "$target/paperclip.check.sh" "$home/state/paperclip.check.sh"
  out=$(XO_HOME="$home" "$CHECK" arm 2>&1) || rc=$?
  expect_code 1 "$rc" "arm must refuse a symlink at the shim path"
  assert_contains "$out" "could not write" "arm reports the shim write failure"
  assert_absent "$home/state/paperclip.check-trust" "no trust binding is left behind by a refused arm"
  pass "xo-paperclip-check: arm refuses a symlink at the shim path"
}

test_arm_refuses_without_the_board_reader() {
  local tmpbin home out rc=0 lib
  # A copy of the check tool with no reader beside it is a home where the board
  # reader has not landed: arming must refuse instead of arming a check that
  # can never read a board.
  tmpbin="$TMP_ROOT/no-reader/bin"
  home="$TMP_ROOT/no-reader/home"
  mkdir -p "$tmpbin" "$home/state"
  cp "$ROOT/bin/xo-paperclip-check.sh" "$tmpbin/"
  for lib in xo-timeout-lib.sh xo-pr-lib.sh xo-line-cap-lib.sh xo-check-lib.sh \
    xo-wake-lib.sh xo-classify-lib.sh xo-inbox.sh; do
    [ -e "$tmpbin/$lib" ] || ln -s "$ROOT/bin/$lib" "$tmpbin/$lib"
  done
  out=$(XO_HOME="$home" "$tmpbin/xo-paperclip-check.sh" arm 2>&1) || rc=$?
  expect_code 1 "$rc" "arm must refuse when the board reader is missing"
  assert_contains "$out" "board reader is missing" "arm names the missing reader"
  assert_absent "$home/state/paperclip.check.sh" "a refused arm writes no shim"
  pass "xo-paperclip-check: arm refuses without the board reader"
}

test_a_new_assigned_ticket_becomes_exactly_one_note() {
  local home url issues out note
  home=$(make_home dispatch)
  issues="$TMP_ROOT/dispatch.issues.json"
  write_issues "$issues" \
    "$(issue_row i1 ATB-18 18 backlog "$AGENT" 'Wire the fleet digest' 'Two lines.
Second line.')" \
    "$(issue_row i2 ATB-19 19 'done' "$AGENT" 'Already finished' 'x')" \
    "$(issue_row i3 ATB-20 20 cancelled "$AGENT" 'Called off' 'x')" \
    "$(issue_row i4 ATB-21 21 backlog agent-other 'Someone else' 'x')"
  board_conf dispatch "token=\"board-token\"" "issues=\"$issues\"" 'users=1'
  url=$(start_board dispatch)
  write_env "$home" "$url" board-token

  out="$home/out1.txt"
  run_check "$home" "$out"
  assert_contains "$(cat "$out")" "paperclip: 1 ticket dispatched from the board: ATB-18" \
    "a new assigned ticket wakes xo once, naming the ticket"
  [ "$(wc -l < "$out" | tr -d '[:space:]')" = 1 ] || fail "a delivery reports exactly one line: $(cat "$out")"
  [ "$(count_notes "$home")" = 1 ] || fail "exactly one note must be queued, got $(count_notes "$home")"

  note=$(cat "$home"/state/inbox/*.note)
  assert_contains "$note" "Paperclip dispatch: ATB-18 - Wire the fleet digest" \
    "the note names the ticket and its title"
  assert_contains "$note" "state: backlog" "the note carries the ticket state"
  assert_contains "$note" "project: Onboarding" "the note carries the project name"
  assert_contains "$note" "$url/ATB/issues/ATB-18" "the note carries the ticket URL"
  assert_contains "$note" "Second line." "the note carries the whole description"
  assert_equals board "$(note_field "$home" source)" \
    "a board dispatch is recorded as a board-origin note, not a captain-typed one"
  assert_contains "$(cat "$home/state/.wake-queue")" "check: captain inbox note" \
    "the delivery queues one durable captain inbox wake"
  [ "$(wc -l < "$home/state/.wake-queue" | tr -d '[:space:]')" = 1 ] \
    || fail "one ticket must queue one wake: $(cat "$home/state/.wake-queue")"
  assert_equals i1 "$(tr -d '[:space:]' < "$home/state/.paperclip-seen")" \
    "the delivered ticket id is the cursor"

  # The second poll is the whole point of the cursor.
  out="$home/out2.txt"
  run_check "$home" "$out"
  [ ! -s "$out" ] || fail "the same ticket must not be reported again: $(cat "$out")"
  [ "$(count_notes "$home")" = 1 ] || fail "the same ticket must not be queued again, got $(count_notes "$home")"

  assert_not_contains "$note" "ATB-19" "a done assignment is never dispatched"
  assert_not_contains "$note" "ATB-20" "a cancelled assignment is never dispatched"
  assert_not_contains "$note" "ATB-21" "another seat's ticket is never dispatched"
  pass "xo-paperclip-check: one assigned ticket becomes exactly one note, once"
}

test_a_shared_board_dispatches_nothing() {
  local home url issues out
  home=$(make_home shared)
  issues="$TMP_ROOT/shared.issues.json"
  write_issues "$issues" "$(issue_row i1 ATB-60 60 backlog "$AGENT" 'From a shared board' 'x')"
  # Three humans can assign to this seat, so nothing on it is known to be the
  # captain's own dispatch.
  board_conf shared "token=\"board-token\"" "issues=\"$issues\"" 'users=3'
  url=$(start_board shared)
  write_env "$home" "$url" board-token

  out="$home/out.txt"
  run_check "$home" "$out"
  assert_contains "$(cat "$out")" "3 human principals" \
    "the refusal names how many principals the board has"
  assert_contains "$(cat "$out")" "$url" "the refusal names the board it refused"
  [ "$(count_notes "$home")" = 0 ] || fail "a shared board must queue no note"
  assert_absent "$home/state/.wake-queue" "a refused board wakes nobody about its tickets"

  # Once the board is the captain's alone, the same ticket is delivered.
  board_conf shared "token=\"board-token\"" "issues=\"$issues\"" 'users=1'
  out="$home/out2.txt"
  run_check "$home" "$out"
  assert_contains "$(cat "$out")" "ATB-60" "a board narrowed to one principal dispatches again"
  [ "$(count_notes "$home")" = 1 ] || fail "the narrowed board must deliver, got $(count_notes "$home")"
  pass "xo-paperclip-check: a board with more than one human principal dispatches nothing"
}

test_an_unverifiable_membership_dispatches_nothing() {
  local home url issues out now
  home=$(make_home unverifiable)
  issues="$TMP_ROOT/unverifiable.issues.json"
  write_issues "$issues" "$(issue_row i1 ATB-70 70 backlog "$AGENT" 'Unverifiable' 'x')"
  # The declared board-actor endpoint refusing an agent key is exactly the 403
  # a future instance would answer; it must stop delivery rather than be
  # shrugged off.
  board_conf unverifiable "token=\"board-token\"" "issues=\"$issues\"" \
    'users={"status": 403, "body": {"error": "Forbidden"}}'
  url=$(start_board unverifiable)
  write_env "$home" "$url" board-token

  out="$home/out1.txt"
  run_check "$home" "$out"
  assert_contains "$(cat "$out")" "paperclip:" "an unverifiable boundary is reported"
  assert_contains "$(cat "$out")" "403" "the report names what the board answered"
  [ "$(count_notes "$home")" = 0 ] || fail "an unverifiable boundary must queue no note"

  # The same refusal must keep reporting, because the dispatch is still waiting.
  now=$(date +%s)
  out="$home/out2.txt"
  run_check "$home" "$out" XO_PAPERCLIP_CHECK_REREPORT=60 XO_PAPERCLIP_CHECK_NOW=$((now + 120))
  assert_contains "$(cat "$out")" "403" "an unchanged refusal reports again once its window has passed"
  pass "xo-paperclip-check: a membership read that does not answer dispatches nothing"
}

test_a_plaintext_board_is_refused_rather_than_polled() {
  local home out
  home=$(make_home plaintext)
  {
    printf 'XO_PAPERCLIP_URL=http://boards.example.invalid\n'
    printf 'XO_PAPERCLIP_COMPANY=c1\n'
    printf 'XO_PAPERCLIP_AGENT=%s\n' "$AGENT"
    printf 'XO_PAPERCLIP_KEY=plaintext-token\n'
  } > "$home/.env"

  out="$home/out.txt"
  run_check "$home" "$out"
  assert_contains "$(cat "$out")" "must be https" \
    "a plaintext non-loopback board is refused as configuration"
  assert_not_contains "$(cat "$out")" "plaintext-token" "the refusal never prints the key"
  [ "$(count_notes "$home")" = 0 ] || fail "a refused board must queue no note"
  pass "xo-paperclip-check: a plaintext non-loopback board is refused rather than polled"
}

test_the_key_does_not_follow_a_cross_origin_redirect() {
  local home first second issues out
  home=$(make_home redirect)
  issues="$TMP_ROOT/redirect.issues.json"
  write_issues "$issues" "$(issue_row i1 ATB-80 80 backlog "$AGENT" 'Redirected' 'x')"
  board_conf elsewhere "token=\"board-token\"" "issues=\"$issues\"" 'users=1'
  second=$(start_board elsewhere)
  board_conf home-board "token=\"board-token\"" "issues=\"$issues\"" 'users=1' \
    "redirect={\"/user-directory\": \"$second/api/companies/c1/user-directory\"}"
  first=$(start_board home-board)
  write_env "$home" "$first" board-token

  out="$home/out.txt"
  run_check "$home" "$out"
  assert_grep 'user-directory' "$TMP_ROOT/elsewhere.log" \
    "the redirect really did reach the other origin"
  assert_no_grep 'board-token' "$TMP_ROOT/elsewhere.log" \
    "the agent key is not replayed to another origin by a redirect"
  assert_grep 'board-token' "$TMP_ROOT/home-board.log" \
    "the key is still sent to the board it belongs to"
  pass "xo-paperclip-check: a cross-origin redirect does not carry the agent key"
}

test_a_hanging_project_lookup_still_delivers_the_ticket() {
  local home url issues out
  home=$(make_home hanging-projects)
  issues="$TMP_ROOT/hanging.issues.json"
  write_issues "$issues" "$(issue_row i1 ATB-90 90 backlog "$AGENT" 'Named by id' 'x')"
  # The project name only annotates a delivery, so a blackholed lookup must
  # cost the project NAME and nothing else: the ticket still arrives inside the
  # one outer bound, and the cursor still records it.
  board_conf hanging "token=\"board-token\"" "issues=\"$issues\"" 'users=1' 'hang="/projects"'
  url=$(start_board hanging)
  write_env "$home" "$url" board-token

  out="$home/out.txt"
  run_check "$home" "$out" XO_PAPERCLIP_CHECK_BUDGET=5
  assert_contains "$(cat "$out")" "ATB-90" "a hanging annotation lookup still delivers the ticket"
  [ "$(count_notes "$home")" = 1 ] || fail "the ticket must arrive, got $(count_notes "$home")"
  assert_contains "$(cat "$home"/state/inbox/*.note)" "project: p1" \
    "an unavailable lookup degrades to the raw project id"
  assert_equals i1 "$(tr -d '[:space:]' < "$home/state/.paperclip-seen")" \
    "the delivered ticket is still recorded, so it does not arrive twice"
  pass "xo-paperclip-check: a hanging project lookup still delivers the ticket"
}

test_an_unreachable_instance_keeps_reporting() {
  local home out port now
  home=$(make_home unreachable)
  # A port nothing is listening on: the dispatch the captain made is sitting on
  # a board this home cannot read, which is the failure that must never go quiet.
  port=$(python3 -c '
import socket
s = socket.socket()
s.bind(("127.0.0.1", 0))
print(s.getsockname()[1])
s.close()')
  write_env "$home" "http://127.0.0.1:$port" board-token

  out="$home/out1.txt"
  run_check "$home" "$out"
  assert_contains "$(cat "$out")" "paperclip:" "an unreachable board is reported"
  assert_contains "$(cat "$out")" "cannot reach" "the report names the transport failure"
  assert_contains "$(cat "$home/state/.paperclip-check")" "xo-paperclip-check-v1" \
    "the record carries its schema"

  out="$home/out2.txt"
  run_check "$home" "$out"
  [ ! -s "$out" ] || fail "the same failure must stay quiet inside its window: $(cat "$out")"

  now=$(date +%s)
  out="$home/out3.txt"
  run_check "$home" "$out" XO_PAPERCLIP_CHECK_REREPORT=60 XO_PAPERCLIP_CHECK_NOW=$((now + 120))
  assert_contains "$(cat "$out")" "cannot reach" \
    "an unchanged failure must be reported again once its window has passed"
  pass "xo-paperclip-check: an unreachable board reports and keeps reporting"
}

test_a_rejected_key_reports_the_credential_problem() {
  local home url issues out
  home=$(make_home rejected)
  issues="$TMP_ROOT/rejected.issues.json"
  write_issues "$issues" "$(issue_row i1 ATB-22 22 backlog "$AGENT" 'Waiting' 'x')"
  board_conf rejected "token=\"the-real-token\"" "issues=\"$issues\"" 'users=1'
  url=$(start_board rejected)
  # The board is reachable; this home's key is not the one it accepts.
  write_env "$home" "$url" expired-token

  out="$home/out.txt"
  run_check "$home" "$out"
  assert_contains "$(cat "$out")" "key rejected" "a rejected key is reported as a credential problem"
  assert_contains "$(cat "$out")" "401" "the report names the status the board answered"
  assert_not_contains "$(cat "$out")" "expired-token" "the report never prints the key"
  [ "$(count_notes "$home")" = 0 ] || fail "a rejected key must queue no note"
  pass "xo-paperclip-check: a rejected key reports the credential problem"
}

test_broken_configuration_is_actionable_not_skipped() {
  local home out
  home=$(make_home unconfigured)
  out="$home/out1.txt"
  run_check "$home" "$out"
  assert_contains "$(cat "$out")" "no board is configured" "an unconfigured home says so"
  assert_contains "$(cat "$out")" "XO_PAPERCLIP_URL" "the report names what to set"

  printf 'XO_PAPERCLIP_URL=https://boards.example\n' > "$home/.env"
  out="$home/out2.txt"
  run_check "$home" "$out"
  assert_contains "$(cat "$out")" "the board is not configured" "a half-configured board is reported"
  assert_contains "$(cat "$out")" "XO_PAPERCLIP_KEY" "the report names every missing value"
  pass "xo-paperclip-check: broken configuration is an actionable report"
}

test_the_per_poll_cap_defers_the_rest_without_dropping_them() {
  local home url issues out
  home=$(make_home capped)
  issues="$TMP_ROOT/capped.issues.json"
  write_issues "$issues" \
    "$(issue_row i1 ATB-41 41 backlog "$AGENT" 'First' 'a')" \
    "$(issue_row i2 ATB-42 42 backlog "$AGENT" 'Second' 'b')" \
    "$(issue_row i3 ATB-43 43 backlog "$AGENT" 'Third' 'c')"
  board_conf capped "token=\"board-token\"" "issues=\"$issues\"" 'users=1'
  url=$(start_board capped)
  write_env "$home" "$url" board-token

  out="$home/out1.txt"
  run_check "$home" "$out" XO_PAPERCLIP_CHECK_MAX=2
  assert_contains "$(cat "$out")" "2 tickets dispatched from the board: ATB-41, ATB-42" \
    "the cap bounds one poll and keeps the oldest tickets first"
  [ "$(count_notes "$home")" = 2 ] || fail "the cap must bound the notes, got $(count_notes "$home")"

  out="$home/out2.txt"
  run_check "$home" "$out" XO_PAPERCLIP_CHECK_MAX=2
  assert_contains "$(cat "$out")" "1 ticket dispatched from the board: ATB-43" \
    "the deferred ticket arrives on the next poll rather than being dropped"
  [ "$(count_notes "$home")" = 3 ] || fail "every ticket must arrive eventually, got $(count_notes "$home")"
  pass "xo-paperclip-check: the per-poll cap defers the rest without dropping them"
}

test_overlapping_polls_deliver_one_ticket_once() {
  local home url issues a b
  home=$(make_home overlapping)
  issues="$TMP_ROOT/overlapping.issues.json"
  write_issues "$issues" "$(issue_row i1 ATB-55 55 backlog "$AGENT" 'Only once' 'x')"
  board_conf overlapping "token=\"board-token\"" "issues=\"$issues\"" 'users=1'
  url=$(start_board overlapping)
  write_env "$home" "$url" board-token

  # A hand-run check racing the watcher's standing shim: without the poll lock
  # both read the cursor before either appends to it, so one ticket becomes two
  # notes and two wakes.
  a="$home/out-a.txt"
  b="$home/out-b.txt"
  XO_HOME="$home" XO_CHECK_TIMEOUT=30 "$CHECK" check >"$a" 2>&1 &
  XO_HOME="$home" XO_CHECK_TIMEOUT=30 "$CHECK" check >"$b" 2>&1 &
  wait

  [ "$(count_notes "$home")" = 1 ] \
    || fail "overlapping polls must queue one note, got $(count_notes "$home"): $(cat "$a" "$b")"
  [ "$(wc -l < "$home/state/.wake-queue" | tr -d '[:space:]')" = 1 ] \
    || fail "overlapping polls must queue one wake: $(cat "$home/state/.wake-queue")"
  [ "$(wc -l < "$home/state/.paperclip-seen" | tr -d '[:space:]')" = 1 ] \
    || fail "overlapping polls must record one delivery: $(cat "$home/state/.paperclip-seen")"
  pass "xo-paperclip-check: overlapping polls deliver one ticket once"
}

test_a_reachable_board_with_nothing_waiting_stays_silent() {
  local home url issues out
  home=$(make_home quiet)
  issues="$TMP_ROOT/quiet.issues.json"
  write_issues "$issues" "$(issue_row i1 ATB-50 50 backlog agent-other 'Not mine' 'x')"
  board_conf quiet "token=\"board-token\"" "issues=\"$issues\"" 'users=1'
  url=$(start_board quiet)
  write_env "$home" "$url" board-token

  out="$home/out.txt"
  run_check "$home" "$out"
  [ ! -s "$out" ] || fail "a healthy poll with nothing waiting must stay silent: $(cat "$out")"
  [ "$(count_notes "$home")" = 0 ] || fail "a quiet poll must queue no note"
  assert_grep '/api/companies/c1/issues' "$TMP_ROOT/quiet.log" \
    "the poll really did ask the board for its issues"
  assert_grep '/api/companies/c1/user-directory' "$TMP_ROOT/quiet.log" \
    "every poll re-checks who may dispatch from the board"
  pass "xo-paperclip-check: a reachable board with nothing waiting stays silent"
}

test_a_captain_typed_note_is_still_a_captain_typed_note() {
  local home out rc=0
  home=$(make_home captain-note)
  out=$(XO_HOME="$home" "$INBOX" note "the captain typed this" 2>&1) \
    || fail "a bare note must succeed: $out"
  assert_contains "$out" "queued " "a bare note still reports what it queued"
  assert_contains "$out" "the captain typed this" "a bare note still echoes its summary"
  assert_contains "$out" "xo will pick this up" "a bare note still confirms the wake"
  assert_equals text "$(note_field "$home" source)" \
    "a bare note is still recorded as captain-typed"
  [ "$(wc -l < "$home/state/.wake-queue" | tr -d '[:space:]')" = 1 ] \
    || fail "a bare note still queues exactly one wake: $(cat "$home/state/.wake-queue")"

  out=$(XO_HOME="$home" "$INBOX" note --source 'Not A Source' body 2>&1) || rc=$?
  expect_code 1 "$rc" "an unusable note source must be refused"
  assert_contains "$out" "note source is" "the refusal says what a source may be"
  [ "$(count_notes "$home")" = 1 ] || fail "a refused source must queue no note"
  pass "xo-inbox: a bare note is still a captain-typed note, and a bad source is refused"
}

write_board_server
test_help_and_usage
test_arm_writes_and_binds_the_check_and_disarm_removes_it
test_arm_refuses_a_symlink_at_the_shim_path
test_arm_refuses_without_the_board_reader
test_a_new_assigned_ticket_becomes_exactly_one_note
test_a_shared_board_dispatches_nothing
test_an_unverifiable_membership_dispatches_nothing
test_a_plaintext_board_is_refused_rather_than_polled
test_the_key_does_not_follow_a_cross_origin_redirect
test_a_hanging_project_lookup_still_delivers_the_ticket
test_an_unreachable_instance_keeps_reporting
test_a_rejected_key_reports_the_credential_problem
test_broken_configuration_is_actionable_not_skipped
test_the_per_poll_cap_defers_the_rest_without_dropping_them
test_overlapping_polls_deliver_one_ticket_once
test_a_reachable_board_with_nothing_waiting_stays_silent
test_a_captain_typed_note_is_still_a_captain_typed_note
