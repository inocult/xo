#!/usr/bin/env bash
# Live guard for bin/xo-estate-review.sh against the real gh-axi and real GitHub.
#
# bin/xo-estate-review.sh reads a vendor-rendered surface: gh-axi renders every
# response for an agent to read, and the script decodes the one envelope field
# that carries its shaped payload. A fake can only ever confirm the assumption
# already written into the fake, so the envelope itself has to be proven against
# the installed gh-axi. tests/xo-estate-review.test.sh pins the decode and every
# derived figure portably; this guard answers the one question it cannot: does
# the real gh-axi still emit what that decode expects.
#
# It spends no model tokens. It does need an authenticated gh, which the portable
# CI lane has no credentials for, so an unauthenticated host reports a capability
# skip rather than a failure - unless the guard was explicitly requested, where an
# unusable host must fail instead of quietly passing over the thing under test.
#
# The estate is jqlang, a small public organization. Public is deliberate: this
# guard prints report fragments, and a report names the accounts that contributed.
set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

xo_live_gate default-on XO_ESTATE_REVIEW_LIVE gh-axi gh jq

REQUESTED=0
case "${XO_ESTATE_REVIEW_LIVE:-}${XO_LIVE:-}" in
  *1*) REQUESTED=1 ;;
esac
if ! gh auth status > /dev/null 2>&1; then
  if [ "$REQUESTED" = 1 ]; then
    fail "gh is not authenticated, so this guard cannot read GitHub; authenticate or unset XO_ESTATE_REVIEW_LIVE/XO_LIVE"
  fi
  printf 'skip: live: gh is not authenticated for GitHub reads\n'
  exit 0
fi

REVIEW="$ROOT/bin/xo-estate-review.sh"
ESTATE=${XO_ESTATE_REVIEW_LIVE_ESTATE:-jqlang}
REPO=${XO_ESTATE_REVIEW_LIVE_REPO:-jq}
WINDOW=(--since 2025-05-01 --until 2025-07-01 --periods 3 --max-prs 0)
GH_AXI_VERSION=$(gh-axi --version 2>/dev/null | head -n 1)
[ -n "$GH_AXI_VERSION" ] || GH_AXI_VERSION="unknown"

ROOT_DIR=$(xo_test_tmproot xo-estate-review-live) || fail "could not create a fixture root"

test_the_real_gh_axi_envelope_still_carries_a_shaped_payload() {
  # The exact three couplings gh_read depends on, read straight off the vendor:
  # one api_response body field, a truncated marker that says false under --full,
  # and a tab-separated payload that survives the round trip as a payload rather
  # than being re-rendered into something else.
  local raw bodies truncated decoded
  raw=$ROOT_DIR/envelope.txt
  gh-axi api "/repos/$ESTATE/$REPO" --full \
    --jq '["repo",.full_name,(.default_branch//"-"),(.archived|tostring)]|@tsv' > "$raw" 2>&1 ||
    fail "gh-axi ($GH_AXI_VERSION) could not read /repos/$ESTATE/$REPO"
  bodies=$(grep -c '^[[:space:]]*body:[[:space:]]*' "$raw") || bodies=0
  [ "$bodies" = 1 ] ||
    fail "gh-axi ($GH_AXI_VERSION) rendered $bodies body fields, not 1; bin/xo-estate-review.sh's gh_read decodes exactly one"
  truncated=$(sed -n 's/^[[:space:]]*truncated:[[:space:]]*//p' "$raw" | head -n 1)
  [ "$truncated" = "false" ] ||
    fail "gh-axi ($GH_AXI_VERSION) reported truncated='$truncated' under --full; the collector refuses a truncated payload"
  decoded=$(sed -n 's/^[[:space:]]*body:[[:space:]]*//p' "$raw" | jq -r .)
  case $decoded in
    "repo	$ESTATE/$REPO	"*) ;;
    *) fail "gh-axi ($GH_AXI_VERSION) body decoded to '$decoded', not the tab-separated record the --jq program asked for" ;;
  esac
  pass "gh-axi $GH_AXI_VERSION still renders one quoted api_response body carrying an untruncated tab-separated payload"
}

