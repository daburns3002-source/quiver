// Web Audio loops: a decoded buffer looped by the source itself is sample
// exact, so the seam heard here is the seam in the file.
let ctx = null;
const buffers = {};
let playing = null; // { id, src, startedAt, offset }

function context() {
  if (!ctx) ctx = new (window.AudioContext || window.webkitAudioContext)();
  return ctx;
}

async function decode(b64) {
  const bytes = Uint8Array.from(atob(b64), (c) => c.charCodeAt(0));
  return context().decodeAudioData(bytes.buffer);
}

async function buffer(id) {
  if (buffers[id]) return buffers[id];
  try {
    buffers[id] = await decode(TRACKS[id].ogg);
  } catch (e) {
    if (!TRACKS[id].mp3) {
      note("This browser can't play Ogg; open the page in Chrome or Edge.");
      throw e;
    }
    buffers[id] = await decode(TRACKS[id].mp3); // no Ogg in this browser; MP3 may add a tiny gap at the seam
  }
  return buffers[id];
}

function stop() {
  if (!playing) return;
  try { playing.src.stop(); } catch (e) {}
  document.querySelectorAll(".play.playing").forEach((b) => b.classList.remove("playing"));
  playing = null;
}

async function play(id, offset) {
  const c = context();
  if (c.state === "suspended") await c.resume();
  const b = await buffer(id);
  stop();
  const src = c.createBufferSource();
  src.buffer = b;
  src.loop = true;
  const region = TRACKS[id].loop; // an intro: once from the top, then round the region
  if (region) {
    src.loopStart = region[0];
    src.loopEnd = region[1];
  }
  src.connect(c.destination);
  const at = c.currentTime + 0.03;
  src.start(at, Math.max(0, offset));
  const [from, to] = region || [0, b.duration];
  playing = { id, src, startedAt: at, offset: Math.max(0, offset), from, to };
  document.querySelector(`[data-loop="${id}"]`).classList.add("playing");
}

function tick() {
  document.querySelectorAll("[data-head]").forEach((el) => {
    let w = 0;
    if (playing && playing.id === el.dataset.head) {
      let t = Math.max(0, context().currentTime - playing.startedAt + playing.offset);
      if (t >= playing.to) t = playing.from + ((t - playing.from) % (playing.to - playing.from));
      w = (t / playing.to) * 100;
    }
    el.style.width = w + "%";
  });
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);

document.addEventListener("click", async (e) => {
  const loop = e.target.closest("[data-loop]");
  if (loop) {
    const id = loop.dataset.loop;
    if (playing && playing.id === id) stop();
    else play(id, 0).catch(() => {});
    return;
  }
  const seam = e.target.closest("[data-seam]");
  if (seam) {
    const id = seam.dataset.seam;
    const b = await buffer(id).catch(() => null);
    const end = TRACKS[id].loop ? TRACKS[id].loop[1] : b && b.duration;
    if (b) play(id, end - 4).catch(() => {});
  }
});

// The pick lives in the page's database (COLLECTION/<track>), so Claude reads
// it back; the copy button is the fallback.
let db = null;

function note(text) {
  const el = document.getElementById("saved");
  el.hidden = false;
  el.textContent = text;
}

function render() {
  const chosen = document.querySelector(`input[name="${TRACK}"]:checked`);
  document.querySelectorAll(`input[name="${TRACK}"]`).forEach((input) => {
    input.closest(".opt").classList.toggle("chosen", input.checked);
  });
  document.getElementById("summary").textContent = chosen ? `Picked ${chosen.value}` : "No pick yet.";
  try { localStorage.setItem(COLLECTION + "/" + TRACK, chosen ? chosen.value : ""); } catch (e) {}
}

function restore(value) {
  const input = value && document.querySelector(`input[name="${TRACK}"][value="${value}"]`);
  if (input) input.checked = true;
  render();
}

document.addEventListener("change", async (e) => {
  if (!e.target.matches('input[type="radio"]')) return;
  render();
  if (!db) return;
  try {
    await db.doc(COLLECTION + "/" + e.target.name).set({ variant: e.target.value, track: NAMES[e.target.name] });
    note("Saved. I'll read your pick from here.");
  } catch (err) {
    note("Couldn't save here; use Copy my pick and paste it to me.");
  }
});

document.getElementById("copy").addEventListener("click", async () => {
  const chosen = document.querySelector(`input[name="${TRACK}"]:checked`);
  const text = "Music pick — " + NAMES[TRACK] + ": " + (chosen ? chosen.value : "none yet");
  const button = document.getElementById("copy");
  try {
    await navigator.clipboard.writeText(text);
    button.textContent = "Copied";
  } catch (err) {
    document.getElementById("summary").textContent = text;
    button.textContent = "Copy the line above";
  }
  setTimeout(() => (button.textContent = "Copy my pick"), 1800);
});

try { restore(localStorage.getItem(COLLECTION + "/" + TRACK) || ""); } catch (e) { render(); }

(async () => {
  try {
    db = window.claude && window.claude.use ? await window.claude.use("db") : null;
  } catch (e) {
    db = null;
  }
  if (!db) return;
  try {
    const snap = await db.doc(COLLECTION + "/" + TRACK).get();
    const body = snap && snap.exists ? snap.data() : null;
    if (body && typeof body.variant === "string") {
      restore(body.variant);
      note("Your saved pick is loaded.");
    }
  } catch (e) {}
})();
