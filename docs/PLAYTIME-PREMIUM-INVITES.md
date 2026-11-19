# Playtime gifts, the Premium perk and invite rewards

Three retention hooks (owner, 2026-11-18: "yes all of these create them").
Numbers are starting numbers in `Config/Rewards` (`playtime`, `premium`,
`invite`); the rules are pure (`Util/PlaytimeRules`, `Util/PremiumRules`,
`Util/InviteRules`) and pinned by `tests/Playtime.spec`, `tests/Premium.spec`
and `tests/Invites.spec`. Save version 27 holds what must be kept. Rewards are
given by the server only; the client draws and asks.

## Playtime gifts

| Opens at | Gift |
|---|---|
| 5 min | 250 coins |
| 10 min | 500 coins |
| 20 min | 5 gems, 250 coins |
| 30 min | 10 gems, 500 coins |
| 45 min | an egg |
| 60 min | an egg, a weapon crate, 15 gems |

The egg and crate are the best open to the player (`Util/PrizeRules`), as the
gift box's are, with their reveals. 30 gems for a whole hour against the
daily rewards' ~77 a day, so the store keeps its price (the spec holds an hour
under 40).

**The server's clock decides.** Claims are judged with the server's
`os.time()`; the screens draw with `Workspace:GetServerTimeNow()`.

**Why it is saved.** Every run, solo too, is played on a reserved server of
its own (`Run/Party`), and the lobby after it is another server again. A clock
in one server's memory would start over at every level, and nobody would ever
reach the 20-minute gift. So the session rides in the save
(`SaveSchema.playtime`: when it began, when a server last held the player,
which gifts are claimed). The server stamps it every 5 s (`Data/Rewards`), the
profile's save on leave carries it, and the next server goes on with the
session if the player was held within `gap` (10 minutes); otherwise a new
session starts with all six shut. Quitting and rejoining soon after goes on
with the same session, so it cannot be farmed by rejoining; a break of more
than ten minutes starts over, which is the intended "each session".

**On screen.** A round gold gift button under REWARDS in the lobby
(`UI/PlaytimeButton`): a ring of 20 blocks fills towards the next gift with
the time left under it; once one is open the ring turns gold, it says GIFT READY!
and the button pulses and sways. It opens REWARDS on the new GIFTS tab, where
the six cards show CLAIM, the time left or DONE. The tab's corner, the lobby
REWARDS badge and CLAIM ALL count open gifts with everything else
(`RewardRules.readyBy`/`ready`/`claimAll` take the server time). A gift that
opens is said on the toast. The button goes away once all six are claimed.

Studio: `Remotes.DebugPlaytime:FireServer(n)` moves the session `n` minutes on.

## Roblox Premium

Premium members get **+10% coins** on a run's kills and clears, added to the
pay scale beside VIP's +10% (`RunBonus.scale`, `RunSession.payEarned`), never
multiplied with it, and **a free egg once a reward day** (the best open),
paid as they reach a lobby (`Arrived`), so its reveal never plays over the
title or in a run; `profile.premiumDay` is marked before it is given.
Whether a player has Premium is read on the server from
`Player.MembershipType`, again on `PlayerMembershipChanged`; the `Premium`
Player attribute only tells the screens.

On screen: Roblox's own Premium mark before the name on the name tag
(`UI/NameTags`, `rbxasset://textures/ui/PlayerList/PremiumIcon.png`, no upload),
and a ROBLOX PREMIUM panel on REWARDS > GIFTS: YOU HAVE IT! for a member,
GET PREMIUM (Roblox's `PromptPremiumPurchase`) for anyone else.

Studio: `Remotes.DebugPremium:FireServer(true/false)`.

## Invite rewards

The invite buttons (the party line's INVITE A FRIEND and REWARDS > GIFTS'
INVITE) send Roblox's invite through `UI/InvitePrompt` with launch data
`invite:<sender's user id>` (`InviteRules.launchData`).

1. A friend's **very first join ever** (no save stored: `PlayerData.isNew`)
   reads who invited them: Roblox's `ReferredByPlayerId` first, else the
   launch data. It is written into their own save as owed, with no wait (a new
   player is sent to the tutorial's server at once).
2. **When they first stand in a lobby** (for a new player, after the
   tutorial) the welcome is marked settled, then, if Roblox says the two are
   friends (`IsFriendsWithAsync`; launch data can be typed into a link by
   anyone), they get **500 coins and 25 gems** and their user id goes on the
   inviter's waiting list.
3. The **inviter gets 500 coins and an egg** per friend, once a friend ever,
   at most **3 friends a reward day**; more wait for the next day. Paid on a
   lobby server: at once if the friend joined theirs, else within two minutes
   while online, else as they next arrive; the save is written at once after.

The waiting list is its own DataStore (`Invites`, `Invites_Studio` in Studio;
one key per inviter, the newest 50 user ids), because one server cannot write
another player's session-locked save. Nobody is counted twice: the friend's
save says the welcome is settled, the inviter's says which friends were paid
(`invites.counted`).

Studio: `Remotes.DebugInvite:FireServer(userId)` plays a first join invited
by `userId` with the friendship check skipped; the player's own id pays both
sides to them.

## Not verified

- A real Premium account and a real invite from a second account: Studio
  has neither, so both are proved with the Studio stand-ins only.
- That `ReferredByPlayerId` is filled for an invite in the live game (the
  launch data covers it if not).
- Phone size: the gift button, the GIFTS tab upright, the name tag's mark.
