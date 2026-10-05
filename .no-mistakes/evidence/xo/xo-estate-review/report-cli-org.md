# Estate review: cli

- Estate: organization `cli`
- Window: 2026-07-07T00:00:00Z to 2026-10-05T00:00:00Z (90 days, 6 periods of 15 days)
- Repositories: 7 matched the selection, 7 reviewed, 6 read completely, 1 read with at least one gap
- Generated: 2026-10-05T05:25:24Z by `estate-review.sh`, report contract `xo-estate-review.v1`

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
| Pull requests merged | 164 | pull requests | falling |
| Cycle time, first commit to merge | 9.6 | hours (median) | falling |
| Merged pull requests reviewed by another account | 99.4 | percent | not tracked over periods |
| Continuous integration latest-attempt pass rate | 88.2 | percent | not tracked over periods |
| Repositories where one account authored over half the commits | 2 | repositories | not tracked over periods |

A rising cycle time means work is getting slower; a rising merged count means more is landing.

## 3. Who did what

### 3.1 Contribution by person

Sorted by account name, never by volume.
This table is a record of participation, not a ranking, and the counts carry no judgement about anyone's effort, difficulty of work, or worth.

| Account | Automation, at collection | Commits | Pull requests opened | Pull requests merged | Reviews submitted | Pull requests reviewed | Repositories touched |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 00200200 | no | 0 | 1 | 0 | 0 | 0 | 1 |
| 22elix3r | no | 0 | 1 | 0 | 0 | 0 | 1 |
| 2cs2vprhyf-creator | no | 0 | 0 | 0 | 1 | 1 | 1 |
| 9999years | no | 0 | 1 | 0 | 0 | 0 | 1 |
| Abhirup0 | no | 0 | 1 | 0 | 3 | 2 | 1 |
| AgentSmithClaw | no | 1 | 0 | 0 | 0 | 0 | 1 |
| AlexisAMZ | no | 0 | 1 | 0 | 0 | 0 | 1 |
| ArjunCodess | no | 0 | 1 | 0 | 0 | 0 | 1 |
| AshSgDe29071999 | no | 0 | 1 | 0 | 0 | 0 | 1 |
| BagToad | no | 121 | 37 | 25 | 56 | 45 | 2 |
| BlasCasale | no | 0 | 1 | 0 | 0 | 0 | 1 |
| Copilot | yes | 4 | 0 | 0 | 0 | 0 | 1 |
| DynamoIVII | no | 0 | 1 | 0 | 0 | 0 | 1 |
| HIHACK1911 | no | 0 | 1 | 0 | 0 | 0 | 1 |
| Hiro5409 | no | 0 | 1 | 0 | 0 | 0 | 1 |
| Lishkinfeld | no | 0 | 1 | 0 | 0 | 0 | 1 |
| LucasLeao18 | no | 0 | 1 | 0 | 0 | 0 | 1 |
| MaramHarsha | no | 0 | 1 | 0 | 0 | 0 | 1 |
| MingcongBai | no | 0 | 1 | 0 | 0 | 0 | 1 |
| MsfPablo | no | 0 | 2 | 0 | 0 | 0 | 1 |
| MumuTW | no | 0 | 1 | 0 | 0 | 0 | 1 |
| SCW5370 | no | 0 | 1 | 0 | 0 | 0 | 1 |
| SORBELLOSTEFANIE | no | 1 | 0 | 0 | 0 | 0 | 1 |
| Saaalih2g | no | 0 | 0 | 0 | 1 | 1 | 1 |
| Sanjays2402 | no | 0 | 0 | 0 | 2 | 2 | 1 |
| SatvikMishra08 | no | 0 | 1 | 0 | 0 | 0 | 1 |
| Solaris-star | no | 1 | 1 | 0 | 0 | 0 | 1 |
| Soundcreates | no | 0 | 1 | 0 | 0 | 0 | 1 |
| aadieng100 | no | 0 | 1 | 0 | 0 | 0 | 1 |
| acoulton | no | 0 | 1 | 0 | 0 | 0 | 1 |
| adityabagla7 | no | 0 | 1 | 0 | 0 | 0 | 1 |
| ajbeattie | no | 1 | 0 | 0 | 0 | 0 | 1 |
| akasakariko | no | 0 | 1 | 0 | 0 | 0 | 1 |
| alondahari | no | 6 | 0 | 0 | 0 | 0 | 1 |
| areesh-ali | no | 1 | 1 | 1 | 0 | 0 | 1 |
| ayy-bc | no | 0 | 2 | 0 | 0 | 0 | 1 |
| azariahporras8686-eng | no | 0 | 2 | 0 | 0 | 0 | 1 |
| babakks | no | 48 | 18 | 8 | 82 | 44 | 4 |
| baiyuxi930826 | no | 0 | 1 | 1 | 0 | 0 | 1 |
| bdehamer | no | 3 | 0 | 0 | 0 | 0 | 1 |
| beltagyy | no | 0 | 3 | 0 | 0 | 0 | 1 |
| benekuehn | no | 0 | 1 | 0 | 0 | 0 | 1 |
| bodapatisaikrishna | no | 0 | 1 | 0 | 0 | 0 | 1 |
| bwt615 | no | 0 | 1 | 0 | 0 | 0 | 1 |
| chj2dctmcr-debug | no | 0 | 0 | 0 | 1 | 1 | 1 |
| copilot-pull-request-reviewer | yes | 0 | 0 | 0 | 178 | 132 | 4 |
| copilot-swe-agent | yes | 0 | 1 | 0 | 2 | 1 | 1 |
| coyaSONG | no | 0 | 1 | 0 | 0 | 0 | 1 |
| csy20 | no | 0 | 1 | 0 | 0 | 0 | 1 |
| dependabot | yes | 111 | 80 | 65 | 0 | 0 | 5 |
| desarrollogmtd9-afk | no | 0 | 1 | 0 | 0 | 0 | 1 |
| drewe7192 | no | 0 | 2 | 0 | 0 | 0 | 1 |
| efegokdemir | no | 0 | 7 | 0 | 0 | 0 | 1 |
| ege-arhan | no | 0 | 1 | 0 | 0 | 0 | 1 |
| felipeofdev-ai | no | 0 | 1 | 0 | 0 | 0 | 1 |
| gaelreyes0318-netizen | no | 0 | 1 | 0 | 0 | 0 | 1 |
| github-actions | yes | 0 | 2 | 1 | 0 | 0 | 1 |
| heaths | no | 0 | 3 | 0 | 0 | 0 | 2 |
| hpsin | no | 0 | 1 | 0 | 0 | 0 | 1 |
| imkp1 | no | 0 | 1 | 0 | 0 | 0 | 1 |
| iulia-b | no | 0 | 1 | 0 | 0 | 0 | 1 |
| jacobmerlincornelius02-alt | no | 0 | 0 | 0 | 1 | 1 | 1 |
| jamietanna | no | 0 | 1 | 0 | 0 | 0 | 1 |
| jarrensj | no | 0 | 1 | 0 | 0 | 0 | 1 |
| jaykrishna316 | no | 0 | 1 | 0 | 0 | 0 | 1 |
| jessehouwing | no | 0 | 1 | 0 | 0 | 0 | 1 |
| ke66344060-ship-it | no | 0 | 0 | 0 | 2 | 1 | 1 |
| kishansaaai | no | 0 | 1 | 0 | 0 | 0 | 1 |
| kjbyrnes84-lgtm | no | 0 | 0 | 0 | 1 | 1 | 1 |
| knowmunever-creator | no | 0 | 0 | 0 | 1 | 1 | 1 |
| kobihikri | no | 1 | 0 | 0 | 0 | 0 | 1 |
| kyleyoungsr82-ai | no | 0 | 0 | 0 | 1 | 1 | 1 |
| lprnmns | no | 0 | 1 | 0 | 0 | 0 | 1 |
| malancas | no | 1 | 0 | 0 | 0 | 0 | 1 |
| maxbeizer | no | 0 | 1 | 0 | 0 | 0 | 1 |
| michaeljacholke | no | 3 | 0 | 0 | 0 | 0 | 1 |
| mirsalimorteza4-hub | no | 0 | 1 | 0 | 0 | 0 | 1 |
| naufalfx805-source | no | 0 | 1 | 0 | 0 | 0 | 1 |
| niik | no | 6 | 3 | 4 | 9 | 8 | 2 |
| nishantmulchandani | no | 0 | 1 | 0 | 0 | 0 | 1 |
| offbyone | no | 0 | 2 | 0 | 0 | 0 | 1 |
| oldregime | no | 0 | 1 | 0 | 0 | 0 | 1 |
| paulacoca95-glitch | no | 0 | 0 | 0 | 1 | 1 | 1 |
| piceri | no | 1 | 0 | 0 | 0 | 0 | 1 |
| promisefidelis001-cmd | no | 0 | 0 | 0 | 2 | 1 | 1 |
| pstoeckle | no | 1 | 0 | 0 | 0 | 0 | 1 |
| reginaldalfret | no | 0 | 1 | 0 | 0 | 0 | 1 |
| ryux1 | no | 1 | 2 | 1 | 0 | 0 | 2 |
| sagarithm | no | 0 | 1 | 0 | 0 | 0 | 1 |
| saidheerajgantala | no | 0 | 1 | 0 | 0 | 0 | 1 |
| scarletkc | no | 1 | 2 | 1 | 0 | 0 | 1 |
| sds | no | 0 | 1 | 0 | 0 | 0 | 1 |
| sergiou87 | no | 19 | 5 | 5 | 5 | 5 | 1 |
| sidsri14 | no | 0 | 1 | 0 | 0 | 0 | 1 |
| streetercurtis290-cloud | no | 0 | 0 | 0 | 1 | 1 | 1 |
| sunxiayi | no | 0 | 1 | 0 | 0 | 0 | 1 |
| tbontb-iaq | no | 0 | 1 | 0 | 0 | 0 | 1 |
| tidy-dev | no | 41 | 4 | 3 | 7 | 7 | 2 |
| timmattison | no | 0 | 1 | 0 | 0 | 0 | 1 |
| timrogers | no | 0 | 1 | 0 | 0 | 0 | 1 |
| tommaso-moro | no | 5 | 3 | 1 | 0 | 0 | 1 |
| unlinked:willmartian@github.com | no | 1 | 0 | 0 | 0 | 0 | 1 |
| victorysHope-arch | no | 0 | 0 | 0 | 1 | 1 | 1 |
| vimalyad | no | 0 | 1 | 0 | 0 | 0 | 1 |
| vimuwaruna3-png | no | 0 | 0 | 0 | 1 | 1 | 1 |
| waldyrious | no | 1 | 1 | 1 | 0 | 0 | 1 |
| wangyusheng1985 | no | 0 | 1 | 0 | 0 | 0 | 1 |
| web-flow | no | 3 | 0 | 0 | 0 | 0 | 1 |
| williammartin | no | 156 | 55 | 47 | 63 | 59 | 4 |
| wilmartin_microsoft | no | 2 | 0 | 0 | 0 | 0 | 2 |
| wippa-studios | no | 0 | 1 | 0 | 0 | 0 | 1 |
| wyaaa671-afk | no | 0 | 0 | 0 | 1 | 1 | 1 |
| ylfeng250 | no | 0 | 1 | 0 | 0 | 0 | 1 |
| zainnadeem786 | no | 0 | 1 | 0 | 0 | 0 | 1 |
| zskbot | no | 0 | 1 | 0 | 0 | 0 | 1 |
| zwick | no | 6 | 0 | 0 | 6 | 2 | 1 |

