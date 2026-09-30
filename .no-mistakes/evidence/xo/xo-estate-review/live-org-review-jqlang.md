# Estate review: jqlang

- Estate: organization `jqlang`
- Window: 2025-05-01T00:00:00Z to 2025-07-01T00:00:00Z (61 days, 3 periods of 20.33 days)
- Repositories: 5 matched the selection, 5 reviewed, 5 read completely, 0 read with at least one gap
- Generated: 2026-09-30T15:44:00Z by `xo-estate-review.sh`, report contract `xo-estate-review.v1`

## 1. Scope and method

This report has a fixed shape.
The same nine sections appear in the same order for every estate, and a section with no data says so rather than disappearing.
Two reports of the same estate are therefore comparable line for line, and section 9 names the read every figure came from.

Selection: forks excluded, archived repositories included and labelled, at most 100 repositories, at most no limit on pull requests per repository.
Thresholds: an open pull request idle for 14 days or more is stalled; a repository unpushed for 180 days or more is unmaintained; a period-over-period change beyond 15% is called rising or falling, and anything inside that band is flat.
Both of those thresholds, and every figure they select over, are measured from when this review collected rather than from inside the window, because they are facts about the estate now rather than events in it: the repository set and each default branch, the archived flag, whether an account is automation, days since last push, the open pull request and open issue counts, the stalled list with its idle and age days, and what section 9 records as read.
Rather than list where each is labelled, the rule holds everywhere: a table column carrying a figure measured that way ends its heading `at collection`, and a column carrying a figure that does not is bounded by the window. A column that names rather than measures - a repository, an account, a pull request's number or title - carries no clock. Section 9 is the exception and is collection-time throughout, because it records the reads themselves.
A direction is never drawn from a period that ended before the window did: where the last period holds no measurement, no direction is reported and the empty periods are named.
Section 6's lists show at most 15 worst-first rows and state how many there are in total; the counts are always complete even where the rows are bounded.

Definitions, which are the same in every report:

- Commits are commits on each repository's default branch that landed inside the window, counted by committer date, which is the date GitHub's own commit list filters on. Work that was rebased, amended, cherry-picked, or squashed therefore counts in the window it landed in, not the window it was written in. Merge commits are counted separately and excluded from authorship, revert, and concentration figures, because a merge is not an authored change.
- A person is a GitHub account. A commit whose author GitHub could not link to an account is attributed to `unlinked:<email>` and never merged into an account by name, because matching people by name is a guess.
- An automation account is marked as such and its counts are kept in every total, because a bot's merged pull requests really did land. The only identity GitHub reports two ways is an app's account, given as `name[bot]` by one endpoint and `name` by another; that suffix is folded so one actor is one row, and nothing else is.
- Pull requests opened, merged, and closed without merging are counted by the date of that event falling inside the window.
- Cycle time is the hours from the commit date of a merged pull request's first commit to its merge. A pull request whose first commit is unreadable is reported as unmeasurable rather than dropped.
- Review latency is the hours from a merged pull request being opened to the first review on it submitted by another identified account, no earlier than the pull request itself. Self-review is not review coverage and is excluded everywhere in this report, and so is a review whose author GitHub no longer reports.
- Change size is additions plus deletions on merged pull requests, which is the unit of change a person actually reviews.
- The revert rate is the share of authored commits whose subject opens with `Revert` or `revert` followed by a space, colon, bracket, or quote, which is the shape git's own revert subjects take; the hotfix rate is the share whose subject contains `hotfix` in any case. Both measure what the estate labels, not what actually broke.
- The continuous integration latest-attempt pass rate groups GitHub Actions pull-request runs by workflow and commit, takes the most recent run of each group, and reports the share of them that succeeded out of those that succeeded or failed. A run's conclusion is the conclusion of its latest attempt, because that is what the runs list reports; a run re-run without a new commit therefore counts here as whatever it ended up as. Succeeded means `success`; failed means `failure`, `timed_out`, or `startup_failure`. Every other conclusion is counted as inconclusive and left out of the rate entirely, which covers a cancelled or skipped run, one still going, and the rarer `neutral`, `action_required`, and `stale`.
- Accounts covering half the commits is the smallest number of accounts whose combined commits exceed half the authored commits in the window. Section 6.1 reports it for the estate; its per-repository form is not printed as a figure, and is what decides which repositories section 6.1 lists as concentrated and what the headline count of them is. Section 7's Authors column is a different figure: the number of accounts that authored any commit.
- The median is the middle value, or the mean of the two middle values where there is an even number of them; p90 is the ninetieth percentile by nearest rank.

