// Copy on any address, in a real Chrome driven over the DevTools protocol (real clicks, so the browser counts them as
// a person's). Run by tests/test_copy_any_address.py:
//   node tests/js/copy_cdp.test.mjs <chrome> <profile dir> <base url>[,<base url>...]
// The first base is http://127.0.0.1 (a secure context); a LAN address is not, so the clipboard API is missing there.
// Each address: the clipboard text after every kind of Copy button, then with the older copy command turned off, a
// button that says "Press and hold to copy" with the text selected, all at 390 px wide.
import assert from "node:assert";
import { spawn } from "node:child_process";
import { readFileSync } from "node:fs";

const [chrome, profile, bases] = process.argv.slice(2);
const tick = ms => new Promise(r => setTimeout(r, ms));
const proc = spawn(chrome, ["--headless=new", "--no-sandbox", "--disable-gpu", "--no-first-run", "--remote-debugging-port=0",
  "--remote-allow-origins=*", `--user-data-dir=${profile}`, "about:blank"], { stdio: "ignore" });
let wsUrl = "";
for (let i = 0; i < 200 && !wsUrl; i++) {
  await tick(50);
  try { const [port, path] = readFileSync(`${profile}/DevToolsActivePort`, "utf8").trim().split("\n"); wsUrl = `ws://127.0.0.1:${port}${path}`; } catch { /* not up yet */ }
}
assert.ok(wsUrl, "Chrome did not start");
const ws = new WebSocket(wsUrl);
await new Promise((r, j) => { ws.onopen = r; ws.onerror = j; });
let nextId = 1; const waiting = new Map(), events = [];
ws.onmessage = m => { const d = JSON.parse(m.data); if (d.id) { const w = waiting.get(d.id); waiting.delete(d.id); d.error ? w.j(new Error(d.error.message)) : w.r(d.result); } else events.push(d); };
const send = (method, params = {}, sessionId) => new Promise((r, j) => { const id = nextId++; waiting.set(id, { r, j }); setTimeout(() => j(new Error("no answer to " + method)), 15000).unref(); ws.send(JSON.stringify({ id, method, params, sessionId })); });

let fails = 0;
async function t(name, fn) { try { await fn(); console.log("ok   " + name); } catch (e) { fails++; console.log("FAIL " + name + "\n     " + e.message); } }

async function open(base, path) {
  const { targetId } = await send("Target.createTarget", { url: "about:blank" });
  const { sessionId } = await send("Target.attachToTarget", { targetId, flatten: true });
  const s = (m, p) => send(m, p, sessionId);
  const ev = async (expression) => {
    const r = await s("Runtime.evaluate", { expression, awaitPromise: true, returnByValue: true, userGesture: true });
    if (r.exceptionDetails) throw new Error(r.exceptionDetails.exception?.description ?? r.exceptionDetails.text);
    return r.result.value;
  };
  await s("Emulation.setDeviceMetricsOverride", { width: 390, height: 844, deviceScaleFactor: 1, mobile: false });
  await s("Page.enable");
  // No dialog may stand in the way of a click: an alert after a copy, a confirm, the prompt for a blocker's note.
  await s("Page.addScriptToEvaluateOnNewDocument", { source: `window.alert = () => {}; window.confirm = () => true; window.prompt = () => "stuck";` });
  await s("Page.navigate", { url: base + path });
  for (let i = 0; i < 200; i++) { if (await ev(`!!document.querySelector(".rvbar .cnt, main")`).catch(() => false)) break; await tick(50); }
  await tick(400);
  try { await send("Browser.grantPermissions", { origin: new URL(base).origin, permissions: ["clipboardReadWrite", "clipboardSanitizedWrite"] }); } catch { /* an insecure origin cannot be granted */ }
  // A real click: scroll to it, then press and release at its centre.
  const click = async (selector, which = 0) => {
    const box = await ev(`(() => { const e = [...document.querySelectorAll(${JSON.stringify(selector)})].filter(x => x.offsetParent)[${which}]; if (!e) return null;
      e.scrollIntoView({ block: "center" }); const r = e.getBoundingClientRect(); return { x: r.x + r.width / 2, y: r.y + r.height / 2 }; })()`);
    assert.ok(box, "no visible " + selector);
    await s("Input.dispatchMouseEvent", { type: "mousePressed", x: box.x, y: box.y, button: "left", clickCount: 1 });
    await s("Input.dispatchMouseEvent", { type: "mouseReleased", x: box.x, y: box.y, button: "left", clickCount: 1 });
    await tick(250);
  };
  // What is on the clipboard now: pasted into a text box, which works on any address.
  const pasted = async () => {
    await ev(`(() => { let t = document.getElementById("__paste"); if (!t) { t = document.createElement("textarea"); t.id = "__paste"; t.style.cssText = "position:fixed;bottom:0;left:0;width:50px;height:20px"; document.body.appendChild(t); } t.value = ""; t.focus(); })()`);
    await s("Input.dispatchKeyEvent", { type: "keyDown", key: "v", code: "KeyV", modifiers: process.platform === "darwin" ? 4 : 2, commands: ["paste"] });
    await s("Input.dispatchKeyEvent", { type: "keyUp", key: "v", code: "KeyV" });
    await tick(150);
    return ev(`document.getElementById("__paste").value`);
  };
  return { ev, click, pasted, s, targetId };
}

