#!/usr/bin/env bash
# Behavior tests for bin/xo-estate-review.sh, the read-only estate review.
#
# Two things need pinning and they fail for different reasons.
#
# The report's SHAPE is the product: every run emits the same nine sections in
# the same order, and a surface with no data states that it is empty instead of
# disappearing. Those cases drive the renderer through --from-json, because a
# fixed shape is only worth anything if it survives an estate with no reviews, no
# CI, and an unreadable repository.
#
# The gh-axi ENVELOPE is a vendor rendering this script decodes. The fake gh-axi
# here is not a stub of the answer: it holds real GitHub-shaped JSON, applies the
# script's own --jq program to it, and renders the envelope gh-axi renders, so the
# collection path under test is the real one. A changed envelope must refuse
# loudly rather than report an empty estate, which is the worst possible failure
# for a report the captain acts on, so that refusal is pinned here too.
# tests/xo-estate-review-live-e2e.test.sh proves the real gh-axi still emits the
# envelope these fakes reproduce.
set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

REVIEW="$ROOT/bin/xo-estate-review.sh"
NOW=2026-04-01T00:00:00Z
WINDOW=(--since 2026-01-01 --until 2026-04-01)

# --- fixtures ---------------------------------------------------------------
# One organization: an active repository with two people, one unlinked commit
# author, two automation accounts, a revert, a workflow run that needed a second
# attempt on the same commit, and one long-idle open pull request that carries a
# review from another account; plus an archived repository with nothing in it,
# which is what proves an empty row still appears.
write_fixtures() {
  local dir=$1
  mkdir -p "$dir"
  cat > "$dir/owner.json" <<'JSON'
{"login":"acme","type":"Organization"}
JSON
  cat > "$dir/owner-user.json" <<'JSON'
{"login":"acme","type":"User"}
JSON
  cat > "$dir/repos.json" <<'JSON'
[
 {"full_name":"acme/widgets","name":"widgets","owner":{"login":"acme"},"default_branch":"main","archived":false,"fork":false,"pushed_at":"2026-03-30T00:00:00Z","private":false},
 {"full_name":"acme/attic","name":"attic","owner":{"login":"acme"},"default_branch":"main","archived":true,"fork":false,"pushed_at":"2024-01-01T00:00:00Z","private":false}
]
JSON
  # Every commit carries both dates GitHub reports. They agree here, which is the
  # ordinary case; the case where they disagree gets its own fixture below.
  cat > "$dir/commits-widgets.json" <<'JSON'
[
 {"sha":"c1","author":{"login":"ada","type":"User"},"parents":[{"sha":"c0"}],"commit":{"author":{"email":"ada@example.com","date":"2026-01-10T00:00:00Z"},"committer":{"email":"ada@example.com","date":"2026-01-10T00:00:00Z"},"message":"feat: add widget\n\nbody"}},
 {"sha":"c2","author":{"login":"ada","type":"User"},"parents":[{"sha":"c1"}],"commit":{"author":{"email":"ada@example.com","date":"2026-01-20T00:00:00Z"},"committer":{"email":"ada@example.com","date":"2026-01-20T00:00:00Z"},"message":"fix: widget edge case"}},
 {"sha":"c3","author":{"login":"brooke","type":"User"},"parents":[{"sha":"c2"}],"commit":{"author":{"email":"brooke@example.com","date":"2026-02-05T00:00:00Z"},"committer":{"email":"brooke@example.com","date":"2026-02-05T00:00:00Z"},"message":"feat: add gadget"}},
 {"sha":"c4","author":null,"parents":[{"sha":"c3"}],"commit":{"author":{"email":"Carol@Example.com","date":"2026-02-15T00:00:00Z"},"committer":{"email":"Carol@Example.com","date":"2026-02-15T00:00:00Z"},"message":"chore: tidy"}},
 {"sha":"c5","author":{"login":"dependabot[bot]","type":"Bot"},"parents":[{"sha":"c4"}],"commit":{"author":{"email":"bot@example.com","date":"2026-03-01T00:00:00Z"},"committer":{"email":"bot@example.com","date":"2026-03-01T00:00:00Z"},"message":"build(deps): bump lib"}},
 {"sha":"c6","author":{"login":"ada","type":"User"},"parents":[{"sha":"c5"},{"sha":"x1"}],"commit":{"author":{"email":"ada@example.com","date":"2026-03-10T00:00:00Z"},"committer":{"email":"ada@example.com","date":"2026-03-10T00:00:00Z"},"message":"Merge pull request #4"}},
 {"sha":"c7","author":{"login":"brooke","type":"User"},"parents":[{"sha":"c6"}],"commit":{"author":{"email":"brooke@example.com","date":"2026-03-12T00:00:00Z"},"committer":{"email":"brooke@example.com","date":"2026-03-12T00:00:00Z"},"message":"Revert \"feat: add gadget\""}}
]
JSON
  # The runs list returns one entry per run carrying that run's CURRENT attempt:
  # a re-run increments run_attempt on the same entry rather than adding another,
  # so run 2 below is the shape GitHub gives a check that failed and was re-run to
  # green on one commit. Two entries sharing a head_sha with different run_numbers
  # would not be that shape, and a fixture that invented one would confirm the
  # code rather than the claim.
  cat > "$dir/runs-widgets.json" <<'JSON'
{"workflow_runs":[
 {"workflow_id":1,"head_sha":"s1","run_number":1,"run_attempt":1,"conclusion":"success","created_at":"2026-01-06T00:00:00Z"},
 {"workflow_id":1,"head_sha":"s2","run_number":2,"run_attempt":2,"conclusion":"success","created_at":"2026-02-03T00:00:00Z"},
 {"workflow_id":1,"head_sha":"s3","run_number":3,"run_attempt":1,"conclusion":"failure","created_at":"2026-03-06T00:00:00Z"},
 {"workflow_id":1,"head_sha":"s4","run_number":4,"run_attempt":1,"conclusion":"cancelled","created_at":"2026-03-09T00:00:00Z"}
]}
JSON
  cat > "$dir/issues-widgets.json" <<'JSON'
[
 {"number":10,"created_at":"2026-01-02T00:00:00Z","updated_at":"2026-01-02T00:00:00Z"},
 {"number":11,"created_at":"2026-03-20T00:00:00Z","updated_at":"2026-03-20T00:00:00Z"},
 {"number":12,"created_at":"2026-03-21T00:00:00Z","updated_at":"2026-03-21T00:00:00Z","pull_request":{"url":"x"}}
]
JSON
  cat > "$dir/prs-widgets.json" <<'JSON'
{"data":{"repository":{"pullRequests":{"pageInfo":{"hasNextPage":false,"endCursor":null},"nodes":[
 {"number":1,"state":"MERGED","isDraft":false,"createdAt":"2026-01-05T00:00:00Z","updatedAt":"2026-01-06T00:00:00Z","mergedAt":"2026-01-06T00:00:00Z","closedAt":"2026-01-06T00:00:00Z","additions":30,"deletions":10,"changedFiles":3,"headRefName":"f/1","title":"add widget","author":{"login":"ada","__typename":"User"},"commits":{"nodes":[{"commit":{"committedDate":"2026-01-04T00:00:00Z"}}]},"reviews":{"totalCount":1,"nodes":[{"author":{"login":"brooke","__typename":"User"},"submittedAt":"2026-01-05T12:00:00Z","state":"APPROVED"}]},"reviewThreads":{"totalCount":2}},
 {"number":2,"state":"MERGED","isDraft":false,"createdAt":"2026-02-01T00:00:00Z","updatedAt":"2026-02-03T00:00:00Z","mergedAt":"2026-02-03T00:00:00Z","closedAt":"2026-02-03T00:00:00Z","additions":200,"deletions":100,"changedFiles":9,"headRefName":"f/2","title":"add gadget","author":{"login":"brooke","__typename":"User"},"commits":{"nodes":[{"commit":{"committedDate":"2026-02-01T00:00:00Z"}}]},"reviews":{"totalCount":2,"nodes":[{"author":{"login":"brooke","__typename":"User"},"submittedAt":"2026-02-02T00:00:00Z","state":"COMMENTED"},{"author":{"login":"ada","__typename":"User"},"submittedAt":"2026-02-02T06:00:00Z","state":"APPROVED"}]},"reviewThreads":{"totalCount":5}},
 {"number":3,"state":"MERGED","isDraft":false,"createdAt":"2026-03-05T00:00:00Z","updatedAt":"2026-03-06T00:00:00Z","mergedAt":"2026-03-06T00:00:00Z","closedAt":"2026-03-06T00:00:00Z","additions":5,"deletions":2,"changedFiles":1,"headRefName":"f/3","title":"tidy","author":{"login":"ada","__typename":"User"},"commits":{"nodes":[{"commit":{"committedDate":"2026-03-04T00:00:00Z"}}]},"reviews":{"totalCount":0,"nodes":[]},"reviewThreads":{"totalCount":0}},
 {"number":4,"state":"MERGED","isDraft":false,"createdAt":"2026-03-08T00:00:00Z","updatedAt":"2026-03-09T00:00:00Z","mergedAt":"2026-03-09T00:00:00Z","closedAt":"2026-03-09T00:00:00Z","additions":2,"deletions":2,"changedFiles":1,"headRefName":"f/4","title":"bump lib","author":{"login":"dependabot","__typename":"Bot"},"commits":{"nodes":[{"commit":{"committedDate":"2026-03-08T00:00:00Z"}}]},"reviews":{"totalCount":1,"nodes":[{"author":{"login":"copilot-pull-request-reviewer","__typename":"Bot"},"submittedAt":"2026-03-08T01:00:00Z","state":"COMMENTED"}]},"reviewThreads":{"totalCount":0}},
 {"number":5,"state":"OPEN","isDraft":false,"createdAt":"2026-01-15T00:00:00Z","updatedAt":"2026-01-16T00:00:00Z","mergedAt":null,"closedAt":null,"additions":10,"deletions":0,"changedFiles":1,"headRefName":"f/5","title":"spike\twith a tab | and a pipe","author":{"login":"brooke","__typename":"User"},"commits":{"nodes":[{"commit":{"committedDate":"2026-01-15T00:00:00Z"}}]},"reviews":{"totalCount":1,"nodes":[{"author":{"login":"ada","__typename":"User"},"submittedAt":"2026-01-16T00:00:00Z","state":"APPROVED"}]},"reviewThreads":{"totalCount":0}},
 {"number":6,"state":"CLOSED","isDraft":false,"createdAt":"2026-02-20T00:00:00Z","updatedAt":"2026-02-21T00:00:00Z","mergedAt":null,"closedAt":"2026-02-21T00:00:00Z","additions":1,"deletions":1,"changedFiles":1,"headRefName":"f/6","title":"abandoned","author":{"login":"ada","__typename":"User"},"commits":{"nodes":[{"commit":{"committedDate":"2026-02-20T00:00:00Z"}}]},"reviews":{"totalCount":0,"nodes":[]},"reviewThreads":{"totalCount":0}}
]}}}}
JSON
  jq '.data.repository.pullRequests.nodes |= map(select(.state == "OPEN"))' \
    "$dir/prs-widgets.json" > "$dir/prs-open-widgets.json"
  local one
  for one in widgets attic; do
    jq --arg n "$one" '.[] | select(.name == $n)' "$dir/repos.json" > "$dir/repo-$one.json"
  done
  printf '[]\n' > "$dir/empty-array.json"
  printf '{"workflow_runs":[]}\n' > "$dir/empty-runs.json"
  cat > "$dir/empty-prs.json" <<'JSON'
{"data":{"repository":{"pullRequests":{"pageInfo":{"hasNextPage":false,"endCursor":null},"nodes":[]}}}}
JSON
}

# One page of the merged-pull-request walk: <count> pull requests merged at
# <at>, numbered from <first>, and a pageInfo that either names the cursor of the
# next page or ends the walk. A page whose next cursor names its own fixture is
# a repository the walk never runs out of pages on.
write_pr_page() {  # <file> <at-iso> <count> <first-number> <next-cursor-or-empty> [state]
  local file=$1 at=$2 count=$3 first=$4 next=$5 state=${6:-MERGED}
  jq -n --arg at "$at" --argjson count "$count" --argjson first "$first" --arg next "$next" \
    --arg state "$state" '
    (if $state == "OPEN" then null else $at end) as $ended
    | {data: {repository: {pullRequests: {
      pageInfo: (if $next == "" then {hasNextPage: false, endCursor: null}
                 else {hasNextPage: true, endCursor: $next} end),
      nodes: [range(0; $count) | ($first + .) as $n | {
        number: $n, state: $state, isDraft: false,
        createdAt: $at, updatedAt: $at, mergedAt: $ended, closedAt: $ended,
        additions: 1, deletions: 1, changedFiles: 1,
        headRefName: "f/\($n)", title: "pull request \($n)",
        author: {login: "ada", __typename: "User"},
        commits: {nodes: [{commit: {committedDate: $at}}]},
        reviews: {totalCount: 0, nodes: []}, reviewThreads: {totalCount: 0}}]}}}}' > "$file" ||
    fail "could not write the pull-request page $file"
}

# One repository, so the pull-request walk under test is the only one that runs.
keep_only_widgets() {  # <fixtures-dir>
  local dir=$1
  jq '[.[] | select(.name == "widgets")]' "$dir/repos.json" > "$dir/repos.tmp" ||
    fail "could not narrow the estate to one repository"
  mv "$dir/repos.tmp" "$dir/repos.json"
}

