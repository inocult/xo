#!/usr/bin/env bash
# xo-estate-review.sh - read-only estate review with a fixed report shape.
#
# Reviews an engineering estate - a GitHub organization or one of its
# repositories - over a bounded collection window and prints a status report whose
# sections, headings, and order are identical on every run against every estate.
# That fixed shape is the point: a reader who has read one of these reports can
# read any other without re-learning where to look, and two reports of the same
# estate taken at different times are directly comparable.
#
# The shape is enforced by construction. The renderer emits all nine sections
# unconditionally; a surface with no data prints an explicit "none in the window"
# statement rather than disappearing. A missing section and an empty section read
# identically to a human and only one of them is honest, so a section is never
# dropped. Every report states its estate scope, its collection window, and the
# template of every read it made, so a figure can be traced to the read that
# produced it and two reports can be compared line for line.
#
# READ-ONLY. It observes an estate and never writes to one: no push, no comment,
# no label, no issue, no merge. The only filesystem writes are inside a private
# temporary directory this script creates and removes, used for request bodies.
#
# It reports on people, and stays factual about the work: contribution counts,
# review participation, and ownership concentration. It does not rank individuals,
# score productivity, or infer anyone's effort or worth. The person table is
# sorted by account name, never by volume, so it cannot be read as a leaderboard.
# Section 8 of every report states what the numbers do not measure.
#
# Usage:
#   bin/xo-estate-review.sh <org> [flags]              every repository the org owns
#   bin/xo-estate-review.sh <owner>/<repo> [flags]     one repository
#   bin/xo-estate-review.sh --from-json <file>         render a stored model, no network
#
# An organization review is a per-repository review plus an aggregate; a single
# repository review is the same report with one repository in it.
#
# Flags:
#   --since <YYYY-MM-DD>     window start (default: --window days before --until)
#   --until <YYYY-MM-DD>     window end, exclusive of later data (default: today, UTC)
#   --window <days>          window length when --since is absent (default 90)
#   --periods <n>            equal periods the window is split into for trend (default 6)
#   --stalled-days <n>       an open pull request idle this long is stalled (default 14)
#   --unmaintained-days <n>  a repository unpushed this long is unmaintained (default 180)
#   --max-repos <n>          cap repositories reviewed, 0 for no cap (default 100)
#   --max-prs <n>            cap pull requests read per repository, 0 for no cap (default 300)
#   --max-listed <n>         cap rows in the risk lists, 0 for no cap (default 15)
#   --include-forks          include forked repositories (default: excluded)
#   --exclude-archived       drop archived repositories (default: included and labeled)
#   --json                   print the derived model instead of the report
#   --from-json <file>       render the report from a stored model, making no network call
#   -h, --help               usage
#
# Model contract: `xo-estate-review.v1`. --json prints it; --from-json renders a
# report from it. The derived model carries every number the report prints, so the
# renderer performs no arithmetic and a model and its report cannot disagree.
#
# WHICH FLAGS --from-json ACCEPTS, and why each one lands where it does. A stored
# model is a finished collection, so a flag is honoured there only when the model
# already holds everything it needs and the flag changes nothing but presentation:
#   --max-listed   honoured; the model keeps every risk row and only the report is
#                  bounded, so raising it shows rows already in hand
#   --json         honoured; it re-emits the stored model itself
# Every other flag is refused by name rather than silently ignored, because each
# one decides what gets collected or how a figure is derived, and neither can be
# redone from a model:
#   --since --until --window --periods       choose the window and its periods, and
#                                            the per-period tallies are already cut
#   --max-repos --max-prs                    bound what collection read at all
#   --include-forks --exclude-archived       choose which repositories were reviewed
#   --stalled-days                           filtered the stalled list at derivation,
#                                            so a lower threshold cannot restore rows
#   --unmaintained-days                      likewise filtered the unmaintained list;
#                                            re-deriving it here would leave the report
#                                            disagreeing with the model it came from
#
# XO_ESTATE_REVIEW_NOW overrides the collection clock (ISO 8601 UTC), the same
# injected-clock contract bin/xo-fleet-snapshot.sh uses, so a run is reproducible.
#
# DATA SOURCES, and what each figure does and does not evidence:
#   gh-axi api                 repository metadata, commits on the default branch,
#                              open issues, and GitHub Actions workflow runs
#   gh-axi api POST graphql    pull requests with their reviews and review threads
# No figure is ever estimated or extrapolated: a surface the estate does not
# expose is reported as not exposed, and every collection bound this run hit is
# named in section 9.2 rather than quietly shortening a figure.
#
# WHICH CLOCK EVERY FIGURE IS MEASURED AGAINST. Two clocks exist here and they
# are not interchangeable: the WINDOW, which bounds events by when they happened,
# and COLLECTION (XO_ESTATE_REVIEW_NOW, printed as the report's Generated line),
# which is when the estate was read. An event has a date and belongs to the
# window. A state - what is open, what has been pushed, what is archived - is
# only true as of the read, so measuring it against the window end would produce
# a negative age on any window that ended before today. Every figure the report
# prints is below, with the clock it uses and where its label says so.
#
#   Figure                                             Clock       Labelled where
#   Repositories matched / reviewed / read             collection  header bullet
#   Generated at                                       collection  header bullet
#   Window since, until, days, periods                 window      header bullet
#   Headline: merged, cycle time, reviewed share,      window      section 1
#     CI latest-attempt rate, concentrated repos
#   Person counts: commits, opened, merged, reviews    window      section 1, 3.1
#     submitted, pull requests reviewed, repositories
#   Automation flag                                    collection  section 1
#   Per-period commit / opened / merged tallies        window      section 4.1
#   Cycle time and review latency, all statistics      window      sections 4.2, 4.3
#   Reverts, hotfixes, and their denominator           window      section 5.1
#   Change size and its distribution                   window      section 5.2
#   Review coverage and review threads                 window      section 5.3
#   CI runs, pass rate, attempts                       window      section 5.4
#   Concentration, accounts covering half              window      sections 1, 6.1
#   Days since last push, archived flag                collection  sections 1, 6.2, 7
#   Open pull request and open issue counts            collection  sections 1, 6.3, 7
#   Stalled set, its idle days and age days            collection  sections 1, 6.3
#   Oldest open issue age (model only)                 collection  this table
#   Repository set, default branch, read statuses,     collection  section 9
#     caps, and the recorded commands
#
# The stalled list and the unmaintained list are collection-time throughout: the
# set is what GitHub reports open or unpushed when the read runs, so its ages are
# measured from the same read rather than from the window end, and their sections
# say so rather than sitting unlabelled beside the window figures.
#
# gh-axi ENVELOPE COUPLING. gh-axi renders every response for an agent to read,
# so this script asks for a shaped tab-separated payload with --jq and decodes the
# one rendered envelope field that carries it. That coupling lives in exactly one
# function, gh_read, which refuses loudly with the installed gh-axi version rather
# than degrading to empty data when the envelope is not the shape it knows.
# tests/xo-estate-review.test.sh pins the decode against a fake gh-axi, and
# tests/xo-estate-review-live-e2e.test.sh proves the real gh-axi still emits it.
set -u

SCRIPT_NAME=xo-estate-review.sh
CONTRACT=xo-estate-review.v1
# The record separator, spelled once. `\t` inside a sed or grep expression is a
# GNU extension that BSD sed reads as a literal `t`, so a pattern written that
# way matches nothing on macOS and every record passes through unprefixed. This
# script supports both platforms, so no expression in it spells a tab any other
# way. jq and awk -F own their own escape and are unaffected.
TAB=$(printf '\t')

die() {
  printf '%s: %s\n' "$SCRIPT_NAME" "$1" >&2
  exit "${2:-1}"
}

usage() {
  cat <<'EOF'
usage: xo-estate-review.sh <org|owner/repo> [flags]
       xo-estate-review.sh --from-json <file>

Read-only estate review. Prints the same nine sections in the same order for
every estate; a surface with no data is stated as empty, never omitted.

  --since <YYYY-MM-DD>     window start (default: --window days before --until)
  --until <YYYY-MM-DD>     window end (default: today, UTC)
  --window <days>          window length when --since is absent (default 90)
  --periods <n>            equal periods the window is split into for trend (default 6)
  --stalled-days <n>       an open pull request idle this long is stalled (default 14)
  --unmaintained-days <n>  a repository unpushed this long is unmaintained (default 180)
  --max-repos <n>          cap repositories reviewed, 0 for no cap (default 100)
  --max-prs <n>            cap pull requests read per repository, 0 for no cap (default 300)
  --max-listed <n>         cap rows in the risk lists, 0 for no cap (default 15)
  --include-forks          include forked repositories (default: excluded)
  --exclude-archived       drop archived repositories (default: included and labeled)
  --json                   print the derived model (contract xo-estate-review.v1)
  --from-json <file>       render the report from a stored model, making no network call
  -h, --help               this usage

With --from-json only --max-listed and --json apply, because they change how a
stored model is presented rather than what was collected. Any other flag is
refused by name: it needs a fresh collection.

It never writes to the estate it reviews.
EOF
}

SCOPE_ARG=
SINCE=
UNTIL=
WINDOW_DAYS=90
PERIODS=6
STALLED_DAYS=14
UNMAINTAINED_DAYS=180
MAX_REPOS=100
MAX_PRS=300
MAX_LISTED=15
INCLUDE_FORKS=0
EXCLUDE_ARCHIVED=0
OUTPUT=report
FROM_JSON=
FLAGS_GIVEN=()
MAX_LISTED_GIVEN=0

need_value() {
  [ "$2" -gt 1 ] || die "$1 needs a value" 2
}

validate_uint() {  # <flag> <value> [min]
  case "$2" in
    '' | *[!0-9]*) die "$1 must be a non-negative integer, got '$2'" 2 ;;
  esac
  if [ -n "${3:-}" ] && [ "$2" -lt "$3" ]; then
    die "$1 must be at least $3, got '$2'" 2
  fi
}

validate_date() {  # <flag> <value>
  case "$2" in
    [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]) ;;
    *) die "$1 must be YYYY-MM-DD, got '$2'" 2 ;;
  esac
}

