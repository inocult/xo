#!/usr/bin/env bash
# xo-paperclip-check.sh - recurring Paperclip dispatch poll as a standing check.
#
# Usage:
#   xo-paperclip-check.sh [check]
#   xo-paperclip-check.sh arm
#   xo-paperclip-check.sh disarm
#   xo-paperclip-check.sh --help
#
# The intake half of the board link. A ticket the captain assigns to this home's
# own agent seat becomes a captain inbox note through bin/xo-inbox.sh, so a
# dispatch made on the board arrives the same way an out-of-band note does and
# is presented at xo's next drain. Writing ticket state back to the board is
# NOT this script's business and never happens here: an agent key cannot write
# at all (Paperclip binds agent writes to a heartbeat run it started).
#
# `arm` writes state/paperclip.check.sh and binds its bytes with
# xo-check-register.sh, so the watcher dispatches it on its normal
# XO_CHECK_INTERVAL cadence and turns its one line into a `check:` wake.
# `disarm` removes the shim, its trust binding, and the report record.
#
# Board configuration is read from the home's own gitignored .env, so arming
# needs no configuration of its own and a home can be armed before its boards
# are wired. See docs/configuration.md "Paperclip dispatch intake" for the
# schema: XO_PAPERCLIP_BOARDS names the boards, and each board contributes
# XO_PAPERCLIP_<BOARD>_URL, _COMPANY, _AGENT, and _KEY. More than one board is
# the normal case, because one captain works across organizations and each has
# its own instance.
#
# DELIVERED EXACTLY ONCE, AND NEVER LOST. state/.paperclip-seen is the durable
# per-board cursor of delivered ticket ids. Delivery writes the note FIRST and
# records the cursor after, deliberately: a crash between the two costs one
# duplicate note naming the same ticket, which xo can see for what it is,
# while recording first would let the same crash drop a dispatch with nothing
# anywhere to recover it from. A cursor that cannot be written is reported, so
# the duplicate is never a silent surprise.
#
# REPORTS KEEP REPORTING. A board that cannot be reached, or whose key is
# rejected, is the failure that matters most here, because the captain's
# dispatch then sits on the board looking sent. So unlike a one-shot news key,
# an unchanged failure is re-reported every XO_PAPERCLIP_CHECK_REREPORT seconds
# (default 1800, valid 60..86400) rather than going quiet after the first line.
# A poll that delivered anything always prints, so the watcher wakes to drain
# the notes the delivery queued. A healthy poll with nothing waiting is the
# only silence.
#
# A malformed board list, a board missing one of its four values, and an
# unreadable cursor are all actionable conditions, reported on that same
# cadence rather than skipped.
#
# The poll must finish inside the watcher's per-check bound (XO_CHECK_TIMEOUT,
# default 30, read from this check's own environment because the watcher runs
# it as a direct child). The internal budget XO_PAPERCLIP_CHECK_BUDGET
# (default 15, valid 5..25) is cut down to whatever fits inside that bound and
# then split across the configured boards, so one unreachable instance cannot
# spend another board's share. XO_PAPERCLIP_CHECK_MAX (default 10, valid
# 1..100) bounds the notes one poll may queue per board; the rest arrive on the
# next poll, which keeps the wake queue bounded without dropping a dispatch.
set -u
export LC_ALL=C

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
XO_HOME="${XO_HOME:-${XO_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/.." && pwd)}}"
STATE="${XO_STATE_OVERRIDE:-$XO_HOME/state}"
RECORD="$STATE/.paperclip-check"
SEEN="$STATE/.paperclip-seen"
CHECK_ID=paperclip
CHECK_SHIM="$STATE/$CHECK_ID.check.sh"
CHECK_TRUST="$STATE/$CHECK_ID.check-trust"
API_BIN="$SCRIPT_DIR/xo-paperclip-api.py"
INBOX_BIN="$SCRIPT_DIR/xo-inbox.sh"
REGISTER_BIN="$SCRIPT_DIR/xo-check-register.sh"
RECORD_SCHEMA=xo-paperclip-check-v1
MAX_LINE=240
ENV_FILE="$XO_HOME/.env"

# shellcheck source=bin/xo-timeout-lib.sh
. "$SCRIPT_DIR/xo-timeout-lib.sh"
# shellcheck source=bin/xo-pr-lib.sh
. "$SCRIPT_DIR/xo-pr-lib.sh"
# shellcheck source=bin/xo-line-cap-lib.sh
. "$SCRIPT_DIR/xo-line-cap-lib.sh"
# shellcheck source=bin/xo-check-lib.sh
. "$SCRIPT_DIR/xo-check-lib.sh"

