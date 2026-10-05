# Estate review: jqlang/jq

- Estate: repository `jqlang/jq`
- Window: 2026-09-29T00:00:00Z to 2026-10-05T00:00:00Z (6 days, 6 periods of 1 days)
- Repositories: 1 matched the selection, 1 reviewed, 0 read completely, 1 read with at least one gap
- Generated: 2026-10-05T19:56:59Z by `estate-review.sh`, report contract `xo-estate-review.v1`

## 1. Scope and method

This report has a fixed shape.
The same nine sections appear in the same order for every estate, and a section with no data says so rather than disappearing.
Two reports of the same estate are therefore comparable line for line, and section 9 names the read every figure came from.

Selection: forks included, archived repositories included and labelled, at most 100 repositories.
Thresholds: an open pull request idle for 14 days or more is stalled; a repository unpushed for 180 days or more is unmaintained; the trend band section 4.1 reports a direction outside is 15%.
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
| Pull requests merged | 3 | pull requests | falling |
| Cycle time, first commit to merge | 0 | hours (median) | not reported: the last period has no measurement |
| Merged pull requests reviewed by another account | 66.7 | percent | not tracked over periods |
| Continuous integration latest-attempt pass rate | 94.5 | percent | not tracked over periods |
| Repositories where one account authored over half the commits | 1 | repositories | not tracked over periods |

A rising cycle time means work is getting slower; a rising merged count means more is landing.

## 3. Who did what

### 3.1 Contribution by person

Sorted by account name, never by volume.
This table is a record of participation, not a ranking, and the counts carry no judgement about anyone's effort, difficulty of work, or worth.

| Account | Automation, at collection | Commits | Pull requests opened | Pull requests merged | Reviews submitted | Pull requests reviewed | Repositories touched |
| --- | --- | --- | --- | --- | --- | --- | --- |
| HarmfulBreeze | no | 0 | 1 | 0 | 0 | 0 | 1 |
| MbappeWU | no | 0 | 1 | 0 | 0 | 0 | 1 |
| Pandapip1 | no | 0 | 0 | 0 | 2 | 1 | 1 |
| christf | no | 0 | 0 | 0 | 1 | 1 | 1 |
| davidscottpope-gif | no | 0 | 1 | 0 | 0 | 0 | 1 |
| dependabot | yes | 2 | 2 | 2 | 0 | 0 | 1 |
| itchyny | no | 1 | 1 | 1 | 2 | 2 | 1 |
| mikamikasuki | no | 0 | 1 | 0 | 0 | 0 | 1 |
| mvanslobbe | no | 0 | 1 | 0 | 0 | 0 | 1 |
| owenthereal | no | 0 | 0 | 0 | 5 | 5 | 1 |
| wader | no | 0 | 0 | 0 | 1 | 1 | 1 |

Automation accounts in this table: 1 of 11.

### 3.2 Review participation

Reviews given matter as much as authorship and are the half most tooling drops, so they get their own section whether or not the estate has any.

| Account | Automation, at collection | Reviews submitted | Pull requests reviewed |
| --- | --- | --- | --- |
| Pandapip1 | no | 2 | 1 |
| christf | no | 1 | 1 |
| itchyny | no | 2 | 2 |
| owenthereal | no | 5 | 5 |
| wader | no | 1 | 1 |

2 of 3 merged pull requests carried a review by an account other than the author (66.7%).

## 4. Velocity

### 4.1 Throughput

Each period is 1 days; the earliest period begins at the window start.

| Period beginning | 2026-09-29 | 2026-09-30 | 2026-10-01 | 2026-10-02 | 2026-10-03 | 2026-10-04 | Direction |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Commits authored | 0 | 0 | 3 | 0 | 0 | 0 | falling |
| Pull requests opened | 1 | 1 | 4 | 0 | 1 | 1 | falling |
| Pull requests merged | 0 | 0 | 3 | 0 | 0 | 0 | falling |

Direction compares the last period against the mean of the earlier ones.

### 4.2 Cycle time, first commit to merge

- Median: 0 h over 3 merged pull requests
- p90: 0.2 h
- Direction: not reported, because the last period has no measurement; periods beginning 2026-09-29, 2026-09-30, 2026-10-02, 2026-10-03, 2026-10-04 had none
- Unmeasurable: 0 merged pull requests had no readable first commit

