# The season pass

Asked for by the owner on 2026-11-18 ("yes all of these create them", one of twelve
retention ideas). The tier list below got its yes the same day ("Yes, build it"),
with Season 1 from 1 December, the trail as its own Claude Design build, and the
pass at 299 Robux.

Numbers live in `src/shared/Config/Season.luau`, the rules in
`src/shared/Util/SeasonRules.luau` (pinned by `tests/Season.spec.luau`), the server in
`src/server/Data/Season.luau`, the tab in `src/client/UI/SeasonTab.luau`.

## The season

- **One calendar month by the server's clock, UTC**: 00:00 on the 1st to 00:00 on the
  next 1st, keyed "YYYY-MM" (`Season.seasons`). The dates are worked out from the
  seconds (`SeasonRules.month`), never from a time zone.
- A month with no entry has no season: the tab names the next one and counts down to
  it ("SEASON 1 STARTS IN"), or says NO SEASON RIGHT NOW.
- **Season 1, Starwish: December 2026**, themed on the Starwish weapon set
  (`docs/WEAPONS-THEMED.md`): pink and mint, its trail the Wish Ribbon, its title
  WISHKEEPER.
- A new season is an entry in `Season.seasons` (number, name, set, trail, title, two
  colours), its trail in `Config/Trails` with `earn = "Season"` (a Codex panel, a
  Claude Design build, an icon) and its title in `Season.titles`. The 30 tiers are the
  same every season.

## Season XP (server-decided, saved)

| What the server sees | XP |
|---|---|
| A campaign room cleared (not the tutorial, not the sandbox) | 10 |
| A campaign level won | 50 |
| An Endless floor cleared | 10 |
| A daily quest claimed (one by one or by CLAIM ALL) | 100 |

Every tier is 500 XP, 15,000 for all 30. Three quests and four levels of about five
rooms a day is about 700 XP, so tier 30 in about three weeks; the spec holds that
inside the shortest month and not under ten days. XP comes from `Data/Rewards.note`
(rooms and floors from `Run/RoomController`, levels won) and the quests' claims, through
the `Rewards.onNote` hook that `Data/Season` sets. Nothing a client sends is XP. XP
past tier 30 counts for nothing.

## The tiers

Free is everyone's. Premium is the Season Pass, **fixed things only, never random**
(eggs and crates are free-track only; paid random items are restricted in some
countries, so nothing here needs `PolicyService.ArePaidRandomItemsRestricted`). Free
eggs and crates are the best open to the player, as the quests' are.

| Tier | Free | Premium |
|---|---|---|
| 1 | 500 coins | 50 gems |
| 2 | 10 gems | 2,000 coins |
| 3 | 1 egg | 30 gems |
| 4 | 750 coins | 30 gems |
| 5 | 1 crate | 75 gems |
| 6 | 1,000 coins | 3,000 coins |
| 7 | 10 gems | 30 gems |
| 8 | 1 egg | 40 gems |
| 9 | 1,250 coins | 40 gems |
| 10 | 2 crates | 100 gems |
| 11 | 1,500 coins | 4,000 coins |
| 12 | 15 gems | 40 gems |
| 13 | 1 egg | 50 gems |
| 14 | 1,750 coins | 50 gems |
| 15 | 1 crate | **the season's trail** (Legendary, glows) |
| 16 | 2,000 coins | 5,000 coins |
| 17 | 15 gems | 50 gems |
| 18 | 1 egg | 60 gems |
| 19 | 2,250 coins | 60 gems |
| 20 | 2 eggs | 100 gems |
| 21 | 2,500 coins | 6,000 coins |
| 22 | 20 gems | 60 gems |
| 23 | 1 egg | 70 gems |
| 24 | 2,750 coins | 70 gems |
| 25 | 1 crate | 125 gems |
| 26 | 3,000 coins | 8,000 coins |
| 27 | 20 gems | 75 gems |
| 28 | 1 egg | 75 gems |
| 29 | 3,500 coins | 100 gems |
| 30 | **the season's free weapon**, 3 eggs and 3 crates | **the season's premium weapon**, **the season's title** and 150 gems |

