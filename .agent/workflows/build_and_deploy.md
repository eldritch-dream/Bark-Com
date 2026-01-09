---
description: How to build the game for Web and Windows
---

# Build & Deploy Workflow

## Prerequisites
1.  **Godot in PATH**: Ensure `godot` command works in your terminal. If not, edit `build_game.ps1` and set `$GodotPath` to your executable path.
2.  **Export Templates**: Install Godot Export Templates (Editor > Manage Export Templates).
3.  **Export Presets**:
    *   **Web**: Must be named `web` (case-insensitive usually, but match script).
    *   **Windows**: Go to **Project > Export**, click **Add...**, select **Windows Desktop**, and name it `Windows Desktop`.

## Running the Build
2. Open a terminal in the project root.
3. Run:
   ```powershell
   .\build_game.ps1 -Version "0.5.2"
   ```
   // turbo

## Output
- **Zipped Artifacts**: `builds/dist/`
    - `BarkCom_Web_v0.5.2.zip` (Ready for itch.io)
    - `BarkCom_Win_v0.5.2.zip`
- **Raw Files**: `builds/web/` and `builds/windows/`