Automation accounts in this table: 5 of 116.

### 3.2 Review participation

Reviews given matter as much as authorship and are the half most tooling drops, so they get their own section whether or not the estate has any.

| Account | Automation, at collection | Reviews submitted | Pull requests reviewed |
| --- | --- | --- | --- |
| 2cs2vprhyf-creator | no | 1 | 1 |
| Abhirup0 | no | 3 | 2 |
| BagToad | no | 56 | 45 |
| Saaalih2g | no | 1 | 1 |
| Sanjays2402 | no | 2 | 2 |
| babakks | no | 82 | 44 |
| chj2dctmcr-debug | no | 1 | 1 |
| copilot-pull-request-reviewer | yes | 178 | 132 |
| copilot-swe-agent | yes | 2 | 1 |
| jacobmerlincornelius02-alt | no | 1 | 1 |
| ke66344060-ship-it | no | 2 | 1 |
| kjbyrnes84-lgtm | no | 1 | 1 |
| knowmunever-creator | no | 1 | 1 |
| kyleyoungsr82-ai | no | 1 | 1 |
| niik | no | 9 | 8 |
| paulacoca95-glitch | no | 1 | 1 |
| promisefidelis001-cmd | no | 2 | 1 |
| sergiou87 | no | 5 | 5 |
| streetercurtis290-cloud | no | 1 | 1 |
| tidy-dev | no | 7 | 7 |
| victorysHope-arch | no | 1 | 1 |
| vimuwaruna3-png | no | 1 | 1 |
| williammartin | no | 63 | 59 |
| wyaaa671-afk | no | 1 | 1 |
| zwick | no | 6 | 2 |

