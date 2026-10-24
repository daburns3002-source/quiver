"""Takes for the upgrade effects' sounds, pulled from CC0 recordings on
Freesound, rendered like freesound.py's.

    python -I effect_sounds.py <out_dir> <cache_dir> [round] [used manifest]

Round 12 (owner, 2026-10-24): sounds for ten upgrade effects. Each effect
has search terms; the best-rated CC0 results (Freesound's own licence
filter) are fetched, each sound's page is read to confirm "Creative Commons
0" before it is used (CC0: public domain, no credit owed, fine in a
commercial game), and the first TAKES are cut to the effect's length:
leading silence trimmed, faded out, levelled. A game's ripped audio is
never used. Sources are not kept in the repo; they download into
<cache_dir>. Credits go in the manifest's notes all the same.
"""
import json
import os
import re
import subprocess
import sys
import urllib.parse
import urllib.request

import numpy as np
from scipy.io import wavfile

SR = 44100
TAKES = 4
FF = os.environ.get("FFMPEG", "ffmpeg")
UA = {"User-Agent": "Mozilla/5.0"}

# effect: (search terms, seconds kept)
EFFECTS = {
    "fx_blaze": (["fire ignite", "flame burst whoosh", "torch ignite"], 1.2),
    "fx_heal": (["magic heal", "healing spell", "potion drink sparkle"], 1.6),
    "fx_overdraw": (["power up charge", "charging up energy", "magic charge up", "bow string pull"], 1.6),
    "fx_blast_arrows": (["small explosion", "magic explosion", "explosion pop"], 1.3),
    "fx_soul_chain": (["chain rattle", "chain whip", "magic chain"], 1.0),
    "fx_heavy_blade": (["sword heavy impact", "metal slam ground", "heavy hit impact"], 1.3),
    "fx_bloodletting": (["magic drain", "life drain spell", "squelch"], 1.1),
    "fx_earthbreaker": (["ground slam rocks", "earthquake impact", "rock crumble impact", "rock impact", "stone smash", "boulder drop", "debris explosion"], 2.0),
    "fx_chain_lightning": (["electric zap", "lightning spark", "electricity arc"], 0.9),
    "fx_meteor": (["fireball whoosh", "meteor falling", "fire whoosh pass"], 1.4),
}


# effect: words that rule a result out by its title (the wrong kind of sound)
EXCLUDE = {
    "fx_overdraw": ["down"],
    "fx_soul_chain": ["domino", "8-bit", "door"],
    "fx_earthbreaker": ["flashlight", "plastic", "metal"],
    "fx_meteor": ["lighting a fire"],
}


# Round 13 (owner, 2026-10-24): "the others need reworked sounds". New
# searches for the five whose round-12 takes were all turned down; nothing
# already heard (the round-12 manifest's sources) is offered again.
ROUND_13 = {
    "fx_blaze": (["fire whoosh burst", "flame ignite magic", "fireball cast", "torch whoosh"], 1.2),
    "fx_overdraw": (["bow string tension", "bow draw", "arrow nock draw", "string stretch creak"], 1.6),
    "fx_soul_chain": (["magic chain link", "chain clank", "metal chain snap", "chain impact"], 1.0),
    "fx_heavy_blade": (["sword impact ground", "heavy sword hit", "weapon impact heavy", "axe hit wood"], 1.3),
    "fx_earthbreaker": (["ground pound", "earth slam", "boulder impact debris", "stone break explosion"], 2.0),
}
ROUNDS = {"12": EFFECTS, "13": ROUND_13}


def get(url):
    return urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=40).read().decode("utf-8", "replace")


def search(term):
    q = urllib.parse.quote(term)
    url = (
        f"https://freesound.org/search/?q={q}"
        "&f=license:%22Creative+Commons+0%22+duration:[0+TO+6]&s=Rating+highest+first"
    )
    seen = []
    for _, sid in re.findall(r'href="/people/([^/]+)/sounds/(\d+)/"', get(url)):
        if sid not in seen:
            seen.append(sid)
    return seen


