#!/usr/bin/env bash
# Behavior tests for bin/xo-paperclip-check.sh, the standing Paperclip dispatch
# check, and for the reader behind it.
#
# Everything is exercised through the script's own interface. The board is a
# real HTTP server on 127.0.0.1 answering the two endpoints the reader calls,
# so the request path, the bearer header, the JSON shape, and the note the
# delivery queues are all checked for real rather than asserted against the
# implementation's source. No case contacts a Paperclip instance.
#
# The cases that matter are the contract the dispatch direction depends on:
# one assigned ticket becomes exactly one note, a second poll re-delivers
# nothing, a board that cannot be reached or whose key is rejected keeps
# reporting on a bounded cadence instead of going quiet, broken configuration
# is an actionable report, and arm/disarm leave no stray shim or binding.
set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

CHECK="$ROOT/bin/xo-paperclip-check.sh"
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

# A fake Paperclip instance: GET /api/companies/<id>/issues and
# /api/companies/<id>/projects, both behind the agent bearer token.
write_board_server() {
  cat > "$TMP_ROOT/board.py" <<'PY'
import json
import os
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer

ISSUES = sys.argv[1]
TOKEN = sys.argv[2]
PORTFILE = sys.argv[3]
LOGFILE = sys.argv[4]


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def do_GET(self):
        with open(LOGFILE, 'a', encoding='utf-8') as log:
            log.write('%s %s\n' % (self.path, self.headers.get('Authorization', '')))
        if self.headers.get('Authorization') != 'Bearer %s' % TOKEN:
            payload = json.dumps({'error': 'Unauthorized'}).encode()
            self.send_response(401)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Content-Length', str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)
            return
        if self.path.endswith('/projects'):
            body = json.dumps([{'id': 'p1', 'name': 'Onboarding'}]).encode()
        elif self.path.endswith('/issues'):
            with open(ISSUES, 'r', encoding='utf-8') as handle:
                body = handle.read().encode()
        else:
            self.send_response(404)
            self.end_headers()
            return
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)


server = HTTPServer(('127.0.0.1', 0), Handler)
with open(PORTFILE, 'w', encoding='utf-8') as handle:
    handle.write('%d\n' % server.server_address[1])
os.close(0)
server.serve_forever()
PY
}

