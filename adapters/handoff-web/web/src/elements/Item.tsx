import { useEffect, useRef, useState, type ReactNode } from "react";
import { flushSync } from "react-dom";
import { Answer, type AnswerOption } from "@/elements/Answer";
import { Blocks, ItemExtras } from "@/elements/Blocks";
import { Chip } from "@/elements/Chip";
import { Choices } from "@/elements/Choices";
import { ItemMore, type ItemAction } from "@/elements/ItemMore";
import { Thread, type Entry } from "@/elements/Thread";
import type { ItemDef, ItemState, Local } from "@/lib/types";

const LABEL: Record<string, string> = { yes: "Yes", no: "No", chg: "Changes", skip: "Skipped", risk: "Accept risk" };
const PILL: Record<string, string> = { yes: "Yes", no: "No", chg: "Changes", skip: "Skipped (locked)", risk: "Accept risk" };
const TONE: Record<string, string> = { yes: "a-yes", no: "a-no", chg: "a-chg", skip: "skp", risk: "a-risk" };
const ANS: Record<string, string> = { yes: "yes", no: "no", changes: "chg", skipped: "skip" };
const BASE: Record<string, string[]> = { check: ["yes", "no", "chg", "skip"], step: ["yes", "no", "chg", "skip"] };

export function optionsFor(it: ItemDef, type: string, risk: boolean): AnswerOption[] {
  let set = it.answers ? it.answers.map(a => ANS[a] ?? a) : (BASE[type] ?? ["yes", "no", "chg"]);
  if (it.skip && !set.includes("skip")) set = [...set, "skip"];
  if (risk && !it.answers) set = [...set, "risk"];
  return set.map(value => ({ value, label: LABEL[value] }));
}

export interface ItemProps {
  item: ItemDef;
  /** What the heading leads with: the card's number, or nothing where the id says it. */
  n: number | string;
  /** A round item also takes Accept risk. */
  risk?: boolean;
  type: string;
  state?: ItemState;
  value: Local;
  /** Who or what is holding it, for Blocked by. A fix in progress also holds it, with the text of the fix in fixing. */
  blockedBy?: string;
  /** The item is marked fix in progress (page.py fixing): drawn purple, locked, and not awaiting the reviewer. */
  fixing?: string;
  /** A Drop was asked for and the operator hasn't answered: the item takes no pick. */
  dropping?: boolean;
  /** This choice item has a pick that was not sent: a "Send this item" button sends it (and only it). */
  canSendPick?: boolean;
  onSendPick?: () => Promise<void>;
  /** The page lets questions be skipped: Skip keeps the typed text and locks it, Un-skip gives it back. */
  skippable?: boolean;
  /** The page lets items be dropped; onDrop sends the request once the reviewer confirms. */
  droppable?: boolean;
  onDrop?: () => Promise<void>;
  /** Sent, and waiting on the agent. */
  held?: boolean;
  /** A sent No or Changes the agent dealt with. */
  handled?: boolean;
  entries: Entry[];
  /** The email element, when the page takes drafts: given whether its form is open and how to close it. */
  email?: (asking: boolean, close: () => void) => ReactNode;
  /** What this item's More button offers, besides its email draft. */
  actions?: ItemAction[];
  /** The label of the email action, when the page takes drafts. */
  emailLabel?: string;
  diffs?: Record<string, string>;
  build?: string | null;
  choices?: { value: string; label: string }[];
  defaultChoice?: string;
  blockerLabel: string;
  blockerTitle: string;
  isItem: (id: string) => boolean;
  goTo: (id: string) => void;
  onChange: (next: Local) => void;
  onBlocker: (note: string) => void;
  /** Take the lock off a confirmed Yes; the reason is required. Rejects with the server's message. */
  onReopen: (reason: string) => Promise<void>;
}