for (const base of bases.split(",")) {
  const secure = base.startsWith("http://127.0.0.1");
  const where = (secure ? "127.0.0.1 (secure)" : base + " (not secure)") + ": ";

  await t(where + "the address is the kind it should be", async () => {
    const p = await open(base, "/demo/cp-ref");
    assert.strictEqual(await p.ev("window.isSecureContext"), secure);
    assert.strictEqual(await p.ev("!!navigator.clipboard"), secure);
  });

  await t(where + "a step's copy block and an inline Copy put the exact text on the clipboard", async () => {
    const p = await open(base, "/demo/cp-ref");
    await p.click("button.copy-cmd");
    assert.strictEqual(await p.pasted(), "kubectl get pods -n warren");
    assert.strictEqual(await p.ev(`document.querySelector("button.copy-cmd").textContent`), "Copied");
    await p.click("button.copy-inline");
    assert.strictEqual(await p.pasted(), "http://burrow.lan:5390/");
  });

  await t(where + "Copy results and Copy blockers only", async () => {
    const p = await open(base, "/demo/cp-copyroute");
    await p.click(".rvbar .copy");
    assert.match(await p.pasted(), /^Review: Copy route \(\/demo\/cp-copyroute\)\n- \[r1\] NOT ANSWERED: A module repo\n/);
    await p.click('[data-review-question="r1"] .blocker-btn');
    assert.match(await p.pasted(), /^BLOCKER: Copy route \(\/demo\/cp-copyroute\)\n- \[r1\] A module repo\n/);
  });

  await t(where + "a closed round's Copy results", async () => {
    const p = await open(base, "/demo/cp-history");
    await p.click("details#rvhist > summary");
    await p.click("details.rvhist-round > summary");
    await p.click("button.hist-copy");
    assert.strictEqual(await p.pasted(), "Round 1: History\n- [r1] NO: A module repo");
  });

  await t(where + "when the copy command fails too, the text is selected and the button says Press and hold to copy, at 390 px", async () => {
    const p = await open(base, "/demo/cp-ref");
    await p.ev(`document.execCommand = () => false; if (navigator.clipboard) navigator.clipboard.writeText = () => Promise.reject(new Error("blocked"))`);
    await p.click("button.copy-cmd");
    assert.strictEqual(await p.ev(`document.querySelector("button.copy-cmd").textContent`), "Press and hold to copy");
    assert.strictEqual(await p.ev(`getSelection().toString().trim()`), "kubectl get pods -n warren");
    const fit = await p.ev(`(() => { const b = document.querySelector("button.copy-cmd").getBoundingClientRect();
      return { right: Math.round(b.right), left: Math.round(b.left), page: document.documentElement.scrollWidth }; })()`);
    assert.ok(fit.left >= 0 && fit.right <= 390 && fit.page <= 390, JSON.stringify(fit));
    await tick(5200);
    assert.strictEqual(await p.ev(`document.querySelector("button.copy-cmd").textContent`), "Copy");
    await p.click("button.copy-inline");
    assert.strictEqual(await p.ev(`document.querySelector("button.copy-inline").title`), "Press and hold to copy");
  });

  await t(where + "the same page fits 390 px wide", async () => {
    const p = await open(base, "/demo/cp-ref");
    assert.ok(await p.ev(`document.documentElement.scrollWidth <= 390`), "the page scrolls sideways");
  });
}
ws.close(); proc.kill();
process.exit(fails ? 1 : 0);
