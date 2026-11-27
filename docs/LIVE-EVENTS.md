# Live events

Three hooks that make a player come back on a schedule (owner, 2026-11-18: "yes all of these
create them"): the weekly set rotation, the weekend boosts with the owner's live event switch,
and the Server Luck sold for Robux. Numbers are starting numbers in `Config/LiveEvents`; the
rules are pure, in `Util/SetRotation` and `Util/LiveBoosts`, pinned by `tests/SetRotation.spec`
and `tests/LiveBoosts.spec`. **Everything is decided on the server, on UTC.**

## The clock

A week starts Monday 00:00 UTC; weeks are counted from `LiveEvents.firstMonday` (2026-11-16,
the week the rotation began). The server publishes nothing for the clock: every screen reads
`workspace:GetServerTimeNow()` (`Util/LiveState.now`), which Roblox keeps in step with the server.
In Studio, `Remotes.DebugClock(seconds)` moves the clock for the server and every screen (the
`LiveClockShift` workspace attribute; 0 puts it back), to see a weekend or a new week.

## The weekly set rotation

- **Two themed sets a week** (`setsPerWeek`), from the stocked sets of `Config/Shop.sets` in their
  order, wrapping round: with eight sets, every set is on sale one week in four. The first week
  (from 2026-11-16) is Neon Circuit and Starwish; then Tumbleweed and Splash Day; then Coin-Op and
  Voidglass; then Lantern Bloom and Cinderforge; then round again.
- **The others leave the shop** until their week comes back (owner, 2026-11-18: "They leave"). A
  weapon already owned is always kept: the rotation decides only what can be bought.
- **The server refuses** a set weapon that is not on sale (`ShopRules.buyable` with the server's
  `now`, in `Data/Shop`; without a clock it is never buyable), not only the screen.
- **The SETS tab** at the Blacksmith shows only the week's two (its arrows step between them), with
  **NEW SETS IN 3D 4H** ticking under the set's name; it redraws itself when Monday comes.
- The Dex's set pages, the Gear sheet and owned weapons are untouched.
- **Only the shop's buy path checks the week.** `ShopRules.stocked`, `ShopRules.catalog` and
  `Wallet.grantWeapon` know nothing of the rotation, so a prize (the Endless tournament's top-10
  pick of a set weapon) grants any set's weapon in any week. Keep the check out of any shared
  ownership or grant function.

## The boosts

| Boost | When | What | Banner |
|---|---|---|---|
| **Weekend** | Friday 00:00 to Monday 00:00 UTC (Sunday 23:59:59 is the last second) | 2x Luck and 2x Coins weekend about, by week number: the first weekend (2026-11-20 to 22) is Luck | `2x LUCK WEEKEND 2D 5H` |
| **Live event** | when the owner fires it, 30 minutes (`liveSeconds`) | 2x Luck or 2x Coins, in every server | `LIVE EVENT! 2x COINS 29:59` |
| **Server Luck** | when someone buys it, 15 minutes, more time for each one bought | 2x Luck for everyone in that server | `THANKS NAME! 2x LUCK 14:59` |

- **2x Coins** adds one to a run's kill and clear coin scale (`RunSession.payEarned`), as the 2x
  Coins pass does; other coins (chests, quests, prizes) are not scaled.
- **2x Luck** doubles the Legendary and Mythic odds of every egg hatched in that server (bought,
  free, a prize's, the starter pack's); every other rarity gives up what they gain in proportion,
  so the odds still add up (`LiveBoosts.odds`). The egg screen's odds are drawn at the luck running,
  with **2x LUCK!** in gold at the card's head, and redraw when a boost starts or ends. The Mythic
  pity is untouched.
- **How they combine (pinned):** boosts add, never multiply, and stop at `LiveEvents.caps`.
  - Luck: 1 + one for each luck boost running, **at most 3x** (a Luck weekend and a Server Luck are
    3x; the owner's event on top is still 3x). The lucky share of an egg never passes half
    (`luckShareCap`), whatever the numbers become.
  - Coins: the events add **at most one** to the scale (a Coins weekend and a coins live event are
    still 2x), beside the passes, the win streak, the friend bonus and hard mode, which add too.
    Everything at once: 1 + 1 (2x Coins pass) + 0.1 (VIP) + 1 (event) + 0.5 (streak) + 0.2
    (friend) + 1 (hard) = **4.8x**, held under 5x by `tests/LiveBoosts.spec`.
  - **VIP brings no luck**: its tenth of coins and daily gems are as before.

### The owner's live event switch

- The owner sees a purple **LIVE** button under the banner in the lobby; it opens **2x LUCK 30M**,
  **2x COINS 30M** and **END**. The server checks the sender by user id (`LiveEvents.ownerIds`, or
  the place's creator when a user owns it, `game.CreatorId`); anyone else is turned away and
  logged. Firing one replaces the one running.
- It runs at once in that server, goes to every other server through MessagingService (topic
  `LiveEvent`), and is kept in a MemoryStore map (`LiveEvent`, expiring with it) so a server that
  starts during it picks it up. A message is checked and never runs longer than 30 minutes from
  when it arrives. END clears it everywhere.
- **Not seen across servers:** MessagingService and MemoryStore were only run in Studio (one
  server). The first live event in the published game is the real test: fire one and join a
  second server.

## The Server Luck (Robux)

- A developer product, **Server Luck, 49 Robux** (owner, 2026-11-18), `Config/RobuxStore`
  `ServerLuck`: 15 minutes of 2x egg luck for everyone in the server; buying again adds 15 minutes
  to what is left (`LiveBoosts.extend`). It lives as long as the server; nothing is saved, but the
  receipt is (`purchases.receipts`), so it is granted once.
- **Where it is sold:** the green **2x LUCK ALL** button at the head of the Hatchery's odds card.
  Not on the STORE's shelves.
- **PolicyService:** it touches random rewards, so it is `paidRandom`: never offered to, and refused
  on the server for, a player whose `ArePaidRandomItemsRestricted` is true, or whose answer is not
  in yet (`Server/Data/Policy`, `StoreRules.offered`; unknown counts as restricted). The
  `PaidRandomRestricted` Player attribute tells the screens. The Starter Pack's eggs have the same
  gate since 2026-11-19 (owner: "Yes to all three").
- Everyone in the server sees the thanks on the banner, its pill popping as it is bought.

## Testing in Studio

- `Remotes.DebugClock:FireServer(seconds)` from a client probe moves the clock: to Friday for a
  weekend, past Monday for the next sets.
- `Remotes.DebugReceipt:FireServer("ServerLuck", id)` grants a made-up Server Luck receipt (the
  same id twice is granted once).
- `Remotes.LiveEventStart:FireServer("Luck" | "Coins" | "End")` as the owner fires a live event.
