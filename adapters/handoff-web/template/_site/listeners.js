/* The Listeners switch on the home page: On or Paused, and "Pause until HH:MM". The state lives on the server
   (GET/POST /_listeners, stored in _saved/_listeners.json), so every tab, agent and hook sees the same one. While paused,
   agents are not woken and nothing is lost: Send still saves to the inbox, and turning listeners On delivers what queued. */
(function () {
  "use strict";
  var box = document.querySelector("[data-listeners]");
  if (!box) return;
  var on = box.querySelector('[data-ls="on"]'), off = box.querySelector('[data-ls="pause"]'), until = box.querySelector('[data-ls="until"]');
  var time = box.querySelector("input[type=time]"), out = box.querySelector(".ls-state"), live = box.querySelector(".ls-live");

  function clock(iso) {
    var d = new Date(iso);
    return isNaN(d) ? "" : d.toLocaleTimeString("en-US", { hour: "2-digit", minute: "2-digit", hourCycle: "h23" });
  }
  function show(st) {
    var p = !!(st && st.paused);
    on.setAttribute("aria-pressed", String(!p));
    off.setAttribute("aria-pressed", String(p));
    box.classList.toggle("paused", p);
    // The two labels (On, Paused) never change; the pressed one is the state. The note below is for the paused case only, so
    // nothing extra is written while listeners are on, and nothing replaces a label.
    out.textContent = p ? (st.until ? "Back on at " + clock(st.until) + ". " : "") + "Sends are saved and delivered when you turn listeners on." : "";
    out.hidden = !p;
    live.textContent = p ? "Listeners paused" + (st.until ? " until " + clock(st.until) : "") : "Listeners on";
    box.setAttribute("data-ready", "1");
  }
  function get() {
    return fetch("/_listeners", { cache: "no-store" }).then(function (r) { return r.json(); }).then(show).catch(function () { out.hidden = false; out.textContent = "Can't reach the site"; });
  }
  function set(body) {
    return fetch("/_listeners", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(body), cache: "no-store" })
      .then(function (r) { return r.json().then(function (j) { if (!r.ok) throw new Error(j.error || r.status); return j; }); })
      .then(show)
      .catch(function (e) { out.hidden = false; out.textContent = "Not changed: " + e.message; });
  }
  on.addEventListener("click", function () { set({ paused: false }); });
  off.addEventListener("click", function () { set({ paused: true }); });
  until.addEventListener("click", function () { set({ paused: true, until: time.value || "06:00" }); });
  // Another tab, an agent or the clock may have changed it: look again now and then, and when this tab comes back.
  setInterval(function () { if (!document.hidden) get(); }, 10000);
  document.addEventListener("visibilitychange", function () { if (!document.hidden) get(); });
  get();
})();