| Period beginning | 2026-09-29 | 2026-09-30 | 2026-10-01 | 2026-10-02 | 2026-10-03 | 2026-10-04 |
| --- | --- | --- | --- | --- | --- | --- |
| Median hours | not measurable | not measurable | 0 | not measurable | not measurable | not measurable |

### 4.3 Review latency, opened to first review by another account

- Median: 0 h over 2 merged pull requests
- p90: 0 h
- Direction: not reported, because the last period has no measurement; periods beginning 2026-09-29, 2026-09-30, 2026-10-02, 2026-10-03, 2026-10-04 had none
- Not included: 1 merged pull request had no review from another account

| Period beginning | 2026-09-29 | 2026-09-30 | 2026-10-01 | 2026-10-02 | 2026-10-03 | 2026-10-04 |
| --- | --- | --- | --- | --- | --- | --- |
| Median hours | not measurable | not measurable | 0 | not measurable | not measurable | not measurable |

## 5. Quality

Each figure below says what it evidences and what it does not.
A quality signal that is presented without that boundary invites a conclusion the data cannot carry.

### 5.1 Reverts and hotfixes

- Reverts: 0 of 3 authored commits (0%)
- Hotfixes: 0 of 3 authored commits (0%)

This counts what the estate labelled.
It evidences how often the estate itself declared a change wrong; it does not evidence the defect rate, because a fix that was never called a revert or a hotfix is invisible here.

### 5.2 Change size

- Median merged pull request: 8 lines changed
- p90 merged pull request: 354 lines changed

| Lines changed | Merged pull requests |
| --- | --- |
| under 10 | 2 |
| 10 to 49 | 0 |
| 50 to 249 | 0 |
| 250 to 999 | 1 |
| 1000 or more | 0 |

Size evidences how much a reviewer was asked to hold at once.
It does not evidence difficulty or risk: a one-line change can be the dangerous one, and a large generated diff can be trivial.

### 5.3 Review depth

- Merged pull requests reviewed by another account: 2 of 3 (66.7%)
- Median review threads per merged pull request: 0
- Total review threads on merged pull requests: 0

Thread count evidences how much conversation a change drew.
It does not evidence how carefully anything was read: a correct change reviewed closely can draw no comment at all.

### 5.4 Continuous integration latest-attempt pass rate

- Latest-attempt pass rate: 94.5% (52 passed, 3 failed)
- Inconclusive runs excluded from the rate: 0
- Checks that needed more than one attempt on the same commit: 0

This evidences how a check ended up, not how it started: the runs list reports each run's latest attempt, so a check that failed and was re-run to green on the same commit counts as a pass here.
It cannot separate a real defect from a flaky job, and it sees only GitHub Actions: checks reported by any other system are invisible to it.
The attempt count says only that a check on that commit was attempted more than once; it does not say why.

## 6. Risk and concentration

### 6.1 Knowledge concentration

- Accounts that authored commits: 2
- Accounts covering half the estate's authored commits: 1
- Largest single share: dependabot at 66.7%

Repositories where one account authored more than half the commits in this window: 1.

| Repository | Account | Share | Authors | Authored commits |
| --- | --- | --- | --- | --- |
| jqlang/jq | dependabot | 66.7% | 2 | 3 |

This evidences where the estate's recorded history sits with one account.
It does not evidence who understands what: someone who reviewed every change may hold the knowledge without a commit to show for it.

### 6.2 Unmaintained repositories, as at collection

No reviewed repository is archived, has never been pushed to, or had gone 180 days without a push when this review collected.

### 6.3 Stalled work, as at collection

Like section 6.2 and unlike the sections before it, this subsection is the state of the estate when this review collected rather than a quantity inside the window: what is open now, and how long it has been sitting as at 2026-10-05T19:56:59Z.

- Open pull requests: 106
- Open issues: 322

Open pull requests idle for 14 days or more: 88, longest idle first.