# A fake gh-axi that answers from those fixtures with the caller's own --jq
# program and renders the api_response envelope the real one renders: a bare body
# for a payload that needs no escaping, a JSON-quoted body otherwise.
install_fake_gh_axi() {
  local bin=$1 fixtures=$2 mode=${3:-ok}
  cat > "$bin/gh-axi" <<SH
#!/usr/bin/env bash
set -u
FIXTURES=$fixtures
MODE=$mode
SH
  cat >> "$bin/gh-axi" <<'SH'
[ "${1:-}" != "--version" ] || { printf 'gh-axi fake 9.9.9\n'; exit 0; }
printf '%s\n' "$*" >> "${FAKE_GH_LOG:-/dev/null}"
path='' program='' input='' cursor='' args=("$@") i=0
while [ "$i" -lt "${#args[@]}" ]; do
  case ${args[$i]} in
    --jq) i=$((i + 1)); program=${args[$i]} ;;
    --input) i=$((i + 1)); input=${args[$i]} ;;
    api | --full | GET | POST | PUT | PATCH | DELETE | HEAD) ;;
    -*) ;;
    *) [ -n "$path" ] || path=${args[$i]} ;;
  esac
  i=$((i + 1))
done
page=1
case $path in *page=*) page=${path##*page=}; page=${page%%&*} ;; esac
fixture=''
case $path in
  graphql)
    repo=$(jq -r '.variables.name' "$input")
    cursor=$(jq -r '.variables.cursor // "-"' "$input")
    # Either walk pages by cursor rather than by page number, so the next page is
    # the fixture named for the cursor the walk asked for. That is how a
    # multi-page walk is modelled without a second fake, and a fixture whose own
    # endCursor names itself is a walk that never runs out of pages.
    if grep -q 'states:OPEN' "$input"; then
      fixture=$FIXTURES/prs-open-$repo.json
      if [ "$cursor" != "-" ] && [ -f "$FIXTURES/prs-open-$repo-$cursor.json" ]; then
        fixture=$FIXTURES/prs-open-$repo-$cursor.json
      fi
    else
      fixture=$FIXTURES/prs-$repo.json
      if [ "$cursor" != "-" ] && [ -f "$FIXTURES/prs-$repo-$cursor.json" ]; then
        fixture=$FIXTURES/prs-$repo-$cursor.json
      fi
    fi
    [ -f "$fixture" ] || fixture=$FIXTURES/empty-prs.json
    ;;
  /users/*) fixture=$FIXTURES/owner.json ;;
  /orgs/*/repos*)
    # An estate that fills every page answers from repos-every-page.json, whose
    # entries are renamed per page below so the listing is a real walk over
    # distinct repositories rather than one page repeated.
    if [ -f "$FIXTURES/repos-every-page.json" ]; then
      fixture=$FIXTURES/repos-every-page.json
    else
      fixture=$FIXTURES/repos.json
    fi
    ;;
  */actions/runs*) repo=${path#/repos/acme/}; fixture=$FIXTURES/runs-${repo%%/actions/runs*}.json ;;
  */commits*) repo=${path#/repos/acme/}; fixture=$FIXTURES/commits-${repo%%/commits*}.json ;;
  */issues*) repo=${path#/repos/acme/}; fixture=$FIXTURES/issues-${repo%%/issues*}.json ;;
  /repos/acme/*) repo=${path#/repos/acme/}; fixture=$FIXTURES/repo-${repo%%[?]*}.json ;;
esac
case $path in
  */actions/runs*) [ -f "$fixture" ] || fixture=$FIXTURES/empty-runs.json ;;
  graphql | /users/* | /orgs/*) ;;
  *) [ -f "$fixture" ] || fixture=$FIXTURES/empty-array.json ;;
esac
if [ "$page" -gt 1 ]; then
  case $path in
    */actions/runs*) fixture=$FIXTURES/empty-runs.json ;;
    /orgs/*/repos*)
      if [ -f "$FIXTURES/repos-every-page.json" ]; then
        fixture=$FIXTURES/repos-every-page.json
      else
        fixture=$FIXTURES/empty-array.json
      fi
      ;;
    */issues*)
      # A later page exists only where a fixture provides one, which is how a
      # multi-page read is modelled without a second fake.
      paged=${path#/repos/acme/}
      paged=$FIXTURES/issues-${paged%%/issues*}-page$page.json
      if [ -f "$paged" ]; then fixture=$paged; else fixture=$FIXTURES/empty-array.json; fi
      ;;
    *) fixture=$FIXTURES/empty-array.json ;;
  esac
fi
case $MODE in
  owner-is-user)
    case $path in
      /users/*) fixture=$FIXTURES/owner-user.json ;;
    esac
    ;;
  fail-attic-commits)
    case $path in
      /repos/acme/attic/commits*) printf 'gh: HTTP 451 reading the repository\n' >&2; exit 1 ;;
    esac
    ;;
  deny-commits)
    case $path in */commits*) printf 'gh: HTTP 403 reading commits\n' >&2; exit 1 ;; esac
    ;;
  deny-pull-requests)
    case $path in
      graphql) grep -q 'states:OPEN' "$input" || { printf 'gh: HTTP 403 reading pull requests\n' >&2; exit 1; } ;;
    esac
    ;;
  deny-open-pull-requests)
    case $path in
      graphql) ! grep -q 'states:OPEN' "$input" || { printf 'gh: HTTP 403 reading open pull requests\n' >&2; exit 1; } ;;
    esac
    ;;
  deny-ci-runs)
    case $path in */actions/runs*) printf 'gh: HTTP 403 reading workflow runs\n' >&2; exit 1 ;; esac
    ;;
  deny-issues)
    case $path in */issues*) printf 'gh: HTTP 410 issues are disabled\n' >&2; exit 1 ;; esac
    ;;
  deny-repository-reads)
    # A token that can list an organization but is refused on every repository,
    # which is what a SAML-restricted token looks like.
    case $path in
      /repos/* | graphql) printf 'gh: HTTP 403 Resource protected by organization SAML enforcement\n' >&2; exit 1 ;;
    esac
    ;;
  owner-not-found)
    # gh-axi renders its own failures as a document on STDOUT, not stderr.
    case $path in
      /users/*) printf 'error: "gh: Not Found (HTTP 404)"\ncode: NOT_FOUND\n'; exit 1 ;;
    esac
    ;;
esac
if [ "$fixture" = "$FIXTURES/repos-every-page.json" ]; then
  jq --arg p "$page" '[.[] | .name = "\(.name)-p\($p)" | .full_name = "\(.owner.login)/\(.name)"]' \
    "$fixture" > "$FIXTURES/.repos-page.json" || exit 1
  fixture=$FIXTURES/.repos-page.json
fi
payload=$(jq -r "$program" "$fixture") || exit 1
printf 'api_response:\n'
case $MODE in
  no-body) printf '  truncated: false\n'; exit 0 ;;
  truncated) printf '  body: "x"\n  truncated: true\n'; exit 0 ;;
  two-bodies) printf '  body: "a"\n  body: "b"\n  truncated: false\n'; exit 0 ;;
esac
case $payload in
  '') printf '  body: ""\n' ;;
  *[!A-Za-z0-9_./:-]*) printf '  body: %s\n' "$(printf '%s' "$payload" | jq -Rs .)" ;;
  *) printf '  body: %s\n' "$payload" ;;
esac
printf '  truncated: false\n'
SH
  chmod +x "$bin/gh-axi"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$bin/gh"
  chmod +x "$bin/gh"
}

collect_model() {  # <fixtures-dir> <mode> [extra args...]
  local fixtures=$1 mode=$2
  shift 2
  local root bin
  root=$(xo_test_tmproot xo-estate-review) || fail "could not create a fixture root"
  bin=$(xo_fakebin "$root")
  write_fixtures "$fixtures"
  install_fake_gh_axi "$bin" "$fixtures" "$mode"
  PATH="$bin:$PATH" XO_ESTATE_REVIEW_NOW=$NOW FAKE_GH_LOG="$fixtures/calls.log" \
    "$REVIEW" acme "${WINDOW[@]}" --json "$@"
}

SECTIONS=(
  "## 1. Scope and method"
  "## 2. Headline"
  "## 3. Who did what"
  "## 4. Velocity"
  "## 5. Quality"
  "## 6. Risk and concentration"
  "## 7. Per-repository detail"
  "## 8. What these numbers do not measure"
  "## 9. Collection log"
)

assert_fixed_shape() {  # <report-file> <label>
  local report=$1 label=$2 seen
  seen=$(grep '^## ' "$report") || fail "$label: the report has no top-level sections"
  [ "$seen" = "$(printf '%s\n' "${SECTIONS[@]}")" ] ||
    fail "$label: the report's sections are not the fixed nine in order; got:
$seen"
  local sub
  for sub in "### 3.1 Contribution by person" "### 3.2 Review participation" \
    "### 4.1 Throughput" "### 4.2 Cycle time, first commit to merge" \
    "### 4.3 Review latency, opened to first review by another account" \
    "### 5.1 Reverts and hotfixes" "### 5.2 Change size" "### 5.3 Review depth" \
    "### 5.4 Continuous integration latest-attempt pass rate" \
    "### 6.1 Knowledge concentration" "### 6.2 Unmaintained repositories, as at collection" \
    "### 6.3 Stalled work, as at collection" "### 9.1 Commands" "### 9.2 What was read"; do
    grep -Fqx "$sub" "$report" || fail "$label: the report dropped the subsection '$sub'"
  done
  assert_every_column_states_its_clock "$report"
}

# Section 1 states one rule for the whole report: a column carrying a figure
# measured at collection ends its heading "at collection", a column carrying a
# figure that does not is window-bounded, a column that only names something
# carries no clock, and section 9 is the exception. This checks that rule over
# the header row of every table before section 9 - found structurally, as the
# line above a `| --- |` separator, so no table can be missed - and it classifies
# every cell it meets. A heading it cannot classify FAILS rather than being
# skipped, which is what makes a column added later break this until someone
# decides which clock it is on.
assert_every_column_states_its_clock() {  # <report>
  local report=$1 header cell
  while IFS= read -r header; do
    while IFS= read -r cell; do
      case $cell in
        # Figures the estate's state supplies, which must name the collection clock.
        "Automation, at collection" | "Open now, at collection" | "Idle days, at collection" |\
          "Age days, at collection" | "Archived, at collection" | "Draft, at collection" |\
          "Days since last push, at collection" | "Gaps, at collection") ;;
        # Figures the window bounds, which must not claim the collection clock.
        "Value" | "Direction" | "Direction over the window" | "Commits" | "Commits in window" |\
          "Merged" | "Merged pull requests" | "Median cycle" | "Median hours" | "Reviewed" |\
          "Latest-attempt CI" | "Authors" | "Authored commits" | "Share" |\
          "Pull requests opened" | "Pull requests merged" | "Pull requests reviewed" |\
          "Reviews submitted" | "Repositories touched" | [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9])
          case $cell in
            *"at collection"*) fail "the '$cell' column is bounded by the window but claims the collection clock" ;;
          esac
          ;;
        # Columns that name rather than measure, so they carry no clock at all.
        "Repository" | "Account" | "Author" | "Title" | "Number" | "Measure" | "Unit" |\
          "Period beginning" | "Lines changed") ;;
        *)
          fail "the '$cell' column is on no known clock: classify it as window-bounded, as collection-time and label it 'at collection', or as a column that only names something"
          ;;
      esac
    done < <(printf '%s\n' "$header" | tr '|' '\n' | sed 's/^ *//; s/ *$//' | grep -v '^$')
  done < <(sed -n '/^## 2\./,/^## 9\./p' "$report" | awk '/^\| --- /{print prev} {prev=$0}')
}

