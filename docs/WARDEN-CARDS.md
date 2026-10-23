# The Warden's cards — a proposal

Written overnight on 2026-10-23 for the owner to decide. Nothing here is
built.

## The problem

The Warden swings a greatsword (`Combat/MeleeSystem`). It draws from the same
28 cards as the Ranger, and **15 of them do nothing for it**, but they are
still dealt to it. A Warden who picks Multishot has wasted the pick.

What a swing takes from the draft today: the player's damage, attack speed
(cooldown), and from the lead shot the pipeline would build, crit chance, crit
damage and Blaze's burn.

| Works for the Warden (13) | Does nothing for it (15) |
|---|---|
| Strength, Precision, Deadly Strike, Blaze | Multishot, Front Arrow, Double Shot |
| Dual Bows, Momentum | Rear Arrow, Side Arrows, Diagonal Arrows |
| Agility, Lightfoot, Vitality, Mending | Piercing Shot, Swift Arrows, Bouncy Wall |
| Bloodthirst, Second Wind, Heal | Tracking Eye, Long Shot, Ricochet |
| | Blast Arrows, Soul Chain, Overdraw |

The last three in the right column are on-hit and charge effects the arrow
applies in `ProjectileSystem`/`FiringSystem` and the swing simply does not yet;
the other twelve shape a volley or an arrow's flight, which a swing does not
have.

## Options

**A. Don't deal them.** Each card says which attacks it works with (data in
`Config/Abilities`, read by the draft), so the Warden is never offered a dead
card. Small, safe, and true to non-negotiable 1 (no `if` on an ability name).
The cost: the Warden's pool shrinks to 13, so its runs vary less, and Mythic
and Legendary picks thin out (it keeps Dual Bows and Second Wind, loses
Tracking Eye, Multishot and Soul Chain).

**B. Give them melee meanings.** The same card does something to a swing. Some
map directly onto mechanics that already exist:

| Card | For the Warden |
|---|---|
| Blast Arrows | A shockwave where the blow lands (the existing splash). |
| Soul Chain | Struck enemies share damage (the existing link). |
| Overdraw | Standing still charges the swing too (the existing charge). |
| Ricochet | The blow also strikes the nearest enemy outside the box. |
| Piercing Shot | A deeper box. |
| Side Arrows / Diagonal Arrows | A wider box. |
| Rear Arrow | A back-swipe behind the Warden. |
| Swift Arrows | Faster swings. |
| Long Shot | More reach. |
| Multishot / Double Shot | The swing echoes: a second, weaker blow. |
| Front Arrow | More damage to the first enemy struck. |
| Tracking Eye | The Warden lunges a step toward its target as it swings. |
| Bouncy Wall | Enemies struck are knocked into walls for extra damage. |

The cards' names and art still say "arrow", so they would need a Warden
wording on the card, at least.

**C. A Warden card set.** New skills built for a greatsword (cleave, parry,
whirlwind, ground slam…), with their own art made with Codex like the
others. The most distinctive, and the most work: design, art, balance.

## Recommendation

**A now, then C over time, borrowing from B where a mapping is natural.**

A fixes the immediate problem (dead picks) in a small, data-only change. The
first three rows of B (Blast Arrows, Soul Chain, Overdraw) are nearly free,
since the mechanic already exists and only the swing has to call it, so they
can come straight back into the Warden's pool with a melee wording. The rest
of B bends arrow cards into shapes the names fight; those slots are better
filled by real Warden cards (C) as they are designed.

## What I need from you

1. A, B, C, or a mix?
2. If B, should the cards keep their names with a Warden wording, or get
   Warden names?
3. The Warden's numbers are a first pass (`Config/Classes.Warden`: reach 7,
   ×1.6 damage, ×1.2 cooldown, slam ×1.5). Worth a playtest before any of
   this.
