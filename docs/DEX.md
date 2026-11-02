# The dexes

The Dex Hall's three books (owner, 2026-10-25: Enemy, Weapon and Pet codexes,
"a 2D book with a little page turn frame animation every time the page is
turned", entries not yet found shown as black silhouettes; 2026-11-01: "start
on the dex screens").

Walk up to the Dex Hall in the lobby and press E.

## What a book holds

Nothing in a dex is new data. The three books are three readings of configs
the game already keeps (`Util/DexBook`, pure, pinned by `tests/DexBook.spec`):

| Book | From | Found when |
|---|---|---|
| Enemies | `Config/NewEnemies` | met (`Profile.enemiesSeen`) |
| Weapons | `Config/WeaponStats` + `Config/ShopAssets` | owned (`Profile.weapons`) |
| Pets | `Config/Pets` + `Config/GearAssets` | hatched (`Profile.pets`) |

A pet no egg holds is still in its book: a dex is a record of the world, not
of what is obtainable this week. A **benched** enemy is not, because it cannot
be met at all and would be a slot that can never be anything but a silhouette.
Nothing with no picture is in a book either, since a slot with nothing in it
cannot even be a silhouette.

That keeps the owner's rule true (2026-11-01): *"anytime the new enemy card
comes up for a player that means it is now unlocked for them in the dex."*
`RunSession.meetEnemy` writes the dex flag in the same block that fires the
card, and `tests/DexBook.spec` pins the two **sets** equal -- every enemy that
can show a card is in the book, and the book holds nothing that never can.

A weapon's big picture is its 2D art and its slot icon the mini pixel one;
both are 2D, never a render of the model.

Meeting an enemy had nowhere lasting to be written down, so **save version 7**
adds `enemiesSeen`. It is written in `RunSession.meetEnemy`, not when the
player presses GOT IT! on the NEW ENEMY! card: they have met the thing whether
or not they read the card. An older profile's dex starts empty rather than
guessing from the bosses it has beaten.

## The screen

`UI/DexScreen`, on the shared station harness (`UI/StationScreen`). Codex's
spread is one finished picture, so the screen draws it whole and puts only the
live furniture on it: the chosen entry down the left page, nine slots on the
right, tabs and arrows round the outside.

A locked entry is **its own picture tinted black**. The shape is the answer,
so it has to be the real picture and not a stand-in.

Everything is built inside `draw`, because `StationScreen` empties the canvas
before every redraw -- anything made once in `start` is destroyed the first
time the screen opens.

### The three books are not the same layout

They look alike, but Codex drew each one separately. The enemy book's slots
are 145 wide on a 199 pitch, the pet book's 125 on 186, the weapon book's 135
on 193, and the plaques and picture windows differ too. One shared set of
boxes put the enemy grid up to 44 pixels out of its frames, so every book
carries its own in `Config/Dex.books`, measured off its own art.

### The page turn

Six frames per book (`Config/Dex.books[n].turn`), 0.04 s each, so a turn runs
in about a quarter of a second. Frames 1 and 6 are the resting spread -- the
page has not lifted yet, and has landed -- so a turn begins and ends where the
book already was. They are kept in the list rather than trimmed, because the
animation reads as six evenly spaced frames.

**Back turns run the frames in reverse** (owner, 2026-11-01: "the page
animation needs to turn the other way if they click the back page arrow"). The
frames are a page lifting off the right and falling to the left, so played
backwards they are a page coming back; because the ends are both the resting
spread, either direction still starts and finishes where the book was.

**The book must not move while they play** (owner: "make sure the book doesnt
move at all when the animation plays"). It cannot, because a turn calls `fill`
and never `draw`: the spread stays the same Instance throughout, and only the
`Pages` frame is emptied and remade. Rebuilding the screen mid-turn destroyed
and recreated the spread, and the book flickered as the image reloaded.

Seen in game: `assets/concepts/blocky/ui/codex/dex_page_turn_in_game.jpg`.

## Art

Sources in `assets/concepts/blocky/ui/codex/`, each 1672x941: a
`<book>_codex_spread.png` and `<book>_turn_1..6.png`. Twenty-one images, of
which fifteen are distinct -- in every book the spread, turn 1 and turn 6 are
the same picture.

### The sample entry is painted out

Codex drew a sample into the **middle slot** of each spread -- a horned enemy,
a sword, a fox -- so every page the screen drew had a silhouette sitting under
its fifth slot (owner, 2026-11-01: "the middle square has a constant
silhouette"). All 21 images are cleaned in place: the sample's footprint is
taken by differencing that cell against the emptiest other cell on the same
page, grown a few pixels to catch the anti-aliased rim, and laid back to paper
copied from that cell with its tone matched to the paper still showing around
the sample.

Where a frame's curling page covers the middle slot, only what is still dark
is rewritten, so the paper of the curl survives. A darkness threshold alone
left a pale ghost of the shape and missed the sword's tip and pommel, which
are mid-tone -- hence differencing rather than thresholding.

**If Codex redraws a spread, it will arrive with its sample back.** Clean it
the same way before uploading.

## Adding to a book

Nothing to do: an enemy, weapon or pet added to its own config appears in its
book, locked, on the next run. Only a new **area** needs a line, in
`DexBook`'s `AREAS`, or its enemies sort after every other area's.
