# Island Rescue! — Game Design Document (GDD) v0.7

**Version:** v0.7  
**Date:** 2026-11-22  
**Author / Team:** XMR (2 people)  
**Competition:** AI Game Creation Competition  
**Purpose:** Team alignment, constraints for AI-generated specifications, scope control and submission instructions.  
**Engine:** Godot 4 (Web export)  
**Deployment:** ModelScope Spaces

> Translation note: Figures and unresolved inconsistencies in the source are retained rather than silently corrected. In particular, “November 31” in section 1 is not a valid calendar date; the source also contains conflicting building/population totals and first-attack timing.

## 0. One-Page Summary

- **Pitch:** A once-in-ten-thousand-years storm devastates the Bilega archipelago. As its founder and leader, gather scattered supplies, rescue survivors and rebuild three island bases over ten days, defending them with residents against deep-sea enemies each night.
- **Genre:** Tower defense / strategy / RPG, with light character progression and equipment.
- **Platform:** Browser, using Godot Web export hosted on ModelScope Spaces.
- **Session length:** 10 × (100-second day + 2-second transition + 80-second night) = **1,820 seconds, approximately 30.3 minutes**.
- **Experience:** Long-term technology planning versus immediate resident assignment; production versus defense; the player can stand on only one island during simultaneous attacks.
- **Scope:** Three islands; main base levels 1–4, secondary bases levels 1–2; ten days and nights, with a final-night BOSS; three resident professions; two six-node trees and three synergies. The **High Tower** is the sole tower-type building; its garrison determines its form. Empty towers cannot attack. Electricity capacity enters at technology level 5.
- **Technology route:** Strengthen the player into a combat machine that clears enemies and patrols islands rapidly.
- **Resident route:** Strengthen population; field eight combat residents and one hero on an island by night ten, relying on people rather than towers.
- **Tension:** Another island is losing HP while you fight on the main island. Communications reveal the danger, but support requires a seven-second voyage.
- **Excluded:** Resident death, simultaneous multi-island views, open world and inter-island logistics.

## 1. Project Information and Rule Constraints

| Item | Content |
|---|---|
| Deadline / time zone | November 31, 23:00 (as written in the source; invalid date, requires confirmation) |
| Development from scratch | Yes |
| Engine / asset / plugin restrictions | Godot |
| Deliverables | Playable ModelScope Spaces link, AI-use disclosure, competition concept-post link |
| Scoring criteria | None |
| Public concept-post link | Already available |
| Compliance risks | None listed |

**Acceptance:** Open the playable link without signing in and complete a session; disclose all generated assets.

## 2. Concept and Positioning

### 2.1 Setting and Theme
A catastrophic storm devastates Bilega. Its founder and leader gathers supplies, rescues residents and rebuilds by day, then fights deep-sea enemies alongside residents at night. The tone is **restoring order**, rather than merely surviving alone: the player starts alone but progresses from swinging a sword to commanding a defense. No competition theme is specified.

### 2.2 Player Fantasy
Become a great and powerful leader. See ruins become lively settlements; see daytime defense investments pay off that night or the next day; command across three islands and judge where danger is greatest.

### 2.3 Design Pillars
1. Prepare by day, defend by night: decisions first, execution and adaptation later.
2. Technology is long-term planning; residents are immediate deployment.
3. Resources remain insufficient, forcing economy-versus-defense choices.
4. Control only your own character; the player is one defensive resource, not a universal solution.
5. Build the line and staff it: an empty tower is a wall; its occupant determines its form.
6. Failure has consequences without humiliation: BE allows loading a save; secondary islands can be reclaimed.

### 2.4 Anti-Pillars
No resident affection or death; no simultaneous multi-island views (parallel data simulation is required); no complex branching story or open world; no logistics because resources are shared; no new systems after week 3.

### 2.5 Routes: Mixed (Recommended), Technology, Residents
Both trees progress independently. Levels 2, 3 and 4 have cross-tree synergies.

| Route | Research allocation | Identity | Endgame |
|---|---|---|---|
| Mixed, recommended first run | Technology 4 (15) + Residents 4 (15) = 30 | All three synergies | Balanced, most forgiving |
| Technology | Technology 35 + Residents level 2 cost 3 = 38 | Powerful player and rapid patrols | Strong player + unmanned facilities |
| Residents | Residents 35 + Technology level 1 cost 0 = 35 | Population cap 40; 15 combat-capable including two heroes | Eight combat residents + one hero on one island |

Rules: Synergy 2 requires both trees at level 2. Technology specialists spend three resident points for communications. Resident specialists stop at technology 1, have no communications tower, and rely on each island holding independently. Level 1 is free in both trees. Both specialist routes must be completable without random drifters; essential population is guaranteed. Days 1–2 teach mixed investment; after the first victory recommend specialist runs.

## 3. Core Gameplay Loop

### 3.1 Loop
**Day:** Wake on main island → gather wood/stone/iron/food → order construction through builders → repair → upgrade cores → invest in trees → assign residents, including tower garrisons → explore secondary islands from day 2 → clear and reclaim lost islands → night.
**Night:** Islands with cores face simultaneous attacks → fight on one island → receive remote reports through Synergy 2 → decide whether to sail for support → gather/build after clearing local waves → results at 80 seconds.

### 3.2 Phases

| Phase | Actions | Feedback | Duration |
|---|---|---|---|
| Day | Gather, build, repair, upgrade, assign, research, travel, clear survivors | Resources, progress bars, work animations, countdown | 100 seconds, cannot end early |
| Transition | No control | Camera pulls back, deep-blue lighting, attack directions | 2 seconds |
| Early night | Combat, monitor, support | Hits, kills, core/facility HP, alerts | While waves remain, usually 40–70 seconds |
| Late night | Cleared island is safe; gather/build/repair, no demolition | Day-style feedback | Until 80 seconds |
| Results | Damage, losses, perfect defense, repair costs | Paused overlay on next morning | Player continues |
| Next day | Increment day | Day begins | — |

No separate dusk state: only the final 20 daytime seconds change atmosphere. Night cannot be skipped or ended early. Clearing waves leaves playable time; building and repair remain allowed, demolition does not. Total fixed time: 1,820 seconds.

### 3.3 Suggested Tutorial Order
Check resources/electricity → find builder and replace damaged walls/towers → choose economy or defense spending → staff towers → sail early if needed → clear enemies and use remaining night for construction.

## 4. Victory, Defeat and Endings

### 4.1 Definitions
**Island damage ratio** = (1 − current total non-defensive-structure HP / maximum total non-defensive-structure HP) × 100%.
Count cores, warehouses, housing, docks, generators and oil wells. Do not count walls, towers, barricades, Tesla towers, automated mortars or residents. Non-defensive HP does not regenerate automatically; repair by day (6.14).