usage() {
  cat <<'EOF'
Usage:
  xo-paperclip-check.sh [check]   poll every configured board; one line when xo should wake
  xo-paperclip-check.sh arm       write and register state/paperclip.check.sh
  xo-paperclip-check.sh disarm    remove the check shim, its trust binding, and the record
  xo-paperclip-check.sh --help    print this help

Board configuration lives in <XO_HOME>/.env, which is gitignored:

  XO_PAPERCLIP_BOARDS=atb,acme          comma- or space-separated board names
  XO_PAPERCLIP_ATB_URL=https://...      instance base URL
  XO_PAPERCLIP_ATB_COMPANY=<uuid>       company id (the UUID, not the ATB prefix)
  XO_PAPERCLIP_ATB_AGENT=<uuid>         this home's agent seat id
  XO_PAPERCLIP_ATB_KEY=pcp_...          agent API key for that seat

A board name is lowercase letters, digits, hyphen, or underscore; its variables
use the uppercased name with hyphens as underscores. The key is never printed.
See docs/configuration.md "Paperclip dispatch intake" for the schema.
EOF
}

die_usage() {
  printf 'xo-paperclip-check: %s\n' "$1" >&2
  usage >&2
  exit 2
}

record_epoch_now() {
  case "${XO_PAPERCLIP_CHECK_NOW:-}" in
    ''|*[!0-9]*) date +%s ;;
    *) printf '%s\n' "$XO_PAPERCLIP_CHECK_NOW" ;;
  esac
}

CHECK_TIMEOUT=${XO_CHECK_TIMEOUT:-30}
case "$CHECK_TIMEOUT" in
  ''|*[!0-9]*|0) CHECK_TIMEOUT=30 ;;
esac

BUDGET_SECS=${XO_PAPERCLIP_CHECK_BUDGET:-15}
case "$BUDGET_SECS" in
  ''|*[!0-9]*|0)
    printf 'xo-paperclip-check: XO_PAPERCLIP_CHECK_BUDGET must be a whole number from 5 to 25\n' >&2
    exit 2
    ;;
esac
if [ "$BUDGET_SECS" -lt 5 ] || [ "$BUDGET_SECS" -gt 25 ]; then
  printf 'xo-paperclip-check: XO_PAPERCLIP_CHECK_BUDGET must be a whole number from 5 to 25\n' >&2
  exit 2
fi

# xo_run_timed counts a whole second before it alarms, so the budget has to fit
# inside the watcher's own bound with the alarm and kill margins left over.
BUDGET_MAX=$((CHECK_TIMEOUT - 3))
[ "$BUDGET_MAX" -ge 1 ] || BUDGET_MAX=1
if [ "$BUDGET_SECS" -gt "$BUDGET_MAX" ]; then
  BUDGET_SECS=$BUDGET_MAX
fi

PER_POLL_MAX=${XO_PAPERCLIP_CHECK_MAX:-10}
case "$PER_POLL_MAX" in
  ''|*[!0-9]*|0) PER_POLL_MAX=10 ;;
esac
[ "$PER_POLL_MAX" -le 100 ] || PER_POLL_MAX=100

REREPORT_SECS=${XO_PAPERCLIP_CHECK_REREPORT:-1800}
case "$REREPORT_SECS" in
  ''|*[!0-9]*|0) REREPORT_SECS=1800 ;;
esac
if [ "$REREPORT_SECS" -lt 60 ] || [ "$REREPORT_SECS" -gt 86400 ]; then
  REREPORT_SECS=1800
fi

# --- configuration --------------------------------------------------------

