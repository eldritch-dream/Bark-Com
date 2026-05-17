# System Map

> [!TIP]
> **Lost?** Use this map to find the "Home" of a concept.

Paths verified against the codebase as of v0.6.10. If you find drift, fix it here — this doc rots fast.

## Core Loop & State
| Concept | File Location |
| :--- | :--- |
| **Main entry point** | `scripts/core/Main.gd` |
| **Global state (Base/Mission), save/load** | `scripts/core/GameManager.gd` (autoload) — `save_game()` ~line 705, `load_game()` ~line 781 |
| **Event bus** | `scripts/managers/SignalBus.gd` (autoload) |
| **Input handling / camera** | `scripts/managers/InputManager.gd` (autoload). Tile clicks: `on_tile_clicked` signal |
| **AI debug overlays** | `scripts/utils/AIDebugger.gd` (autoload) |
| **Cosmetics catalog** | `scripts/managers/CosmeticManager.gd` (autoload) |
| **Skill tree state** | `scripts/managers/BarkTreeManager.gd` (autoload, in-memory; persisted via `GameManager`) |
| **Mission orchestration** | `scripts/managers/MissionManager.gd` |
| **Mission generation** | `scripts/builders/MissionGenerator.gd` |
| **Mission initialization** | `scripts/builders/MissionInitializer.gd` |
| **Objective spawning** | `scripts/builders/ObjectiveSpawner.gd` |
| **Unit spawning** | `scripts/builders/UnitSpawner.gd` |
| **Level generation** | `scripts/core/LevelGenerator.gd` |
| **Bond system** | [docs/architecture/bond_system.md](bond_system.md) |
| **Memorial system** | [docs/architecture/memorial_system.md](memorial_system.md) |
| **Versioning** | [docs/dev_guide/versioning.md](../dev_guide/versioning.md) |

## Units & Entities
| Concept | File Location |
| :--- | :--- |
| **Base unit logic** | `scripts/entities/Unit.gd` |
| **Player corgi** | `scripts/entities/CorgiUnit.gd` |
| **Enemy base** | `scripts/entities/EnemyUnit.gd` |
| **Enemy variants** | `scripts/entities/{Rusher,Sniper,Spitter,Whisperer}*.gd`, plus `scripts/entities/enemies/` |
| **Interactive props** | `scripts/entities/{DestructibleCover,Door,ExplosiveBarrel,GoldenHydrant,HazardZone,InteractiveObject,LootCrate,Terminal,VolatileCover}.gd` |
| **Unit FSM** | `scripts/fsm/StateMachine.gd`, `scripts/fsm/State.gd`, `scripts/fsm/units/` |
| **Class data (Resource)** | `scripts/resources/ClassData.gd` |

## Tactical Grid
| Concept | File Location |
| :--- | :--- |
| **Grid, AStar pathfinding, and cover** | `scripts/managers/GridManager.gd` (single file owns all three) |
| **Vision / LOS** | `scripts/managers/VisionManager.gd` |
| **Fog of war** | `scripts/managers/FogManager.gd` |
| **Grid visualizer** | `scripts/ui/GridVisualizer.gd` |

## Abilities & Combat
| Concept | File Location |
| :--- | :--- |
| **Ability resource base** | `scripts/resources/Ability.gd` |
| **Concrete abilities** | `scripts/abilities/*.gd` (e.g., `HackAbility`, `ScatterShot`, `OverwatchAbility`, …) |
| **Combat resolution** | `scripts/managers/CombatResolver.gd` |
| **Status effects** | `scripts/resources/StatusEffect.gd`, `scripts/resources/statuses/`, `scripts/resources/effects/`, plus `scripts/core/StatusCatalog.gd` |
| **VFX** | `scripts/managers/VFXManager.gd`, `scripts/vfx/` |
| **Turn manager** | `scripts/managers/TurnManager.gd` (+ `TurnManager_Helper.gd`) |
| **Objectives** | `scripts/managers/ObjectiveManager.gd` |
| **Nemesis tracking** | `scripts/managers/NemesisManager.gd` |

## UI
| Concept | File Location |
| :--- | :--- |
| **Main HUD** | `scripts/ui/GameUI.gd` |
| **Unit info card** | `scripts/ui/UnitInfoCard.gd` |
| **Squad detail panel** | `scripts/ui/SquadDetailPanel.gd` (+ `SquadMemberFrame.gd`) |
| **Base scene** | `scripts/ui/BaseScene.gd` |
| **Mission control** | `scripts/ui/MissionControlTab.gd` |
| **Skill tree window** | `scripts/ui/SkillTreeWindow.gd` (+ `SkillTreeNode.gd`, `TalentSelectPopup.gd`, `PerkSelectionUI.gd`) |
| **Field manual** | `scripts/ui/FieldManual.gd` |
| **Victory screen** | `scripts/ui/VictoryScene.gd` |
| **Options** | `scripts/ui/OptionsPanel.gd` |
| **Terminal** | `scripts/ui/TerminalPanel.gd` |
| **Inventory drag/drop** | `scripts/ui/{DraggableItemIcon,UnitInventorySlot,UnitWeaponSlot,StashDropTarget}.gd` |

## Data & Persistence
| Concept | File Location |
| :--- | :--- |
| **Save/load** | `scripts/core/GameManager.gd` (`save_game`, `load_game`). Path: `user://savegame.dat` (or `user://test_savegame.dat` when `TEST_MOCK_ENABLED`) |
| **Persistence rules** | [docs/architecture/persistence_rules.md](persistence_rules.md) |
| **Mission/data resources** | `scripts/resources/{MissionConfig,MissionData,WaveDefinition,EnemyData,EnemySkill,ItemData,WeaponData,ConsumableData,Perk,ClassBarkTree,CosmeticItem}.gd` |