**Lost / To Reclaim:** At night timeout, enemies remain and all offensive defenses—High Towers, Tesla towers, automated mortars and combat residents—are gone. Walls/barricades do not count because they deal no damage.

**Perfect defense:** That island takes no non-defensive-structure damage during that night and is not lost. If defenses survive at timeout, remaining enemies retreat to sea. Only lost islands retain enemies into daytime.

### 4.2 Defeat
Immediately trigger BE if main-core HP reaches zero, player HP reaches zero, or any island is lost on night ten. Losing walls/defenses alone is not defeat while the core remains. Earlier secondary-island losses become To Reclaim. Interrupt play → BE → save selection.

### 4.3 Victory
Night ten is the final BOSS night; all islands are attacked, main island prioritized. Clear its waves with all islands reclaimed to enter victory immediately.

| Ending | Condition | Presentation |
|---|---|---|
| NE | Survive night ten without losing an island | Main ending |
| HE | NE plus final damage ratio ≤20% on every island | Main ending + bonus scene |

The 20% threshold is a final-night snapshot, not accumulated session damage.

### 4.4 Perfect-Defense Rewards
Judge independently per island/night: next-day output +10% and resident trust +1, both guaranteed; first drifter guaranteed, later chance 25%, subject to cap. No research points: these come only from core upgrades and player levels. Generate rewards deterministically from (day, island ID) and the saved seed to prevent reload farming.

### 4.5 Ending Flow
Death / main-core destruction / final-night loss → 3–5 short text screens for BE → save selection → load a daytime save.
Final-night clearance without losses → HE/NE → ending → statistics: duration, damage per island, perfect defenses, total trust and equipment level.

### 4.6 Reclaiming Secondary Islands

| Stage | State | Rules |
|---|---|---|
| Loss night | To Reclaim | Mark lost; retain at most five enemies; excess retreats |
| Next day | To Reclaim | No production; residents shelter, cannot be assigned, consume no food; defense wreckage remains |
| Reclamation | To Reclaim → Owned | Arrive, kill ≤5 enemies, repair core to 100%, instantly and without daily cap |
| Reclaimed | Owned | One-second resident return; production resumes; rebuild wreckage |

Budget: 5-second travel + 10–15-second combat + instant repair + 1-second return = 16–21 seconds, under half a day (50 seconds). Enemies retain current HP. Full repair costs (0.4 wood + 0.2 stone) per HP × island-level factor. The 25% daily repair cap does not apply while To Reclaim. Unreclaimed islands on night ten cause defeat.

## 5. Session Flow and State Machine

```
Boot → MainMenu → SaveSelect → Day ⇄ Travel
                                  ↓
                              Night → Result → NextDay → Day
                                 ↓
          main-core destruction / player death / night-10 loss → BE → SaveSelect
          night-10 clearance → Victory(NE/HE) → Result
```

| State | Entry | Behavior | Exit |
|---|---|---|---|
| MainMenu | Launch | New / continue / load / settings | Selection |
| SaveSelect | Menu or BE | Up to ten slots | Load |
| Day | Morning | Economy, construction, trees, assignment, travel, saving | 100-second timeout |
| Travel | Depart dock | Uncontrollable voyage | Arrival |
| Night | Transition ends | Local rendered combat, remote same-model simulation; work after clearance, no demolition | 80-second timeout or defeat |
| Result | Night ends | Per-island damage/loss/rewards/repairs | Confirm |
| NextDay | Confirm | Day +1, autosave, process lost islands | Day |
| BE | Defeat | Ending | SaveSelect |
| Victory | Night-ten clearance | HE/NE and ending | Results, then menu |

Save only in Day, including autosaves. PlayerIslandRendered and RemoteIslandHeadless run in parallel. Result is a paused overlay on the next morning.

## 6. System Design

### 6.1 Player and Interaction

| Item | Rule |
|---|---|
| View | Orthographic 2D top-down |
| Movement | WASD/arrows; mouse building/interaction |
| Gathering | Hold interaction beside a deposit |
| Attack | Left-click 100° melee arc; range/damage from weapon + technology |
| Building | First rescue a construction resident; interact to open menu, grid preview, click to start timed construction |
| Construction work | Builders work automatically at site; player can also work |
| Demolition | Day only; refund 100% |
| Core upgrade | Stand beside core; three-second action |
| Repair | Beside damaged structure; instant resource-consuming interaction |
| HP | Base 150, +10 every three levels (6.13); armor and technology apply |
| Healing | F consumes one food, heals 20 HP; three-second cooldown |
| Death | HP zero → immediate BE |

### 6.2 Day and Night
Day 100 seconds, no early ending; last 20 seconds use dusk colors only. Transition 2 seconds, no control. Night 80 seconds, no skip; work after clearance, no demolition. Results pause until confirmation. Ten days/nights total 1,820 seconds.

### 6.3 Inventory and Resources

| Resource | Initial | Uses | Sources |
|---|---|---|---|
| Wood | 30 | Building, repair, upgrades, equipment | Main/A trees |
| Stone | 10 | Building, upgrades, repair, equipment | Main/B deposits |
| Iron | 0 | Tower upgrades, advanced facilities, equipment | Sparse main; A/B |
| Food | 20 | Resident upkeep, facility maintenance, resident recovery, player healing | Main/A berries |
| Research | 0 | Both trees | Core upgrades and player levels only |
| Electricity capacity | 0 | Tesla/automated mortars | Each generator +2 |

Electricity is capacity, not consumable stock. If demand exceeds capacity, disable highest-demand facilities first; show shortage. Global inventory, separate cap per resource:
**120 + (main base level − 1) × 50 + warehouse count × 40**. Excess gathering is wasted.

| Deposit | Yield | Daily regrowth |
|---|---|---|
| Tree | 15 wood | +50%, rounded up |
| Stone | 10 stone | +50% |
| Iron | 8 iron | +50% |
| Berry bush | 12 food | +50% |

| Island | Trees | Stone | Iron | Berries |
|---|---|---|---|---|
| Main | 6 | 4 | 1, six iron | 3 |
| A | 4 | 2 | 3, eight each | 6 |
| B | 2 | 5 | 3, eight each | 3 |

A's berries increase from five to six because 40 residents make food the bottleneck. Bare-hand rates: wood 4/s, stone 3/s, iron 2/s, food 5/s. A specializes in food/wood/iron; B in stone/iron.

### 6.4 Construction