Tier 30's weapons are the season's own (`SeasonDef.weapons`, or a set pick in `SeasonDef.picks`;
owner, 2026-11-19). Season 1: the **Wishcutter Blade** (Legendary, earned only) free, and premium a
**pick of the Lantern Bloom set**, any one of four, one for each class: the **Petalfall Blade**
(Mythic, earned only) or the Blossom Bow, Paperglow Staff or Bellchime Daggers (Legendaries; owner:
"a choice BETWEEN THE MYTHICS AND LEGENDARIES FOR ALL CLASSES", "the space and sakura ones"). The
weapon is paid by `Data/Season` through `Wallet.grantWeapon`; the pick is owed through
`Wallet.owePick` (`Util/RewardPickRules`, save v29 `rewardPicks`) and taken on the lobby's pick
panel (`UI/RewardPick`), which comes up over the tab as soon as it is claimed and again on every
return to the lobby until taken. The tab draws the Wishcutter's 2D picture and ANY LANTERN BLOOM
WEAPON with the Petalfall's. A season with neither gives none at tier 30.

Totals: free 90 gems, 11 eggs, 8 crates, 22,750 coins; premium 1,530 gems (about what
the gem packs give for the price), 28,000 coins, the trail and the title.

## Claiming, and the season's end

- CLAIM on a tier sends `Remotes.SeasonClaim(track, tier)`; CLAIM ALL sends `("all")`.
  The rules mark the tier claimed (one bit a tier) and pay in one step, so a claim sent
  twice pays once.
- **At the season's end everything reached and not claimed is claimed for the player**
  (both tracks if they bought premium), once they stand in the lobby: on their next
  join, or within `Season.checkEvery` (30 s) of the month turning or of a run ending
  (never under the title or in a run, where the eggs' and crates' reveals would come up;
  a run in the new month earns no season XP until then), with a toast
  "SEASON 1 ENDED! YOUR REWARDS WERE CLAIMED FOR YOU". Nothing carries over, XP and
  premium included, and nothing reached is lost (`SeasonRules.rollover`). Chosen over
  carrying rewards into the next season so each season's tab stays its own.
- The trail goes into the player's trails (`Wallet.grantTrail`), worn from the Gear
  sheet's TRAILS tab, where it reads "FROM SEASON 1" and, unheld, "SEASON 1 PREMIUM,
  TIER 15". It is never sold and never given again.
- The title goes into `profile.titles`, worn at once if none is. Worn or taken off from
  the SEASON tab's tier 30 (`Remotes.SeasonTitle`) while its season runs; once a second
  season exists, held titles will need a chooser outside the tab (the Gear sheet); the server puts it on the Player's `SeasonTitle` attribute and every
  client draws it over the name tag as "+ WISHKEEPER +" in its colours (`UI/NameTags`).

## The Season Pass (Robux)

- A **developer product**, "SeasonPass" in `Config/RobuxStore` (`season = true`),
  **299 Robux** (owner, 2026-11-18). A game pass is permanent, so it cannot be one.
- Bought from the SEASON tab's PREMIUM button, never from the STORE's shelves
  (`StoreRules.shelf`, `canPrompt`). The server prompts only while a season runs and the
  player has not bought it for that season (`Data/Season.canBuy`).
- Granted once per receipt like every product (`Data/Purchases.settle`):
  `Season.grantPremium` marks premium for the season running. A receipt that lands after
  the month turned is premium for the new season; one that lands while no season runs
  is kept for the next.
- **Created on the Creator Dashboard on 2026-11-19** at the owner's word: id 3733524465,
  299 Robux, on sale, managed pricing off, the Wish Ribbon's picture as its icon
  (`assets/ui/robux/dashboard/SeasonPass.png`). Before 1 December the tab shows no
  PREMIUM button (no season runs to buy for).

## Save (version 28)

`profile.season`: `key` ("YYYY-MM", "" for none), `xp`, `free` and `paid` (claimed
tiers, one bit each), `premium`. `profile.titles` and `profile.title`. An older profile
has no XP, nothing claimed and no title.

## Testing in Studio

- `Remotes.DebugSeason:FireServer(days, xp)` moves the player's season clock on by `days`
  (Studio only; 0 for none), e.g. 13 from 18 November to reach Season 1, and on past
  1 January to see the end claim everything; `xp` adds about that much season XP.
- `Remotes.DebugReceipt:FireServer("SeasonPass", id)` sends a made-up Season Pass
  receipt (send the same id twice: granted once).