while [ $# -gt 0 ]; do
  # Every flag the caller actually typed, so --from-json can refuse the ones a
  # stored model cannot satisfy by name instead of accepting and discarding them.
  case "$1" in -?*) FLAGS_GIVEN+=("$1") ;; esac
  case "$1" in
    -h | --help)
      usage
      exit 0
      ;;
    --json) OUTPUT=json ;;
    --from-json)
      need_value --from-json $#
      FROM_JSON=$2
      shift
      ;;
    --since)
      need_value --since $#
      validate_date --since "$2"
      SINCE=$2
      shift
      ;;
    --until)
      need_value --until $#
      validate_date --until "$2"
      UNTIL=$2
      shift
      ;;
    --window)
      need_value --window $#
      validate_uint --window "$2" 1
      WINDOW_DAYS=$2
      shift
      ;;
    --periods)
      need_value --periods $#
      validate_uint --periods "$2" 2
      PERIODS=$2
      shift
      ;;
    --stalled-days)
      need_value --stalled-days $#
      validate_uint --stalled-days "$2" 1
      STALLED_DAYS=$2
      shift
      ;;
    --unmaintained-days)
      need_value --unmaintained-days $#
      validate_uint --unmaintained-days "$2" 1
      UNMAINTAINED_DAYS=$2
      shift
      ;;
    --max-repos)
      need_value --max-repos $#
      validate_uint --max-repos "$2"
      MAX_REPOS=$2
      shift
      ;;
    --max-prs)
      need_value --max-prs $#
      validate_uint --max-prs "$2"
      MAX_PRS=$2
      shift
      ;;
    --max-listed)
      need_value --max-listed $#
      validate_uint --max-listed "$2"
      MAX_LISTED=$2
      shift
      ;;
    --include-forks) INCLUDE_FORKS=1 ;;
    --exclude-archived) EXCLUDE_ARCHIVED=1 ;;
    -*) die "unknown flag '$1' (see --help)" 2 ;;
    *)
      [ -z "$SCOPE_ARG" ] || die "only one estate scope is accepted, got '$SCOPE_ARG' and '$1'" 2
      SCOPE_ARG=$1
      ;;
  esac
  shift
done

command -v jq > /dev/null 2>&1 || die "jq is required"

if [ -n "$FROM_JSON" ]; then
  [ -z "$SCOPE_ARG" ] || die "--from-json renders a stored model and takes no estate scope" 2
  [ -f "$FROM_JSON" ] || die "no such model file: $FROM_JSON"
  if [ "${#FLAGS_GIVEN[@]}" -gt 0 ]; then
    for given in "${FLAGS_GIVEN[@]}"; do
      case $given in
        --from-json | --json) ;;
        --max-listed) MAX_LISTED_GIVEN=1 ;;
        *) die "$given cannot be applied to a stored model: it decides what gets collected or how a figure is derived, so it needs a fresh collection; re-run the review against the estate with $given" 2 ;;
      esac
    done
  fi
else
  [ -n "$SCOPE_ARG" ] || {
    usage >&2
    die "an estate scope is required: an organization or owner/repo" 2
  }
fi

TMPROOT=
cleanup() {
  [ -z "$TMPROOT" ] || rm -rf "$TMPROOT"
}
trap cleanup EXIT INT TERM HUP

# ---------------------------------------------------------------------------
# The single gh-axi coupling.
# ---------------------------------------------------------------------------
# gh_read <gh-axi api argument>...
#
# Runs one gh-axi api call whose --jq program must render a tab-separated record
# payload, and prints that payload's decoded lines on stdout. gh-axi renders every
# response as an agent-readable document, so a shaped payload comes back as the
# `body` field of an `api_response` envelope, JSON-string-quoted when it contains
# characters the rendering escapes. Returning a JSON document from --jq is not an
# option: gh-axi recognizes and re-renders it, so the payload would stop being a
# payload. Tab-separated records are the one shape that survives the round trip,
# which is why every caller shapes its --jq output that way and sanitizes free
# text out of tabs and newlines at the jq boundary.
#
# It refuses rather than degrading. An envelope without exactly one body field, or
# a body gh-axi marked truncated, is a changed rendering contract, not an empty
# estate, and silently reporting it as no data would be the worst possible
# failure for a report the captain acts on. The refusal names gh-axi's version so
# the diagnostic points at what to check.
GH_AXI_VERSION=
gh_axi_version() {
  if [ -z "$GH_AXI_VERSION" ]; then
    GH_AXI_VERSION=$(gh-axi --version 2>/dev/null | head -n 1)
    [ -n "$GH_AXI_VERSION" ] || GH_AXI_VERSION="unknown"
  fi
  printf '%s' "$GH_AXI_VERSION"
}
# Every read puts its payload in a file rather than on stdout, and every pager
# appends to a file, because a `$(...)` capture runs in a subshell: an error
# recorded there, a cap recorded there, and even a fatal refusal there are all
# lost the moment the substitution closes. A read failure that cannot stop the
# run would be reported as an estate with nothing in it, which is precisely the
# failure this report must never produce.
GH_READ_ERROR=
GH_SCRATCH=
GH_PAYLOAD=
GH_RECORDS=

gh_scratch_init() {
  GH_SCRATCH=$TMPROOT/read
  mkdir -p "$GH_SCRATCH" || die "could not create the read scratch directory"
  GH_PAYLOAD=$GH_SCRATCH/payload
  GH_RECORDS=$GH_SCRATCH/records
}

# gh_read <gh-axi api argument>...: 0 with the decoded payload in $GH_PAYLOAD,
# or 1 with the reason in $GH_READ_ERROR.
gh_read() {
  local body_count truncated body
  GH_READ_ERROR=
  : > "$GH_PAYLOAD"
  if ! gh-axi api "$@" > "$GH_SCRATCH/raw" 2> "$GH_SCRATCH/raw.err"; then
    # gh-axi renders its own failure as a document on STDOUT and exits non-zero,
    # so the useful diagnostic is usually there rather than on stderr. Read both
    # and keep whichever carries text, so the refusal quotes what gh-axi said
    # instead of inventing a reason of its own.
    GH_READ_ERROR=$(tr '\n\t' '  ' < "$GH_SCRATCH/raw.err" | cut -c1-300)
    if [ -z "${GH_READ_ERROR// /}" ]; then
      GH_READ_ERROR=$(tr '\n\t' '  ' < "$GH_SCRATCH/raw" | cut -c1-300)
    fi
    [ -n "${GH_READ_ERROR// /}" ] || GH_READ_ERROR="gh-axi exited non-zero without a diagnostic"
    return 1
  fi
  body_count=$(grep -c '^[[:space:]]*body:[[:space:]]*' "$GH_SCRATCH/raw") || body_count=0
  if [ "$body_count" != 1 ]; then
    GH_READ_ERROR="gh-axi ($(gh_axi_version)) returned an envelope carrying $body_count body fields, not 1; the rendering contract this reader decodes has changed"
    return 1
  fi
  truncated=$(sed -n 's/^[[:space:]]*truncated:[[:space:]]*//p' "$GH_SCRATCH/raw" | head -n 1)
  if [ "$truncated" = "true" ]; then
    GH_READ_ERROR="gh-axi ($(gh_axi_version)) truncated the response body despite --full; the payload cannot be trusted"
    return 1
  fi
  body=$(sed -n 's/^[[:space:]]*body:[[:space:]]*//p' "$GH_SCRATCH/raw")
  case $body in
    '""' | '') return 0 ;;
    '"'*)
      if ! printf '%s' "$body" | jq -r . > "$GH_PAYLOAD"; then
        GH_READ_ERROR="gh-axi ($(gh_axi_version)) rendered a quoted body this reader cannot decode as a string"
        return 1
      fi
      ;;
    *) printf '%s\n' "$body" > "$GH_PAYLOAD" ;;
  esac
  return 0
}

# gh_read_required <what> <gh-axi api argument>...: gh_read, or a fatal refusal
# in the caller's own shell so the run actually stops.
gh_read_required() {
  local what=$1
  shift
  gh_read "$@" || die "could not read $what: $GH_READ_ERROR"
}

# ---------------------------------------------------------------------------
# Clock and window.
# ---------------------------------------------------------------------------
NOW=${XO_ESTATE_REVIEW_NOW:-$(date -u +%Y-%m-%dT%H:%M:%SZ)}
case $NOW in
  [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9]Z) ;;
  *) die "XO_ESTATE_REVIEW_NOW must be ISO 8601 UTC (YYYY-MM-DDTHH:MM:SSZ), got '$NOW'" 2 ;;
esac

# Every date calculation runs in jq so the arithmetic is identical on every
# platform; GNU and BSD date disagree about relative dates, and this report has
# to be comparable across the machines an estate is reviewed from.
WINDOW_JSON=
resolve_window() {
  WINDOW_JSON=$(jq -n \
    --arg now "$NOW" --arg since "$SINCE" --arg until "$UNTIL" \
    --argjson window "$WINDOW_DAYS" --argjson periods "$PERIODS" '
    def day: 86400;
    ($now | fromdateiso8601) as $nowe
    | (if $until == "" then ($nowe - ($nowe % day)) else (($until + "T00:00:00Z") | fromdateiso8601) end) as $untile
    | (if $since == "" then ($untile - ($window * day)) else (($since + "T00:00:00Z") | fromdateiso8601) end) as $sincee
    | if $sincee >= $untile then { error: "the window start must be before the window end" }
      else
        (($untile - $sincee) / day | floor) as $days
        | (($untile - $sincee) / $periods) as $step
        | {
            since: ($sincee | todateiso8601),
            until: ($untile | todateiso8601),
            since_epoch: $sincee,
            until_epoch: $untile,
            days: $days,
            periods: $periods,
            period_days: (($days / $periods) * 100 | round / 100),
            period_edges: [range(0; $periods + 1) | $sincee + (. * $step) | floor],
            period_labels: [range(0; $periods) | ($sincee + (. * $step) | floor | strftime("%Y-%m-%d"))]
          }
      end' 2> /dev/null) || die "could not resolve the collection window from --since '${SINCE:-none}' and --until '${UNTIL:-none}'; both must be real calendar dates" 2
  if [ "$(printf '%s' "$WINDOW_JSON" | jq -r '.error // ""')" != "" ]; then
    die "$(printf '%s' "$WINDOW_JSON" | jq -r '.error')" 2
  fi
}

# ---------------------------------------------------------------------------
# Bounded REST paging.
# ---------------------------------------------------------------------------
# Each REST read is paged by hand rather than through gh-axi's --paginate so the
# work is bounded and a hit cap is disclosed instead of silently truncating an
# estate's history. Every --jq program must open its payload with an `items` line
# carrying the number of items the endpoint returned, before any record line.
# Page completeness is decided from that count and never from the records kept: a
# program that filters items out - the open-issue read drops the pull requests
# GitHub returns alongside issues - would otherwise make a full page look short
# and stop the walk with the rest of the history unread and undisclosed.
REST_PER_PAGE=100
REST_MAX_PAGES=30
REST_CAPPED=0

# rest_pages <path_with_query> <jq_program>: 0 with the records in $GH_RECORDS
# and REST_CAPPED set, or 1 with the reason in $GH_READ_ERROR.
rest_pages() {
  local path=$1 program=$2 page=1 items sep
  REST_CAPPED=0
  : > "$GH_RECORDS"
  case $path in
    *\?*) sep='&' ;;
    *) sep='?' ;;
  esac
  while [ "$page" -le "$REST_MAX_PAGES" ]; do
    gh_read "${path}${sep}per_page=${REST_PER_PAGE}&page=${page}" --full --jq "$program" || return 1
    items=$(awk -F'\t' '$1 == "items" { print $2; exit }' "$GH_PAYLOAD")
    case ${items:-} in
      '' | *[!0-9]*) items=0 ;;
    esac
    awk -F'\t' '$1 != "items"' "$GH_PAYLOAD" >> "$GH_RECORDS"
    [ "$items" -ge "$REST_PER_PAGE" ] || return 0
    page=$((page + 1))
  done
  REST_CAPPED=1
  return 0
}

