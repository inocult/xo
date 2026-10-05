# estate-review reference

Mechanics behind `scripts/estate-review.sh`.
The script's `--help` lists the flags; this file holds everything a maintainer needs that a reader of a report does not.

The script references nothing outside this skill directory: `gh-axi` and `jq` on PATH are its only requirements and it writes only inside a temporary directory it creates.
`SKILL.md` additionally documents what it expects from the harness invoking it, under Host expectations.

## Contents

1. [What an estate is](#1-what-an-estate-is)
2. [The fixed constants and why each one exists](#2-the-fixed-constants-and-why-each-one-exists)
3. [Collection bounds, per walk](#3-collection-bounds-per-walk)
4. [Caps, and which figures each one bounds](#4-caps-and-which-figures-each-one-bounds)
5. [Which clock every figure is measured against](#5-which-clock-every-figure-is-measured-against)
6. [The report's sections](#6-the-reports-sections)
7. [The model contract](#7-the-model-contract)
8. [Data sources, and what each figure does not evidence](#8-data-sources-and-what-each-figure-does-not-evidence)
9. [The gh-axi envelope coupling](#9-the-gh-axi-envelope-coupling)
10. [What the review never does](#10-what-the-review-never-does)

## 1. What an estate is

A GitHub organization, reviewed across every repository it owns, or a single `owner/repo`.
An organization review is the per-repository review plus an aggregate; a single-repository review is the same report with one repository in it.
An owner GitHub reports as anything but an organization is refused with the type it reported.

Forks are excluded from an organization's listing and reviewed when named directly, because a repository someone names explicitly is one they meant.
Archived repositories are reviewed and labelled as archived.
Neither is a setting: both are the fixed behaviour of `collect`, and the report states the selection it actually performed rather than reading a value that could drift from it.

## 2. The fixed constants and why each one exists

Only the collection window is chosen per run, through `--since`, `--until` and `--window`.
Every other setting is fixed, because a report whose value is that two of them are comparable must not offer ways to make two of them differ for a reason their reader cannot see.
Each value below is a lever: editing it is the supported way to change what it bounds.

| Constant | Value | What it bounds | Why this value |
| --- | --- | --- | --- |
| `WINDOW_DAYS` | 90 | the window when `--since` is absent | a quarter is the shortest span in which a trend over six periods is not noise |
| `PERIODS` | 6 | equal periods the window splits into for the trend | the fewest that still shows a direction rather than a before-and-after pair |
| `STALLED_DAYS` | 14 | an open pull request idle this long is stalled | two weeks is long enough that a reviewer's holiday is not a finding |
| `UNMAINTAINED_DAYS` | 180 | a repository unpushed this long is unmaintained | half a year outlasts a quiet but living release cycle |
| `MAX_REPOS` | 100 | repositories reviewed | past this an organization review stops being readable in one sitting |
| `MAX_PRS` | 300 | pull requests counted per repository | enough to cover a busy quarter without a walk that outlives the reader's patience |
| `MAX_LISTED` | 15 | rows shown per risk list | the model keeps every row; only the report is bounded |
| `REST_PER_PAGE` | 100 | items per REST page | GitHub's maximum, so the walk makes the fewest requests |
| `REST_MAX_PAGES` | 30 | REST pages per read | 3,000 commits, runs or issues in one window is past where another page changes a conclusion |
| `PR_PAGE_SIZE` | 50 | pull requests per GraphQL page | a page this size stays inside GitHub's point budget with reviews attached |
| `MAX_PR_PAGES` | 40 | GraphQL pages per pull-request walk | bounds a walk over a historical window that would otherwise page without end |
| `REVIEWS_PER_PR` | 50 | reviews read per pull request | past this the review count is a crowd rather than a signal |

A window shorter than `PERIODS` days is refused, naming the minimum, because sub-day periods would label two periods with the same date.

## 3. Collection bounds, per walk

Each repository gets two pull-request walks and they are bounded separately.

The window walk reads `UPDATED_AT DESC` from the present and stops at the first page whose oldest record predates the window.
It spends `MAX_PRS` only on pull requests updated before the window end, so a pull request touched after the window does not consume the budget on the way down.
That is what makes a historical window reachable: before this, the cap was spent on recent activity and a window far enough in the past reported zero merged pull requests having never reached them.

The open walk reads `CREATED_AT ASC` and is not window-bounded, because what is open is a fact about now.
It spends its own `MAX_PRS` on every record it reads.

Both walks stop at `MAX_PR_PAGES` pages.
Either bound tripping is recorded as a cap, so a zero figure never reads as "none merged" when it means "not reached".

## 4. Caps, and which figures each one bounds

A cap notice is only honest if it names the figures the cap actually shortened.
Each cap is therefore filed under the signal it bounds, and a figure carries a notice only when a cap on one of its own feeding reads tripped.

| Cap | Signal | Bounds |
| --- | --- | --- |
| window walk count or page bound | `pull_requests` | merged and opened counts, cycle time, change size, review coverage |
| open walk count or page bound | `open_pull_requests` | open and stalled counts |
| per-pull-request review page bound | `pull_request_reviews` | review counts inside a pull request, and nothing else |
| REST page bound | `commits`, `ci_runs`, `issues`, `repository_listing` | whichever of those reads hit it |

The same rule governs failed reads: a read that failed and a read that was capped both leave a gap, and neither may render as a complete read of a silent estate.
`fully_read` and `partially_read` count a cap as not-complete for this reason.

## 5. Which clock every figure is measured against

Two clocks exist and they are not interchangeable.
The WINDOW bounds events by when they happened.
COLLECTION is when the estate was read, overridable with `XO_ESTATE_REVIEW_NOW` as an ISO 8601 UTC instant and printed as the report's Generated line.

An event has a date and belongs to the window.
A state - what is open, what has been pushed, what is archived - is only true as of the read, so measuring it against the window end would produce a negative age on any window that ended before today.

| Figure | Clock |
| --- | --- |
| repositories matched, reviewed, read; generated at | collection |
| window since, until, days, periods | window |
| headline merged, cycle time, reviewed share, CI rate, concentrated repositories | window |
| person commits, opened, merged, reviews submitted, pull requests reviewed | window |
| automation flag | collection |
| per-period commit, opened, merged tallies | window |
| cycle time and review latency statistics | window |
| reverts, hotfixes and their denominator | window |
| change size and its distribution | window |
| review coverage and review threads | window |
| CI runs, pass rate, attempts | window |
| concentration, accounts covering half | window |
| days since last push, archived flag | collection |
| open pull request and open issue counts | collection |
| stalled set, its idle and age days, draft flag | collection |
| read statuses and the gaps they leave | collection |
| repository set, default branch, caps, recorded commands | collection |

The stalled and unmaintained lists are collection-time throughout: the set is what GitHub reports open or unpushed when the read runs, so their ages are measured from the same read, and their sections say so rather than sitting unlabelled beside the window figures.

## 6. The report's sections

Nine sections in this order, every run, every estate.
A surface with no data states that it is empty rather than disappearing, because a missing section and an empty section read identically to a human and only one of them is honest.

1. Scope and method - the window, the thresholds, the selection
2. Headline
3. Who did what - 3.1 Contribution by person, 3.2 Review participation
4. Velocity - 4.1 throughput, 4.2 cycle time, 4.3 review latency
5. Quality - 5.1 reverts and hotfixes, 5.2 change size, 5.3 review depth, 5.4 CI
6. Risk and concentration - 6.1 Knowledge concentration, 6.2 Unmaintained repositories, 6.3 Stalled work
7. Per-repository detail
8. What these numbers do not measure
9. Collection log - 9.1 commands, 9.2 what was read

Section 1 carries the window, the thresholds and the selection.
It does not narrate collection mechanics; those live in this file and in `--help`.

## 7. The model contract

`xo-estate-review.v1`.
`--json` prints the derived model; `--from-json` renders a report from a stored one, making no network call.

The model carries every number the report prints, so the renderer performs no arithmetic and a model and its report cannot disagree.
Rendering the same model twice is byte-identical, which is what makes a stored model a fixed input rather than a snapshot of one machine.

Only `--json` is honoured beside `--from-json`.
`--since`, `--until` and `--window` are refused by name, because the window is already cut into the stored model's per-period tallies and a different one needs a fresh collection.

## 8. Data sources, and what each figure does not evidence

- `gh-axi api` - repository metadata, commits on the default branch, open issues, GitHub Actions workflow runs.
- `gh-axi api POST graphql` - pull requests with their reviews and review threads.

No figure is estimated or extrapolated.
A surface the estate does not expose is reported as not exposed, and every collection bound a run hit is named in section 9.2 rather than quietly shortening a figure.

What the numbers cannot see: difficulty, pairing, design work, mentoring, incident response, and review that happened in chat.
A revert rate counts reverts, not mistakes.
A review count counts submissions, not the attention in them.
Section 8 of every report states these limits in writing.

## 9. The gh-axi envelope coupling

gh-axi renders every response for an agent to read, so the script asks for a shaped tab-separated payload with `--jq` and decodes the one rendered envelope field that carries it.
Returning a JSON document from `--jq` is not an option: gh-axi recognizes and re-renders it, so the payload would stop being a payload.
Tab-separated records are the one shape that survives the round trip.

That coupling lives in exactly one function, `gh_read`, which refuses loudly with the installed gh-axi version rather than degrading to empty data when the envelope is not the shape it knows.
An empty estate and an unreadable one must never read the same, because the reader acts on the difference.

Provenance, for a reader working in the XO repository this skill was written in: `tests/xo-estate-review.test.sh` there pins the decode against a fake gh-axi that applies the script's own `--jq` programs to real GitHub-shaped JSON, and `tests/xo-estate-review-live-e2e.test.sh` proves the real gh-axi still emits that envelope.
Neither is something the skill requires; a copied skill directory runs without them.

## 10. What the review never does

It observes an estate and never writes to one: no push, no comment, no label, no issue, no merge.
The only filesystem writes are inside a private temporary directory the script creates and removes.

It reports on people and stays factual about the work.
It does not rank individuals, score productivity, or infer anyone's effort or worth.
The person table is sorted by account name, never by volume, so it cannot be read as a leaderboard.
