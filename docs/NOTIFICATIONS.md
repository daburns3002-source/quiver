# Experience notifications

Roblox's opt-in pings (owner, 2026-11-18: "yes all of these create them"). A
player who says yes gets a message in their Roblox notifications, with a Join
button, when there is a reason to come back: the daily reward is ready, the
gift box is full, the weekend event is live, a new season starts, the sets in
the shop change.

**Built, and switched off.** Nothing is sent to anyone until the owner has done
the steps at the end of this page and said yes. The in-game question is live:
it only records answers and opens Roblox's own opt-in.

Read from Roblox's Creator Docs on 2026-11-18: *Experience notifications*,
*ExperienceNotificationService*, Open Cloud *Notifications* (Create User
Notification) and *Secrets*.

## What Roblox does, and what it allows

- Only players 13 and over can opt in, and only through Roblox's own prompt
  (`ExperienceNotificationService:PromptOptIn`; its words are Roblox's). Roblox
  never shows it to someone who has opted in already, or who has seen it for
  this experience in the last 30 days.
- Roblox delivers **at most one notification a day from an experience** to a
  player, and has a daily cap across all experiences too. Delivery is never
  guaranteed.
- A message is a *notification string* made on the Creator Dashboard (99
  characters at most, `{experienceName}` and `{name}` parameters), sent by its
  Asset ID through Open Cloud: `POST https://apis.roblox.com/cloud/v2/users/{id}/notifications`,
  scope `user.user-notification:write`, the key in the `x-api-key` header.
- No disguised ads, no time pressure, no bait, nothing gated on opting in.
  The strings below follow that.
- The experience needs 100 visits since launch to use them.

## The rules (`Util/NotifyRules`, numbers in `Config/Notifications`)

**Asking.** Never in a player's first session. Only just after they claim a
daily reward, and only once they are free in the lobby with REWARDS put away
(`UI/NotifyPrompt`): **GET A PING?**, the blue diamond, *YES, TELL ME* and
*NOT NOW*. Roblox's prompt comes only behind YES, so nobody who would say no
spends Roblox's once-in-30-days prompt.
- NOT NOW waits 3 days, and after the third NOT NOW the game never asks again.
- YES is never asked again.
- Where Roblox says it cannot ask (opted in already, under 13, asked lately),
  nothing shows and the game waits 7 days before looking again.
- All of it is saved (save version 25, `notify`).

**Sending**, only to players who said YES. As one leaves, a plan of at most
three messages is made from what will be true while they are away:
- the daily reward, when it is next ready, and once more 3 days after if
  nothing else went between;
- the gift box, if they left it full;
- the event, the season and the set rotation, if one starts after they left
  (what was already on when they left, they have just seen).

Never in the first 3 hours after they leave, never two within 20 hours, each
in the player's own evening (16:00 to 20:00 by the clock their device had when
they said yes), and nothing after 14 days away. When two fall in one evening
the event goes first, then the season, the rotation, the daily reward, the
gift box. Coming back clears the plan; leaving again makes a new one.

## How it is built

- `Server/Data/Notify`: counts sessions, asks after a daily claim
  (`Rewards.dailyClaimed`), takes the answer (`Remotes.NotifyAnswer`, only
  while it is waiting for one), makes the plan as a player leaves
  (`PlayerData.onLeaving`) and clears it as they join.
- `Server/Data/NotifyQueue`: the plans live in a MemoryStore sorted map every
  game server shares (`Notifications`), sorted by when the next message is due.
  Every server looks once a minute and sends at most 20; it claims an entry
  before sending it, so two servers never send one message twice. MemoryStore
  keeps an entry at most 45 days; these live 15.
- `Server/Data/NotifySender`: the one Open Cloud call. The key is the
  experience secret `NotifyApiKey` (`HttpService:GetSecret`), handed to the
  request as a `Secret`; no script ever sees its text and it is never in the
  repo. A 429 or 5xx is tried again later (5, 10, 20 minutes), a refused key
  (401, 403) stops that server sending for 30 minutes, anything else is
  dropped.
- `Client/UI/NotifyPrompt`: the question.

Tested by `tests/NotifyRules.spec` (the rules), `tests/NotifySender.spec`
(the call, against a stub: the URL, the header, the body, what each status
means) and `tests/NotifyQueue.spec` (the queue end to end on a table standing
in for MemoryStore: each message once and on time, two servers, a player who
comes back, a refused key, a retry).