| Building | Category | Wood | Stone | Iron | HP | Time | Effect | Upgrade |
|---|---|---|---|---|---|---|---|---|
| Core | Non-defense | Unbuildable | — | — | 6.12 | — | Island lifeline | Base level |
| Warehouse | Non-defense | 30 | 20 | 0 | 80 | 4s | Global per-resource cap +40 | None |
| Housing | Non-defense | 25 | 0 | 0 | 60 | 3s | Local job slot +1 | None |
| Dock | Non-defense | 30 | 10 | 0 | 70 | 8s | Boat access | None |
| Automatic generator | Non-defense | 30 | 20 | 10 | 80 | 6s | Capacity +2 | None |
| Automatic underground oil well | Non-defense | 35 | 15 | 8 | 70 | 8s | 2 wood +1 stone +1 iron every 12s | None |
| Wall | Defense | 5 | 0 | 0 | 120 | 2s | Blocks enemies | Lv2: five stone, 190 HP |
| Barricade | Defense | 10 | 0 | 0 | 30 | 1s | Changes routes | None |
| High Tower | Defense | 25 | 15 | 0 | 70 | 6s | Garrison determines form | Lv2: 15 stone +8 iron; Lv3: 25 stone +15 iron |
| Tesla tower | Defense | 40 | 25 | 15 | 80 | 8s | Area shock; demand 1 | None |
| Automated mortar array | Defense | 45 | 35 | 20 | 90 | 10s | Area bombardment; demand 2 | None |

Archer/communications/cannon/mortar towers are forms, not four separate buildings. Node 1 unlocks warehouse/housing/dock/wall/barricade; node 2 High Tower; nodes 3/4 tower Lv2/3; node 5 generator/oil well/Tesla; node 6 automated mortar.

Construction pauses when the player leaves the site; builder presence adds 60% speed. Tower upgrades take 4s, wall upgrades 2s. Grid placement excludes water, deposits and occupied tiles. Always preserve a passable route from every enemy spawn to the core; reject blocking placements. No building within one tile of core or two of dock. Exhausted deposit tiles become buildable.

High Tower count is limited by base level; Tesla/mortars use electricity instead of tower slots. Daytime demolition refunds all materials.

### 6.5 High Tower: Empty Wall, Occupied Tower

| Occupant/state | Form |
|---|---|
| Empty | No attacks. Connected adjacent to at least one wall, counts as a 70-HP blocking wall, attackable and included in connectivity. Isolated: neither useful nor blocking. |
| Any resident temporarily assigned | Archer tower, fast single-target ranged |
| Combat resident | Elite archer: damage ×1.5, range +10% |
| Signal soldier, Synergy 2 | Communications; no attack |
| Cannoneer, Synergy 3 | Slow, powerful splash |
| Mortar soldier, Synergy 4 | Very long range and large splash |

Drag resident onto tower, occupying their job; no production/gathering while stationed. One occupant per tower; remove anytime. Empty towers immediately revert to wall/isolated state. **Occupied towers are not walls:** enemies can pass. This is the damage-versus-blocking trade-off. Destroying a tower makes its occupant retreat immediately without HP loss; recover with food next day. Levels 1–3 improve all forms; nodes 3/4 unlock upgrades.

### 6.6 Player and Equipment

#### 6.6.1 Attributes
Initial HP 150, cap 180 through +10 every three levels; speed 120 px/s, cap 120; initial attack interval 0.55s and knockback 30px, subsequently weapon-defined. Technology adds further player bonuses.

#### 6.6.2 Player-Only Rusted Shortblade

| Level | Damage | Range | Knockback | Upgrade cost |
|---|---|---|---|---|
| 1 | 10 | 55px | 30px | Initial |
| 2 | 13 | 58px | 34px | 10 stone +5 iron |
| 3 | 16 | 60px | 38px | 20 stone +10 iron |
| 4 | 20 | 62px | 42px | 35 stone +18 iron |
| 5 | 24 | 65px | 46px | 50 stone +28 iron |

Fixed 100° melee arc.

#### 6.6.3 Shared Ranged Weapons

| Weapon | Damage | Interval | Range | Cost |
|---|---|---|---|---|
| Shortbow | 6 | 1.0s | 90px | 20 wood +5 iron |
| Longbow | 10 | 1.2s | 110px | 30 wood +10 iron |
| Crossbow | 16 | 1.8s | 130px | 40 wood +18 iron |

#### 6.6.4 Shared Armor

| Armor | Reduction | Cost |
|---|---|---|
| Leather | 10% | 30 wood +5 iron |
| Iron | 20% | 20 stone +12 iron |
| Refined iron | 30% | 40 stone +20 iron |

#### 6.6.5 Equipment Rules
Craft/upgrade instantly by day in Character, spending resources, while on any reclaimed island. Equipment forms one globally unique shared set: the same ranged item cannot serve player and resident simultaneously. Combat residents may use ranged weapons/armor, never the shortblade. Player can switch to melee anytime in Character.

### 6.7 Enemies and Combat

#### 6.7.1 Enemies

| Enemy | HP | Damage | Interval | Range | Speed | Targeting |
|---|---|---|---|---|---|---|
| Erosion Beast | 30 | 5 | 1.0s | Contact | 60px/s | Nearest attackable building |
| Ranged Entity | 20 | 8 | 1.2s | 90px | 80px/s | Towers → walls → other buildings |
| Heavy Shell | 80 | 10 | 1.2s | Contact | 45px/s | Defenses first; building damage ×1.5 |
| Broodmother BOSS | 600 | 20 | 1.5s | Contact | 35px/s | Core; summons three beasts every 12s |

Unified targeting, inspired by Arknights: Reclamation Algorithm:
1. If blocked, attack blocker.
2. With attack range, select in-range nearest target within highest available tier: A occupied High Towers/Tesla/automated mortars; B walls/wall-like empty towers/barricades; C all other structures.
3. No target: advance on shortest route.
4. At core contact: attack core.

Walls therefore stop ranged enemies; towers draw fire, making protected placement meaningful; melee enemies attack the foremost blocker rather than being lured into towers.

Each island has 2–4 fixed sea-facing entrances. Use a manually placed 12–20-waypoint graph with Dijkstra and straight segments, **not A***. A wall/wall-like tower on a segment stops enemies, which attack instead of detouring. Barricades do not block; multiply adjacent edge costs by four to induce detours. Small graph keeps computation cheap and avoids wall-corner sticking. Fixed waves come from 7.2, not a formula.

#### 6.7.2 Damage
Damage = base × (1 + bonus) × (1 − reduction). No criticals or elemental matchups. Armor reduces player/resident damage; buildings have no reduction. Feedback: optional numbers, hit flashes, red damage flashes, cracks, projectiles and demolition audio. Weapon knockback also affects ranged enemies.

### 6.8 Islands, Map and Docks
Main island is central; A northeast, B southeast, connected across the sea through docks.

| Island | Base levels | Specialty | Unlock |
|---|---|---|---|
| Main | 1–4 | Wood/stone | Initial |
| A | 1–2 | Food/iron | Day 2, boat |
| B | 1–2 | Stone/iron | Day 3, second voyage |