test_collection_derives_the_documented_figures() {
  local root model
  root=$(xo_test_tmproot xo-estate-review-fix) || fail "no fixture root"
  model=$(collect_model "$root/fixtures" ok) || fail "collection failed"
  printf '%s' "$model" > "$root/model.json"
  jq -e '.contract == "xo-estate-review.v1"' "$root/model.json" > /dev/null ||
    fail "the model does not carry the xo-estate-review.v1 contract"

  # Commits: seven on the default branch, one of them a merge, one a revert.
  assert_equals "7" "$(jq -r '.quality.commits.total' "$root/model.json")" "commits read"
  assert_equals "1" "$(jq -r '.quality.commits.merges' "$root/model.json")" "merge commits"
  assert_equals "6" "$(jq -r '.quality.commits.commits' "$root/model.json")" "authored commits"
  assert_equals "1" "$(jq -r '.quality.commits.reverts' "$root/model.json")" "reverts"
  assert_equals "16.7" "$(jq -r '.quality.commits.revert_rate_pct' "$root/model.json")" "revert rate"
  assert_equals "[1,1,1,2,1,0]" "$(jq -c '.velocity.commits.per_period' "$root/model.json")" "commits per period"

  # Pull requests, and the cycle time the merged ones give.
  assert_equals "4" "$(jq -r '[.repositories[].pull_requests.merged] | add' "$root/model.json")" "merged"
  assert_equals "6" "$(jq -r '[.repositories[].pull_requests.opened] | add' "$root/model.json")" "opened"
  assert_equals "1" "$(jq -r '.risk.open_pull_requests' "$root/model.json")" "open now"
  assert_equals "48" "$(jq -r '.velocity.cycle_hours.median' "$root/model.json")" "median cycle hours"
  assert_equals "[48,null,48,null,36,null]" "$(jq -c '.velocity.cycle_hours.per_period_median' "$root/model.json")"     "cycle per period, with the periods this estate merged nothing in left unmeasured rather than zeroed"
  # A direction needs a measured last period, which the cycle series does not
  # have here and the commit series does: a period with no merge in it is an
  # absence, while a period with no commit in it is a measured zero.
  assert_equals "final-period-unmeasured" "$(jq -r '.velocity.cycle_hours.trend' "$root/model.json")"     "cycle time reports no direction when its last period measured nothing"
  assert_equals "falling" "$(jq -r '.velocity.commits.trend' "$root/model.json")" "commit volume reports its direction"

  # Review latency counts only reviews by another account, so the self-review on
  # pull request 2 must not become its first review.
  assert_equals "3" "$(jq -r '.velocity.review_latency_hours.measured' "$root/model.json")" "latency measured"
  assert_equals "12" "$(jq -r '.velocity.review_latency_hours.median' "$root/model.json")" "latency median"
  assert_equals "30" "$(jq -r '.velocity.review_latency_hours.p90' "$root/model.json")" "latency p90"
  assert_equals "3" "$(jq -r '.quality.review.with_review_by_another_account' "$root/model.json")" "reviewed by another"
  assert_equals "75" "$(jq -r '.quality.review.coverage_pct' "$root/model.json")" "review coverage"

  # CI: four runs, of which two ended in success, one in failure, one cancelled.
  # The rate is over the latest attempt of each run, which is what the runs list
  # reports, so the run that took two attempts on one commit counts as the pass
  # it ended as - and is also counted as having needed a second attempt.
  assert_equals "4" "$(jq -r '.quality.ci.runs' "$root/model.json")" "ci runs"
  assert_equals "66.7" "$(jq -r '.quality.ci.latest_attempt_pass_rate_pct' "$root/model.json")" "ci latest-attempt pass rate"
  assert_equals "1" "$(jq -r '.quality.ci.inconclusive' "$root/model.json")" "ci inconclusive"
  assert_equals "1" "$(jq -r '.quality.ci.needed_more_than_one_attempt' "$root/model.json")" "ci second attempts"

  # Change size comes from merged pull requests.
  assert_equals "23.5" "$(jq -r '.quality.size.median_lines' "$root/model.json")" "median size"
  assert_equals "300" "$(jq -r '.quality.size.p90_lines' "$root/model.json")" "p90 size"
  assert_equals "2" "$(jq -r '.quality.size.distribution.under_10' "$root/model.json")" "tiny changes"

  # Risk.
  assert_equals "4" "$(jq -r '.risk.concentration.authors' "$root/model.json")" "authors"
  assert_equals "2" "$(jq -r '.risk.concentration.accounts_covering_half' "$root/model.json")" "accounts covering half"
  assert_equals "acme/attic" "$(jq -r '.risk.unmaintained[0].repo' "$root/model.json")" "unmaintained repository"
  assert_equals "821" "$(jq -r '.risk.unmaintained[0].idle_days' "$root/model.json")" "unmaintained idle days"
  assert_equals "1" "$(jq -r '.risk.stalled_pull_requests | length' "$root/model.json")" "stalled count"
  assert_equals "75" "$(jq -r '.risk.stalled_pull_requests[0].idle_days' "$root/model.json")" "stalled idle days"
  assert_equals "2" "$(jq -r '.risk.open_issues' "$root/model.json")" "open issues excluding pull requests"
  pass "collection derives the documented figures from real GitHub-shaped payloads"
}

test_one_automation_account_is_one_row_and_is_marked() {
  local root model
  root=$(xo_test_tmproot xo-estate-review-ident) || fail "no fixture root"
  model=$(collect_model "$root/fixtures" ok) || fail "collection failed"
  printf '%s' "$model" > "$root/model.json"

  # GitHub gives the same app account as dependabot[bot] on a commit and
  # dependabot on a pull request; folding that suffix is what keeps one actor
  # from becoming two rows of "who did what".
  assert_equals "ada brooke copilot-pull-request-reviewer dependabot unlinked:carol@example.com" \
    "$(jq -r '[.people[].person] | join(" ")' "$root/model.json")" "accounts, sorted by name"
  assert_equals "1" "$(jq -r '.people[] | select(.person == "dependabot") | .commits' "$root/model.json")" "bot commits"
  assert_equals "1" "$(jq -r '.people[] | select(.person == "dependabot") | .prs_merged' "$root/model.json")" "bot merges"
  assert_equals "true" "$(jq -r '.people[] | select(.person == "dependabot") | .automation' "$root/model.json")" "bot marked"
  assert_equals "true" "$(jq -r '.people[] | select(.person == "copilot-pull-request-reviewer") | .automation' "$root/model.json")" "bot reviewer marked"
  assert_equals "false" "$(jq -r '.people[] | select(.person == "ada") | .automation' "$root/model.json")" "human not marked"
  # An unlinkable commit author stays its own identity rather than being matched
  # to an account by name.
  assert_equals "1" "$(jq -r '.people[] | select(.person == "unlinked:carol@example.com") | .commits' "$root/model.json")" "unlinked author"
  # Counts are per person, not per event, and reviews exclude self-review.
  assert_equals "3" "$(jq -r '.people[] | select(.person == "ada") | .prs_opened' "$root/model.json")" "ada opened"
  assert_equals "1" "$(jq -r '.people[] | select(.person == "brooke") | .reviews_submitted' "$root/model.json")" "brooke reviews"
  pass "an automation account is one marked row and no two accounts are merged by name"
}

test_every_run_emits_the_same_nine_sections() {
  local root model
  root=$(xo_test_tmproot xo-estate-review-shape) || fail "no fixture root"
  model=$(collect_model "$root/fixtures" ok) || fail "collection failed"
  printf '%s' "$model" > "$root/model.json"
  "$REVIEW" --from-json "$root/model.json" > "$root/report.md" || fail "rendering failed"
  assert_fixed_shape "$root/report.md" "an estate with activity"
  assert_grep "# Estate review: acme" "$root/report.md" "the report names its estate"
  assert_grep "Window: 2026-01-01T00:00:00Z to 2026-04-01T00:00:00Z" "$root/report.md" "the report states its window"
  # shellcheck disable=SC2016  # the backticks are the report's own markdown.
  assert_grep 'report contract `xo-estate-review.v1`' "$root/report.md" "the report states its contract"
  pass "a report of an active estate emits the fixed nine sections and states its scope, window, and contract"
}

test_an_estate_with_no_data_still_emits_every_section() {
  local root bin model empty
  root=$(xo_test_tmproot xo-estate-review-empty) || fail "no fixture root"
  bin=$(xo_fakebin "$root")
  write_fixtures "$root/fixtures"
  # A real estate that did nothing in the window: one repository whose every read
  # comes back empty. The model under test is the one the collector produces for
  # that estate, not a populated model with its figures overwritten - a doctored
  # model would pass these assertions whatever the renderer did with a real one.
  jq -n '[{full_name: "acme/quiet", name: "quiet", owner: {login: "acme"}, default_branch: "main",
           archived: false, fork: false, pushed_at: "2026-03-30T00:00:00Z", private: false}]' \
    > "$root/fixtures/repos.json" || fail "could not write the silent estate"
  install_fake_gh_axi "$bin" "$root/fixtures" ok
  model=$(PATH="$bin:$PATH" XO_ESTATE_REVIEW_NOW=$NOW "$REVIEW" acme "${WINDOW[@]}" --json) ||
    fail "collection failed"
  empty=$root/empty.json
  printf '%s' "$model" > "$empty"
  assert_equals "0" "$(jq -r '.quality.commits.total' "$empty")" "the estate really did read as empty"
  assert_equals "0" "$(jq -r '.people | length' "$empty")" "no account appears in an empty window"
  assert_equals "0" "$(jq -r '.quality.ci.runs' "$empty")" "no workflow run appears in an empty window"

  "$REVIEW" --from-json "$empty" > "$root/empty.md" || fail "rendering an empty estate failed"
  assert_fixed_shape "$root/empty.md" "an estate with nothing in it"
  # Every empty surface has to SAY it is empty. A section that vanished would be
  # indistinguishable from a section the report never had.
  assert_grep "No account committed, opened a pull request, or reviewed one in this window" "$root/empty.md" "the person section states its emptiness"
  assert_grep "No account submitted a review of another account" "$root/empty.md" "the review section states its emptiness"
  assert_grep "there is no revert or hotfix rate to report" "$root/empty.md" "the revert section states its emptiness"
  assert_grep "there is no change-size distribution to report" "$root/empty.md" "the size section states its emptiness"
  assert_grep "there is no review depth to report" "$root/empty.md" "the review-depth section states its emptiness"
  assert_grep "there is no latest-attempt pass rate to report" "$root/empty.md" "the CI section states its emptiness"
  assert_grep "so concentration is unmeasurable" "$root/empty.md" "the concentration section states its emptiness"
  assert_grep "No reviewed repository is archived or had gone" "$root/empty.md" "the unmaintained section states its emptiness"
  assert_grep "No open pull request has been idle" "$root/empty.md" "the stalled section states its emptiness"
  assert_grep "No commit, pull request, review, or workflow run in this window" "$root/empty.md" "the headline says the window was silent rather than reading as low activity"
  assert_no_grep "behind this figure failed" "$root/empty.md" "an estate that was read completely is not told its reads failed"
  assert_no_grep "A rising cycle time means work is getting slower" "$root/empty.md" "an empty estate is not given the reading note for a report with figures in it"
  # And the limits still get stated, because that is what the reader acts on.
  assert_grep "They do not measure anyone's productivity" "$root/empty.md" "the limits section survives an empty estate"
  pass "an estate with no commits, pull requests, reviews, or checks still emits every section, each stating that it is empty"
}

test_a_repository_the_tooling_cannot_read_is_named_not_dropped() {
  local root model
  root=$(xo_test_tmproot xo-estate-review-unread) || fail "no fixture root"
  model=$(collect_model "$root/fixtures" fail-attic-commits) || fail "collection failed"
  printf '%s' "$model" > "$root/model.json"
  assert_equals "acme/attic" "$(jq -r '.unread[0].repo' "$root/model.json")" "the unread repository is recorded"
  assert_equals "commits" "$(jq -r '.unread[0].signal' "$root/model.json")" "the unread signal is recorded"
  assert_equals "1" "$(jq -r '.selection.partially_read' "$root/model.json")" "the partial read is counted"
  "$REVIEW" --from-json "$root/model.json" > "$root/report.md" || fail "rendering failed"
  assert_fixed_shape "$root/report.md" "an estate with an unreadable repository"
  assert_grep "Named gaps" "$root/report.md" "the report names its gaps"
  assert_grep "| acme/attic | commits |" "$root/report.md" "the unreadable repository is named in the collection log"
  assert_grep "| acme/attic |" "$root/report.md" "the unreadable repository still has a row of its own"
  # One failed read among many still has to reach the surfaces it fed. Section
  # 6.1's list renders its empty sentence here because the repositories that did
  # read have no single-account majority, and that sentence ranges over every
  # reviewed repository - including the one whose commits were never read.
  local claimed
  claimed=$(grep -nE '^(No |Nothing )' "$root/report.md" | grep -F "in this window" || true)
  [ -z "$claimed" ] ||
    fail "a partly unread estate claimed the window in an empty-surface sentence:
$claimed"
  assert_grep "No repository has more than half its authored commits from a single account in what could be read" "$root/report.md"     "a surface fed by the failed read says how far its claim reaches"
  assert_grep "(1 read behind this figure failed; section 9.2 names it)" "$root/report.md"     "a single failed read is counted in the singular"
  # And a figure the failure did not feed is left alone: the open counts come
  # from reads that succeeded, so they carry no warning.
  assert_grep "- Open pull requests: 1" "$root/report.md" "a figure no failed read fed carries no notice"
  assert_grep "- Open issues: 2" "$root/report.md" "the open issue count is not warned about a commits failure"
  pass "a repository the tooling cannot read is named as unread, still appears, and reaches only the figures its failed read fed"
}

