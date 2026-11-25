# Island Rescue! Final Game Design Document

Applies to game version v0.0.5.

## Core gameplay
A top-down pixel-art island survival and defense game. Start on the main island, gather wood, stone, iron, and food, rescue unemployed residents, drag them into professions, and have artisans build defenses. Day one starts with zero wood, stone, and iron and 20 food. Natural resources and camp residents replenish daily. Fixed enemy waves run concurrently on three islands at night. Travel requires docks at both ends.

Daylight lasts 100 seconds, the evening transition takes two seconds, and night lasts 80 seconds. The top-right HUD shows the day and an automatically advancing clock. Destruction of the main island core or player death ends the run. Survive night ten with every island held to win. A perfect ending requires no more than 20% damage on each island. Clear remaining enemies and fully repair the core to reclaim a satellite island.

## Buildings and residents
Construction and gathering share a job quota on each island equal to the sum of building levels. Each building accepts a combined number of construction and gathering residents up to its level. Ground combat has no job quota. The separate population limit still applies. Resident Tree level six unlocks free profession changes. Construction sites and completed buildings have collision footprints. Artisans work from reachable exterior positions. Place walls in batches by clicking the start and end points. Press U to upgrade the core. Repairs take effect immediately.

## Combat and equipment
A tower holds up to three residents of the same role, either archers or musketeers. Musketeers require Synergy II. Technology level four unlocks the standalone mortar emplacement, and Synergy III unlocks mortar operators. Operators work at emplacements and cannot occupy towers. The player can press E near an unoccupied emplacement, fire with a left click, and leave by moving or pressing E. Mortars deal area damage and have range and reload limits.

The inventory shows character and island information above a 12-by-3 grid. Resources stack to ten per slot. Each equipment item occupies its own slot and tracks its own level. The starting blade is exclusive to the player. Right-click a nearby resident to hand over other held equipment. Press E near an artisan to craft or upgrade equipment. Upgrade levels cap at five.

## Controls, art, and validation
Use WASD to move, E to interact or hold E to gather, B to build, I for inventory, Tab for resident management, and F to eat food and recover health. Original pixel characters have four-direction animation. Objects overlap according to their ground positions. Scripts and shaders render the shoreline, sea, and daylight changes. Saving is available during daylight while on land and retains jobs, inventory, and equipment ownership.

Resource-node collision, the title-screen rope animation, and full ten-night balance validation are outstanding.

[Current gameplay data and waves](data/rules.json) · [Art assets](assets/art/) · [Original detailed design](GDD_v0.9.md)