# One KEY=VALUE from a .env-style file, tolerating a leading "export ",
# surrounding whitespace, and one layer of matching quotes. An already-set
# environment value wins, matching the mail-plane and Relay contract.
env_get() {
  local key=$1 file=$2 line val
  if [ -n "${!key:-}" ]; then
    printf '%s' "${!key}"
    return 0
  fi
  [ -f "$file" ] || return 0
  line=$(grep -E "^[[:space:]]*(export[[:space:]]+)?${key}=" "$file" 2>/dev/null | tail -n1) || return 0
  [ -n "$line" ] || return 0
  val=${line#*=}
  val=${val#"${val%%[![:space:]]*}"}
  val=${val%"${val##*[![:space:]]}"}
  case "$val" in
    \"*\") val=${val#\"}; val=${val%\"} ;;
    \'*\') val=${val#\'}; val=${val%\'} ;;
  esac
  printf '%s' "$val"
}

# The variable suffix for a board name: uppercased, hyphens as underscores.
board_suffix() {
  printf '%s' "$1" | tr 'a-z-' 'A-Z_'
}

board_valid() {
  case "$1" in
    ''|*[!a-z0-9_-]*) return 1 ;;
  esac
  [ "${#1}" -le 32 ]
}

# --- cursor ---------------------------------------------------------------

# Already-delivered ticket ids for one board, as the lines the reader filters on.
SEEN_SLICE=
seen_slice_for() {
  local board=$1
  SEEN_SLICE=$(mktemp "$STATE/.xo-paperclip-seen.XXXXXX" 2>/dev/null) || return 1
  chmod 0600 "$SEEN_SLICE" 2>/dev/null || { rm -f -- "$SEEN_SLICE"; SEEN_SLICE=; return 1; }
  if [ -f "$SEEN" ]; then
    awk -F'\t' -v b="$board" '$1 == b { print $2 }' "$SEEN" >> "$SEEN_SLICE" 2>/dev/null \
      || { rm -f -- "$SEEN_SLICE"; SEEN_SLICE=; return 1; }
  fi
  return 0
}

# Record one ticket as delivered. Called only AFTER its note is on disk, so a
# failure here costs a duplicate note rather than a dropped dispatch.
seen_record() {
  local board=$1 issue=$2
  ( umask 077; printf '%s\t%s\n' "$board" "$issue" >> "$SEEN" ) 2>/dev/null || return 1
  chmod 0600 "$SEEN" 2>/dev/null || :
  return 0
}

# --- poll -----------------------------------------------------------------

DELIVERED_COUNT=0
DELIVERED_NAMES=
FINDINGS=

add_finding() {
  if [ -z "$FINDINGS" ]; then
    FINDINGS=$1
  else
    FINDINGS="$FINDINGS; $1"
  fi
}

# The reader's own one-line diagnostic, preferred over any backtrace it may
# have produced, with a truth-stating fallback so a silent failure still reads
# as a failure.
reader_summary() {
  local rc=$1 err=$2 line
  line=$(printf '%s\n' "$err" | sed -n 's/^xo-paperclip: //p' | head -n 1)
  if [ -z "$line" ]; then
    line=$(printf '%s\n' "$err" | sed -n '/^$/d; p' | tail -n 1)
  fi
  if [ -z "$line" ]; then
    line="read failed (rc=$rc)"
  fi
  printf '%s\n' "$line"
}

# Poll one board: list its dispatched tickets, queue a note for each, and record
# each one as delivered only once its note exists.
poll_board() {
  local board=$1 slice=$2 budget=$3
  local suffix url company agent key missing=
  suffix=$(board_suffix "$board")
  url=$(env_get "XO_PAPERCLIP_${suffix}_URL" "$ENV_FILE")
  company=$(env_get "XO_PAPERCLIP_${suffix}_COMPANY" "$ENV_FILE")
  agent=$(env_get "XO_PAPERCLIP_${suffix}_AGENT" "$ENV_FILE")
  key=$(env_get "XO_PAPERCLIP_${suffix}_KEY" "$ENV_FILE")
  [ -n "$url" ] || missing="$missing XO_PAPERCLIP_${suffix}_URL"
  [ -n "$company" ] || missing="$missing XO_PAPERCLIP_${suffix}_COMPANY"
  [ -n "$agent" ] || missing="$missing XO_PAPERCLIP_${suffix}_AGENT"
  [ -n "$key" ] || missing="$missing XO_PAPERCLIP_${suffix}_KEY"
  if [ -n "$missing" ]; then
    add_finding "$board is not configured, missing:${missing}"
    return 0
  fi

  local outdir rc=0 out err
  outdir=$(mktemp -d "$STATE/.xo-paperclip-notes.XXXXXX" 2>/dev/null) || {
    add_finding "$board could not stage notes under $STATE"
    return 0
  }
  err="$outdir/.stderr"
  out=$(
    XO_PAPERCLIP_API_URL="$url" \
    XO_PAPERCLIP_API_COMPANY="$company" \
    XO_PAPERCLIP_API_AGENT="$agent" \
    XO_PAPERCLIP_API_KEY="$key" \
    XO_PAPERCLIP_API_SEEN="$slice" \
    XO_PAPERCLIP_API_TIMEOUT="$budget" \
    XO_PAPERCLIP_API_MAX="$PER_POLL_MAX" \
    xo_run_timed "$((budget + 2))" python3 "$API_BIN" "$outdir" 2>"$err"
  ) || rc=$?
  if [ "$rc" -eq 124 ]; then
    rm -rf -- "$outdir"
    add_finding "$board did not answer within ${budget}s"
    return 0
  fi
  if [ "$rc" -ne 0 ]; then
    add_finding "$board: $(reader_summary "$rc" "$(cat "$err" 2>/dev/null)")"
    rm -rf -- "$outdir"
    return 0
  fi

  local issue identifier path
  while IFS=$'\t' read -r _kind issue identifier path; do
    [ -n "${issue:-}" ] && [ -n "${path:-}" ] || continue
    if ! "$INBOX_BIN" note - < "$path" >/dev/null 2>&1; then
      add_finding "$board could not queue the note for ${identifier:-$issue}"
      break
    fi
    DELIVERED_COUNT=$((DELIVERED_COUNT + 1))
    if [ -z "$DELIVERED_NAMES" ]; then
      DELIVERED_NAMES="${identifier:-$issue}"
    else
      DELIVERED_NAMES="$DELIVERED_NAMES, ${identifier:-$issue}"
    fi
    if ! seen_record "$board" "$issue"; then
      add_finding "${identifier:-$issue} was queued but not recorded as delivered, so it may arrive twice"
    fi
  done <<< "$out"
  rm -rf -- "$outdir"
  return 0
}

# --- report record --------------------------------------------------------

RECORD_REPORTED=
RECORD_REPORTED_AT=0

record_read() {
  local line first=1
  RECORD_REPORTED=
  RECORD_REPORTED_AT=0
  [ -f "$RECORD" ] || return 0
  while IFS= read -r line; do
    if [ "$first" = 1 ]; then
      first=0
      [ "$line" = "$RECORD_SCHEMA" ] || return 0
      continue
    fi
    case "$line" in
      reported=*) RECORD_REPORTED=${line#reported=} ;;
      reported_at=*)
        RECORD_REPORTED_AT=${line#reported_at=}
        case "$RECORD_REPORTED_AT" in ''|*[!0-9]*) RECORD_REPORTED_AT=0 ;; esac
        ;;
    esac
  done < "$RECORD"
  return 0
}