test_the_real_graphql_read_needs_an_explicit_post() {
  # gh-axi defaults api to GET, and GitHub answers a GET on /graphql with schema
  # introspection rather than the query, which is why the collector passes POST
  # explicitly. What this case pins is that the explicit POST still returns the
  # query's own data in the shape the collector reads.
  local body posted
  body=$ROOT_DIR/query.json
  jq -n --arg owner "$ESTATE" --arg name "$REPO" '{
    query: "query($owner:String!,$name:String!){repository(owner:$owner,name:$name){pullRequests(first:1,orderBy:{field:UPDATED_AT,direction:DESC}){nodes{number author{login __typename} reviews(first:5){totalCount}}}}}",
    variables: {owner: $owner, name: $name}}' > "$body" || fail "could not compose the live query body"

  posted=$(gh-axi api POST graphql --input "$body" --full \
    --jq '[.data.repository.pullRequests.nodes[]|["pr",(.number|tostring),((.author.login)//"-"),((.author.__typename)//"-"),(.reviews.totalCount|tostring)]|@tsv]|join("\n")' 2>&1 |
    sed -n 's/^[[:space:]]*body:[[:space:]]*//p' | jq -r .) ||
    fail "gh-axi ($GH_AXI_VERSION) could not POST the GraphQL read"
  case $posted in
    "pr	"*) ;;
    *) fail "the live GraphQL POST decoded to '$posted', not the pr record the collector shapes" ;;
  esac
  # __typename is what marks an automation account whose login carries no [bot]
  # suffix, so the field has to still be selectable.
  case $posted in
    *"	User	"* | *"	Bot	"* | *"	Organization	"* | *"	Mannequin	"* | *"	EnterpriseUserAccount	"*) ;;
    *) fail "the live GraphQL POST returned no author __typename in '$posted'; automation accounts would stop being marked" ;;
  esac
  pass "the live GraphQL read returns the collector's own shaped record under an explicit POST, __typename included"
}

test_a_live_review_produces_the_fixed_report_and_a_matching_model() {
  local report model
  report=$ROOT_DIR/report.md
  model=$ROOT_DIR/model.json
  # A fixed historical window, not a rolling one. What this case proves is that a
  # live collection still reads real work; a quiet month upstream is not a defect
  # in this repository, and a window whose counts are already settled cannot
  # become one. jq 1.8.0 shipped inside this window, so the work is there.
  "$REVIEW" "$ESTATE/$REPO" "${WINDOW[@]}" > "$report" ||
    fail "a live review of $ESTATE/$REPO failed"
  "$REVIEW" "$ESTATE/$REPO" "${WINDOW[@]}" --json > "$model" ||
    fail "a live review of $ESTATE/$REPO could not produce its model"

  local seen expected
  seen=$(grep '^## ' "$report")
  expected=$(printf '%s\n' \
    "## 1. Scope and method" "## 2. Headline" "## 3. Who did what" "## 4. Velocity" \
    "## 5. Quality" "## 6. Risk and concentration" "## 7. Per-repository detail" \
    "## 8. What these numbers do not measure" "## 9. Collection log")
  [ "$seen" = "$expected" ] || fail "a live report's sections are not the fixed nine in order; got:
$seen"

  jq -e '.contract == "xo-estate-review.v1"' "$model" > /dev/null ||
    fail "the live model does not carry the xo-estate-review.v1 contract"
  jq -e '.selection.reviewed == 1' "$model" > /dev/null ||
    fail "the $ESTATE/$REPO scope did not bound the live review to one repository"
  jq -e '[.unread[]] | length == 0' "$model" > /dev/null ||
    fail "the live review reported a gap: $(jq -c '.unread' "$model")"

  # This window's work is history and cannot go away. A live review that read
  # cleanly and still found nothing in it means the collection stopped working,
  # which is the failure a fake can never show.
  jq -e '.quality.commits.total > 0' "$model" > /dev/null ||
    fail "the live review read no commit at all from $ESTATE/$REPO in the pinned window"
  jq -e '[.repositories[].pull_requests.merged] | add > 0' "$model" > /dev/null ||
    fail "the live review read no merged pull request from $ESTATE/$REPO in the pinned window"
  jq -e '(.people | length) > 0' "$model" > /dev/null ||
    fail "the live review attributed no work to any account"
  pass "a live review of $ESTATE/$REPO over a settled historical window emits the fixed nine sections and a model carrying real commits, merges, and accounts"
}

test_the_real_gh_axi_envelope_still_carries_a_shaped_payload
test_the_real_graphql_read_needs_an_explicit_post
test_a_live_review_produces_the_fixed_report_and_a_matching_model

echo "# xo-estate-review-live-e2e.test.sh: all assertions passed"