test_an_estate_nothing_could_be_read_from_never_reads_as_a_quiet_one() {
  local root bin model
  root=$(xo_test_tmproot xo-estate-review-denied) || fail "no fixture root"
  bin=$(xo_fakebin "$root")
  write_fixtures "$root/fixtures"
  install_fake_gh_axi "$bin" "$root/fixtures" deny-repository-reads
  model=$(PATH="$bin:$PATH" XO_ESTATE_REVIEW_NOW=$NOW "$REVIEW" acme "${WINDOW[@]}" --json) ||
    fail "a review whose repository reads all fail did not produce a model"
  printf '%s' "$model" > "$root/model.json"
  # Every read failed, so the derivation sees exactly what a silent estate gives
  # it: no records at all. The difference between the two is the gap list, and it
  # is the difference the captain acts on.
  assert_equals "0" "$(jq -r '.quality.commits.total' "$root/model.json")" "a denied estate yields no commits"
  assert_equals "0" "$(jq -r '.people | length' "$root/model.json")" "a denied estate attributes work to nobody"
  assert_equals "0" "$(jq -r '.quality.ci.runs' "$root/model.json")" "a denied estate yields no runs"
  assert_equals "2" "$(jq -r '.selection.partially_read' "$root/model.json")" "both repositories are counted as partially read"

  "$REVIEW" --from-json "$root/model.json" > "$root/report.md" || fail "rendering failed"
  assert_fixed_shape "$root/report.md" "an estate nothing could be read from"
  # The rule, not a list of sentences: no statement about what the estate did may
  # range over the window when nothing was read. Every such sentence starts a line
  # of the report, so the rule can be checked over the whole report rather than
  # over the surfaces that happen to exist today, and a surface added later that
  # skips the boundary fails here.
  local claimed
  claimed=$(grep -nE '^(No |Nothing )' "$root/report.md" | grep -F "in this window" || true)
  [ -z "$claimed" ] ||
    fail "an unreadable estate claimed the window in an empty-surface sentence:
$claimed"
  # And the same sentences must say what they do range over, in every section.
  local surface
  for surface in "No commit, pull request, review, or workflow run in what could be read" \
    "No account committed, opened a pull request, or reviewed one in what could be read" \
    "No commit or merge landed in what could be read" \
    "No authored commit landed on a default branch in what could be read" \
    "No pull request merged in what could be read" \
    "No GitHub Actions pull-request run in what could be read" \
    "No authored commit landed in what could be read" \
    "No open pull request has been idle for 14 days or more in what could be read"; do
    assert_grep "$surface" "$root/report.md" "an unread estate reports '$surface'"
  done
  # The notice counts the reads behind the figure it sits on, not every read in
  # the run, so the headline, which rests on four reads of two repositories, says
  # eight, while the counts beside each other in 6.3 each name only their own
  # read: the open pull request count rests on the open-pull-request pass and the
  # open issue count on the issue read.
  assert_grep "rather than low (8 reads behind this figure failed" "$root/report.md"     "the headline names every read behind it"
  assert_grep "Open pull requests: 0 (2 reads behind this figure failed" "$root/report.md"     "the open pull request count names the read that fed it and no wider one"
  assert_grep "Open issues: 0 (2 reads behind this figure failed" "$root/report.md"     "the open issue count names its own reads rather than every failure in the run"
  assert_equals "14" "$(grep -c 'behind this figure failed' "$root/report.md")"     "every figure a failed read fed says so"
  pass "an estate whose reads all failed states in every section that it could not be read, never that it was quiet"
}

test_a_read_that_fell_short_reaches_the_figures_it_fed_and_no_others() {
  local root bin model mode case_name expected seen
  # One read at a time, against an estate that is otherwise silent so every
  # surface renders its empty sentence and is therefore eligible for a notice.
  # What the case proves is the whole rule in both directions: the sections the
  # read fed all say so, and no section it did not feed says anything.
  # A surface that named a read it does not rest on fails here as loudly as one
  # that dropped a read it does.
  #
  # Both ways a read falls short are driven through the same rule, because a cap
  # misfiled against a wider signal hedges an exact figure exactly as a notice on
  # the wrong surface does. The per-pull-request review bound is the cap case: it
  # shortens the review list inside a pull request and nothing else, so it must
  # reach the review-derived surfaces and no others.
  while IFS='|' read -r case_name expected; do
    root=$(xo_test_tmproot "xo-estate-review-$case_name") || fail "no fixture root"
    bin=$(xo_fakebin "$root")
    write_fixtures "$root/fixtures"
    jq -n '[{full_name: "acme/quiet", name: "quiet", owner: {login: "acme"}, default_branch: "main",
             archived: false, fork: false, pushed_at: "2026-03-30T00:00:00Z", private: false}]' \
      > "$root/fixtures/repos.json" || fail "could not write the silent estate"
    mode=ok
    case $case_name in
      deny-*) mode=$case_name ;;
      cap-pull-request-reviews)
        # One pull request, merged and reviewed before the window opened, whose
        # review count exceeds what a single page holds. The estate is still
        # silent in the window; the only thing short is that review list.
        jq -n '{data: {repository: {pullRequests: {
                 pageInfo: {hasNextPage: false, endCursor: null},
                 nodes: [{number: 1, state: "MERGED", isDraft: false,
                   createdAt: "2025-06-01T00:00:00Z", updatedAt: "2025-06-02T00:00:00Z",
                   mergedAt: "2025-06-02T00:00:00Z", closedAt: "2025-06-02T00:00:00Z",
                   additions: 1, deletions: 1, changedFiles: 1, headRefName: "f/1",
                   title: "before the window", author: {login: "ada", __typename: "User"},
                   commits: {nodes: [{commit: {committedDate: "2025-06-01T00:00:00Z"}}]},
                   reviews: {totalCount: 60, nodes: [{author: {login: "brooke", __typename: "User"},
                     submittedAt: "2025-06-01T12:00:00Z", state: "APPROVED"}]},
                   reviewThreads: {totalCount: 0}}]}}}}' \
          > "$root/fixtures/prs-quiet.json" || fail "could not write the over-reviewed pull request"
        ;;
      *) fail "unknown case '$case_name'" ;;
    esac
    install_fake_gh_axi "$bin" "$root/fixtures" "$mode"
    model=$(PATH="$bin:$PATH" XO_ESTATE_REVIEW_NOW=$NOW "$REVIEW" acme "${WINDOW[@]}" --json) ||
      fail "the $case_name review did not produce a model"
    printf '%s' "$model" > "$root/model.json"
    "$REVIEW" --from-json "$root/model.json" > "$root/report.md" || fail "rendering failed"
    seen=$(awk '/^#+ [0-9]/ { section = $2; sub(/\.$/, "", section) }
                /behind this figure (failed|stopped at a cap)/ { print section }' \
             "$root/report.md" | sort -u | tr '\n' ' ')
    assert_equals "$expected " "$seen" "$case_name reaches exactly the sections its figures rest on"
  done <<'CASES'
deny-commits|2 3.1 4.1 5.1 6.1
deny-pull-requests|2 3.1 3.2 4.1 4.2 4.3 5.2 5.3 6.3
deny-open-pull-requests|2 3.1 3.2 6.3
deny-ci-runs|2 5.4
deny-issues|6.3
cap-pull-request-reviews|2 3.1 3.2 4.3
CASES
  pass "a read that failed or stopped at a cap is named on every figure it fed and on no figure it did not"
}

test_push_recency_is_measured_from_collection_not_from_the_window_end() {
  local root bin model
  root=$(xo_test_tmproot xo-estate-review-clock) || fail "no fixture root"
  bin=$(xo_fakebin "$root")
  write_fixtures "$root/fixtures"
  install_fake_gh_axi "$bin" "$root/fixtures" ok
  # A historical window that ended long before the last push. Whether a repository
  # is alive is a fact about now, not about the window, so ageing it against the
  # window end would report a repository pushed two days ago as idle for minus
  # three hundred days and would make the unmaintained test unsatisfiable.
  model=$(PATH="$bin:$PATH" XO_ESTATE_REVIEW_NOW=$NOW \
    "$REVIEW" acme --since 2025-01-01 --until 2025-06-01 --json) ||
    fail "collection over a historical window failed"
  printf '%s' "$model" > "$root/model.json"
  assert_equals "2" "$(jq -r '.repositories[] | select(.name == "acme/widgets") | .idle_days' "$root/model.json")"     "a repository pushed two days before collection reads as two days idle"
  assert_equals "821" "$(jq -r '.repositories[] | select(.name == "acme/attic") | .idle_days' "$root/model.json")"     "a long-abandoned repository keeps its real age"
  assert_equals "acme/attic" "$(jq -r '.risk.unmaintained[0].repo' "$root/model.json")"     "the unmaintained test still selects over a historical window"

  "$REVIEW" --from-json "$root/model.json" > "$root/report.md" || fail "rendering failed"
  assert_fixed_shape "$root/report.md" "a historical window"
  ! grep -Eq '\| -[0-9]' "$root/report.md" ||
    fail "the report printed a negative day count over a historical window"
  assert_grep "Days since last push, at collection" "$root/report.md"     "section 6.2 says which clock its days are measured on"
  assert_every_column_states_its_clock "$root/report.md"
  pass "push recency and the unmaintained list are measured from the collection clock and labelled as such"
}

test_rendering_the_same_model_twice_is_byte_identical() {
  local root model
  root=$(xo_test_tmproot xo-estate-review-det) || fail "no fixture root"
  model=$(collect_model "$root/fixtures" ok) || fail "collection failed"
  printf '%s' "$model" > "$root/model.json"
  "$REVIEW" --from-json "$root/model.json" > "$root/a.md" || fail "first render failed"
  "$REVIEW" --from-json "$root/model.json" > "$root/b.md" || fail "second render failed"
  cmp -s "$root/a.md" "$root/b.md" || fail "two renders of one model differ, so two reports are not comparable"
  pass "rendering one model twice is byte-identical, so a comparison between reports is a comparison of estates"
}

test_a_changed_gh_axi_envelope_refuses_instead_of_reporting_an_empty_estate() {
  local root bin out code mode
  for mode in no-body two-bodies truncated; do
    root=$(xo_test_tmproot "xo-estate-review-env") || fail "no fixture root"
    bin=$(xo_fakebin "$root")
    write_fixtures "$root/fixtures"
    install_fake_gh_axi "$bin" "$root/fixtures" "$mode"
    out=$(PATH="$bin:$PATH" XO_ESTATE_REVIEW_NOW=$NOW "$REVIEW" acme "${WINDOW[@]}" --json 2>&1) && code=0 || code=$?
    [ "$code" != 0 ] ||
      fail "the '$mode' envelope was accepted; a changed rendering must never be read as an estate with no data"
    assert_contains "$out" "gh-axi (gh-axi fake 9.9.9)" "the '$mode' refusal names the gh-axi version"
    assert_not_contains "$out" "xo-estate-review.v1" "the '$mode' refusal produced no model"
  done
  pass "a gh-axi envelope this reader does not know refuses loudly with the installed version, never as an empty estate"
}

test_collection_makes_no_state_changing_call() {
  local root model log
  root=$(xo_test_tmproot xo-estate-review-ro) || fail "no fixture root"
  model=$(collect_model "$root/fixtures" ok) || fail "collection failed"
  log=$root/fixtures/calls.log
  assert_present "$log" "the fake recorded the calls collection made"
  # Read-only means read-only. The only write verb the estate ever sees is the
  # POST that carries a GraphQL query, which is how GitHub serves reads.
  local line
  while IFS= read -r line; do
    case $line in
      *" PUT "* | *" PATCH "* | *" DELETE "* | *"-X "*)
        fail "collection issued a state-changing call: $line"
        ;;
      *" POST "*)
        case $line in
          *" POST graphql "*) ;;
          *) fail "collection issued a POST that is not the GraphQL read: $line" ;;
        esac
        ;;
    esac
  done < "$log"
  grep -q 'POST graphql' "$log" || fail "collection never made the GraphQL read"
  pass "collection issues only reads, with POST used solely to carry the GraphQL query"
}

test_the_report_records_the_commands_that_produced_it() {
  local root model
  root=$(xo_test_tmproot xo-estate-review-cmds) || fail "no fixture root"
  model=$(collect_model "$root/fixtures" ok) || fail "collection failed"
  printf '%s' "$model" > "$root/model.json"
  "$REVIEW" --from-json "$root/model.json" > "$root/report.md" || fail "rendering failed"
  assert_grep "gh-axi api /orgs/acme/repos" "$root/report.md" "the repository listing command is recorded"
  assert_grep "since=2026-01-01T00:00:00Z&until=2026-04-01T00:00:00Z" "$root/report.md" "the window is substituted into the recorded commands"
  assert_grep "created=2026-01-01..2026-04-01" "$root/report.md" "the check-run window is recorded"
  pass "the report records the command templates with this run's window substituted, so a figure can be re-derived"
}

test_free_text_from_the_estate_cannot_break_a_record() {
  local root model
  root=$(xo_test_tmproot xo-estate-review-text) || fail "no fixture root"
  model=$(collect_model "$root/fixtures" ok) || fail "collection failed"
  printf '%s' "$model" > "$root/model.json"
  # The stalled pull request's title contains a tab in the fixture. A tab is the
  # record separator, so it has to be neutralised at the collection boundary or
  # every field after it shifts. The pipe in the same title is not a record
  # separator, so the model keeps the estate's own text and the renderer is what
  # deals with it.
  assert_equals "spike with a tab | and a pipe" \
    "$(jq -r '.risk.stalled_pull_requests[0].title' "$root/model.json")" "the tabbed title survives as one field, pipe included"
  assert_equals "5" "$(jq -r '.risk.stalled_pull_requests[0].number' "$root/model.json")" "the fields after it did not shift"
  assert_equals "brooke" "$(jq -r '.risk.stalled_pull_requests[0].author' "$root/model.json")" "the author field did not shift"
  pass "estate free text containing a record separator is neutralised rather than shifting every later field"
}

