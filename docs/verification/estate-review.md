# Estate review verification

Repeatable evidence for the read-only estate review.
Current behavior, every metric definition, and the flags are owned by [`../../bin/xo-estate-review.sh`](../../bin/xo-estate-review.sh)'s header and `--help`, and the invocation policy by the `estate` skill; this page records evidence only.

Date: 2026-09-28.
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

`tests/xo-estate-review.test.sh` (29 assertions) runs with no network and no credentials.
Its fake gh-axi is not a stub of the answer: it holds real GitHub-shaped JSON, applies the script's own `--jq` programs to it, and renders the envelope gh-axi renders, so the collection path under test is the real one.

It covers the derived figures against a hand-computed fixture estate (commits with a merge and a revert excluded from authorship, cycle time from first commit to merge, review latency that excludes the author's own review, the latest-attempt CI pass rate over workflow-and-commit groups with a run that took two attempts on one commit, change-size distribution, concentration, unmaintained and stalled detection, and open issues with pull requests filtered out); the identity rule that folds an app account's `name[bot]` spelling into one marked row while never matching two accounts by name; the fixed nine sections and fourteen subsections on an active estate, on a single-repository estate, and on an estate collected from a repository whose every read comes back empty, where each empty surface states in a sentence that it is empty and the headline says the window was silent rather than reading as low activity; an unreadable repository named as a gap and still carrying its own row; byte-identical re-rendering of one model; the three unknown-envelope refusals, each naming the gh-axi version and producing no model; an unreadable estate owner stopping the run while quoting gh-axi's own diagnostic, and a non-organization owner refused with the type GitHub reported; a call log proving the only write verb the estate ever sees is the POST that carries a GraphQL read; the recorded command templates with the window substituted; estate free text containing a tab neutralized rather than shifting every later field while the model keeps the text's own pipe; selection excluding forks by default and disclosing a repository cap, and a repository listing that stopped at its page bound named as a cap in section 9.2 rather than reading as a complete estate; the person table ordered by account name rather than by volume; a bounded risk list stating its complete count and how many rows it did not show, and raising `--max-listed` on the stored model showing every row it kept; and the window and period settings bounding what is counted.

Five cases pin the bounds where a figure could quietly become wrong: an open-issue read whose full first page is almost all pull requests still walks to the second page, because page completeness follows the endpoint's item count rather than the records the filter kept; a review on an open pull request that both collection passes return is counted once; a pull request carrying more reviews than one page holds is disclosed as a cap in section 9.2 rather than shortening a review count in silence; a median series whose last period holds no measurement reports no direction at all and names the empty periods, rather than describing a period that ended before the window did; and a commit whose workflow ran twice, once after three attempts and once more after a reopen, takes its conclusion from the later run while the attempt count still reports what that commit actually needed.

Three further cases pin what a row of the report is allowed to say.
A commit written in December and rebased onto the default branch in February is counted in the period it landed in, because the committer date is what GitHub's commit list filters on and counting by any other date would drop commits the request itself asked for.
An account that reaches the person table only through a merged pull request is marked as automation when it is one and credits the repository it merged into, so no row can say an account merged a pull request in no repository.
A pull-request title carrying a pipe keeps the column count its header declares and its own text, so a Markdown reader sees the whole title rather than the part before the pipe.

One case pins the `--from-json` contract, which is what makes the report's own instruction to raise `--max-listed` true.
A flag the stored model can satisfy is honoured and written into the model the report is rendered from, and every flag that would need a fresh collection is refused by name with exit 2 rather than accepted and dropped.

Three cases pin the distinction the live guard exists to protect, in the places it can be lost.
An estate whose every repository read is refused yields exactly what a silent estate yields - no commits, no people, no runs - so the whole rendered report is searched for the rule rather than for a list of sentences: no statement about what the estate did may range over the window, every such sentence must instead range over what could be read, and each must name the reads behind that figure that failed.
A surface added later that skips that boundary fails the same assertion.
One failed read among many is checked the same way, and the notice is asserted to reach the surfaces that read fed and no others: section 6.1's list says how far its claim reaches and counts the single failure in the singular, while the open pull request and open issue counts, which came from reads that succeeded, carry no warning at all.
A historical window whose end predates the last push is asserted to age push recency from the collection clock rather than the window end, so no day count renders negative, the unmaintained test still selects, and every table before section 9 is checked column by column against the rule section 1 states: a column reporting the state of the estate ends its heading `at collection`.

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