Each has one fixed coastal dock position. Main dock starts broken, repair for 20 wood. Secondary docks cost 30 wood +10 stone. First story landing requires no dock; day-two boat lands on shore and unlocks island. Later travel requires working docks at both ends. Any route: 5s daytime, 7s nighttime. Player cannot act or be attacked during sailing; alerts continue. Destroyed dock prevents targeting that island. If destination falls during travel, rescue landing remains allowed without dock.

Map: archipelago overview plus island list with name, status badge, level, core HP, dock state and Travel.

### 6.9 Simultaneous Island Nights
Unlocked islands are attacked together. Render/control only the player's island. **All islands run exactly the same simulation**, without abstract models or conversion. No fast-forward views, picture-in-picture or split screen.

A single simulation avoids enemy rounding, lost distances/projectiles/cooldowns and switching exploits; changing island toggles rendering, preserving state. An idle player and absent player should be equivalent for balancing.

Fixed 20Hz logic, accumulator, independent 60-FPS rendering. Each IslandWorld retains enemies' position/HP/target/cooldown/range/priority; buildings' HP/level/cooldown/projectiles/progress/garrison/power/wall status; residents' position/HP/jobs/skills/equipment/tower; wave cursor. Remote islands drop to 5Hz after five seconds without player or communication popup.

Budget: all three combined ≤120 enemies, ≤45 buildings, ≤40 residents; <3ms logic per frame at 20Hz. Same save/night replay must match exactly. Arrival enables rendering/camera/input; departure disables rendering, not simulation. No reconstruction. Travel is physical support, not teleportation; 5s day, 7s night.

### 6.10 Communications
A communications tower is High Tower + signal soldier, not a standalone building.

| Level | Unlock | Information |
|---|---|---|
| 0 | Default | Local island only; remote attack-presence by day, no night contact |
| 1 | Main base ≥2 plus one staffed communications tower | Remote non-defense HP, wave progress, normal/danger/lost labels |
| 2 | Communications tower Lv2, requiring technology 3 | Estimated time to loss, perfect-defense risk, automatic alerts, best support target |

Level 1 requires technology 2, resident 2/Synergy 2 and main base 2. Technology specialists invest three resident points; resident-only route has no towers/communications and deliberately fights blind. Warning lead ≥15s versus seven-second travel. Extrapolate current DPS; refresh every 2s, approximately ±3s error. Destroying tower or signal retreat resets communications to zero until rebuilt.

### 6.11 Residents

#### 6.11.1 Story Tutorial
Day 1, 0–40s: follow footprints, lift collapsed beam, rescue Artisan; first builder opens construction.
Day 1, 40–100s: wall → High Tower → garrison; obtain one usable archer tower.
Day 2, first 50s: discover collapsed settlement, rescue one builder and two combat residents; unlock Resident Assignment and teach dragging onto towers. Total four; combat residents available day two.
Before first builder, no building menu. Each discovery has 1–2 short dialogue screens.

#### 6.11.2 Professions
Construction/production: day-one and day-two story; construction access, faster work/repair, delegated work.
Combat: day-two tutorial and B; garrisons, skills and equipment.
Gathering: A exclusively, first day-two landing; gathering bonuses/passive production.
Unlock at most one island per day: first on day two, second day three. Both appear on first-voyage map with exclusive professions. End of day two guarantees two builders and two combat residents.

#### 6.11.3 Rules

| Item | Rule |
|---|---|
| Progression | Level = trust, 0–5; efficiency +8% per level |
| Trust gain | Work +0.2/day; night defense +0.3/night; perfect defense +1 |
| Upkeep | One food/person/day; shortage halves next-day efficiency; no death or departure |
| Retreat | Combat HP zero: leave combat, untargetable; next day food cost = HP lost ×2 |
| Equipment | Combat residents use armor/ranged weapons |
| Skills | One passive and one active each |
| Jobs | Gather/research/build-repair/High Tower/communications/idle |
| Location | Bound to island; relocation uses same boat times |

Tower garrison is distinct from ground deployment: occupant drives tower, no independent action; retreats if tower destroyed.

#### 6.11.4 Guaranteed Pool

| Source | Count |
|---|---|
| Day-one story | One builder |
| Day-two tutorial | One builder + two combat |
| A | Two gatherers |
| B | Two combat |
| Resident nodes 2/3/4/5/6 | +2 combat / +3 any / +3 any / +4 combat / +6 including three combat |
| Drifters | Extra perfect-defense reward; first guaranteed, later 25%, cap applies |

Eight story +18 tree residents =26 guaranteed, including 13 combat (four story +nine tree), plus two heroes =15 combat-capable. Drifters fill cap. Caps: 12→20→30→40.

Endgame resident route: main, with player, eight combat +one hero +walls; A, three–four combat +walls; B, three–four combat +walls (hero). Section 7.2 must allow those secondary garrisons to hold.

#### 6.11.5 Base Stats

| Profession | HP | Work bonus | Combat |
|---|---|---|---|
| Construction | 60 | Build/repair +60% | Temporary archer garrison |
| Gathering | 50 | Gather +50%; passive wood 1.5/s or stone 1/s or food 2/s | Temporary archer garrison |
| Combat | 90 | — | Damage 8, interval 1.2s, range 70px; replaceable gear; tower damage ×1.5 |
| Hero, resident 6 | 300 | — | Damage 24, interval 1s, range 90px; local combat-resident damage +40% |

### 6.12 Base Levels

| Island | Level | Core HP | Towers | Jobs | Upgrade cost | Gate | Research reward |
|---|---|---|---|---|---|---|---|
| Main | 1 | 200 | 2 | 2 | Initial | — | — |
| Main | 2 | 280 | 3 | 3 | 80 wood +40 stone | — | +3 |
| Main | 3 | 380 | 4 | 4 | 150 wood +90 stone | Total research earned ≥12 | +4 |
| Main | 4 | 500 | 5 | 5 | 250 wood +160 stone | Total earned ≥28 | +5 |
| Secondary | 1 | 150 | 2 | 1 | On unlock | — | +1 |
| Secondary | 2 | 300 | 3 | 2 | 150 wood +90 stone | Main ≥3; earned ≥12 | +3 |

Secondary upgrades intentionally match main level-3 cost and require it first. Gates check cumulative earned research, not spendable balance. Main level 4 needs 250 wood; level-3 cap 220 requires at least one warehouse, raising it to 260. Island population capacity = base job slots +housing +resident-node-3 bonus two. Resident specialists need housing for eight-plus local slots.

### 6.13 Player Levels

