# KOTORMax

A 3ds Max / gmax plugin for importing and exporting models in BioWare's **Odyssey MDL/MDX** format — the model format used by *Star Wars: Knights of the Old Republic* and *KOTOR II: The Sith Lords*.

Originally created by **bead-v**, extended from **NWmax** by Joco (the equivalent plugin for *Neverwinter Nights*).

---

## Features

- Import and export **MDL/MDX** model files for KOTOR 1 and 2
- Full support for all Odyssey node types:
  - Trimesh, skin (skeletal), danglymesh (cloth/hair physics), AABB walkmesh
  - Particle emitters (Fountain, Single, Explosion, Lightning)
  - Point lights, dummy/pivot nodes, reference (model-in-model) nodes
- Animation import and export, including per-property keyframe data
- Pre-export sanity checker to catch common errors before they crash the game
- Texture utilities: TGA copy and TGA→DDS batch conversion
- Additional tools: animation editor, key reduction, normal adjustment, minimap maker, scale wizard, room linker, and more
- Works with both **gmax** (free) and **3ds Max**

---

## Requirements

- **gmax** (free, any version) **or** **3ds Max**

> KOTORMax writes ASCII MDL files to disk. mdlops (or similar) is a separate tool you run to compile them to binary. The two are not bundled together.

---

## Installation

### 3ds Max

1. Copy the `KOTORMax` folder into your 3ds Max `scripts` folder.
2. Create a `startup` folder inside `scripts` if it does not exist, then copy `autokotormax.ms` into it.
3. If NWmax is installed, remove `autonwmax.ms` from the `startup` folder (you cannot run both simultaneously).

> KOTORMax and NWmax use the same globals and will break each other if loaded at the same time. You can swap `autokotormax.ms` / `autonwmax.ms` in the `startup` folder to switch between them between sessions.

### gmax

1. Follow steps 1–2 above (the script folder structure is the same).
2. Copy `kotormax.exe` into your gmax root directory. **Use `kotormax.exe` to launch gmax from now on** — it is required for file export to work.

> `kotormax.exe` is a helper process (based on NWmax Snoop v0.7) that bridges a gmax limitation: gmax's MaxScript cannot write files to disk directly, so the helper reads the output from the MaxScript Listener and writes it. It is not needed when using 3ds Max.

---

## Known Issues Fixed in This Release

- **Detonate controller crash** — KOTORMax previously exported the `detonate` property and its animation controller for every emitter, regardless of type. The KOTOR engine only allocates memory for this controller on `Explosion`-type emitters. On non-Explosion emitters (especially the common `Fountain` type) this produced invalid binary MDL files that caused access violations. This was silent on Windows due to heap layout luck but consistently crashed on Linux (Wine/Proton). Fixed: `detonate` is now only exported for `Explosion` emitters.

---

## Credits

- **bead-v** — Original KOTORMax author
- **Joco** — NWmax (the NWN predecessor this is based on)
- **DarthParametric** — fix for PWK import error (spurious third argument)
- **JCarter426** — fix for model/walkmesh import in 3ds Max 2017+
