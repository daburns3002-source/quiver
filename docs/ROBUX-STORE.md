# The Robux store

What the game sells for Robux (owner, 2026-11-13: "Yes, build them"). Prices are starting numbers, to tune after launch. The numbers live in `src/shared/Config/RobuxStore.luau`; the rules in `src/shared/Util/StoreRules.luau` (pinned by `tests/RobuxStore.spec.luau`).

**Never sold:** Mythics, boss items, Starfall, boss badges. No energy and no timers.

## For the owner: what to create on the Creator Dashboard

Creator Dashboard → the experience → **Monetization**. Every icon is a 512 x 512 PNG in `assets/ui/robux/dashboard/`, centred with room for Roblox's circle crop. Send Claude each id once it is made; nothing can be bought until its id is in `Config/RobuxStore`.

### Developer products (Monetization → Developer Products → Create)

| Name | Price (R$) | Description | Icon |
|---|---|---|---|
| Handful of Gems | 49 | 120 gems. | `Gems.png` |
| Pouch of Gems | 99 | 325 gems. | `Gems.png` |
| Bag of Gems | 199 | 750 gems. | `Gems.png` |
| Chest of Gems | 499 | 2,300 gems. | `Gems.png` |
| Vault of Gems | 999 | 5,500 gems. | `Gems.png` |
| Starter Pack | 99 | 500 gems, 3 Mossy Eggs and 2,000 coins. Once per player. | `StarterPack.png` |
| Revive | 15 | Back into the room you fell in, with your build. Once per run. | `Revive.png` |

### Game passes (Monetization → Passes → Create a Pass, then put it on sale)

| Name | Price (R$) | Description | Icon |
|---|---|---|---|
| 2x Coins | 199 | Double the coins from every kill and every clear. | `DoubleCoins.png` |
| Extra Pet Slot | 249 | A third pet slot: take three pets into every run. | `PetSlot.png` |
| VIP | 399 | A gold name tag, 10% more coins and 25 gems every day. | `VIP.png` |

## How it works

- **Server grants, exactly once.** `MarketplaceService.ProcessReceipt` is `Server/Data/Purchases.processReceipt`. A receipt's `PurchaseId` is looked up in the save (`SaveSchema` v15 `purchases.receipts`, the newest 100 kept); a new one is granted and written down in the same change, then saved at once. Only a save that landed answers `PurchaseGranted`; anything else answers `NotProcessedYet` and Roblox asks again, when only the save is retried.
- **Prompts are the server's.** The client sends `Remotes.StoreBuy(key, where)`; the server checks the product can be sold to this player (`StoreRules.canPrompt`) and opens Roblox's prompt.
- **Passes** (`Server/Data/Passes`): `UserOwnsGamePassAsync` on join, `PromptGamePassPurchaseFinished` on a purchase here. Never saved: Roblox is the record. The `Pass<Key>` Player attributes only tell the screens.
- **2x Coins and VIP** scale a run's kill and clear coins (`RunSession.payEarned`): the bonuses add, 2x Coins and VIP together make 2.1x, and the part under a whole coin is carried to the next payment. The tutorial's top-up to the first egg is not scaled.
- **Extra Pet Slot**: PET 3 on the Gear sheet. Without the pass it shows a lock and opens the STORE on PASSES. The server fills the `Pet3` attribute only for the pass's owner (`Hatchery.apply`), and `Wallet.equipPet` refuses slot 3 without it.
- **VIP**: a gold name tag ("VIP" before the name, `UI/NameTags`), +10% coins, and 25 gems a day, paid on join, on buying the pass and every five minutes for a day that turns over mid-session (`purchases.vipDay`).
- **Starter pack**: offered once, as the player leaves the Victory of their first 1-1 clear (`RunSummary.starter`, `UI/RobuxOffer`); always on the STORE's GEMS tab until bought. Its eggs hatch on the spot and show as a prize.
- **Revive, Robux only** (owner: "the revive should only be robux not diamonds and it should be 15"): offered over DEFEAT once a run (not in the tutorial). The room, wave or floor the player fell in starts over with their level and cards kept, full health behind the revive's shield. While its prompt is open, TRY AGAIN waits up to 30 s. A revive bought when the run has already moved on is kept in the save (`purchases.reviveCredits`) and DEFEAT offers it free next time.
- **Revive in co-op**: it stands up only the buyer. Everyone else sits that room out, as a teammate who bled out does, and is back for the next room (`RunSession.sitOut`, `returnTheDowned`).
- **Analytics**: every grant is a custom "Purchase" event (value: Robux; fields: key, Product or Pass, where it was offered). A revive reopens the run's progression record so its real end is still logged.

## Testing in Studio

- **Test purchases**: with the ids in, Studio's prompts are test purchases (no Robux charged) and `ProcessReceipt` runs for real. Without DataStore access in Studio the grant lives in memory only.
- **Without ids**: from a client probe, `Remotes.DebugReceipt:FireServer(key, id)` sends a made-up receipt (send the same id twice: granted once), and `Remotes.DebugPass:FireServer(key, true/false)` gives or takes a pass. Both are Studio only (`Inbound.debug`).