record_write() {
  local reported=$1 reported_at=$2 tmp
  tmp=$(mktemp "$RECORD.XXXXXX" 2>/dev/null) || return 1
  chmod 0600 "$tmp" 2>/dev/null || { rm -f -- "$tmp"; return 1; }
  {
    printf '%s\n' "$RECORD_SCHEMA"
    printf 'epoch=%s\n' "$(record_epoch_now)"
    printf 'reported=%s\n' "$reported"
    printf 'reported_at=%s\n' "$reported_at"
  } > "$tmp" || { rm -f -- "$tmp"; return 1; }
  mv -f -- "$tmp" "$RECORD" || { rm -f -- "$tmp"; return 1; }
  return 0
}

action_check() {
  local boards_raw boards board count slice line now share
  mkdir -p "$STATE" || return 1

  if [ ! -r "$API_BIN" ]; then
    FINDINGS="the board reader is missing next to this check ($API_BIN)"
  elif [ ! -x "$INBOX_BIN" ]; then
    FINDINGS="the captain inbox is missing next to this check ($INBOX_BIN)"
  elif ! command -v python3 >/dev/null 2>&1; then
    FINDINGS="python3 is not on PATH, so no board can be read"
  else
    boards_raw=$(env_get XO_PAPERCLIP_BOARDS "$ENV_FILE")
    boards=$(printf '%s' "$boards_raw" | tr ',;' '  ')
    count=0
    for board in $boards; do
      count=$((count + 1))
    done
    if [ "$count" -eq 0 ]; then
      FINDINGS="no boards are configured; set XO_PAPERCLIP_BOARDS in $ENV_FILE"
    else
      share=$((BUDGET_SECS / count))
      [ "$share" -ge 3 ] || share=3
      for board in $boards; do
        if ! board_valid "$board"; then
          add_finding "board name \"$board\" is not usable (lowercase letters, digits, hyphen, or underscore)"
          continue
        fi
        if ! seen_slice_for "$board"; then
          add_finding "$board could not read the delivered-ticket record ($SEEN)"
          continue
        fi
        slice=$SEEN_SLICE
        poll_board "$board" "$slice" "$share"
        rm -f -- "$slice"
        SEEN_SLICE=
      done
    fi
  fi

  line=
  if [ "$DELIVERED_COUNT" -gt 0 ]; then
    line="$DELIVERED_COUNT dispatched from the board: $DELIVERED_NAMES"
  fi
  if [ -n "$FINDINGS" ]; then
    if [ -n "$line" ]; then
      line="$line; $FINDINGS"
    else
      line=$FINDINGS
    fi
  fi

  record_read
  now=$(record_epoch_now)
  # Report before recording, so a record that cannot be written costs a
  # repeated report rather than a lost one. A delivery always prints, because
  # the notes it queued need a wake; an unchanged finding prints again once the
  # re-report window has passed, so a dispatch never sits behind a quiet poll.
  if [ -n "$line" ]; then
    if [ "$DELIVERED_COUNT" -gt 0 ] || [ "$line" != "$RECORD_REPORTED" ] \
      || [ "$((now - RECORD_REPORTED_AT))" -ge "$REREPORT_SECS" ]; then
      xo_cap_line_var "paperclip: $line" "$MAX_LINE"
      printf '%s\n' "$XO_LINE_CAP_LINE"
      record_write "$line" "$now" || true
      return 0
    fi
    return 0
  fi
  # A healthy, empty poll clears the news key so the next finding is news again.
  if [ -n "$RECORD_REPORTED" ] || [ ! -f "$RECORD" ]; then
    record_write "" "$now" || true
  fi
  return 0
}