/** One numbered card: id, status, content, its history, answers and the note box. */
export function Item(p: ItemProps) {
  const { item: it, type, state, value, blockedBy, held, handled } = p;
  const heading = (p.n === "" ? "" : p.n + ". ") + it.title;
  const [noteOpen, setNoteOpen] = useState(false);
  const [shown, setShown] = useState(false);
  const [asking, setAsking] = useState(false);
  const [confirming, setConfirming] = useState(false);
  const [cnote, setCnote] = useState("");
  const [reopening, setReopening] = useState(false);
  const [dropAsk, setDropAsk] = useState(false);
  const [busy, setBusy] = useState("");
  const dropOk = useRef<HTMLButtonElement>(null);
  const [why, setWhy] = useState("");
  const [whyErr, setWhyErr] = useState("");
  const [said, setSaid] = useState("");
  const card = useRef<HTMLElement>(null);
  const okBtn = useRef<HTMLButtonElement>(null);
  const whyTa = useRef<HTMLTextAreaElement>(null);
  const ta = useRef<HTMLTextAreaElement>(null);
  const qa = useRef<HTMLTextAreaElement>(null);
  useEffect(() => { if (confirming) okBtn.current?.focus(); }, [confirming]);
  useEffect(() => { if (reopening) whyTa.current?.focus(); }, [reopening]);
  useEffect(() => { if (dropAsk) dropOk.current?.focus(); }, [dropAsk]);
  useEffect(() => { if (qa.current) { qa.current.style.height = "auto"; qa.current.style.height = qa.current.scrollHeight + 2 + "px"; } });
  const group = it.section ? <h2 className="group-h">{it.section}</h2> : null;
  const content = <>
    {p.fixing && <p className="fix-note"><strong>Fix in progress:</strong> {p.fixing}. It takes no answer until the fix is cleared.</p>}
    <ItemExtras item={it} diffs={p.diffs} isDiff={type === "diff"} />
    <Blocks blocks={it.body} id={it.id} diffs={p.diffs} />
    {it.howto && <details className="howto" data-howto={it.id}>
      <summary>How to test{p.build ? <span className="howto-build"> · build <code>{p.build}</code></span> : null}</summary>
      <div className="howto-body"><Blocks blocks={it.howto} id={it.id} part="howto" diffs={p.diffs} /></div>
    </details>}
    <Thread entries={p.entries} label={"History of " + it.id} />
    {p.email?.(asking, () => flushSync(() => setAsking(false)))}
  </>;
  const actions: ItemAction[] = [...(p.emailLabel ? [{ name: "draft-email", label: p.emailLabel, onSelect: () => flushSync(() => { setShown(true); setAsking(true); }) }] : []), ...(p.actions ?? [])];
  const more = <ItemMore id={it.id} actions={actions} />;
  if (type === "info") return <>{group}<section className="info" data-item={it.id}>{actions.length > 0 && <div className="rvhead"><span className="sp" />{more}</div>}<h2>{heading}</h2>{content}</section></>;

  const settled = !!state?.hidden;
  const sent = held ? " is-sent" : "";
  const v = value.v ?? "", note = value.n ?? "";
  // A confirmed Yes: the answer is locked and the row collapses like an earlier-round Yes, but the note stays editable.
  const confirmed = !!value.confirmed && v === "yes" && !settled;
  const softSettled = settled || confirmed;
  const locked = !!value.locked || !!blockedBy || !!held || settled || confirmed;
  const canConfirm = !["question", "choice", "info"].includes(type) && optionsFor(it, type, !!p.risk).some(o => o.value === "yes");
  const cancelConfirm = () => { setConfirming(false); setTimeout(() => card.current?.querySelector<HTMLElement>('.seg button[data-v="yes"]')?.focus()); };
  const doConfirm = () => {
    setConfirming(false);
    p.onChange({ v: "yes", n: cnote, confirmed: true });
    setSaid(`${it.id} confirmed and locked.`);
    setTimeout(() => card.current?.querySelector<HTMLElement>(".settled-tg")?.focus());
  };
  const doReopen = async () => {
    const reason = why.trim();
    if (!reason) { setWhyErr("Say why you are reopening it."); whyTa.current?.focus(); return; }
    try { await p.onReopen(reason); setReopening(false); setWhy(""); setWhyErr(""); setSaid(`${it.id} reopened.`); setTimeout(() => card.current?.querySelector<HTMLElement>('.seg button[data-v="yes"]')?.focus()); }
    catch (e) { setWhyErr((e as Error).message || "Couldn't reopen it."); }
  };
  const blocked = p.fixing ? <span className="st fix" title={p.fixing}>Fix in progress</span> : p.dropping ? <span className="st blk" title="It comes off the board once the request is handled">Drop requested</span> : blockedBy ? <span className="st blk">Blocked by {p.isItem(blockedBy)
    ? <a className="rid" href={"#rv-" + encodeURIComponent(blockedBy)} title={"Go to " + blockedBy} onClick={e => { e.preventDefault(); p.goTo(blockedBy); }}>{blockedBy}</a> : blockedBy}</span> : null;
  const rid = <a className="rid" href={"#rv-" + encodeURIComponent(it.id)} title={"Go to " + it.id} onClick={e => { e.preventDefault(); flushSync(() => setShown(true)); p.goTo(it.id); }}>{it.id}</a>;

  const showBtn = softSettled && <button type="button" className="settled-tg" aria-expanded={shown} onClick={() => flushSync(() => setShown(!shown))}>{shown ? "Hide" : "Show"}</button>;

  // On a choice item: Send this item (a pick, or just a comment, goes only when this is pressed), Drop with its confirm step, and the
  // note that a Drop is waiting. Shared by both kinds of choice item.
  const pickBlock = <>
    {(p.canSendPick || (p.droppable && !p.dropping && !held)) && !dropAsk && <div className="pick-actions">
      {p.canSendPick && <button type="button" className="pick-send" disabled={busy === "send"}
        onClick={() => { setBusy("send"); void p.onSendPick?.().finally(() => setBusy("")); }}>Send this item</button>}
      {p.droppable && !p.dropping && !held && <button type="button" className="drop-btn" onClick={() => flushSync(() => setDropAsk(true))}>Drop</button>}
    </div>}
    {dropAsk && <div className="confirm-drop reopen-yes" role="group" aria-labelledby={"cd-" + it.id}
      onKeyDown={e => { if (e.key === "Escape") { e.stopPropagation(); setDropAsk(false); } }}>
      <p className="confirm-q" id={"cd-" + it.id}>Drop {it.title.split(":")[0].length <= 40 && it.title.includes(":") ? it.title.split(":")[0] : it.id}? This removes it from the board.</p>
      <div className="confirm-btns">
        <button type="button" className="confirm-ok" ref={dropOk} disabled={busy === "drop"}
          onClick={() => { setBusy("drop"); void p.onDrop?.().then(() => setDropAsk(false)).finally(() => setBusy("")); }}>Drop it</button>
        <button type="button" className="confirm-cancel" onClick={() => setDropAsk(false)}>Cancel</button>
      </div>
    </div>}
    {p.dropping && <p className="drop-note" role="status">Drop requested: it comes off the board once the request is handled.</p>}
  </>;

  if (type === "question") return <>{group}
    <section data-item={it.id} data-review-question={it.id} data-title={it.title} data-review-type="question" className={"rvcard" + sent + (blockedBy ? " is-blocked" : "") + (p.fixing ? " is-fixing" : "") + (settled ? " settled" : "") + (shown ? " shown" : "")}>
      <div className="rvhead">{rid}{showBtn}<span className="sp" /><span className="st2" />{blocked ?? (held ? <Chip tone="a-yes">Sent, waiting</Chip> : value.skipped ? <Chip tone="skp">{PILL.skip}</Chip> : settled ? <Chip tone="a-yes">Answered (locked)</Chip> : state?.reopened ? <Chip tone="reo">Reopened: {state.reopened}</Chip> : <Chip>Question</Chip>)}{more}</div>
      <h2>{heading}</h2>{settled && !value.skipped && <p className="locked-answer">{value.a}</p>}{content}
      <div className={"rv in-card question" + (blockedBy ? " blocked" : "")} id={"rv-" + it.id}>
        <div className="qrow"><span className="ask">Your answer:</span>{p.skippable && !value.skipped && !settled && !held && !blockedBy ? <button type="button" className="skip-btn" onClick={() => p.onChange({ ...value, skipped: true })}>Skip</button> : null}{value.skipped ? <button type="button" className="unskip-btn" disabled={!!held || !!blockedBy} onClick={() => p.onChange({ ...value, skipped: false })}>Un-skip</button> : null}{it.suggested && !settled && !value.skipped ? <button type="button" className="suggest-btn" onClick={() => p.onChange({ ...value, a: it.suggested })}>Use suggestion</button> : null}</div>
        <textarea ref={qa} className="qans" placeholder="Type your answer" value={value.a ?? ""} disabled={settled || !!held || !!value.skipped} onChange={e => p.onChange({ ...value, a: e.target.value })} />
      </div>
    </section></>;

  if (type === "choice" && it.choices) {
    const picks = (value.v ?? "").split(",").filter(Boolean);
    const named = picks.map(x => (x === "other" ? "Other" : it.choices?.find(c => c.value === x)?.label ?? x)).join(", ");
    return <>{group}
      <section data-item={it.id} data-review-question={it.id} data-title={it.title} data-answer={picks.length ? "pick" : "default"} className={"rvcard is-choice" + sent + (blockedBy ? " is-blocked" : "") + (p.fixing ? " is-fixing" : "") + (settled ? " settled" : "") + (shown ? " shown" : "")}>
        <div className="rvhead">{rid}{showBtn}<span className="sp" /><span className="st2" />{blocked ?? <Chip tone={picks.length ? "a-yes" : ""}>{held ? "Sent, waiting" : settled ? "Answered (locked)" : named || "Not picked"}</Chip>}{more}</div>
        <h2>{heading}</h2>{settled && <p className="locked-answer">{named}{value.o ? `: ${value.o}` : ""}</p>}{content}
        <div className={"rv in-card choice" + (blockedBy ? " blocked" : "")} id={"rv-" + it.id}>
          <Choices id={it.id} title={it.title} options={it.choices} multi={it.multi} value={value} disabled={!!blockedBy || !!held || settled} onChange={p.onChange} />
          <label className="notel"><span>Note (optional)</span><textarea rows={2} disabled={!!blockedBy || !!held || settled} value={note} onChange={e => p.onChange({ ...value, n: e.target.value })} /></label>
          {pickBlock}
        </div>
      </section></>;
  }

  if (type === "choice") {
    const first = p.choices?.[0]?.value, def = p.defaultChoice ?? "";
    const label = (x: string) => p.choices?.find(c => c.value === x)?.label ?? x;
    const pill = blocked ?? (state?.reopened && !v ? <Chip tone="reo">Reopened: {state.reopened}</Chip>
      : <Chip tone={v === first ? "a-yes" : ""}>{v ? label(v) : def ? `Not picked · ${label(def)} (default)` : "Not chosen"}</Chip>);
    return <>{group}
      <section data-item={it.id} data-review-question={it.id} data-title={it.title} data-answer={v ? (v === first ? "pick-first" : "pick") : "default"} className={"rvcard is-choice" + sent + (blockedBy ? " is-blocked" : "") + (p.fixing ? " is-fixing" : "")}>
        <div className="rvhead">{rid}<span className="sp" /><span className="st2" />{pill}{more}</div>
        <h2>{heading}</h2>{content}
        <div className={"rv in-card choice" + (blockedBy ? " blocked" : "")} id={"rv-" + it.id} data-choice={v || def}>
          <div className="rvrow"><span className="ask">Your answer:</span>
            <div className="seg" role="group" aria-label={"Answer for " + it.id}>
              {p.choices?.map((c, i) => { const isDef = !v && c.value === def; return <button key={c.value} type="button" data-v={c.value} aria-pressed={v === c.value} disabled={!!blockedBy || !!held}
                className={(i === 0 ? "first" : "other") + (isDef ? " def" : "")} onClick={() => p.onChange({ ...value, v: v === c.value ? "" : c.value })}>{c.label + (isDef ? " (default)" : "")}</button>; })}
            </div></div>
          <label className="notel"><span>Comments (optional)</span><textarea rows={2} disabled={!!blockedBy || !!held} value={note} onChange={e => p.onChange({ ...value, v, n: e.target.value })} /></label>
          {pickBlock}
        </div>
      </section></>;
  }

  const showNote = v === "chg" || v === "no" || v === "risk" || !!note.trim() || !!value.blocker || noteOpen || !!value.locked || confirmed;
  const pill = blocked ?? (confirmed ? <Chip tone="a-yes">Yes (locked)</Chip> : value.locked ? <Chip tone="skp">{PILL.skip}</Chip> : held ? <Chip tone="a-yes">Sent, waiting</Chip> : settled ? <Chip tone={v === "risk" ? "a-risk" : "a-yes"}>{v === "risk" ? "Accept risk" : "Yes"} (locked)</Chip> : v ? <Chip tone={TONE[v]}>{PILL[v]}</Chip>
    : state?.reopened ? <Chip tone="reo">Reopened: {state.reopened}</Chip> : handled ? <Chip tone="reo">Updated: answer again</Chip> : <Chip>Open</Chip>);
  const pick = (a: string) => {
    // Yes asks first. Pressing the pressed Yes of an unconfirmed Yes asks too, so it can be locked.
    if (canConfirm && (a === "yes" || (a === "" && v === "yes"))) { setCnote(note); flushSync(() => setConfirming(true)); return; }
    if (a === "skip") { if (!confirm("Skip this item? Once skipped it's locked and can't be changed.")) return; p.onChange({ v: "skip", n: note, locked: true }); return; }
    p.onChange({ ...value, v: a, n: note });
    if (a === "chg" && !note.trim()) setTimeout(() => ta.current?.focus());
  };
  return <>{group}
    <section ref={card} data-item={it.id} data-review-question={it.id} data-title={it.title} data-answer={v}
      className={"rvcard" + sent + (softSettled ? " settled" : "") + (confirmed ? " is-confirmed" : "") + (shown ? " shown" : "") + (blockedBy ? " is-blocked" : "") + (p.fixing ? " is-fixing" : "") + (value.blocker ? " is-blocker" : "")}>
      <div className="rvhead">{rid}
        {showBtn}
        <span className="sp" />
        {value.blocker ? <span className="st bkr">Blocker</span> : state?.reopened && v && !blockedBy ? <span className="st reo">Reopened: {state.reopened}</span> : <span className="st2" />}
        {pill}<span className="lock-live" role="status" aria-live="polite">{said}</span>{more}
      </div>
      <h2>{heading}</h2>{confirmed && !shown && note.trim() && <p className="locked-answer">{note}</p>}{content}
      <div className={`rv in-card ${v}` + (locked ? " locked" : "") + (confirmed ? " confirmed" : "") + (blockedBy ? " blocked" : "") + (value.blocker ? " blocker" : "") + ((v === "chg" || v === "risk") && !note.trim() ? " empty" : "")} id={"rv-" + it.id}>
        <div className="rvrow">
          <span className="ask">Your answer:</span>
          <Answer id={it.id} options={optionsFor(it, type, !!p.risk)} value={v} disabled={locked} onChange={pick} />
          {!showNote && !blockedBy && <button type="button" className="add-note" disabled={locked} onClick={() => { setNoteOpen(true); setTimeout(() => ta.current?.focus()); }}>Add a note</button>}
          <span className="sp" />
          <button type="button" className="blocker-btn" disabled={!!held || settled || confirmed} title={p.blockerTitle} onClick={() => {
            const typed = note.trim() || (prompt("What is blocking you? (one line)") ?? "").trim();
            if (typed) p.onBlocker(typed);
          }}>{p.blockerLabel}</button>
        </div>
        <label className="notel" hidden={!showNote}>
          <span><span className="nlt">{v === "chg" ? "What should change (required)" : v === "risk" ? "How the risk is presented (required)" : v === "no" ? "Why (optional)" : "Note"}</span> <span className="need">{v === "risk" ? "Please say how the risk is presented." : "Please say what to change."}</span></span>
          <textarea ref={ta} rows={3} placeholder="Notes (required for Changes and Accept risk)" value={note} disabled={locked && !confirmed} onChange={e => p.onChange({ ...value, v, n: e.target.value })} />
        </label>
        {confirming && <div className="confirm-yes" role="group" aria-labelledby={"cy-" + it.id} onKeyDown={e => { if (e.key === "Escape") { e.stopPropagation(); cancelConfirm(); } }}>
          <p className="confirm-q" id={"cy-" + it.id}>Confirm Yes for {it.id}? This locks the answer. You can still edit the note, and reopen it later with a reason.</p>
          <label className="notel"><span className="nlt">Note (optional)</span>
            <textarea rows={2} value={cnote} onChange={e => setCnote(e.target.value)} /></label>
          <div className="confirm-btns">
            <button type="button" className="confirm-ok" ref={okBtn} onClick={doConfirm}>Confirm Yes</button>
            <button type="button" className="confirm-cancel" onClick={cancelConfirm}>Cancel</button>
          </div>
        </div>}
        {confirmed && !reopening && <div className="reopen-row"><button type="button" className="reopen-btn" onClick={() => flushSync(() => setReopening(true))}>Reopen…</button></div>}
        {confirmed && reopening && <div className="reopen-yes" role="group" aria-labelledby={"ry-" + it.id} onKeyDown={e => { if (e.key === "Escape") { e.stopPropagation(); setReopening(false); setWhyErr(""); } }}>
          <p className="confirm-q" id={"ry-" + it.id}>Reopen {it.id}? The Yes unlocks and the item is open again. Your reason is saved with the item.</p>
          <label className="notel"><span className="nlt">Why are you reopening it? (required)</span>
            <textarea ref={whyTa} rows={2} value={why} aria-invalid={!!whyErr} aria-describedby={"re-" + it.id} onChange={e => { setWhy(e.target.value); setWhyErr(""); }} /></label>
          <p className="confirm-err" id={"re-" + it.id} role="alert">{whyErr}</p>
          <div className="confirm-btns">
            <button type="button" className="confirm-ok" onClick={() => void doReopen()}>Reopen</button>
            <button type="button" className="confirm-cancel" onClick={() => { setReopening(false); setWhyErr(""); }}>Cancel</button>
          </div>
        </div>}
      </div>
    </section></>;
}
