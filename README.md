# Gem – SxB NPC Conversion Suite

A modular NPC conversion framework built on top of **Sexbound (SxB)**.

Implements a structured lifecycle:

Seduction → Node → Pregnancy → Mother → Afterbirth → Child

Each module has a strictly separated responsibility.

---

# Module Architecture

| Module | Role |
|--------|------|
| Node Conversion Core | Engine |
| Better Conversion | Conversion policy / rules |
| More NPC | Custom NPC types & dialog |
| Upgraded Aphrodite Bow | Weapon integration (optional) |

---

# 1. Gem – SxB Node Conversion Core  
**(Engine Layer – Required)**

Core backend for seduction and node mechanics.

Provides:

- `seduction_mind_control` status effect  
- `seduction_watcher.lua` world watcher  
- `sexbound_main_node*.patch` hooks  
- Node override script  

This module:
- Handles seduction application
- Hooks into node lifecycle
- Triggers conversion pipeline
- Contains no custom NPC types
- Contains no weapon items

Refactored from the old MindControl package into a clean engine-only module.

---

# 2. Gem – SxB Better Conversion  
**(Policy Layer – Required)**

Defines what happens after node interaction ends.

### Flow

1. Waits for node release / break  
2. Checks pregnancy state  
3. If pregnancy detected (player father required by config):

hostile/friendly → `motherexhostilevillager`

4. After birth:

`motherexhostilevillager` → `afterbirthvillager`

### Design Intent

- Prevent premature conversion
- Preserve identity, equipment, and state during type swap
- Enforce pregnancy-based rule logic

### Config

`betterconversion.config`

Allows rule adjustments (father requirement, behavior flags, etc.)

---

# 3. Gem – SxB More NPC  
**(Content Layer – Required)**

Provides custom NPC types and dialog behavior used by the system.

NPC Types:

- `motherexhostilevillager`
- `afterbirthvillager`
- `childrenvillager`

Includes:

- Dialog configs for:
  - Mother
  - Afterbirth
  - Child
- Baby plugin override to ensure SxB child output follows `childrenvillager` pipeline

This module supplies the actors used by the conversion system.

---

# 4. Gem – SxB Upgraded Aphrodite Bow  
**(Integration Layer – Optional)**

Integrates Aphrodite Bow into the conversion engine.

Changes:

- `imbuedaphroditesbow` fires seduction mind-control arrow IDs
- Adds `fertilityaphroditesbow`
  - Applies hyper fertility
  - Triggers mind-control pipeline
- Adds recipe + blueprint patch
- Cleans arrow naming to `seduction...` variants

Optional. Not required for core functionality.

---

# Full Conversion Lifecycle

Seduction Applied  
↓  
Node Interaction  
↓  
Node Released / Broken  
↓  
Better Conversion Policy Check  
↓  
Pregnant?  
- No → Restore original type  
- Yes → Convert to `motherexhostilevillager`  
  ↓  
 Birth  
  ↓  
 Convert to `afterbirthvillager`  
  ↓  
 Child uses `childrenvillager` flow  

---

# Requirements

- Sexbound framework  
- `lox_sexbound`

Villager Conversion mod is not required.

---

# Installation

Place required `.pak` files in:

Starbound/mods/

---

# Credits

Sexbound framework by **Erina**