# The home is embedded already resolved, because the watcher runs the shim from
# its own working directory and a relative spelling would send the check to a
# different home, or to none at all.
shim_content() {
  local home=$1
  printf '%s\n' \
    '#!/usr/bin/env bash' \
    '# Auto-generated by xo-paperclip-check.sh - Paperclip dispatch poll shim.' \
    '# The watcher validates these bytes, then dispatches the trusted check script.' \
    "export XO_HOME=$(printf '%q' "$home")" \
    "exec $(printf '%q' "$SCRIPT_DIR/xo-paperclip-check.sh") check"
}

# Write the shim the way this repo writes its other trusted check shims: the
# guards run before anything is written, so a symlink at the shim path is
# refused instead of followed, and the bytes arrive by rename so the watcher
# never reads a half-written shim and rejects it as unauthenticated.
SHIM_WRITE_TMP=

shim_write() {
  local want=$1 device tmp
  [ -d "$STATE" ] && [ ! -L "$STATE" ] || return 1
  device=$(xo_pr_file_device "$STATE") || return 1
  [ -n "$device" ] || return 1
  xo_pr_regular_destination_on_device_or_absent "$CHECK_SHIM" "$device" || return 1
  if [ -e "$CHECK_SHIM" ] && [ "$(xo_pr_file_mode "$CHECK_SHIM")" = 700 ] \
    && [ "$(cat "$CHECK_SHIM" 2>/dev/null)" = "$want" ]; then
    return 0
  fi
  tmp=$(umask 077; mktemp "$STATE/.xo-paperclip-check.XXXXXX" 2>/dev/null) || return 1
  SHIM_WRITE_TMP=$tmp
  if ! printf '%s\n' "$want" > "$tmp" \
    || ! chmod 0700 "$tmp" \
    || ! xo_pr_private_file_valid "$tmp" 700 "$device"; then
    rm -f -- "$tmp"
    SHIM_WRITE_TMP=
    return 1
  fi
  if ! xo_pr_regular_destination_on_device_or_absent "$CHECK_SHIM" "$device" \
    || ! mv -f -- "$tmp" "$CHECK_SHIM"; then
    rm -f -- "$tmp"
    SHIM_WRITE_TMP=
    return 1
  fi
  SHIM_WRITE_TMP=
  xo_pr_private_file_valid "$CHECK_SHIM" 700 "$device"
}

