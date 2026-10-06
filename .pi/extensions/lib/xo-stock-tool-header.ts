import type { Theme } from "@earendil-works/pi-coding-agent";

// Single owner of the stock tool-call header for XO tools that render their own
// shell (`renderShell: "self"`).
//
// Why this exists at all: Calm must be able to hide an XO tool row completely,
// and the only Pi shell that renders zero lines for an empty component is
// "self" (the "default" shell keeps its box padding and leaves a residual
// blank line). Choosing "self" means XO owns the framing, and Pi offers no way
// to borrow its own call-header component from inside a self-rendered shell:
// `formatToolCallWithArgs` is internal to the package and its subpath is not
// in the package's `exports` map, so it cannot be imported. Reproducing the
// format here is therefore forced by Pi's API shape, not a stylistic choice.
//
// Pi 0.99.0 replaced the old bare-title header with title-plus-arguments.
// Collapsed, arguments are `key=value` pairs appended to the title line;
// expanded, each becomes a `key: value` line below the title. Keeping byte
// parity matters because an XO tool row sits in the same transcript as every
// stock tool row: a bare title next to `grep pattern=...` reads as a
// rendering bug.
//
// Scope is the three XO callers' parameter schemas and nothing more: `{}`,
// `{recent?: number}` and `{through: number}`, so every entry is a scalar that
// occupies one line. Pi's own header additionally cuts a long collapsed line
// to a character budget, expands tabs, and indents multiline continuations;
// none of that is reproduced, because a faithful reproduction of code no
// schema can reach and no test compares is an untested claim of fidelity,
// not fidelity.
//
// Two cases hold that scope, and together they are what makes the parity
// claim above checkable rather than asserted. tests/xo-pi-branch-extension.test.sh
// sweeps every arg shape the schemas admit - `{}` and `{recent: 2}` for
// xo_branch_outcomes, `{through: 7}` for xo_branch_processed - collapsed and
// expanded, comparing each rendered row against the same row rendered by the
// installed Pi itself, so no Pi constant, format or spelling is restated
// here. A companion case in that same file walks those two tools' registered
// schemas and fails, naming the property and its type, if a parameter that is
// not a scalar is ever added, so a long, tabbed, multiline or non-scalar
// parameter breaks that guard instead of silently putting this helper out of
// scope, and the part of Pi's format it needs must be reproduced and compared
// before the parameter lands. xo_watch_arm_pi declares no parameters at all;
// tests/xo-pi-watch-extension.test.sh pins only that it still renders its own
// shell, and its fixture rejects any added parameter at module import rather
// than by name.
export function formatStockToolCallHeader(
  title: string,
  args: unknown,
  theme: Theme,
  expanded: boolean,
): string {
  const header = theme.fg("toolTitle", theme.bold(title));
  if (args == null || typeof args !== "object") return header;
  const entries = Object.entries(args as Record<string, unknown>);
  if (entries.length === 0) return header;
  if (expanded) {
    const lines = entries.map(([key, value]) => `  ${key}: ${JSON.stringify(value)}`);
    return `${header}\n${theme.fg("muted", lines.join("\n"))}`;
  }
  const pairs = entries.map(([key, value]) => `${key}=${JSON.stringify(value)}`).join(" ");
  return `${header} ${theme.fg("muted", pairs)}`;
}
