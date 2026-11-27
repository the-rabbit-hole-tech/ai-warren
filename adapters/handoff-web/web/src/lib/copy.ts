// Click handling for the small inline Copy buttons that inline(text, {copy: true}) writes into the page.

/** Copy text: the clipboard API where the browser allows it, else a hidden textarea, else select the source text. */
export async function copyText(text: string, src?: Element | null): Promise<"copied" | "selected" | "failed"> {
  try {
    if (navigator.clipboard && window.isSecureContext) { await navigator.clipboard.writeText(text); return "copied"; }
  } catch { /* fall through to the older route */ }
  const ta = document.createElement("textarea");
  ta.value = text; ta.readOnly = true; ta.style.cssText = "position:fixed;top:0;left:0;opacity:0";
  document.body.appendChild(ta); ta.select();
  try { ta.setSelectionRange(0, text.length); } catch { /* some engines refuse on a hidden box */ }
  let ok = false;
  try { ok = document.execCommand("copy"); } catch { ok = false; }
  ta.remove();
  if (ok) return "copied";
  if (src) { const r = document.createRange(); r.selectNodeContents(src); const sel = window.getSelection(); sel?.removeAllRanges(); sel?.addRange(r); return "selected"; }
  return "failed";
}

/** What a button says when nothing could copy and the text is selected for the person to copy by hand. */
export const HOLD = "Press and hold to copy";

/** Copy for a text button: show Copied, or HOLD when the text could only be selected, then put the idle label back. */
export async function copyButton(b: HTMLElement, text: string, src: Element | null | undefined, idle: string): Promise<void> {
  const done = await copyText(text, src);
  b.textContent = done === "copied" ? "Copied" : done === "selected" ? HOLD : idle;
  const t = timers.get(b); if (t) clearTimeout(t);
  timers.set(b, window.setTimeout(() => { b.textContent = idle; }, done === "selected" ? 5000 : 1500));
}

/** Copy text that has no element on the page: when nothing can copy it, a prompt shows it selected. */
export async function copyOrPrompt(text: string): Promise<boolean> {
  if ((await copyText(text)) === "copied") return true;
  window.prompt(HOLD, text);
  return false;
}

const timers = new WeakMap<Element, number>();

/** One delegated click handler for every .copy-inline button on the page. */
export async function copyInline(e: Event): Promise<void> {
  const b = (e.target as Element | null)?.closest?.("button.copy-inline") as HTMLButtonElement | null;
  if (!b) return;
  const done = await copyText(b.dataset.copy ?? "", b.previousElementSibling);
  b.dataset.state = done; b.title = done === "copied" ? "Copied" : done === "selected" ? HOLD : "";
  const t = timers.get(b); if (t) clearTimeout(t);
  timers.set(b, window.setTimeout(() => { delete b.dataset.state; b.removeAttribute("title"); }, 1500));
}
