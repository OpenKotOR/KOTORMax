# AGENTS.md

## Cursor Cloud specific instructions

### Project nature

KOTORMax is a **MAXScript plugin** for Autodesk 3ds Max / gmax. The entire codebase consists of `.ms` (MAXScript) files, `.ini` configs, and `.nam` name-lookup tables. There are:

- **No installable dependencies** (no `package.json`, `requirements.txt`, `Makefile`, etc.)
- **No build system** — scripts are interpreted at runtime by the 3ds Max / gmax host application
- **No automated tests**
- **No CI/CD pipeline**

### Runtime requirement

The plugin **requires Windows + Autodesk 3ds Max (or gmax)** to execute. It cannot be run, built, or tested in a Linux/cloud environment. The only development activity possible on Linux is editing `.ms` script files.

### Project structure

- `autokotormax.ms` — Startup script (placed in 3ds Max `scripts/startup/`)
- `KOTORMax/kotormax.ms` — Main entry point; loads all sub-scripts and sets up UI
- `KOTORMax/kotormax_scripts/` — Core scripts (~38 `.ms` files): import/export functions, UI rollouts, helper plug-ins, modifier plug-ins, utility tools
- `KOTORMax/plugins/` — Optional extension plugins (`head_fixer.ms`, `flame_emitter.ms`)
- `KOTORMax/names/` — Name lookup tables for KOTOR model types (`.nam` files)
- `KOTORMax/kotormax.ini` — User configuration
- `KOTORMax/wokmat.ini` — Walkmesh material definitions

### Lint / test / build / run

There are no lint, test, build, or run commands for this project. Code quality must be verified manually by loading the plugin in 3ds Max/gmax. See `README.md` for installation instructions.