test_scope_and_argument_validation_refuses_rather_than_guessing() {
  local root bin out code
  root=$(xo_test_tmproot xo-estate-review-args) || fail "no fixture root"
  bin=$(xo_fakebin "$root")
  write_fixtures "$root/fixtures"
  install_fake_gh_axi "$bin" "$root/fixtures" ok

  out=$(PATH="$bin:$PATH" "$REVIEW" 2>&1) && code=0 || code=$?
  assert_equals "2" "$code" "a missing estate scope exits 2"
  assert_contains "$out" "an estate scope is required" "a missing scope is refused, not guessed"

  out=$(PATH="$bin:$PATH" "$REVIEW" a/b/c 2>&1) && code=0 || code=$?
  assert_equals "2" "$code" "a three-part scope exits 2"
  assert_contains "$out" "is not an estate scope" "a three-part scope is refused"

  out=$(PATH="$bin:$PATH" "$REVIEW" acme --window zero 2>&1) && code=0 || code=$?
  assert_equals "2" "$code" "a non-numeric window exits 2"
  assert_contains "$out" "--window must be a non-negative integer" "a non-numeric window is refused"

  out=$(PATH="$bin:$PATH" "$REVIEW" acme --window 0 2>&1) && code=0 || code=$?
  assert_equals "2" "$code" "a zero-day window exits 2"
  assert_contains "$out" "--window must be at least 1" "a window with no days in it is refused"

  out=$(PATH="$bin:$PATH" "$REVIEW" acme --since 2026-13-99 2>&1) && code=0 || code=$?
  assert_equals "2" "$code" "a malformed date exits 2"

  # The trend splits the window into a fixed number of periods and dates each one
  # rather than timing it, so a window with fewer days than periods would print
  # the same date as two different period headings. The input is refused instead,
  # and the refusal names the minimum, because there is no flag to reduce the
  # period count and a report that cannot be read is worse than one not produced.
  out=$(PATH="$bin:$PATH" XO_ESTATE_REVIEW_NOW=$NOW "$REVIEW" acme --window 3 2>&1) && code=0 || code=$?
  assert_equals "2" "$code" "a window with fewer days than trend periods exits 2"
  assert_contains "$out" "at least 6 days" "the refusal names the minimum window"
  out=$(PATH="$bin:$PATH" XO_ESTATE_REVIEW_NOW=$NOW "$REVIEW" acme --since 2026-03-28 --until 2026-04-01 2>&1) && code=0 || code=$?
  assert_equals "2" "$code" "a short window given as dates is refused the same way"
  assert_contains "$out" "at least 6 days" "the dated refusal names the same minimum"
  out=$(PATH="$bin:$PATH" XO_ESTATE_REVIEW_NOW=$NOW "$REVIEW" acme --window 6 --json) && code=0 || code=$?
  assert_equals "0" "$code" "the shortest accepted window is collected"
  printf '%s' "$out" > "$root/shortest.json"
  assert_equals "6" "$(jq -r '.window.period_labels | unique | length' "$root/shortest.json")"     "the shortest accepted window still dates its six periods distinctly, which is what the minimum is for"

  out=$(PATH="$bin:$PATH" "$REVIEW" acme --since 2026-04-01 --until 2026-01-01 2>&1) && code=0 || code=$?
  assert_equals "2" "$code" "an inverted window exits 2"
  assert_contains "$out" "window start must be before the window end" "an inverted window is refused"

  out=$(PATH="$bin:$PATH" "$REVIEW" acme --nonsense 2>&1) && code=0 || code=$?
  assert_equals "2" "$code" "an unknown flag exits 2"

  # An estate is an organization or one of its repositories. An owner GitHub
  # reports as anything else is refused with the type it reported, rather than
  # reviewed through a second acceptance path.
  install_fake_gh_axi "$bin" "$root/fixtures" owner-is-user
  out=$(PATH="$bin:$PATH" XO_ESTATE_REVIEW_NOW=$NOW "$REVIEW" acme "${WINDOW[@]}" --json 2>&1) && code=0 || code=$?
  assert_equals "2" "$code" "a non-organization owner exits 2"
  assert_contains "$out" "type 'User'" "the refusal names the type GitHub reported"
  assert_not_contains "$out" "xo-estate-review.v1" "a non-organization owner produced no model"
  install_fake_gh_axi "$bin" "$root/fixtures" ok

  out=$(PATH="$bin:$PATH" "$REVIEW" --from-json "$root/fixtures/repos.json" 2>&1) && code=0 || code=$?
  [ "$code" != 0 ] || fail "--from-json accepted a file that is not a review model"
  assert_contains "$out" "is not a xo-estate-review.v1 model" "a foreign model file is refused"
  pass "an unusable scope, window, flag, or model file is refused rather than guessed around"
}

test_a_single_repository_review_is_the_same_report_with_one_row() {
  local root bin model
  root=$(xo_test_tmproot xo-estate-review-one) || fail "no fixture root"
  bin=$(xo_fakebin "$root")
  write_fixtures "$root/fixtures"
  install_fake_gh_axi "$bin" "$root/fixtures" ok
  model=$(PATH="$bin:$PATH" XO_ESTATE_REVIEW_NOW=$NOW "$REVIEW" acme/widgets "${WINDOW[@]}" --json) ||
    fail "a single-repository review failed"
  printf '%s' "$model" > "$root/model.json"
  assert_equals "repository" "$(jq -r '.scope.kind' "$root/model.json")" "the scope is a repository"
  assert_equals "1" "$(jq -r '.repositories | length' "$root/model.json")" "one repository is reviewed"
  assert_equals "acme/widgets" "$(jq -r '.repositories[0].name' "$root/model.json")" "the named repository is the one reviewed"
  "$REVIEW" --from-json "$root/model.json" > "$root/report.md" || fail "rendering failed"
  assert_fixed_shape "$root/report.md" "a single-repository estate"
  pass "a single-repository review emits the same nine sections as an organization review"
}

test_repository_selection_excludes_forks_and_discloses_it() {
  local root bin model report
  root=$(xo_test_tmproot xo-estate-review-select) || fail "no fixture root"
  bin=$(xo_fakebin "$root")
  write_fixtures "$root/fixtures"
  jq '.[1].fork = true' "$root/fixtures/repos.json" > "$root/fixtures/repos.tmp" &&
    mv "$root/fixtures/repos.tmp" "$root/fixtures/repos.json"
  install_fake_gh_axi "$bin" "$root/fixtures" ok

  model=$(PATH="$bin:$PATH" XO_ESTATE_REVIEW_NOW=$NOW "$REVIEW" acme "${WINDOW[@]}" --json) ||
    fail "collection failed"
  printf '%s' "$model" > "$root/model.json"
  assert_equals "1" "$(jq -r '.repositories | length' "$root/model.json")" "a fork is not reviewed"
  assert_equals "false" "$(jq -r '.options.include_forks' "$root/model.json")"     "the model records that forks were excluded"

  # Excluding forks is not configurable, so the report has to say it happened:
  # an undisclosed exclusion would read as an estate with one repository in it.
  report=$root/report.md
  "$REVIEW" --from-json "$root/model.json" > "$report" || fail "rendering failed"
  assert_grep "Selection: forks excluded" "$report" "section 1 discloses that forks were excluded"
  pass "forks are excluded from an organization review and the report discloses it"
}

test_a_named_repository_is_reviewed_whether_or_not_it_is_a_fork() {
  local root bin model report
  root=$(xo_test_tmproot xo-estate-review-named-fork) || fail "no fixture root"
  bin=$(xo_fakebin "$root")
  write_fixtures "$root/fixtures"
  # The fork filter belongs to the organization listing: it drops the forks an
  # organization happens to own from a review of that organization's own work.
  # A repository the caller named is the estate they asked about, so reviewing it
  # cannot depend on who originally created it - there is no flag to override.
  jq '.fork = true' "$root/fixtures/repo-widgets.json" > "$root/fixtures/repo.tmp" ||
    fail "could not mark the named repository as a fork"
  mv "$root/fixtures/repo.tmp" "$root/fixtures/repo-widgets.json"
  install_fake_gh_axi "$bin" "$root/fixtures" ok

  model=$(PATH="$bin:$PATH" XO_ESTATE_REVIEW_NOW=$NOW "$REVIEW" acme/widgets "${WINDOW[@]}" --json) ||
    fail "a review of a named fork failed"
  printf '%s' "$model" > "$root/model.json"
  assert_equals "1" "$(jq -r '.repositories | length' "$root/model.json")" "the named fork is reviewed"
  assert_equals "acme/widgets" "$(jq -r '.repositories[0].name' "$root/model.json")"     "the repository reviewed is the one named"
  assert_equals "true" "$(jq -r '.repositories[0].fork' "$root/model.json")" "the model records that it is a fork"
  assert_equals "true" "$(jq -r '.options.include_forks' "$root/model.json")"     "the model records that no fork was excluded from this review"

  report=$root/report.md
  "$REVIEW" --from-json "$root/model.json" > "$report" || fail "rendering failed"
  assert_grep "Selection: forks included" "$report" "section 1 discloses the selection that actually ran"
  assert_fixed_shape "$report" "a named fork"
  pass "a repository named explicitly is reviewed whether or not it is a fork, and the report says so"
}

test_a_window_behind_the_pull_request_cap_is_still_reached() {
  local root bin fixtures model file i
  local -a after=(2026-03-01 2026-01-01 2025-11-01 2025-09-01 2025-07-01 2025-05-01)
  root=$(xo_test_tmproot xo-estate-review-prwindow) || fail "no fixture root"
  bin=$(xo_fakebin "$root")
  fixtures=$root/fixtures
  write_fixtures "$fixtures"
  keep_only_widgets "$fixtures"
  # The merged-pull-request walk descends by updated-at from the present, so a
  # window in the past sits behind every pull request touched since it ended.
  # Six pages of fifty such pull requests - 300, the review's whole pull-request
  # cap - stand between the walk and the window's own two merged pull requests on
  # the seventh page. None of the 300 is counted by any figure in the report, so
  # spending the cap on them would stop the walk short of the window and print
  # every pull-request figure as zero with nothing on the figure to say why.
  for i in 0 1 2 3 4 5; do
    if [ "$i" = 0 ]; then file=$fixtures/prs-widgets.json; else file=$fixtures/prs-widgets-c$((i + 1)).json; fi
    write_pr_page "$file" "${after[$i]}T00:00:00Z" 50 "$((2000 + i * 100))" "c$((i + 2))"
  done
  write_pr_page "$fixtures/prs-widgets-c7.json" 2025-02-10T00:00:00Z 2 11 ""
  install_fake_gh_axi "$bin" "$fixtures" ok

  model=$(PATH="$bin:$PATH" XO_ESTATE_REVIEW_NOW=$NOW \
    "$REVIEW" acme --since 2025-01-01 --until 2025-04-01 --json) || fail "collection failed"
  printf '%s' "$model" > "$root/model.json"
  assert_equals "2" "$(jq -r '.repositories[0].pull_requests.merged' "$root/model.json")"     "the window's own merged pull requests are counted"
  assert_equals "2" "$(jq -r '.headline[] | select(.metric == "Pull requests merged") | .value' "$root/model.json")"     "the headline reports them rather than reading as a window in which nothing merged"
  assert_equals "0" "$(jq -r '[.caps[] | select(.signal == "pull_requests")] | length' "$root/model.json")"     "a cap spent on no counted pull request is not reported as a cap"
  pass "a historical window is reached through the pull requests updated after it, which spend no cap"
}

test_a_walk_that_cannot_reach_the_window_names_the_page_bound() {
  local root bin fixtures model detail limit calls report
  root=$(xo_test_tmproot xo-estate-review-prpages) || fail "no fixture root"
  bin=$(xo_fakebin "$root")
  fixtures=$root/fixtures
  write_fixtures "$fixtures"
  keep_only_widgets "$fixtures"
  # Not spending the cap on pull requests outside the window leaves the walk
  # itself unbounded, so a repository whose pages never reach the window has to
  # stop at the page bound and say that it did. Every page here is one the walk
  # passes over, and each names itself as the next cursor, so the walk would
  # otherwise never end.
  write_pr_page "$fixtures/prs-widgets.json" 2026-03-01T00:00:00Z 50 2001 endless
  write_pr_page "$fixtures/prs-widgets-endless.json" 2026-03-01T00:00:00Z 50 2001 endless
  install_fake_gh_axi "$bin" "$fixtures" ok

  model=$(PATH="$bin:$PATH" XO_ESTATE_REVIEW_NOW=$NOW FAKE_GH_LOG="$fixtures/calls.log" \
    "$REVIEW" acme --since 2025-01-01 --until 2025-04-01 --json) || fail "collection failed"
  printf '%s' "$model" > "$root/model.json"
  limit=$(jq -r '.options.pull_request_page_limit' "$root/model.json")
  case $limit in '' | *[!0-9]*) fail "the model does not disclose the pull-request page bound, got '$limit'" ;; esac
  detail=$(jq -r '.caps[] | select(.signal == "pull_requests") | .detail' "$root/model.json")
  assert_contains "$detail" "$limit pages" "the cap row states the page bound by the value the model discloses"
  assert_equals "0" "$(jq -r '.repositories[0].pull_requests.merged' "$root/model.json")"     "nothing in the window was reached, so nothing is counted"
  # One page for the open-pull-request pass, which this fixture ends after one.
  calls=$(grep -c 'POST graphql' "$fixtures/calls.log") || calls=0
  assert_equals "$((limit + 1))" "$calls"     "the walk stopped at the disclosed page bound rather than paging without end"

  # A cap is a gap, so it reaches the same boundary an unread signal does. The
  # row in section 9.2 is not enough on its own: the sentences a reader believes
  # are the one that says the window was silent and the one that says the estate
  # was read completely, and both would otherwise be false here.
  assert_equals "0" "$(jq -r '.selection.fully_read' "$root/model.json")"     "a repository whose read stopped at a cap was not read completely"
  assert_equals "1" "$(jq -r '.selection.partially_read' "$root/model.json")"     "it is counted as read with a gap instead"

  report=$root/report.md
  "$REVIEW" --from-json "$root/model.json" > "$report" || fail "rendering failed"
  assert_grep "1 reviewed, 0 read completely, 1 read with at least one gap" "$report"     "the header bullet reports the gap rather than claiming a clean read"
  assert_grep "No commit, pull request, review, or workflow run in what could be read, so every measure above is zero or unmeasurable rather than low (1 read behind this figure stopped at a cap; section 9.2 names it)." "$report"     "the headline says the walk never reached the window rather than that the window was silent"
  assert_grep "No pull request merged in what could be read, so there is no change-size distribution to report (1 read behind this figure stopped at a cap; section 9.2 names it)." "$report"     "a figure the capped read fed says how far its claim reaches"
  # The other half of the same rule: the reads that did complete are not hedged,
  # and the figures resting only on them still range over the window.
  assert_grep "No authored commit landed on a default branch in this window, so there is no revert or hotfix rate to report." "$report"     "a figure fed only by reads that completed still claims the window"
  assert_grep "- Open issues: 2" "$report"     "a count fed only by a read that completed carries no notice"
  assert_no_grep "No read hit a collection cap" "$report"     "a report whose pull-request walk stopped short does not claim every read was complete"
  assert_grep "| acme/widgets | pull_requests |" "$report" "section 9.2 names the repository whose walk stopped"
  assert_grep "| 0 | 2 | no | pull_requests |" "$report"     "section 7 names the capped read in that repository's gaps rather than reporting none"
  assert_fixed_shape "$report" "a walk that never reached the window"
  pass "a pull-request walk that cannot reach the window stops at the disclosed page bound, reports it as a cap, and no sentence claims a silent window or a complete read"
}

