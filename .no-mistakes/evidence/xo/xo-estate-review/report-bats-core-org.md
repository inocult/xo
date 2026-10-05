# Estate review: bats-core

- Estate: organization `bats-core`
- Window: 2026-07-07T00:00:00Z to 2026-10-05T00:00:00Z (90 days, 6 periods of 15 days)
- Repositories: 6 matched the selection, 6 reviewed, 6 read completely, 0 read with at least one gap
- Generated: 2026-10-05T19:52:36Z by `estate-review.sh`, report contract `xo-estate-review.v1`

## 1. Scope and method

This report has a fixed shape.
The same nine sections appear in the same order for every estate, and a section with no data says so rather than disappearing.
Two reports of the same estate are therefore comparable line for line, and section 9 names the read every figure came from.

Selection: forks excluded, archived repositories included and labelled, at most 100 repositories.
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
| Pull requests merged | 33 | pull requests | rising |
| Cycle time, first commit to merge | 38.6 | hours (median) | flat |
| Merged pull requests reviewed by another account | 87.9 | percent | not tracked over periods |
| Continuous integration latest-attempt pass rate | 73.1 | percent | not tracked over periods |
| Repositories where one account authored over half the commits | 1 | repositories | not tracked over periods |

A rising cycle time means work is getting slower; a rising merged count means more is landing.

## 3. Who did what

### 3.1 Contribution by person

Sorted by account name, never by volume.
This table is a record of participation, not a ranking, and the counts carry no judgement about anyone's effort, difficulty of work, or worth.

| Account | Automation, at collection | Commits | Pull requests opened | Pull requests merged | Reviews submitted | Pull requests reviewed | Repositories touched |
| --- | --- | --- | --- | --- | --- | --- | --- |
| VXNCXNX | no | 1 | 1 | 1 | 0 | 0 | 1 |
| Wuodan | no | 15 | 16 | 9 | 8 | 5 | 3 |
| akinomyoga | no | 1 | 0 | 1 | 0 | 0 | 1 |
| aprylewu | no | 5 | 2 | 2 | 0 | 0 | 1 |
| brokenpip3 | no | 0 | 0 | 0 | 2 | 2 | 1 |
| copilot-pull-request-reviewer | yes | 0 | 0 | 0 | 2 | 2 | 1 |
| darettau | no | 4 | 1 | 1 | 0 | 0 | 1 |
| dependabot | yes | 8 | 28 | 9 | 0 | 0 | 2 |
| fzlzjerry | no | 2 | 1 | 1 | 0 | 0 | 1 |
| hcartiaux | no | 0 | 0 | 1 | 0 | 0 | 1 |
| henning-schild | no | 0 | 1 | 0 | 0 | 0 | 1 |
| kolyshkin | no | 2 | 3 | 1 | 0 | 0 | 1 |
| martin-schulze-vireso | no | 8 | 6 | 4 | 31 | 29 | 1 |
| mvanhorn | no | 0 | 0 | 1 | 0 | 0 | 1 |
| natejswenson | no | 2 | 1 | 1 | 0 | 0 | 1 |
| sb123sb123 | no | 0 | 1 | 0 | 0 | 0 | 1 |
| vjymisal0 | no | 2 | 1 | 1 | 0 | 0 | 1 |
| yogch | no | 0 | 1 | 0 | 0 | 0 | 1 |

Automation accounts in this table: 2 of 18.

### 3.2 Review participation

Reviews given matter as much as authorship and are the half most tooling drops, so they get their own section whether or not the estate has any.

| Account | Automation, at collection | Reviews submitted | Pull requests reviewed |
| --- | --- | --- | --- |
| Wuodan | no | 8 | 5 |
| brokenpip3 | no | 2 | 2 |
| copilot-pull-request-reviewer | yes | 2 | 2 |
| martin-schulze-vireso | no | 31 | 29 |

29 of 33 merged pull requests carried a review by an account other than the author (87.9%).

## 4. Velocity

### 4.1 Throughput

Each period is 15 days; the earliest period begins at the window start.

| Period beginning | 2026-07-07 | 2026-07-22 | 2026-08-06 | 2026-08-21 | 2026-09-05 | 2026-09-20 | Direction |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Commits authored | 11 | 7 | 4 | 0 | 16 | 12 | rising |
| Pull requests opened | 11 | 13 | 8 | 2 | 21 | 8 | falling |
| Pull requests merged | 7 | 9 | 0 | 0 | 9 | 8 | rising |

Direction compares the last period against the mean of the earlier ones.