## 2. Headline

| Measure | Value | Unit | Direction over the window |
| --- | --- | --- | --- |
| Pull requests merged | 40 | pull requests | falling |
| Cycle time, first commit to merge | 24.5 | hours (median) | rising |
| Merged pull requests reviewed by another account | 82.5 | percent | not tracked over periods |
| Continuous integration latest-attempt pass rate | not measurable | percent | not tracked over periods |
| Repositories where one account authored over half the commits | 3 | repositories | not tracked over periods |

A rising cycle time means work is getting slower; a rising merged count means more is landing.

## 3. Who did what

### 3.1 Contribution by person

Sorted by account name, never by volume.
This table is a record of participation, not a ranking, and the counts carry no judgement about anyone's effort, difficulty of work, or worth.

| Account | Automation, at collection | Commits | Pull requests opened | Pull requests merged | Reviews submitted | Pull requests reviewed | Repositories touched |
| --- | --- | --- | --- | --- | --- | --- | --- |
| ElirannKeter | no | 0 | 1 | 0 | 0 | 0 | 1 |
| Eomtaeyong820 | no | 1 | 1 | 1 | 0 | 0 | 1 |
| NemRolo | no | 1 | 0 | 0 | 0 | 0 | 1 |
| SArpnt | no | 1 | 0 | 1 | 0 | 0 | 1 |
| TheOdd | no | 1 | 1 | 1 | 0 | 0 | 1 |
| brahmlower | no | 1 | 0 | 1 | 0 | 0 | 1 |
| copilot-pull-request-reviewer | yes | 0 | 0 | 0 | 9 | 3 | 1 |
| corneliusroemer | no | 0 | 0 | 0 | 2 | 1 | 1 |
| dependabot | yes | 5 | 11 | 5 | 0 | 0 | 2 |
| github-actions | yes | 1 | 1 | 1 | 0 | 0 | 1 |
| itchyny | no | 24 | 12 | 20 | 16 | 12 | 1 |
| izroxxet | no | 0 | 1 | 0 | 0 | 0 | 1 |
| mihaigmarin | no | 1 | 1 | 1 | 0 | 0 | 1 |
| owenthereal | no | 12 | 4 | 4 | 0 | 0 | 1 |
| qianbinbin | no | 1 | 1 | 1 | 0 | 0 | 1 |
| ronmen91 | no | 0 | 1 | 1 | 0 | 0 | 1 |
| sihde | no | 1 | 1 | 1 | 0 | 0 | 1 |
| thaliaarchi | no | 1 | 0 | 1 | 2 | 1 | 1 |
| tsibley | no | 1 | 2 | 1 | 0 | 0 | 1 |
| wader | no | 2 | 0 | 0 | 24 | 19 | 1 |
| xiongbingou | no | 0 | 1 | 0 | 0 | 0 | 1 |
| yertto | no | 0 | 1 | 0 | 0 | 0 | 1 |

Automation accounts in this table: 3 of 22.

### 3.2 Review participation

Reviews given matter as much as authorship and are the half most tooling drops, so they get their own section whether or not the estate has any.

| Account | Automation, at collection | Reviews submitted | Pull requests reviewed |
| --- | --- | --- | --- |
| copilot-pull-request-reviewer | yes | 9 | 3 |
| corneliusroemer | no | 2 | 1 |
| itchyny | no | 16 | 12 |
| thaliaarchi | no | 2 | 1 |
| wader | no | 24 | 19 |

33 of 40 merged pull requests carried a review by an account other than the author (82.5%).

## 4. Velocity

### 4.1 Throughput

Each period is 20.33 days; the earliest period begins at the window start.

| Period beginning | 2025-05-01 | 2025-05-21 | 2025-06-10 | Direction |
| --- | --- | --- | --- | --- |
| Commits authored | 23 | 22 | 9 | falling |
| Pull requests opened | 15 | 16 | 9 | falling |
| Pull requests merged | 18 | 16 | 6 | falling |

Direction compares the last period against the mean of the earlier ones.

### 4.2 Cycle time, first commit to merge

- Median: 24.5 h over 40 merged pull requests
- p90: 1650.1 h
- Direction: rising (rising means slower)
- Unmeasurable: 0 merged pull requests had no readable first commit

| Period beginning | 2025-05-01 | 2025-05-21 | 2025-06-10 |
| --- | --- | --- | --- |
| Median hours | 23.9 | 9.8 | 80.3 |

### 4.3 Review latency, opened to first review by another account

