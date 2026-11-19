# Codes, the favourite prompt and hatch shout-outs

Three of the twelve retention ideas (owner, 2026-11-18: "yes all of these create them").
Branch `phase-4/codes-fav-shoutouts`, save version 24.

## Codes

A CODES row at the bottom of the SETTINGS panel (`UI/SettingsScreen`): a text box and a green
REDEEM button, the answer under them in green or red. Settings, not REWARDS, because REWARDS
is already three full tabs and other work is adding to it.

- **The list is the server's only:** `src/server/Data/CodeList.luau`, in ServerScriptService,
  which no client receives. `tests/CodeRules.spec` fails if a `CodeList` ever shows up in
  ReplicatedStorage, and checks every entry is well formed.
- Each code: a prize of any of coins, gems, eggs (the best egg open to the player) and crates
  (the best crate for their class), and an optional `expires` date, its last day in UTC. Eggs
  and crates are given as a quest chest's are (`Rewards.givePrize`), with the reveal; what
  cannot be given is paid in gems.
- Typed text is read in capitals with spaces dropped, letters and digits only, 24 at most
  (`Util/CodeRules.normalise`), so "la unch" is LAUNCH.
- Once per player: `profile.codesUsed`, marked and saved before anything is paid.
- Answers: CODE REDEEMED! 500 COINS + 25 GEMS / THAT CODE DOES NOT EXIST / THAT CODE HAS
  EXPIRED / YOU ALREADY USED THAT CODE / TYPE A CODE FIRST / TOO MANY TRIES! WAIT A MOMENT.
  The typed text is never said back or logged.
- Rate limit: four tries at once, then one every 15 seconds (`Config/Codes.tries`), on top of
  `Net/Inbound`'s floor; a guessing script gets four a minute.
- **Placeholder:** one code, `LAUNCH`, 500 coins and 25 gems, until 2027-01-31. The real words
  and prizes are the owner's.

Adding a code: one line in `Data/CodeList.luau`, the word in capitals and digits. No save
change is needed.

## The favourite prompt

Roblox's own prompt (`AvatarEditorService:PromptSetFavorite(game.PlaceId,
Enum.AvatarItemType.Asset, true)`), once ever, after a boss win, and never again.

- `Wallet.beatBoss` calls `Favourite.bossWon`, which sets the player's `FavouriteOwed`
  attribute while `profile.favouriteAsked` is false. `UI/FavouritePrompt` waits until the
  player is in the lobby with nothing else up (end screen, story beat, reveal, menu) for
  2.5 s, shows the prompt and fires `Remotes.FavouriteAsked`; the server saves it.
- A new player is asked after their first boss win. A player from before this update who has
  already beaten a boss is asked after their next one. Leaving before it shows means it shows
  after the next boss win.
- **No reward, and nothing of ours on screen.** What Roblox says (looked up 2026-11-18):
  the API reference documents `PromptSetFavorite` for assets and bundles and does not
  mention experiences; using the place id as an Asset is the community's way, and Studio
  accepted it (the call was left "in progress", which is the prompt open; Studio's screen
  capture does not draw Roblox's own prompts). On rewards: I found no official rule that
  names favourites, but the Community Rules forbid promotions that offer prizes in exchange
  for actions, and developers on the DevForum read that as covering likes and favourites.
  Some games do reward favourites anyway. We attach nothing.
- `GetFavoriteAsync` is not used: it needs Roblox's inventory-access prompt first, which we
  do not want to show. So a player who already favourites the game sees the prompt once too.

## Hatch shout-outs

When anyone in the server hatches a Legendary or Mythic pet, or pulls a Legendary or Mythic
weapon from any crate, everyone in the server sees a banner across the top in the rarity's
colour ("ImFil HATCHED A MYTHIC GLIMMERHORN!", "... PULLED A LEGENDARY ..."), glowing with
the gleam and sparkles (rule 12), and the same line in chat in that colour (Roblox's own
system line, `TextChannel:DisplaySystemMessage`).

- Server: `Data/Shoutouts.rolled(player, kind, item)` from every roll that makes a pet or a
  crate weapon, after the grant: `Data/Hatchery` (bought, free and prize eggs),
  `Data/Shop` (bought crates) and `Data/EndlessPrizes.crates` (every free crate: quest chest,
  Victory's chests, goals, codes, Soulstone shop). Robux-bought eggs are hatches too. A weapon
  bought from the store or earned (golden) is not a roll and is not shouted.
- Client: `UI/Shoutout`. A banner and its chat line wait while the player's own reveal is up,
  so whoever hatched it sees their pet first. Three banners can wait; more are chat lines only.
  Display order 145: over the station screens, so it shows inside the Hatchery.
- **Other servers: a Mythic only, as a chat line, no banner** ("... IN ANOTHER SERVER!"),
  through MessagingService. Why: a Mythic is rare enough (the pity gives one in a hundred at
  the latest) that hearing of one is exciting and says the game is alive; a Legendary is
  common enough that across many servers it would be noise. A banner is for somebody you can
  see. Each server sends at most one per 10 s and shows at most one from elsewhere per 20 s;
  a message not in our shape is dropped (`ShoutoutRules.read`). Studio never publishes, so a
  test Mythic cannot reach live servers.

## Checked

- Gates; in-Roblox tests (`CodeRules.spec`, `ShoutoutRules.spec`, `SaveSchema.spec`
  version 24).
- Studio Play by probe (2091 x 1113): the codes' six answers (coins went 50,000 to 50,500);
  99 real Mossy Egg hatches gave a Mythic Glimmerhorn and three Legendaries, each shouted to
  the client, three banners drawn and three chat lines; the banner and the CODES row seen in
  captures; the favourite flow from the attribute to the save.
- **Not seen:** a phone (the banner and the CODES row upright), a real boss win reaching the
  prompt (the attribute was set by hand; `bossWon` is three lines in `Wallet.beatBoss`), the
  prompt itself on screen, two players in one server, MessagingService between live servers.
