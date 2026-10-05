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
// Collapsed, arguments are `key=value` pairs appended to the title line and cut
// to COLLAPSED_ARGS_CHARS; expanded, each becomes a `key: value` line below the
// title with continuation lines indented. Keeping byte parity matters because
// an XO tool row sits in the same transcript as every stock tool row: a bare
// title next to `grep pattern=...` reads as a rendering bug.
//
// tests/xo-pi-branch-extension.test.sh compares a self-shelled XO row against
// the same row rendered by Pi's own fallback and fails on any difference, so
// this reproduction cannot drift silently.
const COLLAPSED_ARGS_CHARS = 100;

// Pi's own tab handling for header values (core/tools/render-utils.ts).
const replaceTabs = (text: string): string => text.replace(/\t/g, "   ");

export function formatStockToolCallHeader(
  title: string,
  args: unknown,
  theme: Theme,
  expanded: boolean,
): string {
  const header = theme.fg("toolTitle", theme.bold(title));
  if (args == null) return header;
  const entries: [string, unknown][] =
    typeof args === "object" && !Array.isArray(args)
      ? Object.entries(args as Record<string, unknown>)
      : [["args", args]];
  if (entries.length === 0) return header;
  if (expanded) {
    const lines = entries.map(([key, value]) => {
      const text = typeof value === "string" ? value : (JSON.stringify(value, null, 2) ?? String(value));
      return `  ${key}: ${replaceTabs(text).replace(/\r/g, "").split("\n").join("\n    ")}`;
    });
    return `${header}\n${theme.fg("muted", lines.join("\n"))}`;
  }
  const pairs = entries
    .map(([key, value]) => `${key}=${JSON.stringify(value) ?? String(value)}`)
    .join(" ");
  const preview =
    pairs.length > COLLAPSED_ARGS_CHARS ? `${pairs.slice(0, COLLAPSED_ARGS_CHARS - 3)}...` : pairs;
  return `${header} ${theme.fg("muted", preview)}`;
}
