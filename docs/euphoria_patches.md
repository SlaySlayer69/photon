# Euphoria Patches integration

Photon can be extended by the [Euphoria Patcher](https://euphoriapatches.com) mod. The mod is
best known for the Complementary add-on it ships, but the parts of it that matter here are
generic: while it is installed, it injects a set of `EUPHORIA_PATCHES_*` preprocessor macros
and `euphoriaPatches*` uniforms into **every** shaderpack Iris or OptiFine loads.

`shaders/include/misc/euphoria_patches.glsl` is the single place where Photon consumes them.
Everything it exposes has a fallback that reproduces upstream behaviour exactly, so the pack
compiles and looks unchanged when the mod is absent.

## What the mod provides

Macros (a selection - the mod defines more):

| Macro | Set when |
| --- | --- |
| `EUPHORIA_PATCHES_MOD_INSTALLED` | always, while the mod is installed |
| `EUPHORIA_PATCHES_UNIFORMS` | the uniforms below are actually bound |
| `EUPHORIA_PATCHES_IS_SEASONS_MOD_INSTALLED` | Serene Seasons, Fabric Seasons or Ecliptic Seasons is present |
| `EUPHORIA_PATCHES_IS_SKYBOX_MOD_INSTALLED` | a skybox mod is present |
| `EUPHORIA_PATCHES_IS_SPACE_MOD_INSTALLED` | Stellar View, AstroCraft or Caelum is present |

Uniforms:

| Uniform | Meaning |
| --- | --- |
| `bool euphoriaPatchesIsDayAdvancing` | false while the world clock is frozen |
| `int euphoriaPatchesCurrentDayMillis` | milliseconds since midnight, UTC |
| `int euphoriaPatchesCurrentDayMillisLocal` | milliseconds since midnight, local time |
| `int euphoriaPatchesCurrentSeasonTick` | tick within the season cycle, counted from spring |
| `int euphoriaPatchesSeasonDuration` | length of one season in ticks |
| `int euphoriaPatchesTotalSeasonDuration` | length of the whole cycle in ticks |

The season uniforms are zero without a seasons mod, which is why the integration also checks
`EUPHORIA_PATCHES_IS_SEASONS_MOD_INSTALLED` before using them.

## Features built on it

* **Seasonal foliage** - grass, plants and leaves are tinted by the current season, blended
  smoothly rather than switched. Applied in `gbuffers_all_solid.fsh` for the foliage material
  masks.
* **Sky mod compatibility** - Photon's own stars and galaxy are dimmed while a skybox or space
  mod draws its own night sky, so the two do not stack.

Both are configurable under *Mod Options -> Euphoria Patches*.

## Adding a feature

1. Add the helper to `shaders/include/misc/euphoria_patches.glsl`, with an `#else` branch that
   returns the unmodified upstream value.
2. Add the setting to `shaders/settings.glsl`, the menu entry to `shaders/shaders.properties`
   (and to `sliders` when it is a slider), and the strings to `shaders/lang/en_US.lang`.
3. Mirror the change in the
   [`photon_patches`](https://github.com/SlaySlayer69/photon_patches) overlay, which is what
   actually gets shipped to players, and rebuild the patch there.

## How it reaches players

Players do not download a patched pack. They install Photon and the Euphoria Patcher mod; on
launch the mod verifies their Photon archive against a pinned hash and applies a binary patch
next to it. The build lives in the `photon_patches` repository, which pins the exact Photon
release the patch is made for - Photon's `main` is usually ahead of the newest release, so the
shipped patch is built from that release rather than from this branch.