| Level | Total XP | Reward |
|---|---|---|
| 1 | 0 | Initial |
| 2 | 40 | 2 research |
| 3 | 100 | 2 research |
| 4 | 180 | 2 research, max HP +10 |
| 5 | 280 | 3 research |
| 6 | 400 | 2 research |
| 7 | 540 | 2 research, max HP +10 |
| 8 | 700 | 2 research |
| 9 | 880 | 2 research |
| 10 | 1080 | 3 research, max HP +10 |

Player progression totals 20 research; island upgrades also total 20. Equal sources prevent ignoring islands or making levels irrelevant. Without island upgrades, half the research is lost and no tree can be maxed.

| Event | XP |
|---|---|
| Beast/Ranged Entity kill | 2 |
| Heavy Shell kill | 5 |
| Broodmother kill | 40 |
| Complete construction | 3 |
| Perfect defense, island/night | 15 |
| Reclaim island | 25 |
| Survive night | 10 |

### 6.14 Upkeep, Repairs and Damage
Damage ratio uses non-defense HP.

| Daytime non-defense repair | Rule |
|---|---|
| Location | Beside damaged building on its island |
| Time | Instant |
| Cost per HP | (0.4 wood +0.2 stone) × island factor |
| Factor | Main 1/2/3/4: 1.0/1.2/1.4/1.6; secondary 1/2: 0.8/1.0 |
| Daily cap | 25% of total non-defense maximum HP per island; To Reclaim exempt |

At dawn, automatically repair damaged defenses for construction materials ×missing-HP fraction, rounded up. Insufficient materials leave damage for manual repair. Damaged, undestroyed towers still fight; only zero HP disables. Technology 6 makes dawn repair free and full. Combat-resident recovery costs food = HP lost ×2 next day.

Base upgrades preserve HP ratio: 300/380 becomes 394/500. Do not reset daily repair allowance; recalculate remainder against new maximum. Three-second upgrade action interrupts on damage without deducting resources.

### 6.15 Saves
Day only. Autosave each morning, one rolling slot; manual save anytime by day. Ten slots total: one auto, nine manual. A new manual save overwrites oldest after confirmation. Player chooses any existing save.

Store day and remaining daytime seconds; complete islands/resources/tree levels/synergies/power; player level/XP/HP/equipment ownership; all residents and their towers; story progress, reward seed and playtime. Saving remaining time prevents reload time resets. Godot Web user:// uses browser IndexedDB.

### 6.16 UI, Feedback and Tutorial

| HUD position | Content |
|---|---|
| Top right | Player level/XP |
| Bottom right | Vertical HP +armor |
| Top center | Phase/countdown; orange at 20 day seconds, red at 15 night seconds |
| Top left | Wood/stone/iron/food, research, power used/capacity, residents assigned/cap |
| Bottom center | Six quick slots: wall/barricade/High Tower/warehouse/housing/more |
| Left | Communications-1 island HP/status: normal/danger/lost/To Reclaim |

Tower panel: level, precise current form including isolated versus wall-linked empty tower, HP, damage/interval/range/comms; selectable eligible resident portraits and Ungarrison. Explicitly explain empty linked tower blocks, isolated tower neither attacks nor blocks.

| Menu tab | Content |
|---|---|
| Information | Situation, objectives, tutorial review |
| Character | Level/HP/stats and technology breakdown; crafting/upgrades/ranged ownership |
| Trees | Technology/resident subtabs; highlighted synergy links at 2/3/4 |
| Resident Assignment | Profession, trust, HP, job, island/tower, boat reassignment, batch garrison |
| Map | Islands/status/docks/travel |
| Settings | Audio, damage numbers, main menu |

Night UI: waves, communications-2 alerts, voyage/target status and post-clear work UI. Results: island damage/loss/perfect defense/repair costs/rewards/trust/retreats, Continue.

Tutorial: day-one 0–40s gather, footprints, rescue Artisan; 40–100s wall/tower, put Artisan on tower. First night explain walls and work after clearance. Day-two first 50s rescue three, open assignment, put two combat residents on towers. Remaining day teach instant repair, base upgrade +3 research, invest in both trees. Night two symbolic secondary attack teaches independent defenses. Day three teach Synergy 2 and signal garrison. Days 4–5 explain ranged attackers prioritize towers/walls. After victory recommend specialists.

## 7. Balance Tables
First-build baselines; after week-three testing allow ±30% adjustment, or ±50% for node 6/Synergy 4.

### 7.1 Day/Island Schedule

| Day | Event | Main | A | B |
|---|---|---|---|---|
| 1 | Alone → Artisan → defense, one resident | Active | — | — |
| 2 | Three-resident assignment tutorial; combat unlock; boat/first landing; main level 2 | Active | Symbolic first attack | — |
| 3 | Second island; Synergy 2 available | Active | Active | Symbolic first attack |
| 4 | Main level 3; tower Lv2 | Active | Active | Active |
| 5 | Pressure rises; first Heavy Shell | Active | Active | Active |
| 6 | Technology 4 /tower Lv3 | Active | Active | Active |
| 7 | Pressure inflection | Active | Active | Active |
| 8 | Main level 4; technology 5 electricity | Active | Active | Active |
| 9 | Peak; technology/resident 6 | Active | Active | Active |
| 10 | Final night | BOSS | Small wave | Small wave |

### 7.2 Fixed Waves
Three batches at 0/30/60 seconds. B=Beast, R=Ranged Entity, H=Heavy Shell.

| Night | Main | A | B |
|---|---|---|---|
| 1 | 3 B | — | — |
| 2 | 5 B | — | — |
| 3 | 7 B +1 R | 2 B | — |
| 4 | 8 B +2 R | 4 B | 2 B |
| 5 | 10 B +2 R | 5 B +1 R | 4 B |
| 6 | 12 B +3 R | 6 B +1 R | 5 B +1 R |
| 7 | 10 B +3 R +1 H | 7 B +2 R | 6 B +1 H |
| 8 | 12 B +4 R +2 H | 8 B +2 R | 7 B +1 H |
| 9 | 14 B +5 R +3 H | 9 B +3 R +1 H | 8 B +2 R +1 H |
| 10 | Broodmother +12 B +5 R | 7 B +2 R | 7 B +2 R |

Secondary first attack: ×0.5, round up, no Heavy Shell. Initial landing gives one wall/two barricades. Secondary pressure assumes three–four combat residents +walls can clear 250 enemy HP in 80s; allow further 20% reduction if too hard. Ranged count rises slightly from v0.6 because walls now stop them, but remains below normal count.

### 7.3 Tower Forms
Values are damage /interval /range; splash radius in parentheses.