163 of 164 merged pull requests carried a review by an account other than the author (99.4%).

## 4. Velocity

### 4.1 Throughput

Each period is 15 days; the earliest period begins at the window start.

| Period beginning | 2026-07-07 | 2026-07-22 | 2026-08-06 | 2026-08-21 | 2026-09-05 | 2026-09-20 | Direction |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Commits authored | 35 | 129 | 88 | 182 | 77 | 36 | falling |
| Pull requests opened | 17 | 35 | 50 | 83 | 64 | 51 | flat |
| Pull requests merged | 1 | 22 | 15 | 63 | 40 | 23 | falling |

Direction compares the last period against the mean of the earlier ones.

### 4.2 Cycle time, first commit to merge

- Median: 9.6 h over 164 merged pull requests
- p90: 285.6 h
- Direction: falling (rising means slower)
- Unmeasurable: 0 merged pull requests had no readable first commit

| Period beginning | 2026-07-07 | 2026-07-22 | 2026-08-06 | 2026-08-21 | 2026-09-05 | 2026-09-20 |
| --- | --- | --- | --- | --- | --- | --- |
| Median hours | 1247.2 | 1.5 | 0.9 | 18.4 | 5.2 | 8.2 |

### 4.3 Review latency, opened to first review by another account

- Median: 0.1 h over 163 merged pull requests
- p90: 275.6 h
- Direction: flat (rising means longer waits)
- Not included: 1 merged pull requests had no review from another account