# Keep a byte copy of a shim that is already in place, so a failed arm can put
# back the shim a working home was already using rather than an equivalent
# rewrite. The trust binding is over the bytes, so a rewrite would satisfy it
# too, but a home that was armed stays armed with what it had.
shim_backup() {
  local device tmp
  device=$(xo_pr_file_device "$STATE") || return 1
  [ -n "$device" ] || return 1
  tmp=$(umask 077; mktemp "$STATE/.xo-paperclip-check.XXXXXX" 2>/dev/null) || return 1
  if ! cat "$CHECK_SHIM" > "$tmp" 2>/dev/null \
    || ! chmod 0700 "$tmp" \
    || ! xo_pr_private_file_valid "$tmp" 700 "$device"; then
    rm -f -- "$tmp"
    return 1
  fi
  printf '%s\n' "$tmp"
}

ARM_BACKUP=

# An unregistered shim is not inert: the watcher rejects it on every cycle and
# wakes xo about unauthenticated state checks. So the one rule after a failed or
# interrupted arm is that the home never holds a shim without a matching trust
# binding. The shim a working home had is put back and kept only when it is
# still bound; otherwise the shim goes, so the home is plainly not armed and the
# failure is the only thing the operator has to act on.
arm_rollback() {
  [ -z "$SHIM_WRITE_TMP" ] || rm -f -- "$SHIM_WRITE_TMP"
  SHIM_WRITE_TMP=
  if [ -n "$ARM_BACKUP" ]; then
    mv -f -- "$ARM_BACKUP" "$CHECK_SHIM" 2>/dev/null || rm -f -- "$ARM_BACKUP"
    ARM_BACKUP=
    if xo_custom_check_registered "$STATE" "$CHECK_ID"; then
      return 0
    fi
  fi
  rm -f -- "$CHECK_SHIM"
}

# shellcheck disable=SC2329  # Registered by action_arm's signal trap.
arm_interrupted() {
  arm_rollback
  printf 'xo-paperclip-check: arming was interrupted, so state/%s.check.sh is not armed\n' "$CHECK_ID" >&2
  exit 1
}

action_arm() {
  local want home
  if [ ! -r "$API_BIN" ]; then
    printf 'xo-paperclip-check: the board reader is missing at %s; cannot arm\n' "$API_BIN" >&2
    return 1
  fi
  if [ ! -x "$INBOX_BIN" ]; then
    printf 'xo-paperclip-check: the captain inbox is missing at %s; cannot arm\n' "$INBOX_BIN" >&2
    return 1
  fi
  mkdir -p "$STATE" || return 1
  case "$XO_HOME" in
    /*) home=$XO_HOME ;;
    *)
      home=$(CDPATH='' cd -- "$XO_HOME" 2>/dev/null && pwd -P) || {
        printf 'xo-paperclip-check: cannot resolve XO_HOME %s\n' "$XO_HOME" >&2
        return 1
      }
      ;;
  esac
  want=$(shim_content "$home")
  ARM_BACKUP=
  if [ -f "$CHECK_SHIM" ] && [ ! -L "$CHECK_SHIM" ]; then
    ARM_BACKUP=$(shim_backup) || {
      printf 'xo-paperclip-check: could not save the existing %s\n' "$CHECK_SHIM" >&2
      return 1
    }
  fi
  # The shim exists unbound from the rename until the register returns, so a
  # signal in that window rolls back the same way a failure does.
  trap arm_interrupted HUP INT TERM
  if ! shim_write "$want"; then
    trap - HUP INT TERM
    arm_rollback
    printf 'xo-paperclip-check: could not write %s\n' "$CHECK_SHIM" >&2
    return 1
  fi
  if ! XO_HOME="$home" "$REGISTER_BIN" "$CHECK_ID" >/dev/null; then
    trap - HUP INT TERM
    arm_rollback
    printf 'xo-paperclip-check: could not register %s\n' "$CHECK_SHIM" >&2
    return 1
  fi
  trap - HUP INT TERM
  [ -z "$ARM_BACKUP" ] || rm -f -- "$ARM_BACKUP"
  ARM_BACKUP=
  printf 'armed: state/%s.check.sh\n' "$CHECK_ID"
  return 0
}

# The delivered-ticket cursor deliberately survives a disarm, so re-arming a
# home does not re-deliver every ticket already on its seat.
action_disarm() {
  rm -f -- "$CHECK_SHIM" "$CHECK_TRUST" "$RECORD"
  printf 'disarmed: state/%s.check.sh\n' "$CHECK_ID"
  return 0
}

case "${1:-check}" in
  check) action_check ;;
  arm) action_arm ;;
  disarm) action_disarm ;;
  -h|--help) usage ;;
  *) die_usage "unknown action: $1" ;;
esac