test_a_cap_on_the_window_pass_leaves_the_open_count_unhedged() {
  local root bin fixtures model report line file i
  root=$(xo_test_tmproot xo-estate-review-prcapopen) || fail "no fixture root"
  bin=$(xo_fakebin "$root")
  fixtures=$root/fixtures
  write_fixtures "$fixtures"
  keep_only_widgets "$fixtures"
  # The window-bounded pass spends its whole cap on pull requests merged inside
  # the window; the open-pull-request pass is a separate walk that completes.
  # The open count is what the completed pass supplies, so it is exact, and a cap
  # on the other walk must not hedge it: a notice on a figure it does not bound
  # teaches a reader to ignore the notice, which costs as much as omitting one.
  for i in 0 1 2 3 4 5; do
    if [ "$i" = 0 ]; then file=$fixtures/prs-widgets.json; else file=$fixtures/prs-widgets-c$((i + 1)).json; fi
    write_pr_page "$file" 2026-02-01T00:00:00Z 50 "$((1000 + i * 100))" "c$((i + 2))"
  done
  install_fake_gh_axi "$bin" "$fixtures" ok

  model=$(PATH="$bin:$PATH" XO_ESTATE_REVIEW_NOW=$NOW "$REVIEW" acme "${WINDOW[@]}" --json) ||
    fail "collection failed"
  printf '%s' "$model" > "$root/model.json"
  assert_equals "1" "$(jq -r '[.caps[] | select(.signal == "pull_requests")] | length' "$root/model.json")"     "the window pass is recorded as capped"
  assert_contains "$(jq -r '.caps[] | select(.signal == "pull_requests") | .detail' "$root/model.json")"     "updated before the window ended" "the cap says what it is actually spent on"
  assert_equals "$(jq -r '.options.max_prs' "$root/model.json")" "$(jq -r '.repositories[0].pull_requests.merged' "$root/model.json")"     "the cap the report discloses is the count the walk actually stopped at"
  assert_equals "complete" "$(jq -r '.repositories[0].signals.open_pull_requests.detail' "$root/model.json")"     "the open-pull-request pass completed"
  assert_equals "1" "$(jq -r '.risk.open_pull_requests' "$root/model.json")"     "the open count is what the completed pass supplies"

  report=$root/report.md
  "$REVIEW" --from-json "$root/model.json" > "$report" || fail "rendering failed"
  line=$(grep -F "Open pull requests: " "$report" | head -n 1)
  assert_not_contains "$line" "behind this figure"     "a count a completed read supplies in full carries no notice from another walk's cap"
  assert_grep "| acme/widgets | pull_requests |" "$report" "section 9.2 still names the cap that did bite"
  assert_fixed_shape "$report" "a capped window pass beside a complete open pass"
  pass "a cap on the window-bounded pull-request walk does not hedge the open count the completed open pass supplies"
}

test_each_pull_request_walk_spends_its_own_budget() {
  local root bin fixtures model file i
  root=$(xo_test_tmproot xo-estate-review-twowalks) || fail "no fixture root"
  bin=$(xo_fakebin "$root")
  fixtures=$root/fixtures
  write_fixtures "$fixtures"
  keep_only_widgets "$fixtures"
  # Each repository takes two pull-request walks and each spends its own cap, the
  # open one regardless of the window. Both are driven past the cap here, with
  # every open pull request last touched long before the window opened, so the
  # open count is capped by what that walk read rather than by anything about the
  # window, and the collection log names each cap against the walk that hit it.
  for i in 0 1 2 3 4 5; do
    if [ "$i" = 0 ]; then file=$fixtures/prs-widgets.json; else file=$fixtures/prs-widgets-c$((i + 1)).json; fi
    write_pr_page "$file" 2026-02-01T00:00:00Z 50 "$((1000 + i * 100))" "c$((i + 2))"
    if [ "$i" = 0 ]; then file=$fixtures/prs-open-widgets.json; else file=$fixtures/prs-open-widgets-o$((i + 1)).json; fi
    write_pr_page "$file" 2024-05-01T00:00:00Z 50 "$((5000 + i * 100))" "o$((i + 2))" OPEN
  done
  install_fake_gh_axi "$bin" "$fixtures" ok

  model=$(PATH="$bin:$PATH" XO_ESTATE_REVIEW_NOW=$NOW "$REVIEW" acme "${WINDOW[@]}" --json) ||
    fail "collection failed"
  printf '%s' "$model" > "$root/model.json"
  local cap
  cap=$(jq -r '.options.max_prs' "$root/model.json")
  assert_equals "$cap" "$(jq -r '.repositories[0].pull_requests.merged' "$root/model.json")"     "the window-bounded walk stopped at its own cap"
  assert_equals "$cap" "$(jq -r '.risk.open_pull_requests' "$root/model.json")"     "the open walk stopped at a cap of its own rather than sharing the window walk's"
  assert_equals "1" "$(jq -r '[.caps[] | select(.signal == "pull_requests")] | length' "$root/model.json")"     "the window walk reports its cap"
  assert_equals "1" "$(jq -r '[.caps[] | select(.signal == "open_pull_requests")] | length' "$root/model.json")"     "the open walk reports its own cap"
  assert_contains "$(jq -r '.caps[] | select(.signal == "open_pull_requests") | .detail' "$root/model.json")"     "open pull requests" "the open walk's cap says it is spent on open pull requests"
  "$REVIEW" --from-json "$root/model.json" > "$root/report.md" || fail "rendering failed"
  assert_fixed_shape "$root/report.md" "an estate where both pull-request walks hit their cap"
  pass "each pull-request walk spends a cap of its own, the open one regardless of the window"
}

test_section_1_states_the_bounds_the_model_carries() {
  local root bin model section1 name phrase
  root=$(xo_test_tmproot xo-estate-review-bounds) || fail "no fixture root"
  bin=$(xo_fakebin "$root")
  write_fixtures "$root/fixtures"
  install_fake_gh_axi "$bin" "$root/fixtures" ok
  model=$(PATH="$bin:$PATH" XO_ESTATE_REVIEW_NOW=$NOW "$REVIEW" acme "${WINDOW[@]}" --json) ||
    fail "collection failed"
  printf '%s' "$model" > "$root/model.json"

  # Section 1 states the window, the thresholds and the selection - what a reader
  # needs in order to read the figures, and nothing about how collection walks.
  # The way it goes wrong is by restating one of those in prose instead of
  # printing the value collection used, so the rule is that every one it states
  # comes from the model: rendering a model whose option values have been
  # replaced must state the replacements, and a value the renderer still holds as
  # a literal fails here rather than waiting for a reader to notice.
  jq '.options.max_repos = 7
          | .options.max_listed = 23
      | .options.stalled_days = 29
      | .options.unmaintained_days = 31
      | .options.trend_band_pct = 37' "$root/model.json" > "$root/altered.json" ||
    fail "could not replace the stored model's bounds"
  "$REVIEW" --from-json "$root/altered.json" > "$root/altered.md" || fail "rendering failed"
  section1=$(awk '/^## 1\./ { inside = 1; next } /^## 2\./ { inside = 0 } inside' "$root/altered.md")
  [ -n "$section1" ] || fail "the rendered report has no section 1 to read the bounds from"
  while IFS='|' read -r name phrase; do
    assert_contains "$section1" "$phrase" "section 1 states $name from the model rather than from a literal"
  done <<'BOUNDS'
max_repos|at most 7 repositories
max_listed|at most 23 worst-first rows
stalled_days|idle for 29 days or more
unmaintained_days|unpushed for 31 days or more
trend_band_pct|beyond 37%
BOUNDS
  pass "every collection bound section 1 states is printed from the model, so the disclosure cannot drift from it"
}

test_an_estate_larger_than_the_caps_names_both_of_them() {
  local root bin model
  root=$(xo_test_tmproot xo-estate-review-listcap) || fail "no fixture root"
  bin=$(xo_fakebin "$root")
  write_fixtures "$root/fixtures"
  # An organization whose listing never runs out of pages, which is what an estate
  # larger than the review looks like. Two bounds bite here and they are different
  # facts: the listing walk stops at its page bound, so the matched count describes
  # only what it saw, and the review then stops at the repository cap, so the
  # reviewed count describes only part of what it matched. Neither bound is
  # reachable by a flag any more, so both have to be disclosed or the report
  # claims a completeness it does not have.
  jq -n '[range(0; 100) | {name: "widgets-\(.)", owner: {login: "acme"},
            default_branch: "main", archived: false, fork: false,
            pushed_at: "2026-03-30T00:00:00Z", private: false}]' \
    > "$root/fixtures/repos-every-page.json" || fail "could not write the endless listing"
  install_fake_gh_axi "$bin" "$root/fixtures" ok

  model=$(PATH="$bin:$PATH" XO_ESTATE_REVIEW_NOW=$NOW \
    "$REVIEW" acme "${WINDOW[@]}" --json) || fail "collection failed"
  printf '%s' "$model" > "$root/model.json"
  assert_equals "1" "$(jq -r '[.caps[] | select(.signal == "repository_listing")] | length' "$root/model.json")"     "the truncated listing is recorded as a cap"
  assert_equals "acme" "$(jq -r '.caps[] | select(.signal == "repository_listing") | .repo' "$root/model.json")"     "the listing cap is keyed to the estate rather than to a repository"
  assert_equals "true" "$(jq -r '.selection.capped' "$root/model.json")" "the repository cap is recorded"
  assert_equals "100" "$(jq -r '.selection.reviewed' "$root/model.json")"     "the review stops at the repository cap"
  assert_equals "3000" "$(jq -r '.selection.matched' "$root/model.json")"     "the matched count survives the cap, so the shortfall is visible"

  "$REVIEW" --from-json "$root/model.json" > "$root/report.md" || fail "rendering failed"
  assert_fixed_shape "$root/report.md" "an estate larger than the caps"
  assert_no_grep "No read hit a collection cap" "$root/report.md"     "a report whose listing stopped short does not claim every read was complete"
  assert_grep "| acme | repository_listing |" "$root/report.md" "section 9.2 names the listing cap"
  assert_grep "3000 matched, 100 reviewed under this review's cap of 100 repositories" "$root/report.md"     "section 9.2 states the repository cap as the value that produced the shortfall"
  pass "an estate larger than the review names the listing page bound and the repository cap, with the value of each"
}

test_a_full_page_of_mostly_pull_requests_does_not_end_the_issue_walk() {
  local root bin model
  root=$(xo_test_tmproot xo-estate-review-issue-page) || fail "no fixture root"
  bin=$(xo_fakebin "$root")
  write_fixtures "$root/fixtures"
  # GitHub answers /issues with pull requests alongside issues, and the read
  # drops them. A full page whose surviving records are few is the case that
  # decides whether paging follows the endpoint or the filter: the estate has
  # five open issues, but only three of them are on the full first page.
  jq -n '[range(0; 100) | {number: (200 + .), created_at: "2026-02-01T00:00:00Z",
            updated_at: "2026-02-01T00:00:00Z"}
          | if (.number - 200) < 97 then . + {pull_request: {url: "x"}} else . end]' \
    > "$root/fixtures/issues-widgets.json" || fail "could not write the full first page"
  jq -n '[range(0; 2) | {number: (400 + .), created_at: "2026-02-02T00:00:00Z",
            updated_at: "2026-02-02T00:00:00Z"}]' \
    > "$root/fixtures/issues-widgets-page2.json" || fail "could not write the second page"
  install_fake_gh_axi "$bin" "$root/fixtures" ok

  model=$(PATH="$bin:$PATH" XO_ESTATE_REVIEW_NOW=$NOW "$REVIEW" acme "${WINDOW[@]}" --json) ||
    fail "collection failed"
  printf '%s' "$model" > "$root/model.json"
  assert_equals "5" "$(jq -r '.risk.open_issues' "$root/model.json")" "both pages of open issues are counted"
  assert_equals "0" "$(jq -r '[.caps[] | select(.signal == "issues")] | length' "$root/model.json")"     "a walk that ended on a short page reports no cap"
  pass "a full page whose pull requests are filtered out does not end the open-issue walk with the rest unread"
}