| Period beginning | 2026-07-07 | 2026-07-22 | 2026-08-06 | 2026-08-21 | 2026-09-05 | 2026-09-20 |
| --- | --- | --- | --- | --- | --- | --- |
| Median hours | 0.1 | 14.3 | 0.1 | 0.1 | 0.1 | 2.8 |

## 5. Quality

Each figure below says what it evidences and what it does not.
A quality signal that is presented without that boundary invites a conclusion the data cannot carry.

### 5.1 Reverts and hotfixes

- Reverts: 2 of 547 authored commits (0.4%)
- Hotfixes: 0 of 547 authored commits (0%)

This counts what the estate labelled.
It evidences how often the estate itself declared a change wrong; it does not evidence the defect rate, because a fix that was never called a revert or a hotfix is invisible here.

### 5.2 Change size

- Median merged pull request: 11 lines changed
- p90 merged pull request: 774 lines changed

| Lines changed | Merged pull requests |
| --- | --- |
| under 10 | 77 |
| 10 to 49 | 33 |
| 50 to 249 | 20 |
| 250 to 999 | 22 |
| 1000 or more | 12 |

Size evidences how much a reviewer was asked to hold at once.
It does not evidence difficulty or risk: a one-line change can be the dangerous one, and a large generated diff can be trivial.

