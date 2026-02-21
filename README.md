# Gem – SxB NPC Conversion Suite

A modular NPC conversion framework built on top of **Sexbound (SxB)**.

Implements a structured lifecycle:

Seduction → Node → Pregnancy → Mother → Afterbirth → Child

---

# Download

## Required (Core Conversion Pipeline)

- Gem - SxB Node Conversion Core  
  https://github.com/LegacyGem/SxB-Mods/releases/download/NPCs/Gem-SxB_Node_Conversion_Core.pak

- Gem - SxB Better Conversion  
  https://github.com/LegacyGem/SxB-Mods/releases/download/NPCs/Gem-SxB_Better_Conversion.pak

- Gem - SxB More NPC  
  https://github.com/LegacyGem/SxB-Mods/releases/download/NPCs/Gem-SxB_More_NPC.pak


## Optional (Weapon Integration)

- Gem - SxB Upgraded Aphrodite Bow  
  https://github.com/LegacyGem/SxB-Mods/releases/download/NPCs/Gem-SxB_Upgraded_Aphrodite_Bow.pak


---

# Module Architecture

| Module | Role |
|--------|------|
| Node Conversion Core | Engine |
| Better Conversion | Policy / state-machine control |
| More NPC | Content endpoints (npctypes + dialog) |
| Upgraded Aphrodite Bow | Weapon-level integration (optional) |

Layered model:

Trigger → Engine → Policy → Content

---

# Module A: SxB Node Conversion Core  
**Engine Layer – Required**

### Core Responsibility
Owns seduction-driven node transformation mechanics.

Bridges:
Actor → Sexbound Node → Actor Restoration

### Execution Layer
Runtime engine orchestration:
- World state tracking
- Node hooks
- Transform lifecycle monitoring

### Lifecycle Timing
- Runs when `seduction_mind_control` is applied
- Maintains world watcher tick while seduction key exists
- Hooks node death / timeout events

### Controlled State Transitions

Target Hit  
→ Transform Pending  
→ Node Active  
→ Node Ended  
→ Restoration + Conversion Release Marker

### Dependencies
- Hard: `lox_sexbound`
- Runtime expectation: Sexbound message handlers (`Sexbound:Transform`)

### Guards Against
- Duplicate trigger loops (`seduction:<entityId>` world key)
- Transform timeouts
- Early node break
- Missing entity / missing node calls
- Stale pending states

### Deliberately Does NOT Handle
- NPC type conversion policy
- Dialogue/content behavior
- Weapon triggers
- Recruitment systems

---

# Module B: Gem - SxB Better Conversion  
**Policy Layer – Required**

### Core Responsibility
Defines when and how NPC type conversion occurs after node interaction.

### Lifecycle Timing
- Attached to hostile/fu-hostile NPC script stacks
- Periodic evaluation during update cycle
- Waits explicitly for node release marker

### Controlled State Transitions

Hostile/Friendly + Pregnant + Node Released + Father Policy Pass  
→ `motherexhostilevillager`

`motherexhostilevillager` + Pregnancy Ended  
→ `afterbirthvillager`

Uses spawn-swap replacement with delayed despawn to prevent duplication.

### Dependencies
- Hard: `lox_sexbound`
- Hard: `sxb_node_conversion_core`
- Hard: `more_sxb_npc`

### Guards Against
- Converting during active node phase
- Converting enemy-team actors
- Missing father requirement (if configured)
- Loss of identity/equipment/storage during swap
- Legacy release marker compatibility

### Deliberately Does NOT Handle
- Triggering seduction
- Dialogue personality systems
- Child content definitions
- Crew/job logic

---

# Module C: Gem - SxB More NPC  
**Content Layer – Required**

### Provides NPC Types

- `motherexhostilevillager`
- `afterbirthvillager`
- `childrenvillager`

### Responsibility
Defines what converted entities become and how they behave.

Includes:
- Dialog sets for mother / afterbirth / child states
- Baby routing override for child output

### Execution Role
Content endpoints only.  
Does not execute conversion logic.

### Dependency Model
- Soft standalone content
- Required by Better Conversion as conversion targets

### Deliberately Does NOT Handle
- Seduction logic
- Node lifecycle tracking
- Weapon effects

---

# Module D: Gem - SxB Upgraded Aphrodite Bow  
**Integration Layer – Optional**

### Core Responsibility
Integrates Aphrodite Bow into the seduction → node pipeline.

### Behavior
- `imbuedaphroditesbow` fires seduction arrow
- Adds `fertilityaphroditesbow`
  - Applies hyper fertility
  - Applies seduction status
- Adds recipe + blueprint patch

### Execution Flow

Weapon Impact  
→ Apply `seduction_mind_control`  
→ Delegates to Node Conversion Core  
→ Conversion continues via policy layer

### Dependencies
- Hard: `Lox_AphroditesBow`
- Hard: `sxb_node_conversion_core`

### Deliberately Does NOT Handle
- Post-pregnancy type conversion
- Dialogue content
- Recruitment systems

---

# End-to-End Lifecycle

Weapon / Effect Trigger  
→ Apply `seduction_mind_control`  
→ Node Conversion Core creates `seduction:<targetId>` world state  
→ Sends `Sexbound:Transform`  
→ Node Active  
→ Node Timeout / Break  
→ Core restores actor + sets conversion release marker  
→ Better Conversion evaluates pregnancy + policy  
→ Spawn-swap to `motherexhostilevillager`  
→ Pregnancy completes  
→ Spawn-swap to `afterbirthvillager`  
→ More NPC defines final presentation + dialog

---

# Minimum Required Combination

1. `lox_sexbound`
2. Gem - SxB Node Conversion Core
3. Gem - SxB Better Conversion
4. Gem - SxB More NPC
5. At least one seduction trigger source (e.g., Upgraded Aphrodite Bow or compatible mod)

---

# Installation

Place `.pak` files in:

Starbound/mods/

---

# Credits

Sexbound framework by **Erina**