# ---------------------------------------------------------------------------
# Estate scope.
# ---------------------------------------------------------------------------
SCOPE_KIND=
SCOPE_NAME=
resolve_scope() {
  local owner_type
  case $SCOPE_ARG in
    */*/*) die "'$SCOPE_ARG' is not an estate scope: give an organization or owner/repo" 2 ;;
    */) die "'$SCOPE_ARG' is not an estate scope: a repository needs owner/repo" 2 ;;
    */*)
      SCOPE_KIND=repository
      SCOPE_NAME=$SCOPE_ARG
      ;;
    '') die "an estate scope is required" 2 ;;
    *)
      gh_read_required "the owner '$SCOPE_ARG'" "/users/$SCOPE_ARG" --full --jq '[.type]|@tsv'
      owner_type=$(head -n 1 "$GH_PAYLOAD")
      [ "$owner_type" = Organization ] ||
        die "GitHub reports owner '$SCOPE_ARG' as type '${owner_type:-none}', not an organization; an estate is an organization or one of its repositories as owner/repo" 2
      SCOPE_KIND=organization
      SCOPE_NAME=$SCOPE_ARG
      ;;
  esac
}

REPO_LIST_JQ='(["items\t" + (length|tostring)] + [.[]|["repo",.full_name,.name,.owner.login,(.default_branch//"-"),(.archived|tostring),(.fork|tostring),(.pushed_at//"-"),(.private|tostring)]|@tsv])|join("\n")'
REPO_ONE_JQ='["repo",.full_name,.name,.owner.login,(.default_branch//"-"),(.archived|tostring),(.fork|tostring),(.pushed_at//"-"),(.private|tostring)]|@tsv'

# list_repos: leaves the estate's repo records in $REPOS_FILE, and the listing's
# own page cap in $REPOS_CAPPED. That flag has to be taken here and kept: it lives
# in REST_CAPPED, which the first per-repository read overwrites, and a listing
# that stopped short shortens the matched count and every aggregate under it.
REPOS_FILE=
REPOS_CAPPED=0
list_repos() {
  REPOS_FILE=$GH_SCRATCH/repos
  REPOS_CAPPED=0
  case $SCOPE_KIND in
    repository)
      gh_read_required "repository $SCOPE_NAME" "/repos/$SCOPE_NAME" --full --jq "$REPO_ONE_JQ"
      cp "$GH_PAYLOAD" "$REPOS_FILE"
      ;;
    organization)
      rest_pages "/orgs/$SCOPE_NAME/repos?type=all&sort=full_name" "$REPO_LIST_JQ" ||
        die "could not list the repositories of organization $SCOPE_NAME: $GH_READ_ERROR"
      REPOS_CAPPED=$REST_CAPPED
      cp "$GH_RECORDS" "$REPOS_FILE"
      ;;
  esac
}

# ---------------------------------------------------------------------------
# Per-repository reads.
# ---------------------------------------------------------------------------
# The date recorded is the committer date, which is the date the commits list
# itself filters `since` and `until` on. Recording the author date instead would
# count a different set of commits from the one the request asked for, and the
# difference is silent: a rebased commit's author date can sit outside a window
# the API already decided it belongs to.
COMMITS_JQ='(["items\t" + (length|tostring)] + [.[]|["commit",(.sha//"-"),(.author.login//"-"),(.author.type//"-"),(.commit.author.email//"-"),(.commit.committer.date//"-"),(.parents|length|tostring),((.commit.message//"")|split("\n")[0]|gsub("[\\t\\r]";" "))]|@tsv])|join("\n")'
RUNS_JQ='(["items\t" + (.workflow_runs|length|tostring)] + [.workflow_runs[]|["run",(.workflow_id|tostring),(.head_sha//"-"),(.run_number|tostring),(.run_attempt|tostring),(.conclusion//"-"),(.created_at//"-")]|@tsv])|join("\n")'
# The open-issue read is the one program that drops items GitHub returned: the
# endpoint answers with pull requests alongside issues. The `items` count is the
# unfiltered page length, so dropping them cannot end the walk early.
ISSUES_JQ='(["items\t" + (length|tostring)] + [.[]|select(.pull_request==null)|["issue",(.number|tostring),(.created_at//"-"),(.updated_at//"-")]|@tsv])|join("\n")'

# One pull request's reviews are read in a single page rather than walked by
# cursor. The bound is stated here once and compared against each pull request's
# own `reviews.totalCount` during collection, so a pull request that carries more
# reviews than this is disclosed as a cap in section 9.2 the way every other
# bound in this report is, rather than silently shortening a review count.
REVIEWS_PER_PR=50

# shellcheck disable=SC2016  # GraphQL variables are literal query syntax.
PR_QUERY='query($owner:String!,$name:String!,$cursor:String,$page:Int!){
  repository(owner:$owner,name:$name){
    pullRequests(first:$page, orderBy:{field:UPDATED_AT,direction:DESC}, after:$cursor){
      pageInfo{hasNextPage endCursor}
      nodes{ number state isDraft createdAt updatedAt mergedAt closedAt additions deletions changedFiles headRefName title
        author{login __typename}
        commits(first:1){nodes{commit{committedDate}}}
        reviews(first:'"$REVIEWS_PER_PR"'){totalCount nodes{author{login __typename} submittedAt state}}
        reviewThreads(first:1){totalCount} } } } }'

# shellcheck disable=SC2016  # GraphQL variables are literal query syntax.
OPEN_PR_QUERY='query($owner:String!,$name:String!,$cursor:String,$page:Int!){
  repository(owner:$owner,name:$name){
    pullRequests(first:$page, states:OPEN, orderBy:{field:CREATED_AT,direction:ASC}, after:$cursor){
      pageInfo{hasNextPage endCursor}
      nodes{ number state isDraft createdAt updatedAt mergedAt closedAt additions deletions changedFiles headRefName title
        author{login __typename}
        commits(first:1){nodes{commit{committedDate}}}
        reviews(first:'"$REVIEWS_PER_PR"'){totalCount nodes{author{login __typename} submittedAt state}}
        reviewThreads(first:1){totalCount} } } } }'

# shellcheck disable=SC2016  # jq owns every $ in this program.
PR_SHAPE_JQ='
  .data.repository.pullRequests as $p
  | (if $p == null then ["page\tfalse\t-"] else
      ["page\t" + (($p.pageInfo.hasNextPage)|tostring) + "\t" + (($p.pageInfo.endCursor)//"-")]
      + [ $p.nodes[]
          | ["pr",(.number|tostring),(.state//"-"),(.isDraft|tostring),(.createdAt//"-"),(.updatedAt//"-"),
             ((.mergedAt)//"-"),((.closedAt)//"-"),(.additions|tostring),(.deletions|tostring),(.changedFiles|tostring),
             ((.author.login)//"-"),((.author.__typename)//"-"),((.commits.nodes[0].commit.committedDate)//"-"),
             (.reviews.totalCount|tostring),(.reviewThreads.totalCount|tostring),((.headRefName)//"-"),
             ((.title//"")|gsub("[\\t\\r\\n]";" "))]|@tsv ]
      + [ $p.nodes[] as $n | $n.reviews.nodes[]
          | ["review",($n.number|tostring),((.author.login)//"-"),((.author.__typename)//"-"),((.submittedAt)//"-"),(.state//"-")]|@tsv ]
    end)
  | join("\n")'

# read_prs <owner> <name> <query> <since_iso> <stop_on_window>
# Walks the pull-request connection by cursor and leaves pr and review records in
# $GH_RECORDS. GraphQL cannot filter a pull-request connection by date, so the
# updated-at ordering is walked until it leaves the window; the open-pull-request
# pass walks oldest-first instead and is deliberately not window-bounded, because
# a pull request nobody has touched for a year is exactly the stalled work
# section 6.3 has to name.
PR_CAPPED=0
read_prs() {
  local owner=$1 name=$2 query=$3 since=$4 stop_on_window=$5
  local cursor=null page_size=50 fetched=0 lines hasnext endcursor oldest body remaining
  PR_CAPPED=0
  : > "$GH_RECORDS"
  while :; do
    if [ "$MAX_PRS" -gt 0 ]; then
      remaining=$((MAX_PRS - fetched))
      if [ "$remaining" -le 0 ]; then
        PR_CAPPED=1
        return 0
      fi
      [ "$remaining" -ge "$page_size" ] || page_size=$remaining
    fi
    body=$GH_SCRATCH/prq.json
    jq -n --arg q "$query" --arg owner "$owner" --arg name "$name" \
      --argjson cursor "$cursor" --argjson page "$page_size" \
      '{query:$q,variables:{owner:$owner,name:$name,cursor:$cursor,page:$page}}' > "$body" || {
      GH_READ_ERROR="could not compose the pull-request query body"
      return 1
    }
    gh_read POST graphql --input "$body" --full --jq "$PR_SHAPE_JQ" || return 1
    hasnext=$(sed -n "s/^page${TAB}\\([^${TAB}]*\\)${TAB}.*\$/\\1/p" "$GH_PAYLOAD" | head -n 1)
    endcursor=$(sed -n "s/^page${TAB}[^${TAB}]*${TAB}\\(.*\\)\$/\\1/p" "$GH_PAYLOAD" | head -n 1)
    lines=$(grep -c "^pr$TAB" "$GH_PAYLOAD") || lines=0
    grep -v "^page$TAB" "$GH_PAYLOAD" >> "$GH_RECORDS" || true
    fetched=$((fetched + lines))
    if [ "$stop_on_window" = 1 ] && [ "$lines" -gt 0 ]; then
      oldest=$(awk -F'\t' '$1 == "pr" { print $6 }' "$GH_PAYLOAD" | sort | head -n 1)
      if [ -n "$oldest" ] && [ "$oldest" \< "$since" ]; then
        return 0
      fi
    fi
    [ "$hasnext" = "true" ] || return 0
    [ -n "$endcursor" ] && [ "$endcursor" != "-" ] || return 0
    cursor=$(jq -n --arg c "$endcursor" '$c')
  done
}

# pr_detail <cap-message>: the disclosure for a pull-request read that succeeded,
# which is "complete" only when neither the pull-request cap nor the per-pull-
# request review page bound was reached. Both bounds shorten what the figures
# describe, so both belong in section 9.2 rather than in this script alone.
pr_detail() {
  local detail=complete over
  [ "$PR_CAPPED" = 0 ] || detail=$1
  over=$(awk -F'\t' -v cap="$REVIEWS_PER_PR" '$1 == "pr" && ($15 + 0) > cap { n++ } END { print n + 0 }' "$GH_RECORDS")
  if [ "$over" != 0 ]; then
    if [ "$detail" = complete ]; then
      detail="$over pull requests carry more than $REVIEWS_PER_PR reviews; only the first $REVIEWS_PER_PR of each were read"
    else
      detail="$detail; $over pull requests carry more than $REVIEWS_PER_PR reviews, of which only the first $REVIEWS_PER_PR were read"
    fi
  fi
  printf '%s' "$detail"
}

# ---------------------------------------------------------------------------
# Collection.
# ---------------------------------------------------------------------------
RECORDS=
collect() {
  local since until since_date until_date selected=0 capped_repos=0
  since=$(printf '%s' "$WINDOW_JSON" | jq -r .since)
  until=$(printf '%s' "$WINDOW_JSON" | jq -r .until)
  since_date=${since%%T*}
  until_date=${until%%T*}

  list_repos

  local line full name owner branch archived fork pushed private detail
  local -a chosen=()
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    case $line in repo*) ;; *) continue ;; esac
    IFS=$'\t' read -r _ full name owner branch archived fork pushed private <<< "$line"
    [ -n "$full" ] || continue
    if [ "$fork" = true ] && [ "$INCLUDE_FORKS" = 0 ]; then continue; fi
    if [ "$archived" = true ] && [ "$EXCLUDE_ARCHIVED" = 1 ]; then continue; fi
    chosen+=("$line")
  done < "$REPOS_FILE"

  if [ "${#chosen[@]}" -eq 0 ]; then
    die "no repository in estate '$SCOPE_NAME' matched the selection; check --include-forks and --exclude-archived"
  fi
  selected=${#chosen[@]}
  if [ "$MAX_REPOS" -gt 0 ] && [ "$selected" -gt "$MAX_REPOS" ]; then
    chosen=("${chosen[@]:0:$MAX_REPOS}")
    capped_repos=1
  fi

  RECORDS=$TMPROOT/records.tsv
  : > "$RECORDS"
  printf 'selection\t%s\t%s\t%s\n' "$selected" "${#chosen[@]}" "$capped_repos" >> "$RECORDS"
  [ "$REPOS_CAPPED" = 0 ] ||
    printf 'signal\t%s\trepository_listing\tread\tcapped at %s pages of %s repositories, so the matched count describes the first %s the estate lists\n' \
      "$SCOPE_NAME" "$REST_MAX_PAGES" "$REST_PER_PAGE" "$((REST_MAX_PAGES * REST_PER_PAGE))" >> "$RECORDS"

  local entry
  for entry in "${chosen[@]}"; do
    IFS=$'\t' read -r _ full name owner branch archived fork pushed private <<< "$entry"
    printf 'repo\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$full" "$owner" "$branch" "$archived" "$fork" "$pushed" "$private" >> "$RECORDS"

    if [ "$branch" = "-" ]; then
      printf 'signal\t%s\tcommits\tunread\tthe repository reports no default branch\n' "$full" >> "$RECORDS"
    elif rest_pages "/repos/$full/commits?sha=$branch&since=$since&until=$until" "$COMMITS_JQ"; then
      detail=complete
      [ "$REST_CAPPED" = 0 ] || detail="capped at $REST_MAX_PAGES pages of 100 commits"
      printf 'signal\t%s\tcommits\tread\t%s\n' "$full" "$detail" >> "$RECORDS"
      sed "s|^commit$TAB|commit$TAB$full$TAB|" "$GH_RECORDS" >> "$RECORDS"
    else
      printf 'signal\t%s\tcommits\tunread\t%s\n' "$full" "$GH_READ_ERROR" >> "$RECORDS"
    fi

    if read_prs "$owner" "$name" "$PR_QUERY" "$since" 1; then
      detail=$(pr_detail "capped at $MAX_PRS pull requests")
      printf 'signal\t%s\tpull_requests\tread\t%s\n' "$full" "$detail" >> "$RECORDS"
      sed -e "s|^pr$TAB|pr$TAB$full$TAB|" -e "s|^review$TAB|review$TAB$full$TAB|" "$GH_RECORDS" >> "$RECORDS"
      if read_prs "$owner" "$name" "$OPEN_PR_QUERY" "$since" 0; then
        detail=$(pr_detail "capped at $MAX_PRS open pull requests, so the open and stalled counts describe the oldest $MAX_PRS")
        printf 'signal\t%s\topen_pull_requests\tread\t%s\n' "$full" "$detail" >> "$RECORDS"
        sed -e "s|^pr$TAB|pr$TAB$full$TAB|" -e "s|^review$TAB|review$TAB$full$TAB|" "$GH_RECORDS" >> "$RECORDS"
      else
        printf 'signal\t%s\topen_pull_requests\tunread\t%s\n' "$full" "$GH_READ_ERROR" >> "$RECORDS"
      fi
    else
      printf 'signal\t%s\tpull_requests\tunread\t%s\n' "$full" "$GH_READ_ERROR" >> "$RECORDS"
      printf 'signal\t%s\topen_pull_requests\tunread\tnot attempted after the pull-request read failed\n' "$full" >> "$RECORDS"
    fi

    if rest_pages "/repos/$full/actions/runs?event=pull_request&created=$since_date..$until_date" "$RUNS_JQ"; then
      detail=complete
      [ "$REST_CAPPED" = 0 ] || detail="capped at $REST_MAX_PAGES pages of 100 runs"
      printf 'signal\t%s\tci_runs\tread\t%s\n' "$full" "$detail" >> "$RECORDS"
      sed "s|^run$TAB|run$TAB$full$TAB|" "$GH_RECORDS" >> "$RECORDS"
    else
      printf 'signal\t%s\tci_runs\tunread\t%s\n' "$full" "$GH_READ_ERROR" >> "$RECORDS"
    fi

    if rest_pages "/repos/$full/issues?state=open" "$ISSUES_JQ"; then
      detail=complete
      [ "$REST_CAPPED" = 0 ] || detail="capped at $REST_MAX_PAGES pages of 100 issues"
      printf 'signal\t%s\tissues\tread\t%s\n' "$full" "$detail" >> "$RECORDS"
      sed "s|^issue$TAB|issue$TAB$full$TAB|" "$GH_RECORDS" >> "$RECORDS"
    else
      printf 'signal\t%s\tissues\tunread\t%s\n' "$full" "$GH_READ_ERROR" >> "$RECORDS"
    fi
  done
}

# ---------------------------------------------------------------------------
# Derivation: records -> model.
# ---------------------------------------------------------------------------
# One pass turns the collected records into the `xo-estate-review.v1` model. The
# model holds every number the report prints, so the renderer formats and never
# calculates, and --json and its report can never disagree about a figure.
#
# Every metric definition lives here and nowhere else. Section 1 of the report
# restates each one in words, because a figure a reader cannot define is a figure
# they cannot act on, but this is the code that produces it.
DERIVE_JQ=$(
  cat <<'JQ'
def ep: if . == null or . == "-" or . == "" then null else (try fromdateiso8601 catch null) end;
def r1: if . == null then null else ((. * 10) | round) / 10 end;
def median: if length == 0 then null
  else (sort) as $s | ($s | length) as $n
  | (if ($n % 2) == 1 then $s[(($n - 1) / 2) | floor]
     else (($s[(($n / 2) | floor) - 1] + $s[($n / 2) | floor]) / 2) end) end;
def p90: if length == 0 then null
  else (sort) as $s | ($s | length) as $n | $s[((($n - 1) * 0.9) | round)] end;
def share($part; $whole): if $whole == 0 or $whole == null then null else (($part / $whole) * 100 | r1) end;
# GitHub reports the same automation account two ways: the commits API gives an
# App's bot user as `dependabot[bot]` while the pull-request API gives `dependabot`.
# Folding that documented suffix is not a name guess and not optional: leaving it
# would split one actor across two rows of "who did what" and double-count it.
# Nothing else is ever folded, because matching people by name IS a guess.
def account: if . == "-" or . == null then "unattributed"
  elif endswith("[bot]") then .[0:length - 5] else . end;
def is_bot($login; $type): ($login != null and $login != "-" and ($login | endswith("[bot]"))) or ($type == "Bot");

$win as $w
| $opt as $o
| ($now | fromdateiso8601) as $nowe
| ($w.period_edges) as $edges
| ($w.periods) as $np
| def bucket_of($e): if $e == null then -1
    else (([range(0; $np) | select($edges[.] <= $e and $e < $edges[. + 1])] | .[0])
          // (if $e >= $edges[$np] then ($np - 1) else -1 end)) end;
  def in_window($e): $e != null and $e >= $w.since_epoch and $e < $w.until_epoch;
  def zeros: [range(0; $np) | 0];
  def tally($points): reduce $points[] as $i (zeros; if $i >= 0 and $i < $np then (.[$i] += 1) else . end);
  def trend($values): if ($values | length) < 2 then "insufficient-history"
    else ($values[-1]) as $last | ($values[0:-1]) as $prior
    | (($prior | map(. // 0) | add) / ($prior | length)) as $base
    | if $base == 0 then (if $last != null and $last > 0 then "rising" else "flat" end)
      elif $last == null then "insufficient-history"
      else ((($last - $base) / $base) * 100) as $pct
      | if $pct > $o.trend_band_pct then "rising"
        elif $pct < (0 - $o.trend_band_pct) then "falling"
        else "flat" end
      end
    end;
  def as_series($values): { per_period: $values, trend: trend($values) };
  # A direction is a statement about the window's end. When the last period holds
  # no measurement, the last MEASURED period ended before the window did, and a
  # direction drawn from it would describe a time the reader is not asking about.
  # That case reports no direction at all; the report names the empty periods.
  def trend_sparse($values): if ($values | length) == 0 or ($values[-1] == null)
    then "final-period-unmeasured"
    else trend([$values[] | select(. != null)]) end;
  def period_medians($pairs): [range(0; $np) as $b | [$pairs[] | select(.[0] == $b) | .[1]] | median | r1];
  # The workflow-runs list returns one entry per run carrying that run's CURRENT
  # attempt: a re-run increments run_attempt on the same entry rather than adding
  # a second one, and earlier attempts are only reachable through another
  # endpoint this script does not read. So what a conclusion here evidences is the
  # latest attempt of the latest run on a commit, and that is what this reports.
  # A workflow can run more than once on one commit - a reopened pull request
  # does it - so the attempt count is the highest attempt anywhere in the group,
  # never just the retained run's, and it says that a check was attempted more
  # than once on that commit and nothing more.
  def ci_of($groups): ($groups | map(select(.conclusion == "success")) | length) as $passed
    | ($groups | map(select(.conclusion == "failure" or .conclusion == "timed_out" or .conclusion == "startup_failure")) | length) as $failed
    | ($groups | length) as $total
    | { runs: $total, passed: $passed, failed: $failed,
        inconclusive: ($total - $passed - $failed),
        needed_more_than_one_attempt: ($groups | map(select(.max_attempt > 1)) | length),
        latest_attempt_pass_rate_pct: share($passed; ($passed + $failed)) };
  def size_of($population): ($population | map(.additions + .deletions)) as $s
    | { measured: ($s | length), median_lines: ($s | median | r1), p90_lines: ($s | p90 | r1),
        distribution: {
          under_10: ($s | map(select(. < 10)) | length),
          from_10_to_49: ($s | map(select(. >= 10 and . < 50)) | length),
          from_50_to_249: ($s | map(select(. >= 50 and . < 250)) | length),
          from_250_to_999: ($s | map(select(. >= 250 and . < 1000)) | length),
          at_least_1000: ($s | map(select(. >= 1000)) | length) } };
  def concentration_of($authored): ($authored | group_by(.person)
      | map({person: .[0].person, commits: length}) | sort_by(-.commits, .person)) as $by
    | ($authored | length) as $total
    | { authors: ($by | length), commits: $total,
        top: ($by | .[0].person // null),
        top_share_pct: share(($by | .[0].commits // 0); $total),
        accounts_covering_half: (if $total == 0 then null
          else (([range(1; ($by | length) + 1) | select((($by[0:.] | map(.commits) | add) // 0) * 2 > $total)] | .[0])
                // ($by | length)) end),
        breakdown: ($by | map(. + {share_pct: share(.commits; $total)})) };
  def revert_of($authored): ($authored | map(select(.subject | test("^[Rr]evert[ (:\"]"))) | length) as $rev
    | ($authored | map(select(.subject | test("hotfix"; "i"))) | length) as $hot
    | { commits: ($authored | length), reverts: $rev, hotfixes: $hot,
        revert_rate_pct: share($rev; ($authored | length)),
        hotfix_rate_pct: share($hot; ($authored | length)) };
  def review_of($population): ($population | length) as $total
    | ($population | map(select(.first_review != null)) | length) as $with
    | { merged: $total, with_review_by_another_account: $with,
        coverage_pct: share($with; $total),
        review_threads_median: ($population | map(.threads) | median | r1),
        review_threads_total: (($population | map(.threads) | add) // 0) };
  def people_of($authored; $opened_in; $merged_in; $reviews_in):
    ((($authored | map(.person)) + ($opened_in | map(.author)) + ($merged_in | map(.author))
      + ($reviews_in | map(.person))) | unique) as $ids
    | ((($authored | map(select(.bot)) | map(.person))
        + ($opened_in | map(select(.author_bot)) | map(.author))
        + ($merged_in | map(select(.author_bot)) | map(.author))
        + ($reviews_in | map(select(.bot)) | map(.person))) | unique) as $bots
    | [$ids[] as $id
       | { person: $id,
           automation: (($bots | index($id)) != null),
           commits: ($authored | map(select(.person == $id)) | length),
           prs_opened: ($opened_in | map(select(.author == $id)) | length),
           prs_merged: ($merged_in | map(select(.author == $id)) | length),
           reviews_submitted: ($reviews_in | map(select(.person == $id)) | length),
           prs_reviewed: ($reviews_in | map(select(.person == $id))
                          | map(.repo + "#" + (.number | tostring)) | unique | length),
           repos: ((($authored | map(select(.person == $id)) | map(.repo))
                    + ($opened_in | map(select(.author == $id)) | map(.repo))
                    + ($merged_in | map(select(.author == $id)) | map(.repo))
                    + ($reviews_in | map(select(.person == $id)) | map(.repo))) | unique | length) } ]
    | sort_by(.person);

  [inputs | split("\t")] as $rows
| ($rows | map(select(.[0] == "selection")) | .[0]) as $sel
| ($rows | map(select(.[0] == "repo")) | map({
    name: .[1], owner: .[2], default_branch: .[3],
    archived: (.[4] == "true"), fork: (.[5] == "true"),
    pushed_at: (if .[6] == "-" then null else .[6] end), private: (.[7] == "true") })) as $repos
| ($rows | map(select(.[0] == "signal")) | map({repo: .[1], signal: .[2], status: .[3], detail: .[4]})) as $signals
| ($rows | map(select(.[0] == "commit")) | map({
    repo: .[1], sha: .[2],
    person: (if .[3] == "-" then ("unlinked:" + (.[5] | ascii_downcase)) else (.[3] | account) end),
    bot: is_bot(.[3]; .[4]),
    linked: (.[3] != "-"), at: (.[6] | ep),
    merge: ((.[7] | tonumber) > 1), subject: .[8] })
   | map(select(in_window(.at)))) as $commits
| ($rows | map(select(.[0] == "pr")) | map({
    repo: .[1], number: (.[2] | tonumber), state: .[3], draft: (.[4] == "true"),
    created: (.[5] | ep), updated: (.[6] | ep), merged: (.[7] | ep), closed: (.[8] | ep),
    additions: (.[9] | tonumber), deletions: (.[10] | tonumber), files: (.[11] | tonumber),
    author: (if .[12] == "-" then "unattributed" else (.[12] | account) end),
    author_bot: is_bot(.[12]; .[13]),
    first_commit: (.[14] | ep), reviews_total: (.[15] | tonumber),
    threads: (.[16] | tonumber), head_ref: .[17], title: .[18] })
   | group_by([.repo, .number]) | map(.[0])) as $prs
| ($rows | map(select(.[0] == "review")) | map({
    repo: .[1], number: (.[2] | tonumber),
    person: (if .[3] == "-" then "unattributed" else (.[3] | account) end),
    bot: is_bot(.[3]; .[4]),
    at: (.[5] | ep), state: .[6] })
   # Collection makes two pull-request passes and a pull request that is open and
   # was updated inside the window appears in both, so one review submission can
   # arrive twice. A review is identified by its pull request, its author, its
   # submission time, and its state; counting it twice would inflate a person's
   # recorded participation, which is the one figure this report must not overstate.
   | unique_by([.repo, .number, .person, .at, .state])) as $reviews_raw
| ($rows | map(select(.[0] == "run")) | map({
    repo: .[1], workflow: .[2], sha: .[3], run: (.[4] | tonumber),
    attempt: (.[5] | tonumber), conclusion: .[6], at: (.[7] | ep) })) as $runs
| ($rows | map(select(.[0] == "issue")) | map({repo: .[1], number: (.[2] | tonumber), created: (.[3] | ep)})) as $issues
| ($prs | map({key: (.repo + "#" + (.number | tostring)), value: .author}) | from_entries) as $pr_author
| ($reviews_raw | map(. + {pr_author: ($pr_author[.repo + "#" + (.number | tostring)] // "unattributed")})
   | map(select(.person != .pr_author and .person != "unattributed"))
   | map(select(in_window(.at)))) as $reviews
| ($prs | map(select(in_window(.merged)))) as $merged_all
| ($merged_all | map(. as $p
    | ([$reviews_raw[] | select(.repo == $p.repo and .number == $p.number
        and .person != $p.author and .person != "unattributed"
        and .at != null and .at >= $p.created) | .at] | min) as $first
    | $p + {first_review: $first})) as $merged
| ($prs | map(select(in_window(.created)))) as $opened
| ($prs | map(select(.state == "OPEN"))) as $open_now
| ($prs | map(select(.state == "CLOSED" and in_window(.closed)))) as $closed_unmerged
| ($commits | map(select(.merge | not))) as $authored
| ($runs | map(select(in_window(.at))) | group_by([.repo, .workflow, .sha]) | map(. as $g
   | ($g | sort_by(.run, .attempt) | .[-1]) as $latest
   | { repo: $latest.repo, conclusion: $latest.conclusion, at: $latest.at,
       max_attempt: ($g | map(.attempt) | max) })) as $ci_groups
# A pull request is open as of the moment collection ran, not as of the window
# end, so how long it has been sitting is measured from the same clock its
# openness was read on. Ageing a collection-time set against a historical window
# end would understate every wait and, for a window that ended before today,
# could not select a stalled pull request at all.
| ($nowe - ($o.stalled_days * 86400)) as $stale_before
| ($open_now | map(select(.updated != null and .updated < $stale_before))
   | map({repo: .repo, number: .number, title: .title, author: .author, draft: .draft,
          age_days: ((($nowe - .created) / 86400) | floor),
          idle_days: ((($nowe - .updated) / 86400) | floor)})
   | sort_by(-.idle_days, .repo, .number)) as $stalled
| ($repos | map(. as $r
    | ($commits | map(select(.repo == $r.name))) as $rc
    | ($rc | map(select(.merge | not))) as $ra
    | ($merged | map(select(.repo == $r.name))) as $rm
    | ($opened | map(select(.repo == $r.name))) as $ro
    | ($open_now | map(select(.repo == $r.name))) as $rn
    | ($closed_unmerged | map(select(.repo == $r.name))) as $rcu
    | ($reviews | map(select(.repo == $r.name))) as $rrv
    | ($ci_groups | map(select(.repo == $r.name))) as $rci
    | ($issues | map(select(.repo == $r.name))) as $ri
    | ($rm | map(select(.first_commit != null) | (.merged - .first_commit) / 3600)) as $cycle
    | ($signals | map(select(.repo == $r.name))
       | map({(.signal): {status: .status, detail: .detail}}) | add // {}) as $rs
    | ($r.pushed_at | ep) as $pushed_epoch
    | $r + {
        signals: $rs,
        idle_days: (if $pushed_epoch == null then null else ((($nowe - $pushed_epoch) / 86400) | floor) end),
        commits: (revert_of($ra) + {
          total: ($rc | length), merges: (($rc | length) - ($ra | length)),
          unlinked_accounts: ($ra | map(select(.linked | not)) | length),
          per_period: tally([$ra[] | bucket_of(.at)]) }),
        pull_requests: {
          opened: ($ro | length), merged: ($rm | length),
          closed_unmerged: ($rcu | length), open_now: ($rn | length),
          merged_per_period: tally([$rm[] | bucket_of(.merged)]),
          cycle_hours: { measured: ($cycle | length), median: ($cycle | median | r1), p90: ($cycle | p90 | r1),
                         unmeasurable: (($rm | length) - ($cycle | length)) } },
        review: review_of($rm),
        reviews_received: ($rrv | length),
        ci: ci_of($rci),
        size: size_of($rm),
        issues: { open: ($ri | length),
                  oldest_open_days: ($ri | map(select(.created != null) | (($nowe - .created) / 86400) | floor) | max) },
        concentration: concentration_of($ra) })
   | sort_by(.name)) as $repo_models
| ($repo_models | map(select(.idle_days != null and .idle_days >= $o.unmaintained_days or .archived)
    | {repo: .name, idle_days: .idle_days, archived: .archived, commits_in_window: .commits.total})
   | sort_by(-(.idle_days // 0), .repo)) as $unmaintained
| ($repo_models | map(select(.concentration.commits > 0 and .concentration.accounts_covering_half == 1)
    | {repo: .name, top: .concentration.top, top_share_pct: .concentration.top_share_pct,
       authors: .concentration.authors, commits: .concentration.commits})
   | sort_by(-(.top_share_pct // 0), .repo)) as $concentrated
| (revert_of($authored) + {
    total: ($commits | length), merges: (($commits | length) - ($authored | length)),
    unlinked_accounts: ($authored | map(select(.linked | not)) | length),
    per_period: tally([$authored[] | bucket_of(.at)]) }) as $estate_commits
| ($merged | map(select(.first_commit != null) | (.merged - .first_commit) / 3600)) as $estate_cycle
| ($merged | map(select(.first_commit != null) | [bucket_of(.merged), (.merged - .first_commit) / 3600])) as $cycle_pairs
| ($merged | map(select(.first_review != null) | (.first_review - .created) / 3600)) as $estate_latency
| ($merged | map(select(.first_review != null) | [bucket_of(.merged), (.first_review - .created) / 3600])) as $latency_pairs
| {
    contract: $contract,
    generated_at: $now,
    generator: "xo-estate-review.sh",
    scope: { kind: $scope_kind, name: $scope_name },
    window: { since: $w.since, until: $w.until, days: $w.days, periods: $np,
              period_days: $w.period_days, period_labels: $w.period_labels },
    options: $o,
    selection: { matched: ($sel[1] | tonumber), reviewed: ($sel[2] | tonumber),
                 capped: ($sel[3] == "1"),
                 fully_read: ($repo_models | map(select([.signals[] | .status] | all(. != "unread"))) | length),
                 partially_read: ($repo_models | map(select([.signals[] | .status] | any(. == "unread"))) | length) },
    commands: $commands,
    headline: [
      { metric: "Pull requests merged", value: ($merged | length),
        unit: "pull requests", trend: trend(tally([$merged[] | bucket_of(.merged)])) },
      { metric: "Cycle time, first commit to merge", value: ($estate_cycle | median | r1),
        unit: "hours (median)", trend: trend_sparse(period_medians($cycle_pairs)) },
      { metric: "Merged pull requests reviewed by another account",
        value: (share(($merged | map(select(.first_review != null)) | length); ($merged | length))),
        unit: "percent", trend: "not-tracked" },
      { metric: "Continuous integration latest-attempt pass rate",
        value: (ci_of($ci_groups) | .latest_attempt_pass_rate_pct), unit: "percent", trend: "not-tracked" },
      { metric: "Repositories where one account authored over half the commits",
        value: ($concentrated | length), unit: "repositories", trend: "not-tracked" }
    ],
    people: people_of($authored; $opened; $merged; $reviews),
    velocity: {
      commits: as_series($estate_commits.per_period),
      merged: as_series(tally([$merged[] | bucket_of(.merged)])),
      opened: as_series(tally([$opened[] | bucket_of(.created)])),
      cycle_hours: { measured: ($estate_cycle | length),
                     unmeasurable: (($merged | length) - ($estate_cycle | length)),
                     median: ($estate_cycle | median | r1), p90: ($estate_cycle | p90 | r1),
                     per_period_median: period_medians($cycle_pairs),
                     trend: trend_sparse(period_medians($cycle_pairs)) },
      review_latency_hours: { measured: ($estate_latency | length),
                     unmeasurable: (($merged | length) - ($estate_latency | length)),
                     median: ($estate_latency | median | r1), p90: ($estate_latency | p90 | r1),
                     per_period_median: period_medians($latency_pairs),
                     trend: trend_sparse(period_medians($latency_pairs)) } },
    quality: {
      commits: $estate_commits,
      size: size_of($merged),
      review: review_of($merged),
      ci: ci_of($ci_groups) },
    risk: {
      concentration: concentration_of($authored),
      concentrated_repositories: $concentrated,
      unmaintained: $unmaintained,
      stalled_pull_requests: $stalled,
      open_pull_requests: ($open_now | length),
      open_issues: ($repo_models | map(.issues.open) | add // 0) },
    repositories: $repo_models,
    unread: [$signals[] | select(.status == "unread") | {repo: .repo, signal: .signal, reason: .detail}],
    caps: [$signals[] | select(.status == "read" and .detail != "complete") | {repo: .repo, signal: .signal, detail: .detail}]
  }
JQ
)

derive() {  # reads $RECORDS, prints the model
  jq -Rn \
    --arg contract "$CONTRACT" \
    --arg now "$NOW" \
    --arg scope_kind "$SCOPE_KIND" \
    --arg scope_name "$SCOPE_NAME" \
    --argjson win "$WINDOW_JSON" \
    --argjson commands "$COMMANDS_JSON" \
    --argjson opt "$OPTIONS_JSON" \
    "$DERIVE_JQ" < "$RECORDS"
}

# ---------------------------------------------------------------------------
# Rendering: model -> report.
# ---------------------------------------------------------------------------
# The renderer is the single owner of the report's shape and performs no
# arithmetic. Every section is emitted unconditionally: an estate with no reviews
# still gets a review section, and it says so in a sentence. A section that
# disappeared when it had no data would be indistinguishable from a section that
# was never part of the report, and only one of those is honest.
RENDER_JQ=$(
  cat <<'JQ'
def num: if . == null then "not measurable" else tostring end;
def pc: if . == null then "not measurable" else ((tostring) + "%") end;
def hrs: if . == null then "not measurable" else ((tostring) + " h") end;
def days: if . == null then "unknown" else ((tostring) + " d") end;
def dash: if . == null or . == "" then "-" else tostring end;
def yn($b): if $b then "yes" else "no" end;
def trendword: if . == "rising" then "rising"
  elif . == "falling" then "falling"
  elif . == "flat" then "flat"
  elif . == "not-tracked" then "not tracked over periods"
  elif . == "final-period-unmeasured" then "not reported: the last period has no measurement"
  else "not enough history" end;
# A cell is one column, whatever the estate put in it. A pull request title or a
# vendor diagnostic can carry the pipe this table separates cells with, so it is
# escaped here, at the one boundary where the one-cell-per-column contract lives.
# The model keeps the estate's own text; only this rendering is escaped.
def row($cells): "| " + ($cells | map(tostring | gsub("[|]"; "\\|")) | join(" | ")) + " |";
def header($cells): [row($cells), "|" + ($cells | map(" --- ") | join("|")) + "|"];
def bullet($text): "- " + $text;
# A risk list is already ordered worst first, so bounding the rows a reader has
# to scan costs nothing as long as the remainder is disclosed. The model keeps
# every row; only this presentation is bounded, and the counts above each list
# are always the complete ones.
def listed($rows; $cap): if $cap == 0 or ($rows | length) <= $cap then $rows else $rows[0:$cap] end;
def remainder($rows; $cap; $what): if $cap == 0 or ($rows | length) <= $cap then []
  else ["", "\(($rows | length) - $cap) further \($what) are in this report's model but not listed above; raise `--max-listed` to see them, either on a fresh run or on this report's model with `--from-json`."] end;

. as $m
| $m.window as $w
| $m.options as $o
| $m.selection as $sel
| ($w.period_labels) as $labels
| (if $m.scope.kind == "repository" then "repository" else "organization" end) as $scope_word
# A series with no measurement in its last period gets no direction at all, and
# the reader is told which periods were empty rather than left to infer it.
| def empty_periods($series): [range(0; ($series | length)) | select($series[.] == null) | $labels[.]];
  def direction($series; $trend; $rising):
    if $trend == "final-period-unmeasured"
    then "Direction: not reported, because the last period has no measurement; periods beginning \(empty_periods($series) | join(", ")) had none"
    else "Direction: \($trend | trendword) (\($rising))" end;
  [
  "# Estate review: \($m.scope.name)",
  "",
  bullet("Estate: \($scope_word) `\($m.scope.name)`"),
  bullet("Window: \($w.since) to \($w.until) (\($w.days) days, \($w.periods) periods of \($w.period_days) days)"),
  bullet("Repositories: \($sel.matched) matched the selection, \($sel.reviewed) reviewed, \($sel.fully_read) read completely, \($sel.partially_read) read with at least one gap"),
  bullet("Generated: \($m.generated_at) by `\($m.generator)`, report contract `\($m.contract)`"),
  "",
  "## 1. Scope and method",
  "",
  "This report has a fixed shape.",
  "The same nine sections appear in the same order for every estate, and a section with no data says so rather than disappearing.",
  "Two reports of the same estate are therefore comparable line for line, and section 9 names the read every figure came from.",
  "",
  "Selection: forks \(if $o.include_forks then "included" else "excluded" end), archived repositories \(if $o.exclude_archived then "excluded" else "included and labelled" end), at most \(if $o.max_repos == 0 then "no limit on" else "\($o.max_repos)" end) repositories, at most \(if $o.max_prs == 0 then "no limit on" else "\($o.max_prs)" end) pull requests per repository.",
  "Thresholds: an open pull request idle for \($o.stalled_days) days or more is stalled; a repository unpushed for \($o.unmaintained_days) days or more is unmaintained; a period-over-period change beyond \($o.trend_band_pct)% is called rising or falling, and anything inside that band is flat.",
  "Those first two are the only figures in this report measured from when it collected rather than from inside the window, because what is open and what has been pushed are facts about the estate now; sections 6.2, 6.3, and section 7's open and idle columns say so where they appear.",
  "A direction is never drawn from a period that ended before the window did: where the last period holds no measurement, no direction is reported and the empty periods are named.",
  "Section 6's lists show \(if $o.max_listed == 0 then "every" else "at most \($o.max_listed)" end) worst-first rows and state how many there are in total; the counts are always complete even where the rows are bounded.",
  "",
  "Definitions, which are the same in every report:",
  "",
  bullet("Commits are commits on each repository's default branch that landed inside the window, counted by committer date, which is the date GitHub's own commit list filters on. Work that was rebased, amended, cherry-picked, or squashed therefore counts in the window it landed in, not the window it was written in. Merge commits are counted separately and excluded from authorship, revert, and concentration figures, because a merge is not an authored change."),
  bullet("A person is a GitHub account. A commit whose author GitHub could not link to an account is attributed to `unlinked:<email>` and never merged into an account by name, because matching people by name is a guess."),
  bullet("An automation account is marked as such and its counts are kept in every total, because a bot's merged pull requests really did land. The only identity GitHub reports two ways is an app's account, given as `name[bot]` by one endpoint and `name` by another; that suffix is folded so one actor is one row, and nothing else is."),
  bullet("Pull requests opened, merged, and closed without merging are counted by the date of that event falling inside the window."),
  bullet("Cycle time is the hours from the commit date of a merged pull request's first commit to its merge. A pull request whose first commit is unreadable is reported as unmeasurable rather than dropped."),
  bullet("Review latency is the hours from a merged pull request being opened to the first review on it submitted by another identified account, no earlier than the pull request itself. Self-review is not review coverage and is excluded everywhere in this report, and so is a review whose author GitHub no longer reports."),
  bullet("Change size is additions plus deletions on merged pull requests, which is the unit of change a person actually reviews."),
  bullet("The revert rate is the share of authored commits whose subject opens with `Revert` or `revert` followed by a space, colon, bracket, or quote, which is the shape git's own revert subjects take; the hotfix rate is the share whose subject contains `hotfix` in any case. Both measure what the estate labels, not what actually broke."),
  bullet("The continuous integration latest-attempt pass rate groups GitHub Actions pull-request runs by workflow and commit, takes the most recent run of each group, and reports the share of them that succeeded out of those that succeeded or failed. A run's conclusion is the conclusion of its latest attempt, because that is what the runs list reports; a run re-run without a new commit therefore counts here as whatever it ended up as. Succeeded means `success`; failed means `failure`, `timed_out`, or `startup_failure`. Every other conclusion is counted as inconclusive and left out of the rate entirely, which covers a cancelled or skipped run, one still going, and the rarer `neutral`, `action_required`, and `stale`."),
  bullet("Accounts covering half the commits is the smallest number of accounts whose combined commits exceed half the authored commits in the window. Section 6.1 reports it for the estate; its per-repository form is not printed as a figure, and is what decides which repositories section 6.1 lists as concentrated and what the headline count of them is. Section 7's Authors column is a different figure: the number of accounts that authored any commit."),
  bullet("The median is the middle value, or the mean of the two middle values where there is an even number of them; p90 is the ninetieth percentile by nearest rank."),
  "",
  "## 2. Headline",
  ""
  ]
+ header(["Measure", "Value", "Unit", "Direction over the window"])
+ [$m.headline[] | row([.metric, (.value | num), .unit, (.trend | trendword)])]
+ [
  "",
  (if $m.quality.commits.total == 0 and ($m.people | length) == 0 and $m.quality.ci.runs == 0 and ($m.unread | length) == 0
   then "No commit, pull request, review, or workflow run fell inside this window, so every measure above is zero or unmeasurable rather than low."
   elif ($m.unread | length) > 0 and $m.quality.commits.total == 0 and ($m.people | length) == 0 and $m.quality.ci.runs == 0
   then "Every figure above is zero or unmeasurable, and \($m.unread | length) reads failed, so this report cannot tell a silent estate from an unread one; section 9.2 names every gap."
   else "A rising cycle time means work is getting slower; a rising merged count means more is landing." end),
  "",
  "## 3. Who did what",
  "",
  "### 3.1 Contribution by person",
  "",
  "Sorted by account name, never by volume.",
  "This table is a record of participation, not a ranking, and the counts carry no judgement about anyone's effort, difficulty of work, or worth.",
  ""
  ]
+ (if ($m.people | length) == 0 then ["No account committed, opened a pull request, or reviewed one in this window."]
   else header(["Account", "Automation", "Commits", "Pull requests opened", "Pull requests merged", "Reviews submitted", "Pull requests reviewed", "Repositories touched"])
        + [$m.people[] | row([.person, yn(.automation), .commits, .prs_opened, .prs_merged, .reviews_submitted, .prs_reviewed, .repos])]
        + ["",
           "Automation accounts in this table: \($m.people | map(select(.automation)) | length) of \($m.people | length)."]
   end)
+ [
  "",
  "### 3.2 Review participation",
  "",
  "Reviews given matter as much as authorship and are the half most tooling drops, so they get their own section whether or not the estate has any.",
  ""
  ]
+ (($m.people | map(select(.reviews_submitted > 0))) as $reviewers
   | if ($reviewers | length) == 0
     then ["No account submitted a review of another account's pull request in this window.",
           "",
           "Of \($m.quality.review.merged) merged pull requests, \($m.quality.review.with_review_by_another_account) carried a review by another account.",
           "That is a fact about this estate's recorded review activity, not evidence that the work went unexamined: review can happen in a channel GitHub never sees."]
     else header(["Account", "Automation", "Reviews submitted", "Pull requests reviewed"])
          + [$reviewers[] | row([.person, yn(.automation), .reviews_submitted, .prs_reviewed])]
          + ["",
             "\($m.quality.review.with_review_by_another_account) of \($m.quality.review.merged) merged pull requests carried a review by an account other than the author (\($m.quality.review.coverage_pct | pc))."]
     end)
+ [
  "",
  "## 4. Velocity",
  "",
  "### 4.1 Throughput",
  "",
  "Each period is \($w.period_days) days; the earliest period begins at the window start.",
  ""
  ]
+ header(["Period beginning"] + $labels + ["Direction"])
+ [row(["Commits authored"] + $m.velocity.commits.per_period + [($m.velocity.commits.trend | trendword)]),
   row(["Pull requests opened"] + $m.velocity.opened.per_period + [($m.velocity.opened.trend | trendword)]),
   row(["Pull requests merged"] + $m.velocity.merged.per_period + [($m.velocity.merged.trend | trendword)])]
+ [
  "",
  (if ($m.quality.commits.total == 0) and (($m.velocity.merged.per_period | add) == 0)
   then (if ($m.unread | length) == 0 then "Nothing was committed or merged in this window."
         else "Nothing was committed or merged in what could be read; \($m.unread | length) reads failed and section 9.2 names them." end)
   else "Direction compares the last period against the mean of the earlier ones." end),
  "",
  "### 4.2 Cycle time, first commit to merge",
  ""
  ]
+ (if $m.velocity.cycle_hours.measured == 0
   then ["No merged pull request in this window had a readable first commit, so cycle time is unmeasurable here.",
         "\($m.velocity.cycle_hours.unmeasurable) merged pull requests were excluded for that reason."]
   else [bullet("Median: \($m.velocity.cycle_hours.median | hrs) over \($m.velocity.cycle_hours.measured) merged pull requests"),
         bullet("p90: \($m.velocity.cycle_hours.p90 | hrs)"),
         bullet(direction($m.velocity.cycle_hours.per_period_median; $m.velocity.cycle_hours.trend; "rising means slower")),
         bullet("Unmeasurable: \($m.velocity.cycle_hours.unmeasurable) merged pull requests had no readable first commit"),
         ""]
        + header(["Period beginning"] + $labels)
        + [row(["Median hours"] + ($m.velocity.cycle_hours.per_period_median | map(num)))]
   end)
+ [
  "",
  "### 4.3 Review latency, opened to first review by another account",
  ""
  ]
+ (if $m.velocity.review_latency_hours.measured == 0
   then ["No merged pull request in this window received a review from another account, so review latency is unmeasurable here.",
         "That is the same fact section 3.2 reports, stated as a waiting time rather than as coverage."]
   else [bullet("Median: \($m.velocity.review_latency_hours.median | hrs) over \($m.velocity.review_latency_hours.measured) merged pull requests"),
         bullet("p90: \($m.velocity.review_latency_hours.p90 | hrs)"),
         bullet(direction($m.velocity.review_latency_hours.per_period_median; $m.velocity.review_latency_hours.trend; "rising means longer waits")),
         bullet("Not included: \($m.velocity.review_latency_hours.unmeasurable) merged pull requests had no review from another account"),
         ""]
        + header(["Period beginning"] + $labels)
        + [row(["Median hours"] + ($m.velocity.review_latency_hours.per_period_median | map(num)))]
   end)
+ [
  "",
  "## 5. Quality",
  "",
  "Each figure below says what it evidences and what it does not.",
  "A quality signal that is presented without that boundary invites a conclusion the data cannot carry.",
  "",
  "### 5.1 Reverts and hotfixes",
  ""
  ]
+ (if $m.quality.commits.commits == 0
   then ["No authored commit landed on a default branch in this window, so there is no revert or hotfix rate to report."]
   else [bullet("Reverts: \($m.quality.commits.reverts) of \($m.quality.commits.commits) authored commits (\($m.quality.commits.revert_rate_pct | pc))"),
         bullet("Hotfixes: \($m.quality.commits.hotfixes) of \($m.quality.commits.commits) authored commits (\($m.quality.commits.hotfix_rate_pct | pc))"),
         "",
         "This counts what the estate labelled.",
         "It evidences how often the estate itself declared a change wrong; it does not evidence the defect rate, because a fix that was never called a revert or a hotfix is invisible here."]
   end)
+ [
  "",
  "### 5.2 Change size",
  ""
  ]
+ (if $m.quality.size.measured == 0
   then ["No pull request merged in this window, so there is no change-size distribution to report."]
   else [bullet("Median merged pull request: \($m.quality.size.median_lines | num) lines changed"),
         bullet("p90 merged pull request: \($m.quality.size.p90_lines | num) lines changed"),
         ""]
        + header(["Lines changed", "Merged pull requests"])
        + [row(["under 10", $m.quality.size.distribution.under_10]),
           row(["10 to 49", $m.quality.size.distribution.from_10_to_49]),
           row(["50 to 249", $m.quality.size.distribution.from_50_to_249]),
           row(["250 to 999", $m.quality.size.distribution.from_250_to_999]),
           row(["1000 or more", $m.quality.size.distribution.at_least_1000])]
        + ["",
           "Size evidences how much a reviewer was asked to hold at once.",
           "It does not evidence difficulty or risk: a one-line change can be the dangerous one, and a large generated diff can be trivial."]
   end)
+ [
  "",
  "### 5.3 Review depth",
  ""
  ]
+ (if $m.quality.review.merged == 0
   then ["No pull request merged in this window, so there is no review depth to report."]
   else [bullet("Merged pull requests reviewed by another account: \($m.quality.review.with_review_by_another_account) of \($m.quality.review.merged) (\($m.quality.review.coverage_pct | pc))"),
         bullet("Median review threads per merged pull request: \($m.quality.review.review_threads_median | num)"),
         bullet("Total review threads on merged pull requests: \($m.quality.review.review_threads_total)"),
         "",
         "Thread count evidences how much conversation a change drew.",
         "It does not evidence how carefully anything was read: a correct change reviewed closely can draw no comment at all."]
   end)
+ [
  "",
  "### 5.4 Continuous integration latest-attempt pass rate",
  ""
  ]
+ (if $m.quality.ci.runs == 0
   then ["No GitHub Actions pull-request run happened inside this window, so there is no latest-attempt pass rate to report.",
         "An estate whose checks run outside GitHub Actions will always read this way here, because this report does not see those checks."]
   else [bullet("Latest-attempt pass rate: \($m.quality.ci.latest_attempt_pass_rate_pct | pc) (\($m.quality.ci.passed) passed, \($m.quality.ci.failed) failed)"),
         bullet("Inconclusive runs excluded from the rate: \($m.quality.ci.inconclusive)"),
         bullet("Checks that needed more than one attempt on the same commit: \($m.quality.ci.needed_more_than_one_attempt)"),
         "",
         "This evidences how a check ended up, not how it started: the runs list reports each run's latest attempt, so a check that failed and was re-run to green on the same commit counts as a pass here.",
         "It cannot separate a real defect from a flaky job, and it sees only GitHub Actions: checks reported by any other system are invisible to it.",
         "The attempt count says only that a check on that commit was attempted more than once; it does not say why."]
   end)
+ [
  "",
  "## 6. Risk and concentration",
  "",
  "### 6.1 Knowledge concentration",
  ""
  ]
+ (if $m.risk.concentration.commits == 0
   then ["No authored commit landed in this window, so concentration is unmeasurable."]
   else [bullet("Accounts that authored commits: \($m.risk.concentration.authors)"),
         bullet("Accounts covering half the estate's authored commits: \($m.risk.concentration.accounts_covering_half | num)"),
         bullet("Largest single share: \($m.risk.concentration.top | dash) at \($m.risk.concentration.top_share_pct | pc)"),
         ""]
        + (if ($m.risk.concentrated_repositories | length) == 0
           then ["No repository has more than half its authored commits from a single account."]
           else ["Repositories where one account authored more than half the commits in this window: \($m.risk.concentrated_repositories | length).",
                 ""]
                + header(["Repository", "Account", "Share", "Authors", "Authored commits"])
                + [listed($m.risk.concentrated_repositories; $o.max_listed)[]
                   | row([.repo, (.top | dash), (.top_share_pct | pc), .authors, .commits])]
                + remainder($m.risk.concentrated_repositories; $o.max_listed; "repositories")
           end)
        + ["",
           "This evidences where the estate's recorded history sits with one account.",
           "It does not evidence who understands what: someone who reviewed every change may hold the knowledge without a commit to show for it."]
   end)
+ [
  "",
  "### 6.2 Unmaintained repositories, as at collection",
  ""
  ]
+ (if ($m.risk.unmaintained | length) == 0
   then ["No reviewed repository is archived or had gone \($o.unmaintained_days) days without a push when this review collected."]
   else ["Repositories archived or unpushed for \($o.unmaintained_days) days or more as at \($m.generated_at): \($m.risk.unmaintained | length).",
         ""]
        + header(["Repository", "Days since last push, at collection", "Archived", "Commits in window"])
        + [listed($m.risk.unmaintained; $o.max_listed)[] | row([.repo, (.idle_days | num), yn(.archived), .commits_in_window])]
        + remainder($m.risk.unmaintained; $o.max_listed; "repositories")
   end)
+ [
  "",
  "### 6.3 Stalled work, as at collection",
  "",
  "Unlike every figure above, this subsection is the state of the estate when this review collected, not a quantity inside the window: what is open now, and how long it has been sitting as at \($m.generated_at).",
  ""
  ]
+ [bullet("Open pull requests: \($m.risk.open_pull_requests)"),
   bullet("Open issues: \($m.risk.open_issues)"),
   ""]
+ (if ($m.risk.stalled_pull_requests | length) == 0
   then ["No open pull request has been idle for \($o.stalled_days) days or more."]
   else ["Open pull requests idle for \($o.stalled_days) days or more: \($m.risk.stalled_pull_requests | length), longest idle first.",
         ""]
        + header(["Repository", "Number", "Idle days", "Age days", "Author", "Draft", "Title"])
        + [listed($m.risk.stalled_pull_requests; $o.max_listed)[]
           | row([.repo, .number, .idle_days, .age_days, (.author | dash), yn(.draft), .title])]
        + remainder($m.risk.stalled_pull_requests; $o.max_listed; "pull requests")
   end)
+ [
  "",
  "## 7. Per-repository detail",
  "",
  "One row per reviewed repository, sorted by name.",
  "An organization review is this table plus the aggregate above; a single-repository review is the same report with one row here.",
  ""
  ]
+ header(["Repository", "Commits", "Merged", "Open", "Median cycle", "Reviewed", "Latest-attempt CI", "Authors", "Idle days at collection", "Archived", "Gaps"])
+ [$m.repositories[] | row([
    .name, .commits.total, .pull_requests.merged, .pull_requests.open_now,
    (.pull_requests.cycle_hours.median | hrs), (.review.coverage_pct | pc),
    (.ci.latest_attempt_pass_rate_pct | pc), .concentration.authors, (.idle_days | num), yn(.archived),
    ([.signals | to_entries[] | select(.value.status == "unread") | .key] | if length == 0 then "none" else join(", ") end)])]
+ [
  "",
  "## 8. What these numbers do not measure",
  "",
  bullet("They do not measure anyone's productivity, effort, skill, or value. A commit count is a count of commits."),
  bullet("They do not measure difficulty. The hardest change in this window may be the smallest row in it."),
  bullet("They do not measure quality of thought. Review threads count conversation, not care."),
  bullet("They do not see work outside this estate's GitHub record: pairing, design, incident response, mentoring, review in chat, and work in repositories outside the selection are all absent."),
  bullet("They do not attribute shared work. A pull request has one author field, whoever did the work."),
  bullet("They do not establish cause. A rising cycle time is a fact to ask about, not a conclusion about anyone."),
  bullet("They are bounded by the window and the caps in section 1. A figure here describes what was collected, never the whole history."),
  "",
  "## 9. Collection log",
  "",
  "### 9.1 Commands",
  "",
  "These are the templates each read was built from, one per surface, with this run's window already substituted.",
  "They are not a transcript to paste: `<owner>/<repo>` and `<default_branch>` stand for each repository in section 7, and the two GraphQL reads name their query rather than printing its body.",
  "Filled in that way and run against the same estate and window, they return the data every figure above was derived from.",
  ""
  ]
+ [$m.commands[] | "- `" + . + "`"]
+ [
  "",
  "### 9.2 What was read",
  ""
  ]
+ header(["Repository", "Commits", "Pull requests", "Open pull requests", "CI runs", "Issues"])
+ [$m.repositories[] | row([.name,
    (.signals.commits.status // "not attempted"),
    (.signals.pull_requests.status // "not attempted"),
    (.signals.open_pull_requests.status // "not attempted"),
    (.signals.ci_runs.status // "not attempted"),
    (.signals.issues.status // "not attempted")])]
+ [""]
+ (if ($m.unread | length) == 0
   then ["Every reviewed repository was read completely for every signal this report uses."]
   else ["Named gaps.",
         "A repository the tooling could not read is named here and excluded from the figures it could not supply; it is never silently dropped from an aggregate.",
         ""]
        + header(["Repository", "Signal", "Reason"])
        + [$m.unread[] | row([.repo, .signal, .reason])]
   end)
+ [""]
+ (if ($m.caps | length) == 0
   then ["No read hit a collection cap."]
   else ["Reads that hit a cap, so the figures they feed describe the collected subset rather than the whole window:",
         ""]
        + header(["Repository", "Signal", "Cap"])
        + [$m.caps[] | row([.repo, .signal, .detail])]
   end)
+ [""]
+ (if ($m.selection.capped | not) then []
   else ["More repositories matched the selection than were reviewed: \($m.selection.matched) matched, \($m.selection.reviewed) reviewed under `--max-repos`.", ""]
   end)
| join("\n")
JQ
)

render() {  # reads the model on stdin
  jq -r "$RENDER_JQ"
}

# ---------------------------------------------------------------------------
# Entry point.
# ---------------------------------------------------------------------------
if [ -n "$FROM_JSON" ]; then
  jq -e --arg c "$CONTRACT" '.contract == $c' "$FROM_JSON" > /dev/null 2>&1 ||
    die "$FROM_JSON is not a $CONTRACT model"
  # A raised --max-listed is written into the model's own options, so the report
  # and the model it was rendered from state the same bound.
  stored_model() {
    jq --argjson listed "$MAX_LISTED" --argjson given "$MAX_LISTED_GIVEN" \
      'if $given == 1 then .options.max_listed = $listed else . end' "$FROM_JSON"
  }
  if [ "$OUTPUT" = json ]; then
    stored_model
  else
    stored_model | render
  fi
  exit 0
fi

command -v gh-axi > /dev/null 2>&1 || die "gh-axi is required for estate collection"
command -v gh > /dev/null 2>&1 || die "gh is required: gh-axi wraps the GitHub CLI"

TMPROOT=$(mktemp -d "${TMPDIR:-/tmp}/xo-estate-review.XXXXXX") || die "could not create a working directory"
gh_scratch_init
resolve_window
resolve_scope

SINCE_ISO=$(printf '%s' "$WINDOW_JSON" | jq -r .since)
UNTIL_ISO=$(printf '%s' "$WINDOW_JSON" | jq -r .until)
OPTIONS_JSON=$(jq -n \
  --argjson window_days "$WINDOW_DAYS" --argjson periods "$PERIODS" \
  --argjson stalled_days "$STALLED_DAYS" --argjson unmaintained_days "$UNMAINTAINED_DAYS" \
  --argjson max_repos "$MAX_REPOS" --argjson max_prs "$MAX_PRS" \
  --argjson max_listed "$MAX_LISTED" \
  --argjson include_forks "$INCLUDE_FORKS" --argjson exclude_archived "$EXCLUDE_ARCHIVED" \
  --argjson reviews_per_pr "$REVIEWS_PER_PR" --argjson max_pages "$REST_MAX_PAGES" \
  '{window_days: $window_days, periods: $periods, stalled_days: $stalled_days,
    unmaintained_days: $unmaintained_days, max_repos: $max_repos, max_prs: $max_prs,
    max_listed: $max_listed,
    include_forks: ($include_forks == 1), exclude_archived: ($exclude_archived == 1),
    reviews_per_pull_request: $reviews_per_pr, page_limit: $max_pages, trend_band_pct: 15}')

# The recorded commands are templates with this run's window substituted, one per
# read the report depends on, rather than one line per page of every repository.
# A reader has to be able to re-derive a figure; a log of four hundred paged URLs
# would bury that rather than serve it.
COMMANDS_JSON=$(jq -n \
  --arg scope "$SCOPE_NAME" --arg kind "$SCOPE_KIND" \
  --arg since "$SINCE_ISO" --arg until "$UNTIL_ISO" \
  --arg since_date "${SINCE_ISO%%T*}" --arg until_date "${UNTIL_ISO%%T*}" '
  (if $kind == "organization" then "gh-axi api /orgs/\($scope)/repos?type=all&sort=full_name --paginate"
   else "gh-axi api /repos/\($scope)" end) as $repos
  | [$repos,
     "gh-axi api /repos/<owner>/<repo>/commits?sha=<default_branch>&since=\($since)&until=\($until) --paginate",
     "gh-axi api POST graphql --input <pull-requests-updated-desc-until-\($since)>",
     "gh-axi api POST graphql --input <open-pull-requests-created-asc>",
     "gh-axi api /repos/<owner>/<repo>/actions/runs?event=pull_request&created=\($since_date)..\($until_date) --paginate",
     "gh-axi api /repos/<owner>/<repo>/issues?state=open --paginate"]')

collect
MODEL=$(derive) || die "could not derive the review model from the collected records"

if [ "$OUTPUT" = json ]; then
  printf '%s\n' "$MODEL"
else
  printf '%s\n' "$MODEL" | render
fi
