import { useState } from "react";

export interface ContentsEntry { id: string; title: string; badge?: string }

/** A list of every item with a filter, to jump to one quickly on a long page. It folds away after a jump. */
export function Contents({ entries, goTo }: { entries: ContentsEntry[]; goTo: (id: string) => void }) {
  const [q, setQ] = useState("");
  const words = q.trim().toLowerCase().split(/\s+/).filter(Boolean);
  const shown = entries.filter(e => words.every(w => (e.title + " " + e.id).toLowerCase().includes(w)));
  return (
    <details className="toc" data-toc>
      <summary>Contents <span className="toc-n">({entries.length})</span></summary>
      <div className="toc-body">
        <label className="toc-filter"><span className="toc-fl">Filter</span>
          <input type="search" value={q} placeholder="number or words" aria-describedby="toc-count" onChange={e => setQ(e.target.value)} /></label>
        <p className="toc-count" id="toc-count" role="status" aria-live="polite">{shown.length === entries.length ? `${entries.length} items` : `${shown.length} of ${entries.length}`}</p>
        <ol className="toc-list">
          {shown.map(e => (
            <li key={e.id}>
              <a href={"#rv-" + encodeURIComponent(e.id)} onClick={ev => {
                ev.preventDefault();
                (ev.currentTarget.closest("details") as HTMLDetailsElement).open = false;
                goTo(e.id);
              }}>{e.title}</a>{e.badge ? <span className="toc-badge">{e.badge}</span> : null}
            </li>
          ))}
          {shown.length === 0 && <li className="toc-none">Nothing matches.</li>}
        </ol>
      </div>
    </details>
  );
}