### 4.2 Cycle time, first commit to merge

- Median: 38.6 h over 33 merged pull requests
- p90: 794.6 h
- Direction: flat (rising means slower)
- Unmeasurable: 0 merged pull requests had no readable first commit

| Period beginning | 2026-07-07 | 2026-07-22 | 2026-08-06 | 2026-08-21 | 2026-09-05 | 2026-09-20 |
| --- | --- | --- | --- | --- | --- | --- |
| Median hours | 20.5 | 38.4 | not measurable | not measurable | 65.6 | 43.4 |

### 4.3 Review latency, opened to first review by another account

- Median: 52.8 h over 29 merged pull requests
- p90: 899.4 h
- Direction: falling (rising means longer waits)
- Not included: 4 merged pull requests had no review from another account

| Period beginning | 2026-07-07 | 2026-07-22 | 2026-08-06 | 2026-08-21 | 2026-09-05 | 2026-09-20 |
| --- | --- | --- | --- | --- | --- | --- |
| Median hours | 2587.8 | 38.5 | not measurable | not measurable | 60.5 | 54.4 |

## 5. Quality

Each figure below says what it evidences and what it does not.
A quality signal that is presented without that boundary invites a conclusion the data cannot carry.

### 5.1 Reverts and hotfixes

- Reverts: 0 of 50 authored commits (0%)
- Hotfixes: 0 of 50 authored commits (0%)

This counts what the estate labelled.
It evidences how often the estate itself declared a change wrong; it does not evidence the defect rate, because a fix that was never called a revert or a hotfix is invisible here.

### 5.2 Change size

- Median merged pull request: 8 lines changed
- p90 merged pull request: 98 lines changed

| Lines changed | Merged pull requests |
| --- | --- |
| under 10 | 17 |
| 10 to 49 | 7 |
| 50 to 249 | 8 |
| 250 to 999 | 1 |
| 1000 or more | 0 |

Size evidences how much a reviewer was asked to hold at once.
It does not evidence difficulty or risk: a one-line change can be the dangerous one, and a large generated diff can be trivial.

### 5.3 Review depth

- Merged pull requests reviewed by another account: 29 of 33 (87.9%)
- Median review threads per merged pull request: 0
- Total review threads on merged pull requests: 7

Thread count evidences how much conversation a change drew.
It does not evidence how carefully anything was read: a correct change reviewed closely can draw no comment at all.

### 5.4 Continuous integration latest-attempt pass rate

- Latest-attempt pass rate: 73.1% (283 passed, 104 failed)
- Inconclusive runs excluded from the rate: 45
- Checks that needed more than one attempt on the same commit: 58

This evidences how a check ended up, not how it started: the runs list reports each run's latest attempt, so a check that failed and was re-run to green on the same commit counts as a pass here.
It cannot separate a real defect from a flaky job, and it sees only GitHub Actions: checks reported by any other system are invisible to it.
The attempt count says only that a check on that commit was attempted more than once; it does not say why.

## 6. Risk and concentration

### 6.1 Knowledge concentration

- Accounts that authored commits: 11
- Accounts covering half the estate's authored commits: 3
- Largest single share: Wuodan at 30%

Repositories where one account authored more than half the commits in this window: 1.

| Repository | Account | Share | Authors | Authored commits |
| --- | --- | --- | --- | --- |
| bats-core/bats-detik | Wuodan | 100% | 1 | 2 |

This evidences where the estate's recorded history sits with one account.
It does not evidence who understands what: someone who reviewed every change may hold the knowledge without a commit to show for it.

### 6.2 Unmaintained repositories, as at collection

Repositories archived, never pushed to, or unpushed for 180 days or more as at 2026-10-05T19:52:36Z: 3.

| Repository | Days since last push, at collection | Archived, at collection | Commits in window |
| --- | --- | --- | --- |
| bats-core/bats-backports | 1595 | no | 0 |
| bats-core/.github | 343 | no | 0 |
| bats-core/bats-vscode | 315 | no | 0 |

### 6.3 Stalled work, as at collection

Like section 6.2 and unlike the sections before it, this subsection is the state of the estate when this review collected rather than a quantity inside the window: what is open now, and how long it has been sitting as at 2026-10-05T19:52:36Z.

- Open pull requests: 40
- Open issues: 108

Open pull requests idle for 14 days or more: 27, longest idle first.

