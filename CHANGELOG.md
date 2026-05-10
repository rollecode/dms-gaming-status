### 1.0.0: 2026-05-10

* Initial release
* Active game detection (Wine + native) via process matching against KNOWN_GAMES list
* Built-in game list: The Sims 4, Baldur's Gate 3, Overwatch, Battle.net, Dead Space, CS2, CS:GO, Dota 2, Factorio, Stardew Valley, RimWorld, Civilization VI/VII, Minecraft, StarCraft
* Generic Wine game detection for unknown .exe processes
* Gamemode active state via gamemoded -s
* Memory pressure indicator (3 levels: healthy, warning, critical) based on RAM and swap usage
* CPU governor display in popout
* Bar pill with optional game name and RAM% badge
* Popout with active game card, memory card, system card
* Settings: poll interval, game-name toggle, RAM-badge toggle, custom-games manager
* Add custom games via settings UI (no JS editing required)
