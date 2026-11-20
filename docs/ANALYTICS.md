# Analytics

Every Roblox `AnalyticsService` event the game sends, where to read it, and
how to add one. The code is `src/server/Data/Analytics.luau` (every send),
its pure rules are `src/shared/Util/AnalyticsRules.luau`, and the specs are
`tests/Analytics.spec` and `tests/AnalyticsRules.spec`. Built 2026-11-13
(onboarding, progression, custom events) and 2026-11-20 for the launch
(recurring funnels, economy; owner: "i also need funnels set up for the
launch as well").

**Roblox records nothing from Studio.** A Studio playtest writes each event
to the Output as `[Analytics] <method> <player>: ...` instead, so you can see
what would be sent. Real numbers come only from the published game, and the
charts fill about a day after the first event.

## Where to read it (Creator Hub)

Creator Hub > Creations > Arrowborne > **Analytics** (left menu):

| Page | What is there |
| --- | --- |
| **Funnels** | The onboarding funnel (pick "Onboarding") and the four recurring funnels below, each step's conversion and drop-off |
| **Economy** | Coins, Gems and Soulstones: sources and sinks by transaction type and sku, average wallet balance |
| **Progression** | Runs: Campaign (by level), Endless (by floor), Tutorial; started, completed, failed |
| **Custom Events** | RunLength, Death, CardPick, Hatch, AreaUnlock, Purchase, CodeTry, ScreenOpen, each with its fields |

Revenue, payers, product and pass sales, retention, session length and join
sources are Roblox's own dashboards (Monetization, Retention, Engagement,
Acquisition), so the game sends nothing for them.

## Funnels

**Onboarding** (`LogOnboardingFunnelStepEvent`, once per player): 1 Joined,
2 Title, 3 Story, 4 Tutorial, 5 ClassSelect, 6 FirstRun, 7 Cleared1-1,
8 FirstHatch, 9 FirstCrate. Steps 1 to 6 count only for a player who has not
beaten 1-1. Roblox counts a step it is sent as completing every step before
it, so a player who pulls a crate before ever hatching is counted at
FirstHatch too: read steps 8 and 9 from the EggHatch and CratePull funnels
instead.

**Recurring** (`LogFunnelStepEvent`): each visit is its own traversal, a
fresh GUID the server makes, and each step is sent once per traversal.

| Funnel | Steps | A traversal is |
| --- | --- | --- |
| RobuxStore | 1 Opened, 2 Prompted, 3 Bought | One opening of the STORE screen; Prompted is BUY pressed and Roblox's prompt up (field 1 the item); Bought is the grant |
| RobuxOffer | 1 Prompted, 2 Bought | One Robux prompt anywhere but the STORE: DEFEAT's revive, the starter pack, a gear slot, the season pass, the egg screen (field 2 says where) |
| EggHatch | 1 Opened, 2 Hatched, 3 HatchedAgain | One opening of the egg hatchery; fields: the egg, how many |
| CratePull | 1 Opened, 2 Pulled, 3 PulledAgain | One opening of the Blacksmith (it opens as the player walks up); fields: the crate, the class chest, how many |

A screen's opening is the only thing a client says (`Remotes.ScreenOpened`,
checked against `AnalyticsRules.SCREENS`); every later step is the server's.
A Bought step is sent only for a prompt this server opened.

## Economy

`LogEconomyEvent` for every coin, gem and Soulstone given or taken through
`Data/Wallet` with a why, with the balance after it. The why is the
transaction type (`AnalyticsRules.SOURCES`, `SINKS`) and the sku says which.

| Flow | Transaction type | Whys (sku) |
| --- | --- | --- |
| Source | Gameplay | Run (the level; summed, sent as the run ends), Chest (area), HardClear (level), ClassLevel (class), Boss (area), Endless (summed per run; Checkpoint), Milestone (floor), Tournament (week), Pick, Swap (gems instead of an egg or crate not open yet), Quest, Goal, Stars, Dex, Season |
| Source | TimedReward | Login, Playtime, Rewards (CLAIM ALL), VIP (VIPDaily) |
| Source | Onboarding | Starter (a starter quest) |
| Source | IAP | Robux (the `Config/RobuxStore` key) |
| Source | Invite, Code | Invite; Code (the code) |
| Sink | Shop | Egg (egg), Crate (crate), Weapon (weapon), Trail (trail), SoulstoneShop (offer) |

Boss items are not a currency. Studio's test wallets pass no why and are not
logged.

## Custom events

RunLength (seconds; stage, outcome, class), Death (room/floor; stage, where,
class), CardPick (level; card, rarity, source), Hatch (per pet; egg, pet,
how), AreaUnlock (bosses beaten; area), Purchase (Robux; key, Product or
Pass, where), CodeTry (result, and the code once redeemed: a typed word that
is not a code is never sent), ScreenOpen (the gear sheet, rewards, the Dex,
badges, settings: which screens are used).

## Adding one

- Send it from `Data/Analytics` only, decided on the server.
- A new grant or price passes a why to `Wallet.addCoins`, `addGems`,
  `addSoulstones` or `pay`; a new why goes in `AnalyticsRules.SOURCES` or
  `SINKS` first (an unknown one is warned about once and never sent).
- Roblox's limits per game: 10 funnels (5 used), 10 currencies (3), 100
  custom event names (8), 3 fields an event, 20 transaction types shown (7),
  about `120 + 20 x players` events a minute. Prefer a field to a new name.