test_a_review_on_an_open_pull_request_is_counted_once() {
  local root model
  root=$(xo_test_tmproot xo-estate-review-dupe) || fail "no fixture root"
  model=$(collect_model "$root/fixtures" ok) || fail "collection failed"
  printf '%s' "$model" > "$root/model.json"
  # Pull request 5 is open and was updated inside the window, so it comes back
  # from both pull-request passes, carrying ada's review each time. One review
  # submission is one act of participation however many passes saw it.
  assert_equals "4" "$(jq -r '[.repositories[] | select(.name == "acme/widgets") | .reviews_received] | add' "$root/model.json")"     "the repository counts four reviews by another account, the open pull request's among them once"
  assert_equals "2" "$(jq -r '.people[] | select(.person == "ada") | .reviews_submitted' "$root/model.json")"     "ada's review of the open pull request is counted once, alongside her review of a merged one"
  assert_equals "2" "$(jq -r '.people[] | select(.person == "ada") | .prs_reviewed' "$root/model.json")"     "reviews submitted and pull requests reviewed agree"
  pass "a review on a pull request both collection passes return is counted once, not twice"
}

test_a_pull_request_with_more_reviews_than_one_page_discloses_the_bound() {
  local root bin model
  root=$(xo_test_tmproot xo-estate-review-revcap) || fail "no fixture root"
  bin=$(xo_fakebin "$root")
  write_fixtures "$root/fixtures"
  # The reviews of one pull request are read in a single page. A pull request
  # whose totalCount exceeds the nodes returned is a shortened review count, and
  # every other bound in this report is disclosed, so this one is too.
  jq '.data.repository.pullRequests.nodes |= map(if .number == 1
        then .reviews.totalCount = 60 else . end)' \
    "$root/fixtures/prs-widgets.json" > "$root/fixtures/prs.tmp" ||
    fail "could not widen the review count"
  mv "$root/fixtures/prs.tmp" "$root/fixtures/prs-widgets.json" || fail "could not install the widened fixture"
  install_fake_gh_axi "$bin" "$root/fixtures" ok

  model=$(PATH="$bin:$PATH" XO_ESTATE_REVIEW_NOW=$NOW "$REVIEW" acme "${WINDOW[@]}" --json) ||
    fail "collection failed"
  printf '%s' "$model" > "$root/model.json"
  # Filed under the signal it bounds rather than under the pull-request walk: it
  # shortens the review list inside a pull request, and nothing else, so it must
  # not reach a merged count that is exact.
  assert_equals "1" "$(jq -r '[.caps[] | select(.repo == "acme/widgets" and .signal == "pull_request_reviews")] | length' "$root/model.json")"     "the review page bound is recorded as a cap of its own"
  assert_contains "$(jq -r '.caps[] | select(.signal == "pull_request_reviews") | .detail' "$root/model.json")"     "carry more than 50 reviews" "the cap says what was shortened"
  assert_equals "complete" "$(jq -r '.repositories[0].signals.pull_requests.detail' "$root/model.json")"     "the pull-request walk itself is still recorded as complete"
  "$REVIEW" --from-json "$root/model.json" > "$root/report.md" || fail "rendering failed"
  assert_fixed_shape "$root/report.md" "an estate with a heavily reviewed pull request"
  assert_grep "Reads that hit a cap" "$root/report.md" "section 9.2 surfaces the bound to the reader"
  assert_grep "carry more than 50 reviews" "$root/report.md" "the reader is told which bound shortened the figures"
  pass "a pull request carrying more reviews than one page holds is disclosed as a cap rather than silently shortening a review count"
}

test_an_account_reaching_the_table_only_through_a_merged_pull_request_is_whole() {
  local root bin model
  root=$(xo_test_tmproot xo-estate-review-merged-only) || fail "no fixture root"
  bin=$(xo_fakebin "$root")
  write_fixtures "$root/fixtures"
  # Two pull requests opened before the window and merged inside it, by accounts
  # with no in-window commit and no review. Each account reaches the person table
  # through the merge alone, which is an ordinary way to arrive there and the one
  # way that used to lose half the row.
  jq '.data.repository.pullRequests.nodes += [
      {"number":7,"state":"MERGED","isDraft":false,"createdAt":"2025-12-20T00:00:00Z","updatedAt":"2026-01-05T00:00:00Z",
       "mergedAt":"2026-01-05T00:00:00Z","closedAt":"2026-01-05T00:00:00Z","additions":4,"deletions":1,"changedFiles":1,
       "headRefName":"f/7","title":"bump transitive lib","author":{"login":"renovate","__typename":"Bot"},
       "commits":{"nodes":[{"commit":{"committedDate":"2025-12-20T00:00:00Z"}}]},
       "reviews":{"totalCount":0,"nodes":[]},"reviewThreads":{"totalCount":0}},
      {"number":8,"state":"MERGED","isDraft":false,"createdAt":"2025-12-01T00:00:00Z","updatedAt":"2026-01-15T00:00:00Z",
       "mergedAt":"2026-01-15T00:00:00Z","closedAt":"2026-01-15T00:00:00Z","additions":9,"deletions":3,"changedFiles":2,
       "headRefName":"f/8","title":"long-running spike","author":{"login":"casey","__typename":"User"},
       "commits":{"nodes":[{"commit":{"committedDate":"2025-12-01T00:00:00Z"}}]},
       "reviews":{"totalCount":0,"nodes":[]},"reviewThreads":{"totalCount":0}}]' \
    "$root/fixtures/prs-widgets.json" > "$root/fixtures/prs.tmp" ||
    fail "could not extend the pull-request fixture"
  mv "$root/fixtures/prs.tmp" "$root/fixtures/prs-widgets.json" || fail "could not install the extended fixture"
  install_fake_gh_axi "$bin" "$root/fixtures" ok

  model=$(PATH="$bin:$PATH" XO_ESTATE_REVIEW_NOW=$NOW "$REVIEW" acme "${WINDOW[@]}" --json) ||
    fail "collection failed"
  printf '%s' "$model" > "$root/model.json"
  assert_equals "0" "$(jq -r '.people[] | select(.person == "renovate") | .prs_opened' "$root/model.json")"     "the bot reaches the table through its merge alone"
  assert_equals "1" "$(jq -r '.people[] | select(.person == "renovate") | .prs_merged' "$root/model.json")"     "the bot's merge is credited"
  assert_equals "true" "$(jq -r '.people[] | select(.person == "renovate") | .automation' "$root/model.json")"     "an automation account is marked as such however it reached the table"
  assert_equals "1" "$(jq -r '.people[] | select(.person == "casey") | .repos' "$root/model.json")"     "a merged pull request is a repository touched"
  assert_equals "false" "$(jq -r '.people[] | select(.person == "casey") | .automation' "$root/model.json")"     "a human who only merged is still a human"

  "$REVIEW" --from-json "$root/model.json" > "$root/report.md" || fail "rendering failed"
  assert_grep "Automation accounts in this table: 3 of 7" "$root/report.md"     "the automation count in section 3.1 includes the merge-only bot"
  pass "an account that reaches the person table only through a merged pull request is marked and counted like any other"
}

test_a_table_cell_carrying_a_pipe_stays_one_cell() {
  local root model report header_cells row_cells
  root=$(xo_test_tmproot xo-estate-review-pipe) || fail "no fixture root"
  model=$(collect_model "$root/fixtures" ok) || fail "collection failed"
  printf '%s' "$model" > "$root/model.json"
  report=$root/report.md
  "$REVIEW" --from-json "$root/model.json" > "$report" || fail "rendering failed"
  # The stalled pull request's title carries a pipe, which is this table's own
  # cell separator. The row has to keep the column count its header declares, or
  # a Markdown reader silently drops the overflow and shows a shortened title.
  cells_of() { printf '%s' "$1" | sed 's/\\|//g' | awk -F'|' '{print NF - 2}'; }
  header_cells=$(cells_of "$(grep -F '| Repository | Number | Idle days, at collection |' "$report")")
  row_cells=$(cells_of "$(grep -F '| acme/widgets | 5 |' "$report")")
  assert_equals "7" "$header_cells" "the stalled-work header declares seven columns"
  assert_equals "$header_cells" "$row_cells" "the row with a pipe in its title has the columns its header declares"
  assert_grep 'spike with a tab \| and a pipe' "$report" "the title survives intact rather than being cut at the pipe"
  pass "a table cell carrying the pipe that separates cells stays one cell and keeps its text"
}

test_a_commit_is_counted_in_the_window_it_landed_in() {
  local root bin model
  root=$(xo_test_tmproot xo-estate-review-landed) || fail "no fixture root"
  bin=$(xo_fakebin "$root")
  write_fixtures "$root/fixtures"
  # A commit written in December and rebased onto the default branch in February.
  # GitHub's commit list filters since/until on the committer date, so the API
  # returns it for this window; counting it by its author date would drop a commit
  # the request itself asked for, with nothing in section 9.2 to say so.
  jq '. += [{"sha":"c8","author":{"login":"brooke","type":"User"},"parents":[{"sha":"c7"}],
      "commit":{"author":{"email":"brooke@example.com","date":"2025-12-20T00:00:00Z"},
                "committer":{"email":"brooke@example.com","date":"2026-02-10T00:00:00Z"},
                "message":"feat: land the december spike"}}]' \
    "$root/fixtures/commits-widgets.json" > "$root/fixtures/commits.tmp" ||
    fail "could not extend the commit fixture"
  mv "$root/fixtures/commits.tmp" "$root/fixtures/commits-widgets.json" || fail "could not install the extended fixture"
  install_fake_gh_axi "$bin" "$root/fixtures" ok

  model=$(PATH="$bin:$PATH" XO_ESTATE_REVIEW_NOW=$NOW "$REVIEW" acme "${WINDOW[@]}" --json) ||
    fail "collection failed"
  printf '%s' "$model" > "$root/model.json"
  assert_equals "8" "$(jq -r '.quality.commits.total' "$root/model.json")" "the rebased commit is counted"
  assert_equals "[1,1,2,2,1,0]" "$(jq -c '.velocity.commits.per_period' "$root/model.json")"     "it falls in the period it landed in, not the one it was written in"
  assert_equals "3" "$(jq -r '.people[] | select(.person == "brooke") | .commits' "$root/model.json")"     "it is credited to whoever wrote it"
  pass "a commit rebased into the window is counted in the period it landed in and credited to its author"
}

test_a_commit_whose_workflow_ran_twice_counts_every_attempt() {
  local root bin model
  root=$(xo_test_tmproot xo-estate-review-attempts) || fail "no fixture root"
  bin=$(xo_fakebin "$root")
  write_fixtures "$root/fixtures"
  # One commit, one workflow, two runs: the first failed after three attempts,
  # then the pull request was reopened and the workflow ran again and passed.
  # The conclusion belongs to the later run, but the commit still needed three
  # attempts, and a counter read off the retained run alone would say none did.
  cat > "$root/fixtures/runs-widgets.json" <<'JSON'
{"workflow_runs":[
 {"workflow_id":1,"head_sha":"s9","run_number":7,"run_attempt":3,"conclusion":"failure","created_at":"2026-02-01T00:00:00Z"},
 {"workflow_id":1,"head_sha":"s9","run_number":9,"run_attempt":1,"conclusion":"success","created_at":"2026-02-02T00:00:00Z"}
]}
JSON
  install_fake_gh_axi "$bin" "$root/fixtures" ok

  model=$(PATH="$bin:$PATH" XO_ESTATE_REVIEW_NOW=$NOW "$REVIEW" acme "${WINDOW[@]}" --json) ||
    fail "collection failed"
  printf '%s' "$model" > "$root/model.json"
  assert_equals "1" "$(jq -r '.quality.ci.runs' "$root/model.json")" "both runs on one commit are one check"
  assert_equals "1" "$(jq -r '.quality.ci.passed' "$root/model.json")" "the check ended as the later run did"
  assert_equals "1" "$(jq -r '.quality.ci.needed_more_than_one_attempt' "$root/model.json")"     "the commit whose checks took three attempts is counted"

  "$REVIEW" --from-json "$root/model.json" > "$root/report.md" || fail "rendering failed"
  assert_grep "Checks that needed more than one attempt on the same commit: 1" "$root/report.md"     "section 5.4 reports what the runs on that commit actually needed"
  pass "a commit whose workflow ran more than once counts the attempts of every run, not only the last"
}