| Level | Cost | HP | Any-resident archer | Combat archer | Cannon | Mortar |
|---|---|---|---|---|---|---|
| 1 | 25 wood +15 stone | 70 | 10/1.0s/95px | 15/1.0s/105px | 26 (45px)/2.5s/110px | 30 (70px)/2.0s/200px |
| 2 | 15 stone +8 iron | 90 | 12/1.0s/105px | 18/1.0s/115px | 34 (50px)/2.2s/120px | 40 (75px)/1.9s/210px |
| 3 | 25 stone +15 iron | 110 | 16/0.9s/115px | 24/0.9s/125px | 60 (60px)/2.0s/130px | 90 (95px)/1.8s/240px |

Empty towers have no attacks; treat as 70-HP walls. Lv3 cannon/mortar are intentionally powerful synergy endpoints, allowed 50% above normal curve. Communications: Lv1 gives level 1; Lv2/3 gives level 2, no damage. Technology 2/3/4 unlock tower levels 1/2/3.
Walls: level 1 HP120; level 2 HP190, five stone upgrade. Barricade: HP30, no upgrade.

### 7.4 Unmanned Powered Defenses

| Facility | Demand | Damage | Interval | Range | HP | Feature |
|---|---|---|---|---|---|---|
| Tesla | 1 | 12 | 1.5s | 80px aura, hits every enemy | 80 | Instant, no projectile |
| Automated mortar | 2 | 40 | 3.0s | 220px; 70px splash | 90 | Unmanned, long range, slow |

Neither requires residents or tower slots; electricity limits them. Disable highest demand first, automated mortar before Tesla.

### 7.5 Technology Tree
Node 1 free; buy 2–6 sequentially, total 35 research. Each strengthens player.

| Node | Name | Target day | Cost | System effect | Player bonus |
|---|---|---|---|---|---|
| 1 | Basic Tools | Default | 0 | Gather; warehouse/housing/dock/wall/barricade | Melee unlock |
| 2 | High Tower | 2 | 3 | Tower Lv1 | Melee damage +20%, speed +10% |
| 3 | Cannon | 4 | 5 | Tower Lv2; cannoneer form | Attack speed +15%, range +15% |
| 4 | Mortar | 6 | 7 | Tower Lv3; mortar form | Sweep hits three targets |
| 5 | Electricity | 8 | 9 | Capacity/generator/oil well/Tesla | HP +60, food healing ×2, travel −40% |
| 6 | Automation | 9 | 11 | Free full dawn repairs; oil-well yield ×2; construction +50% and builder queues; automated mortar | Damage +25% (total +45%), attack speed +20% (total +35%), movement +15% (total +25%) |

Single sequential chain. Travel reduction: day 5→3s, night 7→4.2s, enabling two-island patrols. Node-6 inflation is intentional: level-5 blade 24/0.55 becomes approximately 34.8 damage /0.407s ≈85 DPS, plus three-target sweep. Without technology 3, no communications 2 because tower Lv2 is required.

### 7.6 Resident Tree and Synergy
Node 1 free; sequential 2–6 total 35 research. Large bonuses intentionally support the resident-only route.

| Node | Name | Day | Cost | Effect |
|---|---|---|---|---|
| 1 | Settlement | Default | 0 | Residents, global cap12 |
| 2 | Training | 2 | 3 | All resident attributes +25%; two combat residents immediately |
| 3 | Community | 4 | 5 | Cap +8→20; +2 job slots/island; three residents immediately |
| 4 | Advanced Training | 6 | 7 | Attributes +40%, total +65%; HP +30%; three residents immediately |
| 5 | Watch | 8 | 9 | Double perfect-defense rewards; cap +10→30; four combat residents immediately |
| 6 | Heroes | 9 | 11 | Two heroes: HP300, damage24, range90, local combat damage +40%; cap +10→40; six residents including three combat immediately |

With eight story residents, guarantee 26 by day ten, including 13 combat +two heroes.

| Synergy | Condition | Effect |
|---|---|---|
| 2 | Both trees level2 | Signal soldiers; communications towers; technology-route requirement |
| 3 | Both level3 | Cannoneers; cannon towers; Lv3 damage60, intentionally inflated |
| 4 | Both level4 | Mortar soldiers; Lv3 damage90, splash95px, range240; strongest single building, allowed excess |

Synergies are permanent and visibly linked in Trees.
Mixed: 15+15=30, all synergies. Technology: 35+3=38, synergy2 only. Residents: 35+0=35, no synergies and no High Towers.

### 7.7 Perfect Defense

| Reward | Amount | Chance/condition |
|---|---|---|
| Next-day island output | +10%, +20% after resident node5 | 100% |
| Island resident trust | +1, +2 after node5 | 100% |
| Drifter | First guaranteed; later25%, or50% after node5 | Below cap |

### 7.8 Economy Targets

| Day | Resources at end | Expected progress |
|---|---|---|
| 1 | Wood≈60, stone≈25 | Artisan, main1, tower/wall, technology2 |
| 2 | Wood≈110, stone≈45 | Rescue three; main dock; voyage; secondary dock; main2 |
| 3 | Wood≈150, stone≈70, iron≈12 | Synergy2/comms; one tower per secondary; resident2 |
| 4 | Wood≈200, stone≈110, iron≈20 | Main3, technology3/tower2 |
| 5–6 | Wood≈300, stone≈180, iron≈40 | Two warehouses; two towers/island; technology4 |
| 7–8 | Wood≈400, stone≈260, iron≈65 | Node5/generator/well/Tesla; equipment2–3 |
| 9 | Wood≈500, stone≈340, iron≈85 | Main4, automated mortar, node6 |
| 10 | Spend all on repairs/towers | Survive BOSS |

Skilled finish should leave 0–15% resources. Food is late bottleneck: 20+ residents by day9 consume 20+ daily; establish berry gathering on A early.

### 7.9 Balance Acceptance

| Metric | Target |
|---|---|
| Baseline completion | 28–33 minutes |
| Nights1–3 | All players pass |
| Night5 first-time failure | <30% |
| Night9 first-time failure | 40–60% |
| Night10 first-time failure | 55–70% |
| HE | Skilled players can achieve; first-timers should not |
| Specialists | Both completable without random drifters; lower first-attempt success than mixed |
| Skilled player deaths | ≤1/session |
| Damage from ranged enemies | 25–40%, higher than v0.6 due to tower/wall focus |
| Resident-route main garrison on night10 | ≥8 combat +one hero |

## 8. Art, Audio and Presentation
Orthographic 2D top-down; muted islands, warm campfires versus cold tides, strong deep-sea silhouettes. Day: warm yellow/teal; last20s: orange dusk; night: deep blue-purple/orange flames. Logical resolution 1152×648, proportional resizing. UI: hand-drawn wooden borders and simple icons.

Sounds: gathering, build success/failure, hit/hurt, wall breaking, ranged shot, night/urgent alerts, sailing, perfect defense, reclamation, equipment upgrade, power shortage, garrison/ungarrison, victory/defeat. Music: one each for day/night/final night. Animate player movement/melee/ranged; enemy movement/attack/death; resident work/garrison/knockback; tower forms, Tesla arcs, hero skills, BOSS summoning.

