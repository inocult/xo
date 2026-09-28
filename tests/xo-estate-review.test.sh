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
WINDOW=(--since 2026-01-01 --until 2026-04-01 --periods 3)

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
path='' program='' input='' args=("$@") i=0
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
    if grep -q 'states:OPEN' "$input"; then
      fixture=$FIXTURES/prs-open-$repo.json
    else
      fixture=$FIXTURES/prs-$repo.json
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
  assert_equals "[2,3,1]" "$(jq -c '.velocity.commits.per_period' "$root/model.json")" "commits per period"

  # Pull requests, and the cycle time the merged ones give.
  assert_equals "4" "$(jq -r '[.repositories[].pull_requests.merged] | add' "$root/model.json")" "merged"
  assert_equals "6" "$(jq -r '[.repositories[].pull_requests.opened] | add' "$root/model.json")" "opened"
  assert_equals "1" "$(jq -r '.risk.open_pull_requests' "$root/model.json")" "open now"
  assert_equals "48" "$(jq -r '.velocity.cycle_hours.median' "$root/model.json")" "median cycle hours"
  assert_equals "[48,48,36]" "$(jq -c '.velocity.cycle_hours.per_period_median' "$root/model.json")" "cycle per period"
  assert_equals "falling" "$(jq -r '.velocity.cycle_hours.trend' "$root/model.json")" "cycle trend"

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
  assert_grep "No commit, pull request, review, or workflow run fell in this window" "$root/empty.md" "the headline says the window was silent rather than reading as low activity"
  assert_no_grep "reads failed; section 9.2 names them" "$root/empty.md" "an estate that was read completely is not told its reads failed"
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
  pass "a repository the tooling cannot read is named as unread and still appears, never silently dropped"
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
  for surface in "No commit, pull request, review, or workflow run fell in what could be read" \
    "No account committed, opened a pull request, or reviewed one in what could be read" \
    "Nothing was committed or merged in what could be read" \
    "No authored commit landed on a default branch in what could be read" \
    "No pull request merged in what could be read" \
    "No GitHub Actions pull-request run happened in what could be read" \
    "No authored commit landed in what could be read"; do
    assert_grep "$surface" "$root/report.md" "an unread estate reports '$surface'"
  done
  assert_equals "13" "$(grep -c 'reads failed; section 9.2 names them' "$root/report.md")"     "every empty surface, and the collection-time subsection, names the reads that failed behind its zeros"
  pass "an estate whose reads all failed states in every section that it could not be read, never that it was quiet"
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
    "$REVIEW" acme --since 2025-01-01 --until 2025-06-01 --periods 3 --json) ||
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
  # Section 7 mixes window figures and collection-time state in one row, so every
  # column carrying estate state has to name its clock in the rendered header.
  local cell
  while IFS= read -r cell; do
    case $cell in
      *Open* | *Idle* | *Archived*)
        case $cell in
          *"at collection"*) ;;
          *) fail "section 7's '$cell' column reports the state of the estate without saying it is measured at collection" ;;
        esac
        ;;
    esac
  done < <(sed -n '/^## 7\./,/^## 8\./p' "$root/report.md" | grep -m 1 '^| Repository |' | tr '|' '\n' | sed 's/^ *//; s/ *$//' | grep -v '^$')
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

  out=$(PATH="$bin:$PATH" "$REVIEW" acme --periods 1 2>&1) && code=0 || code=$?
  assert_equals "2" "$code" "one period exits 2"
  assert_contains "$out" "--periods must be at least 2" "a single period is refused, because a trend needs two"

  out=$(PATH="$bin:$PATH" "$REVIEW" acme --since 2026-13-99 2>&1) && code=0 || code=$?
  assert_equals "2" "$code" "a malformed date exits 2"

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

test_repository_selection_excludes_forks_and_discloses_a_cap() {
  local root bin model
  root=$(xo_test_tmproot xo-estate-review-select) || fail "no fixture root"
  bin=$(xo_fakebin "$root")
  write_fixtures "$root/fixtures"
  jq '.[1].fork = true' "$root/fixtures/repos.json" > "$root/fixtures/repos.tmp" &&
    mv "$root/fixtures/repos.tmp" "$root/fixtures/repos.json"
  install_fake_gh_axi "$bin" "$root/fixtures" ok

  model=$(PATH="$bin:$PATH" XO_ESTATE_REVIEW_NOW=$NOW "$REVIEW" acme "${WINDOW[@]}" --json) ||
    fail "collection failed"
  assert_equals "1" "$(printf '%s' "$model" | jq -r '.repositories | length')" "a fork is excluded by default"

  model=$(PATH="$bin:$PATH" XO_ESTATE_REVIEW_NOW=$NOW "$REVIEW" acme "${WINDOW[@]}" --include-forks --json) ||
    fail "collection with forks failed"
  assert_equals "2" "$(printf '%s' "$model" | jq -r '.repositories | length')" "--include-forks includes it"

  model=$(PATH="$bin:$PATH" XO_ESTATE_REVIEW_NOW=$NOW "$REVIEW" acme "${WINDOW[@]}" --include-forks --max-repos 1 --json) ||
    fail "collection with a repository cap failed"
  assert_equals "true" "$(printf '%s' "$model" | jq -r '.selection.capped')" "the repository cap is recorded"
  assert_equals "2" "$(printf '%s' "$model" | jq -r '.selection.matched')" "the matched count survives the cap"
  pass "selection excludes forks by default and discloses a repository cap"
}