test_a_last_period_with_no_measurement_reports_no_direction() {
  local root bin model
  root=$(xo_test_tmproot xo-estate-review-sparse) || fail "no fixture root"
  bin=$(xo_fakebin "$root")
  write_fixtures "$root/fixtures"
  install_fake_gh_axi "$bin" "$root/fixtures" ok
  # Six months: everything merged in the first two, so the later periods hold no
  # measured pull request at all. A direction drawn from the earlier ones would
  # describe a time that ended before the window did.
  model=$(PATH="$bin:$PATH" XO_ESTATE_REVIEW_NOW=2026-07-01T00:00:00Z \
    "$REVIEW" acme --since 2026-01-01 --until 2026-07-01 --json) || fail "collection failed"
  printf '%s' "$model" > "$root/model.json"
  assert_equals "null" "$(jq -r '.velocity.cycle_hours.per_period_median[-1]' "$root/model.json")"     "the last period has no measured cycle time"
  assert_equals "final-period-unmeasured" "$(jq -r '.velocity.cycle_hours.trend' "$root/model.json")"     "no direction is derived from the earlier periods"
  assert_equals "final-period-unmeasured" \
    "$(jq -r '.headline[] | select(.metric | startswith("Cycle time")) | .trend' "$root/model.json")"     "the headline row carries the same absence the model does"

  "$REVIEW" --from-json "$root/model.json" > "$root/report.md" || fail "rendering failed"
  assert_fixed_shape "$root/report.md" "an estate whose last period is empty"
  assert_grep "not reported: the last period has no measurement" "$root/report.md"     "the headline row states that no direction is reported"
  assert_grep "Direction: not reported, because the last period has no measurement; periods beginning 2026-04-01, 2026-05-01, 2026-05-31 had none" "$root/report.md"     "section 4.2 names every period that had no measurement"
  pass "a median series whose last period has no measurement reports no direction and names the empty periods"
}

test_a_person_table_is_ordered_by_account_not_by_volume() {
  local root model report
  root=$(xo_test_tmproot xo-estate-review-order) || fail "no fixture root"
  model=$(collect_model "$root/fixtures" ok) || fail "collection failed"
  printf '%s' "$model" > "$root/model.json"
  report=$root/report.md
  "$REVIEW" --from-json "$root/model.json" > "$report" || fail "rendering failed"
  # ada has three opened pull requests and brooke two, so a volume ordering would
  # not be alphabetical. The report must not read as a leaderboard.
  local order
  order=$(sed -n '/^### 3.1/,/^### 3.2/p' "$report" | sed -n 's/^| \([a-z][^ |]*\) |.*/\1/p' | tr '\n' ' ')
  assert_equals "ada brooke copilot-pull-request-reviewer dependabot unlinked:carol@example.com " \
    "$order" "the person table is ordered by account name"
  assert_grep "not a ranking" "$report" "the person table says it is not a ranking"
  assert_grep "Automation accounts in this table: 2 of 5" "$report" "automation rows are counted for the reader"
  pass "the person table is ordered by account name and says in writing that it is not a ranking"
}

test_a_bounded_risk_list_states_how_many_rows_it_did_not_show() {
  local root bin model
  root=$(xo_test_tmproot xo-estate-review-listed) || fail "no fixture root"
  bin=$(xo_fakebin "$root")
  write_fixtures "$root/fixtures"
  # Twenty open pull requests nobody has touched since before the window, which
  # is what a real estate with a long-open queue looks like. A list that quietly
  # showed the first fifteen would read exactly like a list of fifteen, so the
  # count and the remainder both have to be stated.
  jq '.data.repository.pullRequests.nodes += [range(0; 20) | {
        number: (100 + .), state: "OPEN", isDraft: false,
        createdAt: "2025-11-01T00:00:00Z", updatedAt: "2025-12-01T00:00:00Z",
        mergedAt: null, closedAt: null, additions: 1, deletions: 1, changedFiles: 1,
        headRefName: "f/\(100 + .)", title: "stalled \(.)",
        author: {login: "brooke", __typename: "User"},
        commits: {nodes: [{commit: {committedDate: "2025-11-01T00:00:00Z"}}]},
        reviews: {totalCount: 0, nodes: []}, reviewThreads: {totalCount: 0}}]' \
    "$root/fixtures/prs-widgets.json" > "$root/fixtures/prs.tmp" ||
    fail "could not extend the pull-request fixture"
  mv "$root/fixtures/prs.tmp" "$root/fixtures/prs-widgets.json" || fail "could not install the queue fixture"
  jq '.data.repository.pullRequests.nodes |= map(select(.state == "OPEN"))' \
    "$root/fixtures/prs-widgets.json" > "$root/fixtures/prs-open-widgets.json" ||
    fail "could not rebuild the open-pull-request fixture"
  install_fake_gh_axi "$bin" "$root/fixtures" ok

  model=$(PATH="$bin:$PATH" XO_ESTATE_REVIEW_NOW=$NOW "$REVIEW" acme "${WINDOW[@]}" --json) ||
    fail "collection failed"
  printf '%s' "$model" > "$root/model.json"
  assert_equals "21" "$(jq -r '.risk.stalled_pull_requests | length' "$root/model.json")"     "the model keeps every stalled row"

  stalled_rows() { sed -n '/^### 6.3 Stalled work/,/^## 7\./p' "$1" | grep -c '^| acme/widgets | '; }
  "$REVIEW" --from-json "$root/model.json" > "$root/report.md" || fail "rendering failed"
  assert_fixed_shape "$root/report.md" "an estate with a long stalled queue"
  assert_grep "Open pull requests idle for 14 days or more: 21, longest idle first." "$root/report.md"     "the complete stalled count is stated even though the rows are bounded"
  assert_equals "15" "$(stalled_rows "$root/report.md")" "the stalled list is bounded to fifteen rows"
  assert_grep "6 further pull requests are in this report's model but not listed above" "$root/report.md"     "the rows not shown are disclosed with their count"

  # The report tells the reader that --json carries every row. Following that
  # instruction against the model in hand has to actually produce them, or the
  # report is pointing at a way out that does not exist.
  assert_grep "\`--json\` prints the model, which carries every one of them" "$root/report.md"     "the report names where the rows it did not list can be read"
  "$REVIEW" --from-json "$root/model.json" --json > "$root/re.json" ||
    fail "re-emitting the stored model failed"
  assert_equals "21" "$(jq -r '.risk.stalled_pull_requests | length' "$root/re.json")"     "the model --json prints carries every row the report bounded"
  pass "a bounded risk list states its complete count and how many rows it did not show, and names where every row can be read"
}

test_from_json_re_emits_the_stored_model_and_refuses_a_different_window() {
  local root model out code flag
  root=$(xo_test_tmproot xo-estate-review-fromjson) || fail "no fixture root"
  model=$(collect_model "$root/fixtures" ok) || fail "collection failed"
  printf '%s' "$model" > "$root/model.json"

  # A stored model is a finished collection, and nothing beside --from-json can
  # alter it. --json re-emits exactly what is on disk, which is what makes a
  # stored model a fixed input: the same model renders the same report anywhere.
  "$REVIEW" --from-json "$root/model.json" --json > "$root/re.json" ||
    fail "--json alongside --from-json was refused"
  assert_equals "$(jq -cS . "$root/model.json")" "$(jq -cS . "$root/re.json")"     "the re-emitted model is the stored model, unchanged"

  # The window flags would need data the model cannot supply, so each is refused
  # by name rather than accepted and dropped.
  for flag in "--window 30" "--since 2026-02-01" "--until 2026-03-01"; do
    # shellcheck disable=SC2086  # each entry is a flag and its value.
    out=$("$REVIEW" --from-json "$root/model.json" $flag 2>&1) && code=0 || code=$?
    assert_equals "2" "$code" "'$flag' with --from-json exits 2"
    assert_contains "$out" "${flag%% *} cannot be applied to a stored model" "'$flag' is refused by name"
    assert_contains "$out" "needs a fresh collection" "'$flag' says what to do instead"
  done

  # A setting that is a constant is not a flag anywhere, so it is refused as an
  # unknown flag rather than as something a fresh collection could satisfy.
  for flag in "--periods 4" "--stalled-days 2" "--unmaintained-days 10" "--max-repos 1" \
    "--max-prs 10" "--max-listed 3" "--include-forks" "--exclude-archived"; do
    # shellcheck disable=SC2086  # each entry is a flag and its value.
    out=$("$REVIEW" --from-json "$root/model.json" $flag 2>&1) && code=0 || code=$?
    assert_equals "2" "$code" "'$flag' exits 2"
    assert_contains "$out" "unknown flag '${flag%% *}'" "'$flag' is not a flag at all"
    # shellcheck disable=SC2086
    out=$("$REVIEW" acme $flag 2>&1) && code=0 || code=$?
    assert_equals "2" "$code" "'$flag' exits 2 against an estate too"
    assert_contains "$out" "unknown flag '${flag%% *}'" "'$flag' is not a flag on a fresh collection either"
  done
  pass "--from-json re-emits the stored model, refuses a different window by name, and a constant is not a flag anywhere"
}

test_the_window_bounds_what_is_counted() {
  local root bin model
  root=$(xo_test_tmproot xo-estate-review-window) || fail "no fixture root"
  bin=$(xo_fakebin "$root")
  write_fixtures "$root/fixtures"
  install_fake_gh_axi "$bin" "$root/fixtures" ok
  # February only: the fixture has two authored commits in it (2026-02-05 and
  # 2026-02-15) and one merged pull request (2026-02-03).
  model=$(PATH="$bin:$PATH" XO_ESTATE_REVIEW_NOW=$NOW \
    "$REVIEW" acme --since 2026-02-01 --until 2026-03-01 --json) || fail "collection failed"
  printf '%s' "$model" > "$root/model.json"
  assert_equals "2" "$(jq -r '.quality.commits.commits' "$root/model.json")" "only in-window commits are authored counts"
  assert_equals "1" "$(jq -r '[.repositories[].pull_requests.merged] | add' "$root/model.json")" "only in-window merges are counted"
  assert_equals "6" "$(jq -r '.window.periods' "$root/model.json")" "the fixed period count is recorded"
  assert_equals "28" "$(jq -r '.window.days' "$root/model.json")" "the window length is recorded"
  pass "the window bounds what is counted, and it and the fixed period count are recorded in the model"
}

test_an_unreadable_estate_stops_the_run_with_gh_axis_own_words() {
  local root bin out code
  root=$(xo_test_tmproot xo-estate-review-404) || fail "no fixture root"
  bin=$(xo_fakebin "$root")
  write_fixtures "$root/fixtures"
  install_fake_gh_axi "$bin" "$root/fixtures" owner-not-found
  out=$(PATH="$bin:$PATH" XO_ESTATE_REVIEW_NOW=$NOW "$REVIEW" acme "${WINDOW[@]}" --json 2>&1) && code=0 || code=$?
  [ "$code" != 0 ] || fail "an unreadable estate owner did not stop the run"
  assert_contains "$out" "could not read the owner 'acme'" "the refusal names what could not be read"
  assert_contains "$out" "Not Found (HTTP 404)" "the refusal quotes gh-axi's own diagnostic rather than inventing one"
  assert_not_contains "$out" "xo-estate-review.v1" "an unreadable estate produced no model"
  pass "an unreadable estate stops the run and quotes gh-axi's own diagnostic"
}

test_collection_derives_the_documented_figures
test_one_automation_account_is_one_row_and_is_marked
test_an_unreadable_estate_stops_the_run_with_gh_axis_own_words
test_every_run_emits_the_same_nine_sections
test_an_estate_with_no_data_still_emits_every_section
test_a_repository_the_tooling_cannot_read_is_named_not_dropped
test_an_estate_nothing_could_be_read_from_never_reads_as_a_quiet_one
test_push_recency_is_measured_from_collection_not_from_the_window_end
test_a_read_that_fell_short_reaches_the_figures_it_fed_and_no_others
test_rendering_the_same_model_twice_is_byte_identical
test_a_changed_gh_axi_envelope_refuses_instead_of_reporting_an_empty_estate
test_collection_makes_no_state_changing_call
test_the_report_records_the_commands_that_produced_it
test_free_text_from_the_estate_cannot_break_a_record
test_scope_and_argument_validation_refuses_rather_than_guessing
test_a_single_repository_review_is_the_same_report_with_one_row
test_repository_selection_excludes_forks_and_discloses_it
test_a_named_repository_is_reviewed_whether_or_not_it_is_a_fork
test_an_estate_larger_than_the_caps_names_both_of_them
test_a_cap_on_the_window_pass_leaves_the_open_count_unhedged
test_each_pull_request_walk_spends_its_own_budget
test_section_1_states_the_bounds_the_model_carries
test_a_window_behind_the_pull_request_cap_is_still_reached
test_a_walk_that_cannot_reach_the_window_names_the_page_bound
test_a_person_table_is_ordered_by_account_not_by_volume
test_a_bounded_risk_list_states_how_many_rows_it_did_not_show
test_from_json_re_emits_the_stored_model_and_refuses_a_different_window
test_the_window_bounds_what_is_counted
test_a_full_page_of_mostly_pull_requests_does_not_end_the_issue_walk
test_a_review_on_an_open_pull_request_is_counted_once
test_a_pull_request_with_more_reviews_than_one_page_discloses_the_bound
test_a_last_period_with_no_measurement_reports_no_direction
test_a_commit_whose_workflow_ran_twice_counts_every_attempt
test_an_account_reaching_the_table_only_through_a_merged_pull_request_is_whole
test_a_table_cell_carrying_a_pipe_stays_one_cell
test_a_commit_is_counted_in_the_window_it_landed_in

echo "# xo-estate-review.test.sh: all assertions passed"
