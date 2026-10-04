# Estate review verification

Repeatable evidence for the read-only estate review.
Current behavior, every metric definition, and the flags are owned by [`../../bin/xo-estate-review.sh`](../../bin/xo-estate-review.sh)'s header and `--help`, and the invocation policy by the `estate` skill; this page records evidence only.

Date: 2026-10-04.
Shell: GNU bash 5.3.15 (Linux 7.2.5-3-omarchy).
gh-axi: 0.1.35.
jq: 1.8.2.

## Why this surface needs live evidence

`bin/xo-estate-review.sh` reads a vendor-rendered surface.
gh-axi renders every response for an agent to read, so the collector asks for a tab-separated payload with `--jq` and decodes the one `api_response` body field that carries it.
Returning JSON from `--jq` is not an option: gh-axi recognizes a JSON result and re-renders it as a document, so the payload would stop being a payload.
A portable fake can only confirm the assumption written into the fake, so the envelope itself is proven against the installed gh-axi.

Three couplings carry the collector, and all three are pinned live:

- Exactly one `body:` field per envelope, which is what the decoder reads.
- `truncated: false` under `--full`, because a truncated payload is refused rather than trusted.
- A tab-separated payload that survives the round trip as a payload, quoted by the rendering when it contains escapes and bare when it does not.

A changed envelope refuses with the installed gh-axi version instead of decoding to nothing.
That distinction is the whole point of the guard: an empty estate and an unreadable one must never read the same, because the captain acts on the difference.

## Portable suite

`tests/xo-estate-review.test.sh` (33 assertions) runs with no network and no credentials.
Its fake gh-axi is not a stub of the answer: it holds real GitHub-shaped JSON, applies the script's own `--jq` programs to it, and renders the envelope gh-axi renders, so the collection path under test is the real one.