- Median: 23.1 h over 33 merged pull requests
- p90: 2117 h
- Direction: falling (rising means longer waits)
- Not included: 7 merged pull requests had no review from another account

| Period beginning | 2025-05-01 | 2025-05-21 | 2025-06-10 |
| --- | --- | --- | --- |
| Median hours | 745.4 | 18.1 | 0.5 |

## 5. Quality

Each figure below says what it evidences and what it does not.
A quality signal that is presented without that boundary invites a conclusion the data cannot carry.

### 5.1 Reverts and hotfixes

- Reverts: 3 of 54 authored commits (5.6%)
- Hotfixes: 0 of 54 authored commits (0%)

This counts what the estate labelled.
It evidences how often the estate itself declared a change wrong; it does not evidence the defect rate, because a fix that was never called a revert or a hotfix is invisible here.

### 5.2 Change size

- Median merged pull request: 38 lines changed
- p90 merged pull request: 941 lines changed

| Lines changed | Merged pull requests |
| --- | --- |
| under 10 | 9 |
| 10 to 49 | 13 |
| 50 to 249 | 7 |
| 250 to 999 | 7 |
| 1000 or more | 4 |

Size evidences how much a reviewer was asked to hold at once.
It does not evidence difficulty or risk: a one-line change can be the dangerous one, and a large generated diff can be trivial.

### 5.3 Review depth

- Merged pull requests reviewed by another account: 33 of 40 (82.5%)
- Median review threads per merged pull request: 0
- Total review threads on merged pull requests: 23

Thread count evidences how much conversation a change drew.
It does not evidence how carefully anything was read: a correct change reviewed closely can draw no comment at all.

### 5.4 Continuous integration latest-attempt pass rate

No GitHub Actions pull-request run in this window, so there is no latest-attempt pass rate to report.
An estate whose checks run outside GitHub Actions will always read this way here, because this report does not see those checks.

## 6. Risk and concentration

### 6.1 Knowledge concentration

- Accounts that authored commits: 15
- Accounts covering half the estate's authored commits: 2
- Largest single share: itchyny at 44.4%

Repositories where one account authored more than half the commits in this window: 3.

| Repository | Account | Share | Authors | Authored commits |
| --- | --- | --- | --- | --- |
| jqlang/awesome-jq | NemRolo | 100% | 1 | 1 |
| jqlang/playground | owenthereal | 85.7% | 2 | 14 |
| jqlang/jq | itchyny | 61.5% | 13 | 39 |

This evidences where the estate's recorded history sits with one account.
It does not evidence who understands what: someone who reviewed every change may hold the knowledge without a commit to show for it.

### 6.2 Unmaintained repositories, as at collection

Repositories archived or unpushed for 180 days or more as at 2026-09-30T15:44:00Z: 2.

| Repository | Days since last push, at collection | Archived, at collection | Commits in window |
| --- | --- | --- | --- |
| jqlang/.github | 1198 | no | 0 |
| jqlang/bazel_rules_jq | 1057 | no | 0 |

### 6.3 Stalled work, as at collection

Like section 6.2 and unlike the sections before it, this subsection is the state of the estate when this review collected rather than a quantity inside the window: what is open now, and how long it has been sitting as at 2026-09-30T15:44:00Z.

- Open pull requests: 129
- Open issues: 336

Open pull requests idle for 14 days or more: 116, longest idle first.

| Repository | Number | Idle days, at collection | Age days, at collection | Author | Draft, at collection | Title |
| --- | --- | --- | --- | --- | --- | --- |
| jqlang/jq | 1062 | 1215 | 3920 | pkoppstein | no | project/1, query/1 and unify/1 added to builtin.jq, with tests and documentation |
| jqlang/jq | 1767 | 1215 | 2879 | ayappanec | no | Patches for AIX |
| jqlang/jq | 1907 | 1215 | 2688 | bit2shift | no | Unify/simplify the MultiByteToWideChar() code and add wrappers for open()/stat() |
| jqlang/jq | 2241 | 1215 | 2096 | unattributed | no | Added base/1 and unbase/1 |
| jqlang/awesome-jq | 47 | 737 | 737 | loggerhead | no | add JSON For You |
| jqlang/playground | 224 | 254 | 617 | owenthereal | no | Improve repository with various enhancements |
| jqlang/playground | 280 | 254 | 429 | ThisIsMissEm | no | Replace prisma with sqlite, remove sentry |
| jqlang/jq | 673 | 141 | 4270 | joelpurra | yes | Working module/package system |
| jqlang/jq | 1032 | 141 | 3955 | nicowilliams | no | Dump block |
| jqlang/jq | 1127 | 141 | 3829 | WaffleSouffle | no | Ignore jq.exe, fixed gcc compiler warnings for msys2 (windows). |
| jqlang/jq | 1201 | 141 | 3703 | ltrager | no | Add snap packaging support |
| jqlang/jq | 1215 | 141 | 3693 | mark-kubacki | no | Add support for seccomp |
| jqlang/jq | 1228 | 141 | 3677 | dbohdan | no | Define format in jq code |
| jqlang/jq | 1246 | 141 | 3649 | dequis | no | jv: Add some support for 64 bit ints in a very conservative way |
| jqlang/jq | 1327 | 141 | 3531 | nicowilliams | no | jv: Add some support for 64 bit ints in a very conservative way (ALTERNATIVE) |