test_a_truncated_repository_listing_is_named_as_a_cap() {
  local root bin model
  root=$(xo_test_tmproot xo-estate-review-listcap) || fail "no fixture root"
  bin=$(xo_fakebin "$root")
  write_fixtures "$root/fixtures"
  # An organization whose listing never runs out of pages, which is what an estate
  # larger than the page walk looks like. The walk stops at its page bound, so the
  # matched count describes only what it saw, and a report that did not say so
  # would claim a completeness it does not have.
  jq -n '[range(0; 100) | {name: "widgets-\(.)", owner: {login: "acme"},
            default_branch: "main", archived: false, fork: false,
            pushed_at: "2026-03-30T00:00:00Z", private: false}]' \
    > "$root/fixtures/repos-every-page.json" || fail "could not write the endless listing"
  install_fake_gh_axi "$bin" "$root/fixtures" ok

  model=$(PATH="$bin:$PATH" XO_ESTATE_REVIEW_NOW=$NOW \
    "$REVIEW" acme "${WINDOW[@]}" --max-repos 1 --json) || fail "collection failed"
  printf '%s' "$model" > "$root/model.json"
  assert_equals "1" "$(jq -r '[.caps[] | select(.signal == "repository_listing")] | length' "$root/model.json")"     "the truncated listing is recorded as a cap"
  assert_equals "acme" "$(jq -r '.caps[] | select(.signal == "repository_listing") | .repo' "$root/model.json")"     "the listing cap is keyed to the estate rather than to a repository"

  "$REVIEW" --from-json "$root/model.json" > "$root/report.md" || fail "rendering failed"
  assert_fixed_shape "$root/report.md" "an estate whose listing was truncated"
  assert_no_grep "No read hit a collection cap" "$root/report.md"     "a report whose listing stopped short does not claim every read was complete"
  assert_grep "| acme | repository_listing |" "$root/report.md" "section 9.2 names the listing cap"
  pass "a repository listing that stopped at its page bound is named as a cap instead of reading as a complete estate"
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
  assert_equals "1" "$(jq -r '[.caps[] | select(.repo == "acme/widgets" and .signal == "pull_requests")] | length' "$root/model.json")"     "the review page bound is recorded as a cap"
  assert_contains "$(jq -r '.caps[] | select(.signal == "pull_requests") | .detail' "$root/model.json")"     "carry more than 50 reviews" "the cap says what was shortened"
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
  header_cells=$(cells_of "$(grep -F '| Repository | Number | Idle days |' "$report")")
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
  assert_equals "[2,4,1]" "$(jq -c '.velocity.commits.per_period' "$root/model.json")"     "it falls in the period it landed in, not the one it was written in"
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
  # Six months in three periods: everything merged in the first four months, so
  # the last period holds no measured pull request at all. A direction drawn
  # from the earlier ones would describe a time that ended before the window did.
  model=$(PATH="$bin:$PATH" XO_ESTATE_REVIEW_NOW=2026-07-01T00:00:00Z \
    "$REVIEW" acme --since 2026-01-01 --until 2026-07-01 --periods 3 --json) || fail "collection failed"
  printf '%s' "$model" > "$root/model.json"
  assert_equals "null" "$(jq -r '.velocity.cycle_hours.per_period_median[2]' "$root/model.json")"     "the last period has no measured cycle time"
  assert_equals "final-period-unmeasured" "$(jq -r '.velocity.cycle_hours.trend' "$root/model.json")"     "no direction is derived from the earlier periods"
  assert_equals "final-period-unmeasured" \
    "$(jq -r '.headline[] | select(.metric | startswith("Cycle time")) | .trend' "$root/model.json")"     "the headline row carries the same absence the model does"

  "$REVIEW" --from-json "$root/model.json" > "$root/report.md" || fail "rendering failed"
  assert_fixed_shape "$root/report.md" "an estate whose last period is empty"
  assert_grep "not reported: the last period has no measurement" "$root/report.md"     "the headline row states that no direction is reported"
  assert_grep "Direction: not reported, because the last period has no measurement; periods beginning 2026-05-01 had none" "$root/report.md"     "section 4.2 names the period that had no measurement"
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

  # The report tells the reader to raise --max-listed to see them. Following that
  # instruction against the model in hand has to actually show them.
  "$REVIEW" --from-json "$root/model.json" --max-listed 0 > "$root/all.md" ||
    fail "re-rendering with a raised --max-listed failed"
  assert_equals "21" "$(stalled_rows "$root/all.md")" "raising --max-listed shows every row the model kept"
  assert_no_grep "further pull requests are in this report's model" "$root/all.md"     "nothing is left undisclosed once every row is listed"
  pass "a bounded risk list states its complete count and how many rows it did not show, and raising --max-listed on the stored model shows them"
}

