# Estate review: digitalimpactventures

- Estate: organization `digitalimpactventures`
- Window: 2025-10-05T00:00:00Z to 2026-10-05T00:00:00Z (365 days, 6 periods of 60.83 days)
- Repositories: 4 matched the selection, 4 reviewed, 4 read completely, 0 read with at least one gap
- Generated: 2026-10-05T05:57:38Z by `estate-review.sh`, report contract `xo-estate-review.v1`

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
| Pull requests merged | 0 | pull requests | flat |
| Cycle time, first commit to merge | not measurable | hours (median) | not reported: the last period has no measurement |
| Merged pull requests reviewed by another account | not measurable | percent | not tracked over periods |
| Continuous integration latest-attempt pass rate | not measurable | percent | not tracked over periods |
| Repositories where one account authored over half the commits | 0 | repositories | not tracked over periods |

No commit, pull request, review, or workflow run in this window, so every measure above is zero or unmeasurable rather than low.

## 3. Who did what

### 3.1 Contribution by person

Sorted by account name, never by volume.
This table is a record of participation, not a ranking, and the counts carry no judgement about anyone's effort, difficulty of work, or worth.

No account committed, opened a pull request, or reviewed one in this window.

### 3.2 Review participation

Reviews given matter as much as authorship and are the half most tooling drops, so they get their own section whether or not the estate has any.

No account submitted a review of another account's pull request in this window.

Of 0 merged pull requests, 0 carried a review by another account.
That is a fact about this estate's recorded review activity, not evidence that the work went unexamined: review can happen in a channel GitHub never sees.

## 4. Velocity

### 4.1 Throughput

Each period is 60.83 days; the earliest period begins at the window start.

| Period beginning | 2025-10-05 | 2025-12-04 | 2026-02-03 | 2026-04-05 | 2026-06-05 | 2026-08-05 | Direction |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Commits authored | 0 | 0 | 0 | 0 | 0 | 0 | flat |
| Pull requests opened | 0 | 0 | 0 | 0 | 0 | 0 | flat |
| Pull requests merged | 0 | 0 | 0 | 0 | 0 | 0 | flat |

No commit or merge landed in this window.

### 4.2 Cycle time, first commit to merge

No merged pull request with a readable first commit in this window, so cycle time is unmeasurable here.
0 merged pull requests were excluded for that reason.

### 4.3 Review latency, opened to first review by another account

No merged pull request with a review from another account in this window, so review latency is unmeasurable here.
That is the same fact section 3.2 reports, stated as a waiting time rather than as coverage.

## 5. Quality

Each figure below says what it evidences and what it does not.
A quality signal that is presented without that boundary invites a conclusion the data cannot carry.

### 5.1 Reverts and hotfixes

No authored commit landed on a default branch in this window, so there is no revert or hotfix rate to report.

### 5.2 Change size

No pull request merged in this window, so there is no change-size distribution to report.

### 5.3 Review depth

No pull request merged in this window, so there is no review depth to report.

### 5.4 Continuous integration latest-attempt pass rate

No GitHub Actions pull-request run in this window, so there is no latest-attempt pass rate to report.
An estate whose checks run outside GitHub Actions will always read this way here, because this report does not see those checks.

## 6. Risk and concentration

### 6.1 Knowledge concentration

No authored commit landed in this window, so concentration is unmeasurable.

### 6.2 Unmaintained repositories, as at collection

Repositories archived, never pushed to, or unpushed for 180 days or more as at 2026-10-05T05:57:38Z: 4.

| Repository | Days since last push, at collection | Archived, at collection | Commits in window |
| --- | --- | --- | --- |
| digitalimpactventures/crtc-parser | 2305 | no | 0 |
| digitalimpactventures/mopc-doit | 1805 | no | 0 |
| digitalimpactventures/divs-website-backend | 981 | no | 0 |
| digitalimpactventures/divs-website | 969 | no | 0 |

### 6.3 Stalled work, as at collection

Like section 6.2 and unlike the sections before it, this subsection is the state of the estate when this review collected rather than a quantity inside the window: what is open now, and how long it has been sitting as at 2026-10-05T05:57:38Z.

- Open pull requests: 0
- Open issues: 0

No open pull request has been idle for 14 days or more as at collection.

## 7. Per-repository detail

One row per reviewed repository, sorted by name.
An organization review is this table plus the aggregate above; a single-repository review is the same report with one row here.

| Repository | Commits | Merged | Open now, at collection | Median cycle | Reviewed | Latest-attempt CI | Authors | Idle days, at collection | Archived, at collection | Gaps, at collection |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| digitalimpactventures/crtc-parser | 0 | 0 | 0 | not measurable | not measurable | not measurable | 0 | 2305 | no | none |
| digitalimpactventures/divs-website | 0 | 0 | 0 | not measurable | not measurable | not measurable | 0 | 969 | no | none |
| digitalimpactventures/divs-website-backend | 0 | 0 | 0 | not measurable | not measurable | not measurable | 0 | 981 | no | none |
| digitalimpactventures/mopc-doit | 0 | 0 | 0 | not measurable | not measurable | not measurable | 0 | 1805 | no | none |

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

- `gh-axi api /orgs/digitalimpactventures/repos?type=all&sort=full_name --paginate`
- `gh-axi api /repos/<owner>/<repo>/commits?sha=<default_branch>&since=2025-10-05T00:00:00Z&until=2026-10-05T00:00:00Z --paginate`
- `gh-axi api POST graphql --input <pull-requests-updated-desc-until-2025-10-05T00:00:00Z>`
- `gh-axi api POST graphql --input <open-pull-requests-created-asc>`
- `gh-axi api /repos/<owner>/<repo>/actions/runs?event=pull_request&created=2025-10-05..2026-10-05 --paginate`
- `gh-axi api /repos/<owner>/<repo>/issues?state=open --paginate`

### 9.2 What was read

| Repository | Commits | Pull requests | Open pull requests | CI runs | Issues |
| --- | --- | --- | --- | --- | --- |
| digitalimpactventures/crtc-parser | read | read | read | read | read |
| digitalimpactventures/divs-website | read | read | read | read | read |
| digitalimpactventures/divs-website-backend | read | read | read | read | read |
| digitalimpactventures/mopc-doit | read | read | read | read | read |

No read this report uses failed: every reviewed repository answered every one of them.

No read hit a collection cap.

