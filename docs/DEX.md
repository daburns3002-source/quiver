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

A benched enemy or a pet no egg holds is still in its book: a dex is a record
of the world, not of what is obtainable this week. What is *not* in a book is
anything with no picture, since a slot with nothing in it cannot even be a
silhouette.

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

The left page does not move in the frames, so a turn hides only the grid,
plays the six, and redraws on the next nine. Seen in game:
`assets/concepts/blocky/ui/codex/dex_page_turn_in_game.jpg`.

## Art

Sources in `assets/concepts/blocky/ui/codex/`, each 1672x941: a
`<book>_codex_spread.png` and `<book>_turn_1..6.png`. Twenty-one images, of
which fifteen are distinct -- in every book the spread, turn 1 and turn 6 are
the same picture.

## Adding to a book

Nothing to do: an enemy, weapon or pet added to its own config appears in its
book, locked, on the next run. Only a new **area** needs a line, in
`DexBook`'s `AREAS`, or its enemies sort after every other area's.