# start_board <name> <issues-json-file> <token>: echoes the base URL.
start_board() {
  local name=$1 issues=$2 token=$3 portfile pid waited=0 port
  portfile="$TMP_ROOT/$name.port"
  rm -f -- "$portfile"
  python3 "$TMP_ROOT/board.py" "$issues" "$token" "$portfile" "$TMP_ROOT/$name.log" \
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

write_env() {  # <home> <board> <base-url> <token>
  local home=$1 board=$2 url=$3 token=$4 suffix
  suffix=$(printf '%s' "$board" | tr 'a-z-' 'A-Z_')
  {
    printf 'XO_PAPERCLIP_BOARDS=%s\n' "$board"
    printf 'XO_PAPERCLIP_%s_URL=%s\n' "$suffix" "$url"
    printf 'XO_PAPERCLIP_%s_COMPANY=c1\n' "$suffix"
    printf 'XO_PAPERCLIP_%s_AGENT=%s\n' "$suffix" "$AGENT"
    printf 'XO_PAPERCLIP_%s_KEY=board-token\n' "$suffix"
  } > "$home/.env"
}

# Pin the watcher bound and clear any ambient board configuration so each
# case's outcome comes from its own fixture .env alone.
run_check() {
  local home=$1 out=$2
  shift 2
  local status=0
  env -u XO_PAPERCLIP_BOARDS -u XO_PAPERCLIP_CHECK_BUDGET -u XO_PAPERCLIP_CHECK_MAX \
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

test_help_and_usage() {
  local out rc=0
  out=$("$CHECK" --help 2>&1) || rc=$?
  expect_code 0 "$rc" "--help must exit 0"
  assert_contains "$out" "check" "--help lists the check action"
  assert_contains "$out" "arm" "--help lists the arm action"
  assert_contains "$out" "disarm" "--help lists the disarm action"
  assert_contains "$out" "XO_PAPERCLIP_BOARDS" "--help names the board list"
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
  for lib in xo-timeout-lib.sh xo-pr-lib.sh xo-line-cap-lib.sh xo-check-lib.sh xo-inbox.sh; do
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
    "$(issue_row i3 ATB-20 20 backlog agent-other 'Someone else' 'x')"
  url=$(start_board dispatch "$issues" board-token)
  write_env "$home" atb "$url" board-token

  out="$home/out1.txt"
  run_check "$home" "$out"
  assert_contains "$(cat "$out")" "paperclip: 1 dispatched from the board: ATB-18" \
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
  assert_contains "$(cat "$home/state/.wake-queue")" "check: captain inbox note" \
    "the delivery queues one durable captain inbox wake"
  [ "$(wc -l < "$home/state/.wake-queue" | tr -d '[:space:]')" = 1 ] \
    || fail "one ticket must queue one wake: $(cat "$home/state/.wake-queue")"
  assert_contains "$(cat "$home/state/.paperclip-seen")" "atb	i1" \
    "the delivered ticket is recorded against its board"

  # The second poll is the whole point of the cursor.
  out="$home/out2.txt"
  run_check "$home" "$out"
  [ ! -s "$out" ] || fail "the same ticket must not be reported again: $(cat "$out")"
  [ "$(count_notes "$home")" = 1 ] || fail "the same ticket must not be queued again, got $(count_notes "$home")"

  assert_not_contains "$note" "ATB-19" "a closed assignment is never dispatched"
  assert_not_contains "$note" "ATB-20" "another seat's ticket is never dispatched"
  pass "xo-paperclip-check: one assigned ticket becomes exactly one note, once"
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
  write_env "$home" atb "http://127.0.0.1:$port" board-token

  out="$home/out1.txt"
  run_check "$home" "$out"
  assert_contains "$(cat "$out")" "paperclip: atb:" "an unreachable board is reported"
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
  write_issues "$issues" "$(issue_row i1 ATB-21 21 backlog "$AGENT" 'Waiting' 'x')"
  url=$(start_board rejected "$issues" the-real-token)
  write_env "$home" atb "$url" the-real-token
  # The board is reachable; this home's key is not the one it accepts.
  sed -i'' -e 's/^XO_PAPERCLIP_ATB_KEY=.*/XO_PAPERCLIP_ATB_KEY=expired-token/' "$home/.env"

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
  assert_contains "$(cat "$out")" "no boards are configured" "an unconfigured home says so"
  assert_contains "$(cat "$out")" "XO_PAPERCLIP_BOARDS" "the report names what to set"

  printf 'XO_PAPERCLIP_BOARDS=atb\nXO_PAPERCLIP_ATB_URL=http://127.0.0.1:1\n' > "$home/.env"
  out="$home/out2.txt"
  run_check "$home" "$out"
  assert_contains "$(cat "$out")" "atb is not configured" "a half-configured board is reported"
  assert_contains "$(cat "$out")" "XO_PAPERCLIP_ATB_KEY" "the report names every missing value"

  printf 'XO_PAPERCLIP_BOARDS=Not A Board\n' > "$home/.env"
  out="$home/out3.txt"
  run_check "$home" "$out"
  assert_contains "$(cat "$out")" "is not usable" "an unusable board name is reported, not skipped"
  pass "xo-paperclip-check: broken configuration is an actionable report"
}

test_each_board_keeps_its_own_cursor() {
  local home one two issues_one issues_two out
  home=$(make_home two-boards)
  issues_one="$TMP_ROOT/one.issues.json"
  issues_two="$TMP_ROOT/two.issues.json"
  write_issues "$issues_one" "$(issue_row i1 ATB-30 30 backlog "$AGENT" 'From ATB' 'a')"
  write_issues "$issues_two" "$(issue_row i1 ACME-7 7 backlog "$AGENT" 'From Acme' 'b')"
  one=$(start_board one "$issues_one" board-token)
  two=$(start_board two "$issues_two" board-token)
  {
    printf 'XO_PAPERCLIP_BOARDS=atb,acme\n'
    printf 'XO_PAPERCLIP_ATB_URL=%s\n' "$one"
    printf 'XO_PAPERCLIP_ATB_COMPANY=c1\n'
    printf 'XO_PAPERCLIP_ATB_AGENT=%s\n' "$AGENT"
    printf 'XO_PAPERCLIP_ATB_KEY=board-token\n'
    printf 'XO_PAPERCLIP_ACME_URL=%s\n' "$two"
    printf 'XO_PAPERCLIP_ACME_COMPANY=c9\n'
    printf 'XO_PAPERCLIP_ACME_AGENT=%s\n' "$AGENT"
    printf 'XO_PAPERCLIP_ACME_KEY=board-token\n'
  } > "$home/.env"

  out="$home/out1.txt"
  run_check "$home" "$out"
  assert_contains "$(cat "$out")" "ATB-30" "the first board's dispatch is delivered"
  assert_contains "$(cat "$out")" "ACME-7" "the second board's dispatch is delivered"
  [ "$(count_notes "$home")" = 2 ] || fail "two boards' dispatches must be two notes, got $(count_notes "$home")"
  # The two boards reuse the same issue id, so a cursor that were not keyed by
  # board would have suppressed one of them.
  [ "$(wc -l < "$home/state/.paperclip-seen" | tr -d '[:space:]')" = 2 ] \
    || fail "each board records its own delivery: $(cat "$home/state/.paperclip-seen")"

  out="$home/out2.txt"
  run_check "$home" "$out"
  [ ! -s "$out" ] || fail "neither board may re-deliver: $(cat "$out")"
  pass "xo-paperclip-check: each board keeps its own delivered-ticket cursor"
}

test_the_per_poll_cap_defers_the_rest_without_dropping_them() {
  local home url issues out
  home=$(make_home capped)
  issues="$TMP_ROOT/capped.issues.json"
  write_issues "$issues" \
    "$(issue_row i1 ATB-41 41 backlog "$AGENT" 'First' 'a')" \
    "$(issue_row i2 ATB-42 42 backlog "$AGENT" 'Second' 'b')" \
    "$(issue_row i3 ATB-43 43 backlog "$AGENT" 'Third' 'c')"
  url=$(start_board capped "$issues" board-token)
  write_env "$home" atb "$url" board-token

  out="$home/out1.txt"
  run_check "$home" "$out" XO_PAPERCLIP_CHECK_MAX=2
  assert_contains "$(cat "$out")" "2 dispatched from the board: ATB-41, ATB-42" \
    "the cap bounds one poll and keeps the oldest tickets first"
  [ "$(count_notes "$home")" = 2 ] || fail "the cap must bound the notes, got $(count_notes "$home")"

  out="$home/out2.txt"
  run_check "$home" "$out" XO_PAPERCLIP_CHECK_MAX=2
  assert_contains "$(cat "$out")" "1 dispatched from the board: ATB-43" \
    "the deferred ticket arrives on the next poll rather than being dropped"
  [ "$(count_notes "$home")" = 3 ] || fail "every ticket must arrive eventually, got $(count_notes "$home")"
  pass "xo-paperclip-check: the per-poll cap defers the rest without dropping them"
}

test_a_reachable_board_with_nothing_waiting_stays_silent() {
  local home url issues out
  home=$(make_home quiet)
  issues="$TMP_ROOT/quiet.issues.json"
  write_issues "$issues" "$(issue_row i1 ATB-50 50 backlog agent-other 'Not mine' 'x')"
  url=$(start_board quiet "$issues" board-token)
  write_env "$home" atb "$url" board-token

  out="$home/out.txt"
  run_check "$home" "$out"
  [ ! -s "$out" ] || fail "a healthy poll with nothing waiting must stay silent: $(cat "$out")"
  [ "$(count_notes "$home")" = 0 ] || fail "a quiet poll must queue no note"
  assert_contains "$(cat "$TMP_ROOT/quiet.log")" "/api/companies/c1/issues" \
    "the poll really did ask the board for its issues"
  pass "xo-paperclip-check: a reachable board with nothing waiting stays silent"
}

write_board_server
test_help_and_usage
test_arm_writes_and_binds_the_check_and_disarm_removes_it
test_arm_refuses_a_symlink_at_the_shim_path
test_arm_refuses_without_the_board_reader
test_a_new_assigned_ticket_becomes_exactly_one_note
test_an_unreachable_instance_keeps_reporting
test_a_rejected_key_reports_the_credential_problem
test_broken_configuration_is_actionable_not_skipped
test_each_board_keeps_its_own_cursor
test_the_per_poll_cap_defers_the_rest_without_dropping_them
test_a_reachable_board_with_nothing_waiting_stays_silent