**Seen in Studio (2026-11-19):** the question on a desktop screen, NOT NOW
pressed and saved, an answer the server never asked for ignored, 1,285
in-Roblox tests passing. **Not seen:** a phone-sized screen (needs the owner's
device emulator), Roblox's own prompt behind YES, and any real send (both need
a live server and the steps below). Do not press YES in Studio:
`CanPromptOptInAsync` is true there, so it would show Roblox's real prompt and
spend your account's once-in-30-days opt-in before a live test.

**What it cannot do.** Messages are sent by game servers, so while no server
of the game is running nothing goes out; they wait for the next one. The game
cannot tell whether a player who said YES then accepted Roblox's prompt, so it
sends to everyone who said YES and Roblox drops the rest. Secrets do not exist
in a local Studio playtest, so Studio never sends.

## Hooks for the event, the season and the rotation

The weekend event and the set rotation run on the clock (`Util/LiveBoosts`,
`Util/SetRotation`, live events, #632), so `Data/Notify` hooks them itself: the
next Friday 00:00 UTC weekend, and the next Monday 00:00 UTC rotation. The
owner's live event switch is not on a clock, so it is not announced. The
season is another session's work, and hooks itself the same way, with one
call at start-up:

```lua
local Notify = require(script.Parent.Notify) -- Server/Data/Notify
Notify.upcoming("season", function(now)
	return nextSeasonStart(now), nextSeasonEnd(now) -- Unix seconds
end)
```

`provider(now)` returns `(startsAt, endsAt?)` in Unix seconds, or nil when
nothing is coming. Kinds: `"event"` (the weekend event), `"season"` (a new
season), `"rotation"` (the set rotation). Nothing else is needed: a kind with
no hook is simply never planned.

## The owner's steps

Do these in order, then tell Claude. Nothing is sent until step 6.

**1. Check the experience can use them.** It needs 100 visits since launch,
and you must be able to manage it. Creator Dashboard
(https://create.roblox.com/dashboard/creations), click *Archer Legends [TEST]*:
under **Engagement** there should be **Notifications**.

**2. Make the five notification strings.** On that **Engagement >
Notifications** page, for each row below: click **Create a Notification
String**, type the identifier name and the string exactly, click **Create
Notification String**. Then, in the table, click the **⋯** in its **Actions**
column and **Copy Asset ID**, and keep the five IDs (they are not secret).

| Identifier name | String |
|---|---|
| `daily` | `Your daily reward is ready! Come claim it in {experienceName}.` |
| `gift` | `Your gift box is full! Come open your free gifts in {experienceName}.` |
| `event` | `The weekend event is live in {experienceName}! Come play for bonus rewards.` |
| `season` | `A new season has started in {experienceName}! Come see the new rewards.` |
| `rotation` | `New weapon sets are in the shop in {experienceName} this week!` |

Use no other `{...}` parameter: the game sends none, and a string that asks
for one is not delivered.

**3. Make the API key.** Creator Dashboard, **API Keys**
(https://create.roblox.com/dashboard/credentials?activeTab=ApiKeysTab), **Create
API Key**:
- Name: `Arrowborne notifications`.
- **Access Permissions**: in **Select API System** choose the user
  notifications one, and in **Select Operations** tick **write**: the scope is
  `user.user-notification:write`, and nothing else.
- **Restrict by Experience**: on, and choose *Archer Legends [TEST]*, if the
  page offers it for this API (Roblox allows it for some APIs, not all).
- **Security**: leave *Restrict IP addresses* off; Roblox says not to use it
  for a key used from Roblox servers.
- **Expiration**: none. A key nobody uses for 60 days expires by itself, so
  make it shortly before step 6.
- **Save & Generate key**, and copy the key. Do not paste it to Claude or
  anywhere else.

**4. Put the key in the experience's secrets.** Creator Dashboard, click *Archer
Legends [TEST]*, **Secrets**, **Create Secret**:
- Name: `NotifyApiKey` (exactly; it is `Config/Notifications.secret`).
- Secret: the key from step 3.
- Domain: `apis.roblox.com`.

**5. Allow HTTP requests.** In Studio, with the place open: **File > Experience
Settings > Security**, turn on **Allow HTTP Requests**, and **Save**. The game
made no web calls before this, so it is off.

**6. Say yes to Claude**, and paste the five Asset IDs from step 2. Claude puts
them in `Config/Notifications`, turns `send` on and ships it. Sending starts on
the servers that start after that update.

**After it is on.** The Creator Dashboard's **Engagement > Notifications >
Analytics** tab shows opted-in players, impressions, clicks and turn-offs
(once there are 100 impressions). On a live server's log (F9, Server), the
queue says `[Notify] sent N`; a refused key says `sending paused`.