Acceptance: consistent style, no copyright risks, key audio feedback; distinguish day/night within one second and five tower forms plus linked empty tower at thumbnail size.

## 9. AI Tools and Workflow

| Tool | Purpose | Phase | Human review | Records |
|---|---|---|---|---|
| Code | Prototype/modules/debugging | Weeks1–3 | Core logic, individual module acceptance | Conversations/versions |
| Images | Concepts/placeholders/final assets | Weeks1–3 | Style, background/edge cleanup | Prompts/sources |
| Audio | SFX/music | Weeks2–3 | Selection/editing | Licenses |
| Text | Documents/tests/player instructions | Throughout | Editing | Purpose |
| Management | Tasks/tests | Throughout | Confirmation | — |

AI drafts; humans define standards, select and revise. This document governs AI implementation; put Appendix A.2 prohibitions in AGENTS.md.

## 10. Scope and Cut List

### P0 Required
Three islands and docks; main1–4, secondaries1–2. Ten 100-second days/80-second nights and final BOSS; no dusk state. Player movement/gather/build/demolish/repair/attack/upgrade/heal/death defeat. Five blade levels, three ranged weapons, three armor types; player technology buffs. Five resources, power capacity, per-resource caps and warehouses.

Source lists “10 building types”: core, warehouse, housing, dock, generator, oil well, wall, barricade, High Tower, Tesla and automated mortar. Source also says “four enemy types +BOSS.” Retain unified targeting; five tower forms plus linked-empty-wall behavior. Same simulation on all islands, current island rendered; 5s/7s dock travel; communications0/1/2 via signal garrison.

Three professions/heroes, discovery/jobs/garrison/trust/upkeep/retreat/recovery/equipment/drifters. Guaranteed tree population (source scope states21 guaranteed, cap40). Two six-node trees/three synergies. Base HP/tower/job/research/gates; player levels1–10 and20 research. Damage, instant repairs, dawn maintenance, recovery; perfect defense; loss/reclaim within20s. Main-core destruction/player death/final-night loss →BE; final survival→NE/HE. Day saves, one auto+nine manual. Results/island bars/alerts/tower panel/six tabs/map/tutorial.

### P1 Optional
Target-priority switching; second BOSS form; special perfect-defense scene; travel events; save thumbnails; accessibility; hero-skill presentation; batch garrison/one-click reinforcement.

### P2 Excluded
Resident affection/needs/hunger/death; logistics; multi-island views/splits/fast-forward; defense scoring/daily automatic-defense checks/extension days; branching technology (two six-node chains plus synergies only); branching story/open world/weather/endings beyond NE/HE/BE.

## 11. Technical Plan

### 11.1 Engine and Project
Godot4.x, GL Compatibility, GDScript; no GDExtension in first build. Single-threaded HTML5 Web export. Static ModelScope hosting with index.html +index.pck.

### 11.2 Main Loop
GameRoot contains TickAccumulator, three IslandWorld Node2D instances and UILayer. All three instantiate the same scene/code; only visible/input_enabled differ. No island_id==MAIN logic branches; differences belong in data. Fixed20Hz accumulator, at most four catch-up steps/frame.

Interface: island_id:String; base_level:int; core_hp/core_hp_max:float; buildings:Array[BuildingState]; residents:Array[ResidentState]; enemies:Array[EnemyState]; wave_cursor:int; power_used/power_capacity:int; render_enabled/input_enabled:bool. Methods: tick(dt), apply_player_input(cmd), snapshot(), restore(data), set_active(active), recompute_tower_forms(), recompute_wall_links(), recompute_power(). Recompute forms on garrison changes and wall links on connectivity changes.

### 11.3 Performance

| Metric | Target |
|---|---|
| Render | 60FPS, current island |
| All-island logic | <3ms/frame at20Hz |
| Total enemies | 120 |
| Buildings | 45/island |
| Residents | 40 global |
| Initial loading | <15s |

### 11.4 Technical Risks

| Risk | Mitigation |
|---|---|
| Wall connectivity changes multiple empty towers | Single recompute_wall_links entry, flood fill on build/demolish/destruction only |
| Tower-form changes | Single recompute_tower_forms; tests six states ×three levels |
| Forty-resident workload | Minimal logic, no pathfinding, fixed workplaces; combat only when attacked/garrisoned |
| Targeting | Spatial grid; reselect every0.25s, not every frame |
| Power priorities | Fixed priority array and centralized recomputation |
| Three-island peak | Remote5Hz, object pools |
| Saves with40 residents/towers/equipment | Necessary fields only; IndexedDB |

### 11.5 Versioning
Git/daily builds, runnable main; weekly rollback tag; CSV/JSON in res://data/; run headless three-island/ten-night test before every commit.

## 12. Milestones and Two-Person Responsibilities

| Week | A: Night/combat | B: Day/economy | Shared acceptance |
|---|---|---|---|
| 1 | Single-island combat, waypoints, unified targeting, tower forms/empty links, player/equipment/death | Phases, gather, construction/progress/placement, resources/caps, base levels | Complete day/night/results |
| 2 | Same simulation three islands, render switching, travel/comms, garrisons | Residents/assignment/tree grants, player levels/buffs, trees/synergies, map/docks | State conserved across travel |
| 3 | BOSS/alerts/power/Tesla/mortars/loss/reclaim | Perfect defense/saves40/menu/results/tutorial | Newcomers understand occupant determines tower |
| 4 | Blocking bugs/performance | Packaging/disclosure/ModelScope/incognito | Submit48h early |

Fix in week1: IslandWorld interface; TowerFormDef and recomputation timing; target-priority data; tree-level-pair synergy checks; power recomputation entry.

## 13. Test Plan

### 13.1 Internal
Daily first-three-day run; weekly full ten days. Same-save deterministic replay. Conservation: leaving A for B produces the same final A damage as remaining absent. Reclaim≤30s. Six tower states ×three levels; isolated empty towers neither block nor attack. Removing connecting wall isolates empty tower immediately. Ranged targeting towers→walls→others.

### 13.2 External
Week3 midpoint, three–five unfamiliar players without advance instruction:
1. Understand one body and remote defenses?
2. Sail when first alerted?
3. Understand present/absent defense difference?
4. Explain both trees and synergy?
5. See perfect defense as achievable?
6. First day-two secondary attack feels tense but understandable?
7. Deaths attributable to mistakes?
8. Understand empty-wall versus occupied-tower trade-off?
9. Understand ranged enemies attack towers/walls first?
10. Can assignment UI handle20+/40 residents?