### 5.3 Review depth

- Merged pull requests reviewed by another account: 163 of 164 (99.4%)
- Median review threads per merged pull request: 0
- Total review threads on merged pull requests: 269

Thread count evidences how much conversation a change drew.
It does not evidence how carefully anything was read: a correct change reviewed closely can draw no comment at all.

### 5.4 Continuous integration latest-attempt pass rate

- Latest-attempt pass rate: 88.2% (1129 passed, 151 failed)
- Inconclusive runs excluded from the rate: 19
- Checks that needed more than one attempt on the same commit: 49

This evidences how a check ended up, not how it started: the runs list reports each run's latest attempt, so a check that failed and was re-run to green on the same commit counts as a pass here.
It cannot separate a real defect from a flaky job, and it sees only GitHub Actions: checks reported by any other system are invisible to it.
The attempt count says only that a check on that commit was attempted more than once; it does not say why.

## 6. Risk and concentration

### 6.1 Knowledge concentration

- Accounts that authored commits: 28
- Accounts covering half the estate's authored commits: 2
- Largest single share: williammartin at 28.5%

Repositories where one account authored more than half the commits in this window: 2.

| Repository | Account | Share | Authors | Authored commits |
| --- | --- | --- | --- | --- |
| cli/gh-extension-precompile | dependabot | 88.9% | 2 | 9 |
| cli/oauth | dependabot | 75% | 2 | 4 |

This evidences where the estate's recorded history sits with one account.
It does not evidence who understands what: someone who reviewed every change may hold the knowledge without a commit to show for it.

### 6.2 Unmaintained repositories, as at collection

Repositories archived, never pushed to, or unpushed for 180 days or more as at 2026-10-05T05:25:24Z: 2.

| Repository | Days since last push, at collection | Archived, at collection | Commits in window |
| --- | --- | --- | --- |
| cli/scoop-gh | 1249 | yes | 0 |
| cli/safeexec | 979 | no | 0 |

### 6.3 Stalled work, as at collection

Like section 6.2 and unlike the sections before it, this subsection is the state of the estate when this review collected rather than a quantity inside the window: what is open now, and how long it has been sitting as at 2026-10-05T05:25:24Z.

- Open pull requests: 103
- Open issues: 1076

Open pull requests idle for 14 days or more: 77, longest idle first.