def page_facts(sid):
    """(title, author, preview url) if the sound's own page says CC0, else None."""
    page = get(f"https://freesound.org/s/{sid}/")
    if "Creative Commons 0" not in page and "publicdomain/zero" not in page:
        return None
    title = re.search(r"<title>\s*Freesound\s*-\s*\"?([^\"<]+?)\"?\s*by\s*([^<]+?)\s*</title>", page)
    start = page.index("https://cdn.freesound.org/previews/")
    url = page[start : page.index(".mp3", start) + 4]
    return (title.group(1).strip() if title else sid, title.group(2).strip() if title else "?", url)


def decode(path):
    raw = subprocess.run(
        [FF, "-loglevel", "error", "-i", path, "-f", "f32le", "-ac", "1", "-ar", str(SR), "-"],
        check=True,
        capture_output=True,
    ).stdout
    return np.frombuffer(raw, dtype=np.float32).copy()


def cut(x, seconds):
    """Leading silence off, `seconds` kept with a fade, levelled to -1 dBFS."""
    level = np.abs(x)
    gate = max(level.max() * 0.04, 1e-4)
    on = int(np.argmax(level > gate))
    x = x[max(0, on - int(0.005 * SR)) : on + int(seconds * SR)]
    fade = min(len(x), int(0.25 * SR))
    x[-fade:] *= np.linspace(1, 0, fade) ** 2
    x[: int(0.003 * SR)] *= np.linspace(0, 1, int(0.003 * SR))
    peak = np.abs(x).max()
    return x * (10 ** (-1 / 20) / peak) if peak > 0 else x


def main():
    out, cache = sys.argv[1], sys.argv[2]
    effects = ROUNDS[sys.argv[3] if len(sys.argv) > 3 else "12"]
    used = set()
    if len(sys.argv) > 4:
        for takes in json.load(open(sys.argv[4], encoding="utf-8")).values():
            used.update(t.get("source") for t in takes)
    os.makedirs(out, exist_ok=True)
    os.makedirs(cache, exist_ok=True)
    manifest_path = os.path.join(out, "manifest.json")
    manifest = json.load(open(manifest_path)) if os.path.exists(manifest_path) else {}
    for name, (terms, seconds) in effects.items():
        takes, tried = [], set(used)
        for term in terms:
            for sid in search(term)[:6]:
                if len(takes) >= TAKES or sid in tried:
                    continue
                tried.add(sid)
                facts = page_facts(sid)
                if not facts:
                    print(f"  {name}: {sid} not CC0 on its page, skipped")
                    continue
                if any(word in facts[0].lower() for word in EXCLUDE.get(name, [])):
                    continue
                path = os.path.join(cache, sid + ".mp3")
                if not os.path.exists(path):
                    open(path, "wb").write(urllib.request.urlopen(urllib.request.Request(facts[2], headers=UA), timeout=40).read())
                takes.append((sid, facts[0], facts[1], term))
            if len(takes) >= TAKES:
                break
        manifest[name] = []
        for letter, (sid, title, author, term) in zip("abcd", takes):
            x = cut(decode(os.path.join(cache, sid + ".mp3")), seconds)
            base = os.path.join(out, f"{name}_{letter}")
            wavfile.write(base + ".wav", SR, (np.clip(x, -1, 1) * 32767).astype(np.int16))
            subprocess.run([FF, "-y", "-loglevel", "error", "-i", base + ".wav", "-b:a", "160k", base + ".mp3"], check=True)
            manifest[name].append({
                "variant": letter,
                "file": os.path.basename(base) + ".wav",
                "note": f"\"{title}\" by {author} (Freesound {sid}, CC0)",
                "ms": round(len(x) / SR * 1000),
                "source": sid,
            })
        print(f"{name}: {len(manifest[name])} takes")
    json.dump(manifest, open(manifest_path, "w"), indent=1)


if __name__ == "__main__":
    main()
