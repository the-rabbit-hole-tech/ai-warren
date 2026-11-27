import { useState } from "react";
import { copyText, HOLD } from "@/lib/copy";
import type { Round } from "@/lib/types";

export interface HistoryRow { round: Round; count: string }

function RoundRow({ round: r, count }: HistoryRow) {
  const [copied, setCopied] = useState<"" | "copied" | "selected">("");
  const text = r.results ?? "";
  return <details className="rvhist-round">
    <summary>{`Round ${r.round}${r.build ? " · build " + r.build : ""} · ${(r.closed ?? "").slice(0, 10)} · ${count}`}</summary>
    <pre className="hist-text">{text}</pre>
    <button type="button" className="hist-copy" onClick={async e => { const done = await copyText(text, e.currentTarget.previousElementSibling); if (done === "failed") return; setCopied(done); setTimeout(() => setCopied(""), done === "selected" ? 5000 : 1500); }}>{copied === "copied" ? "Copied" : copied === "selected" ? HOLD : "Copy results"}</button>
  </details>;
}

/** Closed rounds, collapsed, after the page's own content. */
export function History({ rows }: { rows: HistoryRow[] }) {
  return <details className="rvhist" id="rvhist"><summary>{`History (${rows.length}${rows.length === 1 ? " round" : " rounds"})`}</summary>
    {rows.map(r => <RoundRow key={r.round.round} {...r} />)}</details>;
}
