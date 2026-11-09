--!strict
--[[
	The gear screen's and shops' pictures (owner, 2026-10-26), uploaded from
	`assets/ui/gear/` (cut by `assets/ui/gear/cutout.py` from Codex's sheets in
	`assets/concepts/blocky/ui/pixel/` and `reveal/`).

	- `weapons` and `pets`: the mini pixel icons ("i like the mini pixel
	  versions of the weapons and pets"), keyed by `Config/WeaponStats` and
	  `Config/Pets` names. A weapon or pet with none falls back to its shop
	  picture or a silhouette; `tests/GearAssets.spec` wants one for each.
	- `crates` (pixel art: `closed` with its two padlocks for the shop, `bare`
	  without them for the reveal, which draws its own to pop off, and `open`,
	  per `Config/Shop` area) and `eggs` (whole,
	  two cracked stages and the burst, per `Config/Eggs` key): the reveals'
	  frames.
	- `models`: each area's egg and chest as Tripo models, shown by `UI/Reveal`
	  in a viewport in place of the frames above.
	- `fx`: white shapes the reveals tint by rarity.
	  An empty id is not drawn.
]]

--[[ One reveal's model: its mesh, its texture, and whether it tips open
     like a lid. The size is the mesh's own, read off the loaded part. ]]
export type RevealPiece = {
	mesh: string,
	texture: string,
	size: Vector3,
	--[[ Its centre from the whole chest's. ]]
	offset: Vector3,
}
--[[ A chest as Tripo's two models (owner, 2026-11-08), measured against each
     other in `assets/concepts/blocky/eggs_chests/two_part/`. `size` is the
     closed chest's and `hinge` the line the lid turns on, from its centre. ]]
export type RevealParts = {
	size: Vector3,
	hinge: Vector3,
	base: RevealPiece,
	lid: RevealPiece,
}
export type RevealModel = {
	mesh: string,
	texture: string,
	tips: boolean,
	parts: RevealParts?,
}

local GearAssets = {
	--[[ The crate's INSIDE tiles cut whole from the chosen mockup (owner,
	     2026-10-26: "make the icons actually from the option C";
	     `assets/ui/gear/optc/`), its chance band cleared for the game's own. ]]
	--[[ The back and arrow buttons, cut from the same mockup. ]]
	buttons = {
		back = "rbxassetid://108896071664277",
		left = "rbxassetid://83943438986636",
		right = "rbxassetid://118687850481288",
	},
	crateTiles = {
		HootmossStaff = "rbxassetid://80030543863014",
		ThornBlade = "rbxassetid://123784490682545",
		AcornBow = "rbxassetid://95876371507095",
		FireflyBow = "rbxassetid://133209449661927",
		MossSlimeBow = "rbxassetid://118564451999252",
		WorldrootStaff = "rbxassetid://140600630838336",
		BroodsplitBlade = "rbxassetid://80045144092728",
		GladeSpiritBow = "rbxassetid://122509292380004",
		LanternStaff = "rbxassetid://136857707110473",
		ToadstoolStaff = "rbxassetid://138209734091526",
		GladeheartBlade = "rbxassetid://82640059295910",
		MossstoneBlade = "rbxassetid://83971051827860",
	} :: { [string]: string },
	--[[ Full-screen backdrops behind the screens (Codex, 2026-10-26). ]]
	--[[ Small pixel icons for the gear screen's tabs and stats (drawn by
	     Claude, `assets/ui/gear/icons/`; owner, 2026-10-27: "the icon next
	     to classes should be a little pixel icon of the male archer classes
	     head ... pets should be a pixel icon of an egg ... ATK ... a pixel
	     sword icon and next to HP ... a pixel heart icon"; the three tab icons
	     then "should be black and white"). ]]
	uiIcons = {
		archerHead = "rbxassetid://107871767440196",
		egg = "rbxassetid://84843820706730",
		sword = "rbxassetid://126689397355795",
		heart = "rbxassetid://130873345081387",
		-- the WEAPON tab's, black and white like CLASSES and PETS (owner)
		swordTab = "rbxassetid://95308296178918",
	},
	backgrounds = {
		gear = "rbxassetid://123017599667033",
		blacksmith = "rbxassetid://77301261973067",
		hatchery = "rbxassetid://107014711671494",
	},
	--[[ The smith hammering at his anvil on the Blacksmith screen (owner,
	     2026-10-26): a 2 x 2 sheet of 512 px frames, raised, swinging,
	     striking, bouncing back, each held `holds` seconds. ]]
	smith = {
		sheet = "rbxassetid://94508718061923",
		holds = { 0.45, 0.08, 0.16, 0.14 },
	},
	-- with a bold dark outline round each (owner, 2026-10-26: "they need to
	-- have a border around them"; `assets/ui/gear/outlined/`)
	weapons = {
		TwigBow = "rbxassetid://114978753383149",
		AcornBow = "rbxassetid://103578254824601",
		FireflyBow = "rbxassetid://80208319043638",
		MossSlimeBow = "rbxassetid://120077348741310",
		EmberFangBow = "rbxassetid://75293205204691",
		GladeSpiritBow = "rbxassetid://100890874259598",
		BranchStaff = "rbxassetid://133371993333327",
		ToadstoolStaff = "rbxassetid://120537771734800",
		LanternStaff = "rbxassetid://94214474044559",
		HootmossStaff = "rbxassetid://79444290362807",
		SlimeCrownStaff = "rbxassetid://114801576848868",
		WorldrootStaff = "rbxassetid://85721041760335",
		TimberBlade = "rbxassetid://130185177403371",
		MossstoneBlade = "rbxassetid://98674732227468",
		ThornBlade = "rbxassetid://79139442067088",
		BroodsplitBlade = "rbxassetid://104383311597642",
		EmberfangBlade = "rbxassetid://138986950232809",
		GladeheartBlade = "rbxassetid://104297938883406",
	} :: { [string]: string },
	pets = {
		Mosslet = "rbxassetid://90863911704588",
		Babacorn = "rbxassetid://76501430507544",
		FernFrog = "rbxassetid://133132247820472",
		ToadstoolTot = "rbxassetid://110117240407269",
		MossbackSnail = "rbxassetid://102332993002493",
		FireflyBun = "rbxassetid://112201723878493",
		Stumpy = "rbxassetid://93282671939278",
		GladeFox = "rbxassetid://94095091677547",
		Hootmoss = "rbxassetid://133339489384185",
		SlimePrince = "rbxassetid://105364611490161",
		EmberWilfPet = "rbxassetid://84054404368414",
		Glimmerhorn = "rbxassetid://71541557210495",
		-- Thornwood
		BarkHoglet = "rbxassetid://85158712161429",
		Burrball = "rbxassetid://132475844312007",
		Budbulb = "rbxassetid://129302109169568",
		BerryMouse = "rbxassetid://129907274141283",
		ThistleMole = "rbxassetid://137326575980464",
		BriarBeetle = "rbxassetid://92531841301355",
		BerryBat = "rbxassetid://101511303102569",
		BrambleBear = "rbxassetid://70373537383448",
		BriarLynx = "rbxassetid://123920723768844",
		BrambleWilf = "rbxassetid://125517331149325",
		ThornPrincess = "rbxassetid://136102772247481",
		Thornwake = "rbxassetid://91756301390532",
		-- Drowned Village. Rendered from the models rather than drawn, since
		-- these five came out of Tripo with no art of their own
		-- (assets/concepts/pets/drowned/README.md)
		SlateTurtle = "rbxassetid://93629127395703",
		BuoyPuffer = "rbxassetid://138169861363295",
		Inkpot = "rbxassetid://118912345465564",
		TideWilf = "rbxassetid://126851107750395",
		AbyssJelly = "rbxassetid://127216427421276",
		-- Bogheart Caverns: Codex's 2D art each Tripo model was made from,
		-- keyed out (assets/ui/shop/bogheart_icons.py, assets/ui/pets/icons)
		CaveCricket = "rbxassetid://71981670304520",
		LichenGecko = "rbxassetid://85124134290575",
		BogBeaver = "rbxassetid://112831862812693",
		Lanternfin = "rbxassetid://123390657742964",
		Olm = "rbxassetid://109387352166966",
		GlowcapWilf = "rbxassetid://86027144186651",
		Gulpling = "rbxassetid://97124284184604",
		PrismLeviathan = "rbxassetid://113063820686924",
	} :: { [string]: string },
	crates = {
		MossyGlade = {
			closed = "rbxassetid://115732608547127",
			bare = "rbxassetid://132518924413005",
			open = "rbxassetid://110805001270540",
		},
		Thornwood = {
			closed = "rbxassetid://139411907605270",
			bare = "rbxassetid://130462577945262",
			open = "rbxassetid://132986191598031",
		},
		DrownedVillage = {
			closed = "rbxassetid://129406927323412",
			bare = "rbxassetid://93374148317621",
			open = "rbxassetid://78736767331636",
		},
		BogheartCaverns = {
			closed = "rbxassetid://74264485531007",
			bare = "rbxassetid://88397231327506",
			open = "rbxassetid://100424663327388",
		},
		WindsweptCliffs = {
			closed = "rbxassetid://109820030254804",
			bare = "rbxassetid://123984843499980",
			open = "rbxassetid://126672295487581",
		},
		FrostpeakPass = {
			closed = "rbxassetid://84025185082724",
			bare = "rbxassetid://94739226508814",
			open = "rbxassetid://96625859132471",
		},
	} :: { [string]: { closed: string, bare: string, open: string } },
	eggs = {
		MossyEgg = {
			whole = "rbxassetid://106270870780677",
			crack1 = "rbxassetid://83969750477878",
			crack2 = "rbxassetid://71861915568555",
			burst = "rbxassetid://140609227414793",
		},
		ThornwoodEgg = {
			whole = "rbxassetid://104439505138184",
			crack1 = "rbxassetid://114936238157331",
			crack2 = "rbxassetid://116737796954527",
			burst = "rbxassetid://80786736493750",
		},
	} :: { [string]: { whole: string, crack1: string, crack2: string, burst: string } },
	--[[ Each area's egg and chest as its low-poly Tripo model (imported
	     2026-11-06 into the TEST place's `Workspace/TripoImports/EggsChests`;
	     owner: "Yes, wire them in"), keyed by `Config/Economy` area: an
	     egg's hatch plays its area's egg (`Config/Eggs.area`), a crate opens
	     as its area's chest. Shown in a viewport by `UI/Reveal`; the texture
	     is the import's colour map (a SurfaceAppearance cannot be built at
	     runtime). An area with none here, or one that failed to load, plays
	     its pictures.
	     `tips` would rock a lid open, but each chest is one mesh with no lid
	     of its own, so it is false: the whole chest hops and bursts. ]]
	models = {
		eggs = {
			MossyGlade = {
				mesh = "rbxassetid://110872804534404",
				texture = "rbxassetid://138523988202666",
				tips = false,
			},
			Thornwood = {
				mesh = "rbxassetid://131135211719829",
				texture = "rbxassetid://72502064715956",
				tips = false,
			},
			DrownedVillage = {
				mesh = "rbxassetid://119687601447639",
				texture = "rbxassetid://115912952901561",
				tips = false,
			},
			BogheartCaverns = {
				mesh = "rbxassetid://127228698242978",
				texture = "rbxassetid://103981750935904",
				tips = false,
			},
			WindsweptCliffs = {
				mesh = "rbxassetid://106669072404570",
				texture = "rbxassetid://76597900175207",
				tips = false,
			},
			FrostpeakPass = {
				mesh = "rbxassetid://96120168915035",
				texture = "rbxassetid://73121541765287",
				tips = false,
			},
		} :: { [string]: RevealModel },
		chests = {
			MossyGlade = {
				mesh = "rbxassetid://113330487163741",
				texture = "rbxassetid://114390284272834",
				tips = false,
				parts = {
					size = Vector3.new(0.9805, 1.082, 0.8009),
					hinge = Vector3.new(0, 0.0266, 0.4005),
					base = {
						mesh = "rbxassetid://135892239281164",
						texture = "rbxassetid://131836554502455",
						size = Vector3.new(0.9805, 0.687, 0.8009),
						offset = Vector3.new(0, -0.1975, 0),
					},
					lid = {
						mesh = "rbxassetid://81973836639492",
						texture = "rbxassetid://74167299333466",
						size = Vector3.new(0.9805, 0.5224, 0.8009),
						offset = Vector3.new(0, 0.2798, 0),
					},
				},
			},
			Thornwood = {
				mesh = "rbxassetid://78975216964906",
				texture = "rbxassetid://130024333307677",
				tips = false,
				parts = {
					size = Vector3.new(0.9864, 0.9671, 0.8202),
					hinge = Vector3.new(0, 0.0382, 0.4101),
					base = {
						mesh = "rbxassetid://124771487856216",
						texture = "rbxassetid://104227547789617",
						size = Vector3.new(0.9864, 0.5977, 0.8202),
						offset = Vector3.new(0, -0.1847, 0),
					},
					lid = {
						mesh = "rbxassetid://104685735508381",
						texture = "rbxassetid://88616709357164",
						size = Vector3.new(0.9864, 0.4533, 0.8202),
						offset = Vector3.new(0, 0.2569, 0),
					},
				},
			},
			DrownedVillage = {
				mesh = "rbxassetid://73700749705895",
				texture = "rbxassetid://134194978002263",
				tips = false,
				parts = {
					size = Vector3.new(0.9809, 0.9855, 0.7987),
					hinge = Vector3.new(0, 0.0368, 0.3993),
					base = {
						mesh = "rbxassetid://98867367079462",
						texture = "rbxassetid://98701113890605",
						size = Vector3.new(0.9809, 0.6107, 0.7987),
						offset = Vector3.new(0, -0.1874, 0),
					},
					lid = {
						mesh = "rbxassetid://123080051677159",
						texture = "rbxassetid://103393310686032",
						size = Vector3.new(0.9809, 0.4639, 0.7987),
						offset = Vector3.new(0, 0.2608, 0),
					},
				},
			},
			BogheartCaverns = {
				mesh = "rbxassetid://98295346767225",
				texture = "rbxassetid://115463165012046",
				tips = false,
				parts = {
					size = Vector3.new(0.981, 0.9775, 0.822),
					hinge = Vector3.new(0, 0.0594, 0.411),
					base = {
						mesh = "rbxassetid://123426397997839",
						texture = "rbxassetid://115138932645043",
						size = Vector3.new(0.981, 0.632, 0.822),
						offset = Vector3.new(0, -0.1728, 0),
					},
					lid = {
						mesh = "rbxassetid://105799878792834",
						texture = "rbxassetid://136509349093708",
						size = Vector3.new(0.981, 0.4374, 0.822),
						offset = Vector3.new(0, 0.2701, 0),
					},
				},
			},
			WindsweptCliffs = {
				mesh = "rbxassetid://124902873841536",
				texture = "rbxassetid://108531951634378",
				tips = false,
				parts = {
					size = Vector3.new(0.982, 0.9355, 0.7825),
					hinge = Vector3.new(0, 0.0219, 0.3913),
					base = {
						mesh = "rbxassetid://71192920658239",
						texture = "rbxassetid://114248985447078",
						size = Vector3.new(0.982, 0.6822, 0.7825),
						offset = Vector3.new(0, -0.1267, 0),
					},
					lid = {
						mesh = "rbxassetid://98152446521174",
						texture = "rbxassetid://112258537896151",
						size = Vector3.new(0.982, 0.4538, 0.7825),
						offset = Vector3.new(0, 0.2409, 0),
					},
				},
			},
			FrostpeakPass = {
				mesh = "rbxassetid://116730027578371",
				texture = "rbxassetid://81088159126838",
				tips = false,
				parts = {
					size = Vector3.new(0.9805, 0.9896, 0.9455),
					hinge = Vector3.new(0, 0.0656, 0.4727),
					base = {
						mesh = "rbxassetid://80481437497082",
						texture = "rbxassetid://133361961899496",
						size = Vector3.new(0.9805, 0.6285, 0.9455),
						offset = Vector3.new(0, -0.1806, 0),
					},
					lid = {
						mesh = "rbxassetid://115125153213374",
						texture = "rbxassetid://126691683522131",
						size = Vector3.new(0.9805, 0.4372, 0.9455),
						offset = Vector3.new(0, 0.2762, 0),
					},
				},
			},
		} :: { [string]: RevealModel },
	},
	--[[ Each area's egg and chest as one picture (Codex's per-area art,
	     `assets/concepts/blocky/eggs_chests/egg_<area>.png` and
	     `chest_<area>.png`, 2026-11-06), for an egg or chest with no model
	     and no cut frames above: `UI/Reveal` draws its cracks and light over
	     it (cut by assets/ui/shop/bogheart_icons.py into assets/ui/reveal/).
	     "" until uploaded, and then the reveal draws its own in the
	     area's colours (`Config/Reveal.shells`; a chest falls back to
	     Victory's first). A Tripo model, once imported, goes in `models`
	     under the egg's key or the chest's area and wins over all of it. ]]
	areaPictures = {
		eggs = {
			MossyGlade = "rbxassetid://76065283088869",
			Thornwood = "rbxassetid://108887450586880",
			DrownedVillage = "rbxassetid://121474380981161",
			BogheartCaverns = "rbxassetid://83295936746424",
			WindsweptCliffs = "rbxassetid://92920546659530",
			FrostpeakPass = "rbxassetid://116457878440348",
		} :: { [string]: string },
		chests = {
			MossyGlade = "rbxassetid://125919531196238",
			Thornwood = "rbxassetid://76697875072018",
			DrownedVillage = "rbxassetid://112729800271804",
			BogheartCaverns = "rbxassetid://130442503309827",
			WindsweptCliffs = "rbxassetid://134250106942954",
			FrostpeakPass = "rbxassetid://109095257627714",
		} :: { [string]: string },
	},
	--[[ The showcase behind a pulled prize (owner, 2026-10-26: option 4, "the
	     showcase pedestal with the rarity banner and confetti"): white, tinted
	     by rarity. The banner is 748 x 297, the pedestal 642 x 318. ]]
	showcase = {
		banner = "rbxassetid://77309143397049",
		pedestal = "rbxassetid://105357351623859",
		spotlight = "rbxassetid://107959114129330",
	},
	fx = {
		rays = "rbxassetid://123315883761316",
		glow = "rbxassetid://72053512669132",
		sparkle = "rbxassetid://140286080633760",
		star = "rbxassetid://75276390003946",
		ring = "rbxassetid://119651633511726",
		confetti = "rbxassetid://86883153796302",
		badge = "rbxassetid://108895879713593",
	},
}

return table.freeze(GearAssets)