| Repository | Number | Idle days, at collection | Age days, at collection | Author | Draft, at collection | Title |
| --- | --- | --- | --- | --- | --- | --- |
| bats-core/bats-core | 275 | 1728 | 2366 | andrewfowlie | no | add todo and done features |
| bats-core/bats-core | 968 | 792 | 792 | edsantiago | no | WIP: Export and document two new envariables to tests: |
| bats-core/bats-core | 882 | 751 | 942 | soda480 | no | Add variable to track bats call arguments |
| bats-core/bats-core | 196 | 746 | 2771 | cyphar | no | bats: add support for deteriministic --shuffle |
| bats-core/bats-core | 1133 | 359 | 410 | jasonkarns | yes | Remove files handled by .github repo |
| bats-core/.github | 8 | 358 | 411 | dependabot | no | Bump actions/setup-node from 3 to 4 |
| bats-core/.github | 10 | 358 | 398 | dependabot | no | Bump actions/checkout from 3 to 5 |
| bats-core/bats-core | 826 | 356 | 1028 | cyphar | yes | parallel: drop --keep-order to stream test output with -j |
| bats-core/.github | 12 | 336 | 370 | dependabot | no | Bump step-security/harden-runner from 2.13.0 to 2.13.1 |
| bats-core/.github | 13 | 315 | 350 | dependabot | no | Bump ossf/scorecard-action from 2.4.2 to 2.4.3 |
| bats-core/.github | 14 | 308 | 343 | dependabot | no | Bump actions/dependency-review-action from 4.7.1 to 4.8.1 |
| bats-core/bats-core | 1167 | 305 | 336 | dependabot | no | build(deps): bump github/codeql-action from 4.30.8 to 4.31.2 |
| bats-core/bats-core | 1179 | 299 | 299 | giner | no | Add more tests |
| bats-core/bats-core | 1193 | 231 | 231 | martin-schulze-vireso | no | feat: detect collisions of other functions with test |
| bats-core/bats-core | 1194 | 228 | 230 | jzacsh | no | fix missing linebreaks on bootstrap errors for BATS_TMPDIR |

12 further pull requests are in this report's model but not listed above; `--json` prints the model, which carries every one of them.

## 7. Per-repository detail

One row per reviewed repository, sorted by name.
An organization review is this table plus the aggregate above; a single-repository review is the same report with one row here.

| Repository | Commits | Merged | Open now, at collection | Median cycle | Reviewed | Latest-attempt CI | Authors | Idle days, at collection | Archived, at collection | Gaps, at collection |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| bats-core/.github | 0 | 0 | 7 | not measurable | not measurable | not measurable | 0 | 343 | no | none |
| bats-core/bats-backports | 0 | 0 | 0 | not measurable | not measurable | not measurable | 0 | 1595 | no | none |
| bats-core/bats-core | 80 | 31 | 28 | 38.6 h | 87.1% | 72.5% | 11 | 9 | no | none |
| bats-core/bats-detik | 4 | 2 | 0 | 2.7 h | 100% | 100% | 1 | 16 | no | none |
| bats-core/bats-vscode | 0 | 0 | 0 | not measurable | not measurable | not measurable | 0 | 315 | no | none |
| bats-core/homebrew-bats-core | 0 | 0 | 5 | not measurable | not measurable | 78.6% | 0 | 7 | no | none |

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

- `gh-axi api /orgs/bats-core/repos?type=all&sort=full_name --paginate`
- `gh-axi api /repos/<owner>/<repo>/commits?sha=<default_branch>&since=2026-07-07T00:00:00Z&until=2026-10-05T00:00:00Z --paginate`
- `gh-axi api POST graphql --input <pull-requests-updated-desc-until-2026-07-07T00:00:00Z>`
- `gh-axi api POST graphql --input <open-pull-requests-created-asc>`
- `gh-axi api /repos/<owner>/<repo>/actions/runs?event=pull_request&created=2026-07-07..2026-10-05 --paginate`
- `gh-axi api /repos/<owner>/<repo>/issues?state=open --paginate`

### 9.2 What was read

| Repository | Commits | Pull requests | Open pull requests | CI runs | Issues |
| --- | --- | --- | --- | --- | --- |
| bats-core/.github | read | read | read | read | read |
| bats-core/bats-backports | read | read | read | read | read |
| bats-core/bats-core | read | read | read | read | read |
| bats-core/bats-detik | read | read | read | read | read |
| bats-core/bats-vscode | read | read | read | read | read |
| bats-core/homebrew-bats-core | read | read | read | read | read |

No read this report uses failed: every reviewed repository answered every one of them.

No read hit a collection cap.