It covers the derived figures against a hand-computed fixture estate (commits with a merge and a revert excluded from authorship, cycle time from first commit to merge, review latency that excludes the author's own review, the latest-attempt CI pass rate over workflow-and-commit groups with a run that took two attempts on one commit, change-size distribution, concentration, unmaintained and stalled detection, and open issues with pull requests filtered out); the identity rule that folds an app account's `name[bot]` spelling into one marked row while never matching two accounts by name; the fixed nine sections and fourteen subsections on an active estate, on a single-repository estate, and on an estate collected from a repository whose every read comes back empty, where each empty surface states in a sentence that it is empty and the headline says the window was silent rather than reading as low activity; an unreadable repository named as a gap and still carrying its own row; byte-identical re-rendering of one model; the three unknown-envelope refusals, each naming the gh-axi version and producing no model; an unreadable estate owner stopping the run while quoting gh-axi's own diagnostic, and a non-organization owner refused with the type GitHub reported; a call log proving the only write verb the estate ever sees is the POST that carries a GraphQL read; the recorded command templates with the window substituted; estate free text containing a tab neutralized rather than shifting every later field while the model keeps the text's own pipe; forks excluded from an organization review with the report disclosing that they were, while a repository named explicitly is reviewed whether or not it is a fork and the report discloses that selection instead, and an estate larger than the review naming both bounds that bit it - the listing walk's page bound as a cap in section 9.2, and the repository cap with the value that produced the shortfall - rather than reading as a complete estate; the person table ordered by account name rather than by volume; a bounded risk list stating its complete count, how many rows it did not show, and where every row can be read, with the model it names proven to carry them; and the window bounding what is counted while the fixed period count is recorded beside it.

Three cases pin the bounds on the pull-request walk, which is the one read that cannot ask GitHub for a window.
It descends by updated-at from the present, so a window in the past sits behind every pull request touched since that window ended.
Six pages of fifty such pull requests - the review's whole pull-request cap - are placed in front of a window holding two merged pull requests, and the report counts those two: the cap bounds the pull requests the report counts, so a pull request passed over on the way down spends none of it, and no cap is reported because none was spent on anything counted.
Not spending the cap there leaves the walk itself unbounded, so a repository whose pages never reach the window is walked against a page bound instead; the walk is asserted to stop at exactly the number of pages the model discloses, and section 9.2 carries that repository's row with the bound's own value in it, so a zero pull-request figure never reads as none merged when it means not reached.
A window shorter than the trend's period count is refused by name with exit 2, with the shortest accepted window asserted to date its six periods distinctly, which is the reason the minimum exists.

Five cases pin the bounds where a figure could quietly become wrong: an open-issue read whose full first page is almost all pull requests still walks to the second page, because page completeness follows the endpoint's item count rather than the records the filter kept; a review on an open pull request that both collection passes return is counted once; a pull request carrying more reviews than one page holds is disclosed as a cap in section 9.2 rather than shortening a review count in silence; a median series whose last period holds no measurement reports no direction at all and names the empty periods, rather than describing a period that ended before the window did; and a commit whose workflow ran twice, once after three attempts and once more after a reopen, takes its conclusion from the later run while the attempt count still reports what that commit actually needed.

Three further cases pin what a row of the report is allowed to say.
A commit written in December and rebased onto the default branch in February is counted in the period it landed in, because the committer date is what GitHub's commit list filters on and counting by any other date would drop commits the request itself asked for.
An account that reaches the person table only through a merged pull request is marked as automation when it is one and credits the repository it merged into, so no row can say an account merged a pull request in no repository.
A pull-request title carrying a pipe keeps the column count its header declares and its own text, so a Markdown reader sees the whole title rather than the part before the pipe.

One case pins the `--from-json` contract, which is what makes a stored model a fixed input: `--json` re-emits the stored model unchanged, so the same model renders the same report anywhere.
A window flag, which would need a fresh collection, is refused by name with exit 2 rather than accepted and dropped.
A setting that is a constant is asserted to be an unknown flag both beside a stored model and against a live estate, so a report cannot be varied by a flag that documentation elsewhere might still name.

Three cases pin the distinction the live guard exists to protect, in the places it can be lost.
An estate whose every repository read is refused yields exactly what a silent estate yields - no commits, no people, no runs - so the whole rendered report is searched for the rule rather than for a list of sentences: no statement about what the estate did may range over the window, every such sentence must instead range over what could be read, and each must name the reads behind that figure that failed.
A surface added later that skips that boundary fails the same assertion.
One failed read among many is checked the same way, and the notice is asserted to reach the surfaces that read fed and no others: section 6.1's list says how far its claim reaches and counts the single failure in the singular, while the open pull request and open issue counts, which came from reads that succeeded, carry no warning at all.
The "and no others" half is proven as a matrix rather than as an example.
Each of the five per-repository reads is denied on its own against an otherwise silent estate, where every surface renders its empty sentence and is therefore eligible for a notice, and the set of sections carrying one is compared against the set that read actually feeds.
A surface naming a read it does not rest on fails that case as loudly as a surface dropping a read it does.
A historical window whose end predates the last push is asserted to age push recency from the collection clock rather than the window end, so no day count renders negative and the unmaintained test still selects.

The clock labels are held by a rule rather than by a list of known columns.
Every rendered report the suite checks the shape of has the header row of every table before section 9 read structurally, as the line above a separator row, and each heading cell classified: a figure the estate's state supplies must end `at collection`, a figure the window bounds must not claim that clock, and a column that only names something carries neither.
A heading the rule cannot classify fails the assertion rather than being skipped, so a column added later breaks the suite until someone decides which clock it is on.

## Live guard

`tests/xo-estate-review-live-e2e.test.sh` (3 assertions) exercises the real gh-axi and real GitHub against the small public `jqlang` organization.
The estate is public deliberately: the guard prints report fragments, and a report names the accounts that contributed.
It spends no model tokens, so it runs by default wherever gh-axi, gh, and jq are installed; an unauthenticated host reports a capability skip instead of failing, while an explicitly requested run on an unusable host fails rather than passing over the thing under test.
The review case reads a fixed historical window, 2025-05-01 to 2025-07-01, whose counts are settled, so a quiet month upstream cannot fail a suite about this repository.

```console
$ bash tests/xo-estate-review.test.sh | tail -1
# xo-estate-review.test.sh: all assertions passed
$ bash tests/xo-estate-review-live-e2e.test.sh
ok - gh-axi 0.1.35 still renders one quoted api_response body carrying an untruncated tab-separated payload
ok - the live GraphQL read returns the collector's own shaped record under an explicit POST, __typename included
ok - a live review of jqlang/jq over a settled historical window emits the fixed nine sections and a model carrying real commits, merges, and accounts
# xo-estate-review-live-e2e.test.sh: all assertions passed
```

Refresh this record by running the live guard after a gh-axi upgrade:

```console
$ XO_ESTATE_REVIEW_LIVE=1 bash tests/xo-estate-review-live-e2e.test.sh
```

`XO_ESTATE_REVIEW_LIVE_ESTATE` and `XO_ESTATE_REVIEW_LIVE_REPO` point the guard at a different public estate when `jqlang` stops being a useful subject.

## Stock Bash 3.2 parse constraint

The renderer's jq program is read with `IFS= read -r -d '' RENDER_JQ <<'JQ' || :` rather than assigned from `$(cat <<'JQ' ... )`, and that is a correctness constraint rather than a style choice.
Stock macOS Bash 3.2 scans a command substitution for its closing parenthesis without treating a here-document body inside it as data.
The renderer interpolates jq strings, so the parenthesis that closes a `\( ... )` containing a quoted string reads to that scanner as the end of the substitution, and the rest of the program is then parsed as shell.
The observed failure was `bin/xo-estate-review.sh: line 1149: syntax error near unexpected token '('` under `/bin/bash -n`, reported against GNU bash 3.2.57(1)-release (arm64-apple-darwin25).

`DERIVE_JQ` remains an ordinary `$( ... )` assignment because it carries no `\( ... )` interpolation and stays parenthesis-balanced under the same scanner; a future interpolation added there would need the same treatment.

The guard is the stock-Bash parse sweep in `.github/workflows/ci.yml`, which runs `/bin/bash -n` over every file `bin/xo-lint.sh --list-files` reports.
That sweep is what caught this, and it is the regression cover: no local test can stand in for it, because the defect is a parse-time failure on a shell version this repository's Linux hosts do not have, and asserting it from source text would violate the rule that tests exercise behavior rather than implementation bytes.

Changing how the program is delivered must not change what it prints.
The check is that one stored model renders byte-identically, which is also what makes a stored model a fixed input rather than a snapshot of a machine:

```console
$ xo-estate-review.sh jqlang --since 2025-05-01 --until 2025-07-01 --json > model.json
$ xo-estate-review.sh --from-json model.json > a.md
$ xo-estate-review.sh --from-json model.json > b.md
$ cmp a.md b.md && wc -lc a.md
  287 18332 a.md
```

The line and byte counts move with the estate, because a fresh collection reads it as it is today; `cmp` is the assertion and `tests/xo-estate-review.test.sh` pins it with no network.