### 13.3 Severity
Blocking: crash/load failure/stuck state/desynchronized worlds.
Major: loss/death/save/travel/tower-form/connectivity/power errors.
Normal: UI/numbers/missing sounds.
Experience: feel/text/camera.

## 14. Risks and Mitigations

| # | Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|---|
| 1 | Resident specialists lack communications | High | Medium | Intentional; test independent defense; if impossible allow node5 heroes to communicate |
| 2 | Forty-resident simulation/UI | Medium-high | High | Simple logic, virtualized list, week2 stress test |
| 3 | Empty towers leave first night unsupported | Medium | Medium | Three beasts are player-manageable; three more residents day2 |
| 4 | Connectivity cost/state bugs | Medium-high | High | Central entry/flood fill/event-triggered tests |
| 5 | Technology player too strong | Medium | Medium | 85DPS/sweep intentional; death defeats |
| 6 | Simulation performance | Medium-high | High | Remote frequency/pools/week2 peak test |
| 7 | 100s day too short | High | High | Post-clear work buffer; raise to110s if necessary |
| 8 | Alerts ignored | Medium | High | Popup/audio/persistent bars |
| 9 | Web compatibility | Medium | High | Deploy empty scene week1 |
| 10 | AI uses old rules | High | High | Appendix prohibitions in AGENTS.md |

### 14.1 Scope Ladder
In order: post-clear batch building; secondary starts with tower+wall; reduce10 days to8; remove third island.

## 15. Submission Checklist
- [ ] Public ModelScope playable link without login wall
- [ ] Cover
- [ ] Three–five screenshots: day construction, night combat, island bars/alerts, tower forms
- [ ] Controls, outcomes, death defeat, food healing, garrison and empty-wall rules
- [ ] 30–60s video
- [ ] Competition concept post
- [ ] AI disclosure/tool records
- [ ] Two-person team/responsibilities
- [ ] Incognito verification

## Appendix A. AI-Executable Specifications

### A.1 Data Fields
The following declarations retain the source identifiers and types; English comments explain their semantics.
```gdscript

class BuildingDef:
    var id: String
    var display_name: String
    var category: String
    var cost_wood: int
    var cost_stone: int
    var cost_iron: int
    var hp: float
    var build_time: float
    var max_level: int
    var unlock_tech: int
    var is_tower_slot: bool
    var power_cost: int
    var power_output: int
    var blocks_movement: bool


class TowerFormDef:
    var form: String
    var level: int
    var damage: float
    var attack_interval: float
    var range_px: float
    var splash_px: float
    var required_station: String
    var comm_level: int


class EnemyDef:
    var id: String
    var hp: float
    var damage: float
    var attack_interval: float
    var attack_range_px: float
    var speed: float
    var target_priority: String
    var building_damage_mult: float


class WaveDef:
    var day: int
    var island: String
    var batch: int
    var spawn_delay: float
    var entries: Array


class TreeNodeDef:
    var tree: String
    var level: int
    var display_name: String
    var cost_research: int
    var is_default: bool
    var effect: Dictionary
    var player_buffs: Dictionary
    var grants_residents: Array


class SynergyDef:
    var level: int
    var unlocks: String
    var requires_tech: int
    var requires_resident_tree: int


class ResidentState:
    var id: String
    var profession: String
    var station: String
    var faith: int
    var hp: float
    var hp_max: float
    var island: String
    var job: String
    var tower_id: String
    var retreated: bool
    var equipped_ranged: String
    var equipped_armor: String


class PlayerState:
    var level: int
    var xp: int
    var hp: float
    var hp_max: float
    var melee_level: int
    var equipped_ranged: String
    var equipped_armor: String
    var buff_damage: float
    var buff_attack_speed: float
    var buff_move_speed: float
    var sweep_targets: int


class IslandState:
    var island_id: String
    var base_level: int
    var core_hp: float
    var core_hp_max: float
    var status: String
    var buildings: Array
    var residents: Array
    var dock_status: String
    var power_capacity: int
    var power_used: int


class SaveSlot:
    var slot_index: int
    var created_at: int
    var day: int
    var day_remaining_seconds: float
    var islands: Array
    var resources: Dictionary
    var tech_level: int
    var resident_tree_level: int
    var synergy_flags: Dictionary
    var resident_pool: Array
    var player: PlayerState
    var story_flags: Dictionary
    var rng_seed: int
    var playtime_seconds: float
```

Tower-slot flag is true only for High Towers. Movement blocking is dynamic for empty towers; barricades do not block. Form values: NONE/ARCHER/ARCHER_ELITE/COMM/CANNON/MORTAR; stations: NONE/ARCHER/SIGNAL/CANNON/MORTAR. Technology player_buffs apply only to TECH; grants_residents apply only to RESIDENT. Save every resident, including all 40 at capacity.

### A.2 Prohibitions Required in AGENTS.md

1. No automatic-defense score system or daily automatic-defense check.
2. No extension-day mechanism.
3. Maximum levels on every island must not become a victory condition.
4. No remote fast-forward view, picture-in-picture or split screen.
5. No inter-island resource transport or transport capacity.
6. No separate abstract remote simulation or state-conversion functions.
7. No island_id-based gameplay branches inside IslandWorld.
8. Write saves only in Day.
9. No separate Dusk state.
10. No resident death.
11. No early night ending or skipping remaining night.
12. No research-point rewards from perfect defense or kills.
13. No timed repair action; retain the 25% daily cap outside To Reclaim.
14. No nighttime demolition.
15. No construction menu before finding a builder.
16. Do not implement archer/communications/cannon/mortar towers as four separate buildings.
17. Empty High Towers must have zero attack.
18. Occupied High Towers must not count as walls.
19. Synergies must not be hidden.
20. Electricity must not be consumable.
21. Ranged Entities must not ignore walls; follow towers → walls → other buildings.
22. Do not reselect targets every frame; every 0.25s is sufficient.

### A.3 Unified Targeting Pseudocode
One implementation shared by all enemies; first choose blocker, then in-range priority tiers, otherwise continue shortest-path movement.

```gdscript
func pick_target(enemy) -> Target:

    if enemy.blocker != null:
        return enemy.blocker


    if enemy.attack_range_px > 0:
        var cands = spatial_grid.query(enemy.pos, enemy.attack_range_px)
        for tier in [TIER_A_TOWER, TIER_B_WALL, TIER_C_BUILDING]:
            var best = nearest_in(cands, tier)
            if best != null:
                return best


    return null
```

TIER_A_TOWER: occupied High Towers, Tesla towers, automated mortars.  
TIER_B_WALL: walls, wall-like empty High Towers, barricades.  
TIER_C_BUILDING: every other building.

## Appendix B. Development Log

| Date | Completed | Issues | Next steps | AI tools / prompt records |
|---|---|---|---|---|
| | | | | |
