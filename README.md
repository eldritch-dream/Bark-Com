<div align="center">
  <img src="icon.svg" width="128" alt="BARK-COM logo">

# BARK-COM

**Turn-based tactics with genetically enhanced Corgis and Eldritch horrors.**

[![CI/CD Pipeline](https://github.com/eldritch-dream/Bark-Com/actions/workflows/ci_cd_pipeline.yml/badge.svg)](https://github.com/eldritch-dream/Bark-Com/actions/workflows/ci_cd_pipeline.yml)

[Play on itch.io](https://eldritch-dream.itch.io/bark-com) · [Download a release](https://github.com/eldritch-dream/Bark-Com/releases/latest) · [Browse active tasks](tasks/README.md)
</div>

BARK-COM is a tactical turn-based strategy game inspired by XCOM. Command a persistent squad of Corgis against the Whispers and the Sprawling, using cover, flanking, overwatch, abilities, and careful action-point management. Between missions, manage the Kennel, research upgrades, equip the roster, and contend with injuries and permanent death.

> [!NOTE]
> BARK-COM is under active development. Save compatibility is treated as a core engineering constraint.

## Play

- **Browser:** [Play BARK-COM on itch.io](https://eldritch-dream.itch.io/bark-com)
- **Windows and Web downloads:** [Latest GitHub release](https://github.com/eldritch-dream/Bark-Com/releases/latest)

## Development setup

### Requirements

- [Godot **4.5.1**](https://godotengine.org/download/archive/4.5.1-stable/)
- Git
- [PowerShell 7](https://learn.microsoft.com/powershell/scripting/install/installing-powershell) for the repository's test and build scripts
- Godot 4.5.1 export templates if you intend to create distributable builds

### Run from the editor

```bash
git clone https://github.com/eldritch-dream/Bark-Com.git
cd Bark-Com
godot --editor project.godot
```

Alternatively, import `project.godot` through the Godot project manager and run the configured main scene.

## Testing

The parallel runner is the recommended entry point:

```powershell
pwsh ./tests/run_tests_parallel.ps1 -Jobs 4 -Strict $true
```

Run a focused subset by filename pattern:

```powershell
pwsh ./tests/run_tests_parallel.ps1 -Filters "verify_final_mission"
```

Tests touching `GameManager` must enable mock mode and use the protected test-save path. Read [Testing Protocols](docs/architecture/testing_protocols.md) before adding or running persistence tests.

## Building

The repository contains Web and Windows export presets. With Godot 4.5.1 export templates installed:

```powershell
pwsh ./build_game.ps1 -Version "0.6.11"
```

Artifacts are written beneath `builds/`. The current local build script contains a developer-specific fallback path for Godot; if `godot` is not available there, update `$GodotPath` in `build_game.ps1` for your installation. See the [Build and Deploy workflow](.agent/workflows/build_and_deploy.md) and [Versioning guide](docs/dev_guide/versioning.md) for release details.

## Contributing

Start with [agents.md](agents.md), which documents the architecture and the project-specific rules that protect persistent saves. Changes should also follow:

- [Coding standards](docs/dev_guide/coding_standards.md)
- [Commit conventions](docs/dev_guide/commit_conventions.md)
- [Persistence rules](docs/architecture/persistence_rules.md)
- [System map](docs/architecture/system_map.md)

Behavior changes should include focused regression coverage. Before submitting a pull request, run the relevant focused tests and the full parallel suite.

## Project structure

```text
assets/       Source art, audio, models, and imported resources
resources/    Godot resource definitions and game data
scenes/       Godot scenes for UI, entities, levels, and gameplay
scripts/      GDScript game logic, managers, entities, and systems
tests/        Headless regression and integration tests
docs/         Architecture, mechanics, and developer documentation
tasks/        Prioritized work ledger and completed-task history
```

## License

No license has been declared for this repository. Contact the repository owner before redistributing or reusing the code or bundled assets.