| Repository | Number | Idle days, at collection | Age days, at collection | Author | Draft, at collection | Title |
| --- | --- | --- | --- | --- | --- | --- |
| jqlang/jq | 1062 | 1220 | 3925 | pkoppstein | no | project/1, query/1 and unify/1 added to builtin.jq, with tests and documentation |
| jqlang/jq | 1767 | 1220 | 2884 | ayappanec | no | Patches for AIX |
| jqlang/jq | 1907 | 1220 | 2693 | bit2shift | no | Unify/simplify the MultiByteToWideChar() code and add wrappers for open()/stat() |
| jqlang/jq | 2241 | 1220 | 2101 | unattributed | no | Added base/1 and unbase/1 |
| jqlang/jq | 673 | 146 | 4275 | joelpurra | yes | Working module/package system |
| jqlang/jq | 1032 | 146 | 3960 | nicowilliams | no | Dump block |
| jqlang/jq | 1127 | 146 | 3835 | WaffleSouffle | no | Ignore jq.exe, fixed gcc compiler warnings for msys2 (windows). |
| jqlang/jq | 1201 | 146 | 3709 | ltrager | no | Add snap packaging support |
| jqlang/jq | 1215 | 146 | 3699 | mark-kubacki | no | Add support for seccomp |
| jqlang/jq | 1228 | 146 | 3682 | dbohdan | no | Define format in jq code |
| jqlang/jq | 1246 | 146 | 3654 | dequis | no | jv: Add some support for 64 bit ints in a very conservative way |
| jqlang/jq | 1327 | 146 | 3536 | nicowilliams | no | jv: Add some support for 64 bit ints in a very conservative way (ALTERNATIVE) |
| jqlang/jq | 1643 | 146 | 3106 | andremarianiello | no | Add mul builtin |
| jqlang/jq | 1703 | 146 | 2985 | mumoshu | no | wip: feat: terminate jq immediately after the outgoing pipe closed |
| jqlang/jq | 1726 | 146 | 2930 | jgarvin | no | Rename gen_* functions to jq_gen_* |

73 further pull requests are in this report's model but not listed above; `--json` prints the model, which carries every one of them.

## 7. Per-repository detail

One row per reviewed repository, sorted by name.
An organization review is this table plus the aggregate above; a single-repository review is the same report with one row here.

| Repository | Commits | Merged | Open now, at collection | Median cycle | Reviewed | Latest-attempt CI | Authors | Idle days, at collection | Archived, at collection | Gaps, at collection |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| jqlang/jq | 3 | 3 | 106 | 0 h | 66.7% | 94.5% | 2 | 4 | no | pull_request_reviews |

## 8. What these numbers do not measure

- They do not measure anyone's productivity, effort, skill, or value. A commit count is a count of commits.
- They do not measure difficulty. The hardest change in this window may be the smallest row in it.
- They do not measure quality of thought. Review threads count conversation, not care.
- They do not see work outside this estate's GitHub record: pairing, design, incident response, mentoring, review in chat, and work in repositories outside the selection are all absent.
- They do not attribute shared work. A pull request has one author field, whoever did the work.
- They do not establish cause. A rising cycle time is a fact to ask about, not a conclusion about anyone.
- They are bounded by the window section 1 states and by what section 9 records as read, including every read that stopped at a collection cap. A figure here describes what was collected, never the whole history.

## 9. Collection log

### 9.1 Commands

These are the templates each read was built from, one per surface, with this run's window already substituted.
They are not a transcript to paste: `<owner>/<repo>` and `<default_branch>` stand for each repository in section 7, and the two GraphQL reads name their query rather than printing its body.
Filled in that way and run against the same estate and window, they return the data every figure above was derived from.

- `gh-axi api /repos/jqlang/jq`
- `gh-axi api /repos/<owner>/<repo>/commits?sha=<default_branch>&since=2026-09-29T00:00:00Z&until=2026-10-05T00:00:00Z --paginate`
- `gh-axi api POST graphql --input <pull-requests-updated-desc-until-2026-09-29T00:00:00Z>`
- `gh-axi api POST graphql --input <open-pull-requests-created-asc>`
- `gh-axi api /repos/<owner>/<repo>/actions/runs?event=pull_request&created=2026-09-29..2026-10-05 --paginate`
- `gh-axi api /repos/<owner>/<repo>/issues?state=open --paginate`

### 9.2 What was read

| Repository | Commits | Pull requests | Open pull requests | CI runs | Issues |
| --- | --- | --- | --- | --- | --- |
| jqlang/jq | read | read | read | read | read |

No read this report uses failed: every reviewed repository answered every one of them.

Reads that hit a cap, so the figures they feed describe the collected subset rather than the whole window:

| Repository | Signal | Cap |
| --- | --- | --- |
| jqlang/jq | pull_request_reviews | 1 pull request carries more than 50 reviews; only the first 50 of each were read |

