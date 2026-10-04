---
name: estate
description: >-
  Review an engineering estate - a GitHub organization or one of its repositories - and report who did what, how fast work is moving, whether quality is holding, and where risk is concentrated.
  Use when the captain invokes /estate or asks for an estate review, an engineering review of an organization, a contribution or velocity or quality report across repositories, or "who has been doing what" across a set of repositories.
  Plain /estate answers in chat; /estate file also writes the dated report artifact under data/.
  The report has the same shape on every run against every estate, which is what makes two of them comparable.
user-invocable: true
metadata:
  internal: true
---

# estate

Review an estate and tell the captain what is actually happening in it.

`bin/xo-estate-review.sh` is the single owner of collection, every metric definition, and the report's shape; its header and `--help` own the flags.
This skill owns which estate and window to point it at, what the captain hears back, and the two boundaries that matter: the review never writes to the estate, and it never ranks people.

## 1. Resolve the estate and the window

An estate is an organization by default, because that is the unit a captain asks about.
The command also accepts a single `owner/repo`, and an organization review is the per-repository review plus an aggregate.
It accepts nothing else: an owner GitHub reports as anything but an organization is refused with the type it reported.

- The captain named an organization or repository: use it.
- The captain named no estate: ask one concise question naming the candidates you can see, which are the owners of the projects in `data/projects.md`.
  Do not guess, and do not review every organization the account can reach.
- The captain asked about "our repos" or similar in a home with exactly one project owner: use that owner and name it in your answer so a wrong reading is cheap to correct.

Leave the window at its default of 90 days unless the captain asked for a period.
Widen it when the estate is quiet enough that the default returns almost nothing, and say that you widened it.
Never silently change a window between two reports of the same estate: the comparison is the point, and a changed window breaks it.
A window needs at least one day per trend period, so the shortest the command accepts is six days; it refuses anything shorter and names the minimum, because two periods cannot carry the same date.
When the captain asks about the last day or two, give them the shortest accepted window and say that is what you read.

## 2. Run it

```
bin/xo-estate-review.sh <estate> [--since <date>] [--until <date>] [--window <days>]
```

Choosing the period is all the flags do, and that is deliberate: a report whose value is that two of them are comparable must not offer ways to make two of them differ invisibly.
The trend periods, the stalled and unmaintained thresholds, the repository and pull-request bounds and the fork and archived selection are fixed, each disclosed in the report's header bullet or section 1 rather than chosen per run.
If one of those values is wrong for an estate, that is a change to the command, reviewed once and applying to every report after it - not a flag, and not something to work around.

Add `--json` when you need the numbers for something other than reading, and `--from-json` to re-render a stored model without touching the network.
Only `--json` goes alongside `--from-json`; a different window needs a fresh collection and the command says so by name rather than ignoring it.

A large organization is the one case worth bounding before you start.
Do not carry the bounds here: section 1 of every report states the ones that produced it, and section 9.2 names every read that hit one, so quote the report rather than a figure from this page.
What costs the time is the pull-request walk, and it costs most on a window in the past, because it descends from today to reach the window: expect roughly ten reads per repository on a window ending today and up to about fifty on an older one, approximately and from the bounds section 1 discloses.
On an estate with more than about thirty repositories, or any window that does not end today, tell the captain roughly how long it will take before you start rather than after.

Do not compute any figure yourself, do not write a second collector, and do not repair a number you disagree with.
If a figure looks wrong, section 9 names the read it came from and what that read could not see; check those.

## 3. Report it

Read the whole report, then give the captain the outcome in plain words, evidence first.
Lead with the two or three findings that would change a decision, name the numbers behind them, and point to the report for the rest.

Never paste the report into chat.
It is a document to read, and section 1 alone is longer than any answer should be.
When the captain invoked `/estate file`, write it to `data/estate-review-<scope>-<YYYY-MM-DD>.md` (with `/` in a repository scope replaced by `-`) and give the captain that path.
Otherwise keep the report out of the home unless the captain asks for it.

Translate the internal vocabulary before you speak, as `AGENTS.md` section 9 requires: say the investigation, the change, the review, the local copy, not the tool's nouns.

## 4. What you must not do with these numbers

This report is about work, not about people.

- Never rank individuals, score productivity, or name anyone as most or least productive, even when asked directly.
  When the captain asks who is performing best, answer with what the numbers do and do not support: they count commits, pull requests, and reviews, and they cannot see difficulty, pairing, design, mentoring, incident work, or review that happened in chat.
  Offer the concentration and review-participation findings instead, which are about where the estate is exposed rather than about who is good.
- Never infer effort, commitment, skill, or worth from a count, and never repeat someone else's inference.
- Never merge two accounts into one person.
  The command folds only an app account's documented `name[bot]` spelling and states that it did; anything else is a guess about who someone is.
- Treat an automation row as automation.
  A bot's merged pull requests really did land, and they are not a person's contribution.

Section 8 of every report states these limits in writing, which is the version the captain can re-read later.
Do not weaken it when you summarize.

## 5. The read-only boundary

The review observes an estate and never changes one.
Do not open an issue, post a comment, apply a label, close a stalled pull request, or push anything as part of running it, and do not ask a worker to.

A finding is evidence, not authorization.
When the report exposes work worth doing - a stalled pull request to chase, an unmaintained repository to retire, a single-account repository to spread - take it to the captain as a decision, or file it as its own work item under `AGENTS.md` section 10, and dispatch only what the captain authorizes.
A repository the command could not read is named in section 9.2 and excluded from the figures it could not supply; relay that gap rather than reporting the aggregate as complete.
