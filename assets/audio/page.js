// Web Audio, so a sound can be retriggered instantly and repeated in rhythm.
let ctx = null;
const buffers = {};

function context() {
  if (!ctx) ctx = new (window.AudioContext || window.webkitAudioContext)();
  return ctx;
}

async function buffer(id) {
  if (buffers[id]) return buffers[id];
  const bytes = Uint8Array.from(atob(SOUNDS[id]), (c) => c.charCodeAt(0));
  buffers[id] = await context().decodeAudioData(bytes.buffer);
  return buffers[id];
}

async function play(id, repeat, gap) {
  const c = context();
  if (c.state === "suspended") await c.resume();
  const b = await buffer(id);
  const start = c.currentTime + 0.02;
  for (let i = 0; i < repeat; i++) {
    const src = c.createBufferSource();
    src.buffer = b;
    src.connect(c.destination);
    src.start(start + i * gap);
  }
}

document.addEventListener("click", (e) => {
  const btn = e.target.closest("[data-play]");
  if (!btn) return;
  const repeat = Number(btn.dataset.repeat || 1);
  const gap = Number(btn.dataset.gap || 0);
  play(btn.dataset.play, repeat, gap).catch(() => {});
  btn.classList.add("on");
  setTimeout(() => btn.classList.remove("on"), 150);
});

// Picks live in the page's database (picks/<sound>), so Claude reads them
// back. localStorage keeps them for this browser too, and the copy button
// is the fallback when the database is not available.
let db = null;

function picked() {
  const out = {};
  for (const key of Object.keys(NAMES)) {
    const chosen = document.querySelector(`input[name="${key}"]:checked`);
    document.querySelectorAll(`input[name="${key}"]`).forEach((input) => {
      input.closest(".opt").classList.toggle("chosen", input.checked);
    });
    if (chosen) out[key] = chosen.value;
  }
  return out;
}

function summary() {
  const out = picked();
  return Object.keys(out).map((key) => `${NAMES[key]}: ${out[key]}`);
}

function render() {
  const out = picked();
  const count = Object.keys(out).length;
  const total = Object.keys(NAMES).length;
  document.getElementById("summary").textContent = count ? `${count} of ${total} picked` : "No picks yet.";
  try { localStorage.setItem("picks", JSON.stringify(out)); } catch (e) {}
}

function restore(picks) {
  for (const [key, value] of Object.entries(picks)) {
    const input = document.querySelector(`input[name="${key}"][value="${value}"]`);
    if (input) input.checked = true;
  }
  render();
}

function note(text) {
  const el = document.getElementById("saved");
  el.hidden = false;
  el.textContent = text;
}

async function save(key, value) {
  if (!db) return;
  try {
    await db.doc("picks/" + key).set({ variant: value, sound: NAMES[key] });
    note("Saved. I'll read your picks from here.");
  } catch (e) {
    note("Couldn't save here; use Copy my picks and paste them to me.");
  }
}

document.addEventListener("change", (e) => {
  if (!e.target.matches('input[type="radio"]')) return;
  render();
  save(e.target.name, e.target.value);
});

document.getElementById("copy").addEventListener("click", async () => {
  const text = "Sound picks — " + (summary().join(", ") || "none yet");
  const button = document.getElementById("copy");
  try {
    await navigator.clipboard.writeText(text);
    button.textContent = "Copied";
  } catch (e) {
    const p = document.getElementById("summary");
    p.textContent = text;
    const r = document.createRange();
    r.selectNodeContents(p);
    const s = window.getSelection();
    s.removeAllRanges();
    s.addRange(r);
    button.textContent = "Selected, copy it";
  }
  setTimeout(() => (button.textContent = "Copy my picks"), 1800);
});

let local = {};
try { local = JSON.parse(localStorage.getItem("picks") || "{}") || {}; } catch (e) {}
restore(local);

(async () => {
  try {
    db = window.claude && window.claude.use ? await window.claude.use("db") : null;
  } catch (e) {
    db = null;
  }
  if (!db) return;
  try {
    const snap = await db.collection("picks").get();
    const picks = {};
    snap.docs.forEach((d) => {
      const body = d.data();
      if (body && typeof body.variant === "string") picks[d.id] = body.variant;
    });
    restore(picks);
    if (snap.size) note("Your saved picks are loaded.");
  } catch (e) {}
})();