101 further pull requests are in this report's model but not listed above; raise `--max-listed` to see them, either on a fresh run or on this report's model with `--from-json`.

## 7. Per-repository detail

One row per reviewed repository, sorted by name.
An organization review is this table plus the aggregate above; a single-repository review is the same report with one row here.

| Repository | Commits | Merged | Open now, at collection | Median cycle | Reviewed | Latest-attempt CI | Authors | Idle days, at collection | Archived, at collection | Gaps, at collection |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| jqlang/.github | 0 | 0 | 0 | not measurable | not measurable | not measurable | 0 | 1198 | no | none |
| jqlang/awesome-jq | 2 | 1 | 7 | 0.3 h | 0% | not measurable | 1 | 44 | no | none |
| jqlang/bazel_rules_jq | 0 | 0 | 0 | not measurable | not measurable | not measurable | 0 | 1057 | no | none |
| jqlang/jq | 39 | 33 | 102 | 27.2 h | 90.9% | not measurable | 13 | 3 | no | none |
| jqlang/playground | 14 | 6 | 20 | 1.1 h | 50% | not measurable | 2 | 19 | no | none |

## 8. What these numbers do not measure

- They do not measure anyone's productivity, effort, skill, or value. A commit count is a count of commits.
- They do not measure difficulty. The hardest change in this window may be the smallest row in it.
- They do not measure quality of thought. Review threads count conversation, not care.
- They do not see work outside this estate's GitHub record: pairing, design, incident response, mentoring, review in chat, and work in repositories outside the selection are all absent.
- They do not attribute shared work. A pull request has one author field, whoever did the work.
- They do not establish cause. A rising cycle time is a fact to ask about, not a conclusion about anyone.
- They are bounded by the window and the caps in section 1. A figure here describes what was collected, never the whole history.

## 9. Collection log

### 9.1 Commands

These are the templates each read was built from, one per surface, with this run's window already substituted.
They are not a transcript to paste: `<owner>/<repo>` and `<default_branch>` stand for each repository in section 7, and the two GraphQL reads name their query rather than printing its body.
Filled in that way and run against the same estate and window, they return the data every figure above was derived from.

- `gh-axi api /orgs/jqlang/repos?type=all&sort=full_name --paginate`
- `gh-axi api /repos/<owner>/<repo>/commits?sha=<default_branch>&since=2025-05-01T00:00:00Z&until=2025-07-01T00:00:00Z --paginate`
- `gh-axi api POST graphql --input <pull-requests-updated-desc-until-2025-05-01T00:00:00Z>`
- `gh-axi api POST graphql --input <open-pull-requests-created-asc>`
- `gh-axi api /repos/<owner>/<repo>/actions/runs?event=pull_request&created=2025-05-01..2025-07-01 --paginate`
- `gh-axi api /repos/<owner>/<repo>/issues?state=open --paginate`

### 9.2 What was read

| Repository | Commits | Pull requests | Open pull requests | CI runs | Issues |
| --- | --- | --- | --- | --- | --- |
| jqlang/.github | read | read | read | read | read |
| jqlang/awesome-jq | read | read | read | read | read |
| jqlang/bazel_rules_jq | read | read | read | read | read |
| jqlang/jq | read | read | read | read | read |
| jqlang/playground | read | read | read | read | read |

Every reviewed repository was read completely for every signal this report uses.

Reads that hit a cap, so the figures they feed describe the collected subset rather than the whole window:

| Repository | Signal | Cap |
| --- | --- | --- |
| jqlang/jq | pull_requests | 1 pull requests carry more than 50 reviews; only the first 50 of each were read |
| jqlang/jq | open_pull_requests | 1 pull requests carry more than 50 reviews; only the first 50 of each were read |