test_from_json_honours_a_presentation_flag_and_refuses_the_rest() {
  local root model out code flag
  root=$(xo_test_tmproot xo-estate-review-fromjson) || fail "no fixture root"
  model=$(collect_model "$root/fixtures" ok) || fail "collection failed"
  printf '%s' "$model" > "$root/model.json"

  # A stored model is a finished collection. A flag that only changes how it is
  # presented is honoured and says so in the model it re-emits.
  "$REVIEW" --from-json "$root/model.json" --max-listed 3 --json > "$root/re.json" ||
    fail "--max-listed alongside --from-json was refused"
  assert_equals "3" "$(jq -r '.options.max_listed' "$root/re.json")"     "the honoured bound is written into the model the report is rendered from"
  assert_equals "15" "$(jq -r '.options.max_listed' "$root/model.json")"     "the stored model on disk is left alone"

  # Every other flag would need data the model cannot supply, so it is refused by
  # name rather than accepted and dropped.
  for flag in "--window 30" "--since 2026-02-01" "--periods 4" "--stalled-days 2" \
    "--unmaintained-days 10" "--max-repos 1" "--max-prs 10" "--include-forks" "--exclude-archived"; do
    # shellcheck disable=SC2086  # each entry is a flag and its value.
    out=$("$REVIEW" --from-json "$root/model.json" $flag 2>&1) && code=0 || code=$?
    assert_equals "2" "$code" "'$flag' with --from-json exits 2"
    assert_contains "$out" "${flag%% *} cannot be applied to a stored model" "'$flag' is refused by name"
    assert_contains "$out" "needs a fresh collection" "'$flag' says what to do instead"
  done
  pass "--from-json honours a flag the stored model can satisfy and refuses every other one by name"
}

test_the_window_and_periods_bound_what_is_counted() {
  local root bin model
  root=$(xo_test_tmproot xo-estate-review-window) || fail "no fixture root"
  bin=$(xo_fakebin "$root")
  write_fixtures "$root/fixtures"
  install_fake_gh_axi "$bin" "$root/fixtures" ok
  # February only: the fixture has two authored commits in it (2026-02-05 and
  # 2026-02-15) and one merged pull request (2026-02-03).
  model=$(PATH="$bin:$PATH" XO_ESTATE_REVIEW_NOW=$NOW \
    "$REVIEW" acme --since 2026-02-01 --until 2026-03-01 --periods 2 --json) || fail "collection failed"
  printf '%s' "$model" > "$root/model.json"
  assert_equals "2" "$(jq -r '.quality.commits.commits' "$root/model.json")" "only in-window commits are authored counts"
  assert_equals "1" "$(jq -r '[.repositories[].pull_requests.merged] | add' "$root/model.json")" "only in-window merges are counted"
  assert_equals "2" "$(jq -r '.window.periods' "$root/model.json")" "the period count is recorded"
  assert_equals "14" "$(jq -r '.window.period_days' "$root/model.json")" "the period length is recorded"
  assert_equals "28" "$(jq -r '.window.days' "$root/model.json")" "the window length is recorded"
  pass "the window and period settings bound what is counted and are recorded in the model"
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
test_rendering_the_same_model_twice_is_byte_identical
test_a_changed_gh_axi_envelope_refuses_instead_of_reporting_an_empty_estate
test_collection_makes_no_state_changing_call
test_the_report_records_the_commands_that_produced_it
test_free_text_from_the_estate_cannot_break_a_record
test_scope_and_argument_validation_refuses_rather_than_guessing
test_a_single_repository_review_is_the_same_report_with_one_row
test_repository_selection_excludes_forks_and_discloses_a_cap
test_a_truncated_repository_listing_is_named_as_a_cap
test_a_person_table_is_ordered_by_account_not_by_volume
test_a_bounded_risk_list_states_how_many_rows_it_did_not_show
test_from_json_honours_a_presentation_flag_and_refuses_the_rest
test_the_window_and_periods_bound_what_is_counted
test_a_full_page_of_mostly_pull_requests_does_not_end_the_issue_walk
test_a_review_on_an_open_pull_request_is_counted_once
test_a_pull_request_with_more_reviews_than_one_page_discloses_the_bound
test_a_last_period_with_no_measurement_reports_no_direction
test_a_commit_whose_workflow_ran_twice_counts_every_attempt
test_an_account_reaching_the_table_only_through_a_merged_pull_request_is_whole
test_a_table_cell_carrying_a_pipe_stays_one_cell
test_a_commit_is_counted_in_the_window_it_landed_in

echo "# xo-estate-review.test.sh: all assertions passed"