| Repository | Number | Idle days, at collection | Age days, at collection | Author | Draft, at collection | Title |
| --- | --- | --- | --- | --- | --- | --- |
| cli/cli | 10273 | 623 | 623 | heaths | yes | Process `--jq` before `--template` |
| cli/cli | 10275 | 606 | 622 | heaths | yes | Support useful template functions and modules in jq filters |
| cli/cli | 10423 | 571 | 599 | iamazeem | no | [gh env] Introduce `gh env list` subcommand |
| cli/gh-extension-precompile | 51 | 557 | 956 | jamacku | no | ci(lint): add shell linter - Differential ShellCheck |
| cli/go-gh | 177 | 557 | 623 | heaths | no | Support filtering before applying template |
| cli/cli | 9847 | 543 | 704 | Shion1305 | yes | [gh search issues] Support multiple author options |
| cli/cli | 11388 | 435 | 435 | MSch | yes | Add dynamic user switching based on git config gh.user (POC for #326) |
| cli/cli | 10730 | 429 | 548 | cmbrose | no | Add support for custom SSH and SCP commands via environment variables |
| cli/oauth | 85 | 425 | 485 | harmonherring-pro | no | Include expiry fields |
| cli/cli | 11500 | 416 | 417 | babakks | yes | Respect `--title` and `--body` in `pr create` web mode |
| cli/cli | 11844 | 367 | 367 | babakks | yes | fix(pr create): keep tracking upstream at push if already set |
| cli/oauth | 106 | 310 | 310 | gbordier | no | read GH_OAUTH_PORT from the environmnent to listen on a predictable port |
| cli/go-gh | 178 | 240 | 623 | heaths | no | Add useful template functions to jq filters |
| cli/cli | 10253 | 231 | 627 | jacob-keller | yes | Include headRepositoryId when creating a new PR |
| cli/go-gh | 209 | 221 | 252 | amaanq | no | config: allow overriding data directory via `GH_DATA_DIR` |

62 further pull requests are in this report's model but not listed above; `--json` prints the model, which carries every one of them.

## 7. Per-repository detail

One row per reviewed repository, sorted by name.
An organization review is this table plus the aggregate above; a single-repository review is the same report with one row here.

| Repository | Commits | Merged | Open now, at collection | Median cycle | Reviewed | Latest-attempt CI | Authors | Idle days, at collection | Archived, at collection | Gaps, at collection |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| cli/cli | 690 | 121 | 75 | 8.4 h | 100% | 89.5% | 25 | 2 | no | pull_requests |
| cli/gh-extension-precompile | 19 | 10 | 3 | 0.8 h | 100% | 63.2% | 2 | 54 | no | none |
| cli/gh-webhook | 0 | 0 | 2 | not measurable | not measurable | not measurable | 0 | 41 | no | none |
| cli/go-gh | 63 | 28 | 20 | 15.2 h | 100% | 87.1% | 6 | 2 | no | none |
| cli/oauth | 9 | 5 | 3 | 1756.8 h | 80% | 73.5% | 2 | 2 | no | none |
| cli/safeexec | 0 | 0 | 0 | not measurable | not measurable | not measurable | 0 | 979 | no | none |
| cli/scoop-gh | 0 | 0 | 0 | not measurable | not measurable | not measurable | 0 | 1249 | yes | none |

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

- `gh-axi api /orgs/cli/repos?type=all&sort=full_name --paginate`
- `gh-axi api /repos/<owner>/<repo>/commits?sha=<default_branch>&since=2026-07-07T00:00:00Z&until=2026-10-05T00:00:00Z --paginate`
- `gh-axi api POST graphql --input <pull-requests-updated-desc-until-2026-07-07T00:00:00Z>`
- `gh-axi api POST graphql --input <open-pull-requests-created-asc>`
- `gh-axi api /repos/<owner>/<repo>/actions/runs?event=pull_request&created=2026-07-07..2026-10-05 --paginate`
- `gh-axi api /repos/<owner>/<repo>/issues?state=open --paginate`

### 9.2 What was read

| Repository | Commits | Pull requests | Open pull requests | CI runs | Issues |
| --- | --- | --- | --- | --- | --- |
| cli/cli | read | read | read | read | read |
| cli/gh-extension-precompile | read | read | read | read | read |
| cli/gh-webhook | read | read | read | read | read |
| cli/go-gh | read | read | read | read | read |
| cli/oauth | read | read | read | read | read |
| cli/safeexec | read | read | read | read | read |
| cli/scoop-gh | read | read | read | read | read |

No read this report uses failed: every reviewed repository answered every one of them.

Reads that hit a cap, so the figures they feed describe the collected subset rather than the whole window:

| Repository | Signal | Cap |
| --- | --- | --- |
| cli/cli | pull_requests | capped at 300 pull requests updated before the window ended |

