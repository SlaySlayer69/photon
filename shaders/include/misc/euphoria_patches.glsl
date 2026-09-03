// Euphoria Patches 1.10.0
//
// Euphoria Patches integration layer for Photon.
//
// The Euphoria Patcher mod injects a set of EUPHORIA_PATCHES_* macros and a set
// of euphoriaPatches* uniforms into every shaderpack that Iris or OptiFine
// loads while the mod is installed. This file is the single place where Photon
// consumes them, so that the pack keeps compiling and behaving exactly like
// upstream Photon when the mod is absent.
//
// The first line of this file carries the patch version and is read back by the
// Euphoria Patcher to recognise an installed patch - do not change its format.

#if !defined INCLUDE_MISC_EUPHORIA_PATCHES
#define INCLUDE_MISC_EUPHORIA_PATCHES

#include "/include/misc/material_masks.glsl"

// ----------------
//   Mod detection
// ----------------

// EUPHORIA_PATCHES_MOD_INSTALLED is defined by the mod for every loaded
// shaderpack
#ifdef EUPHORIA_PATCHES_MOD_INSTALLED
#define EP_ACTIVE
#endif

// EUPHORIA_PATCHES_UNIFORMS signals that the uniforms below are actually bound.
// Without it they would silently read as zero, which is not the same as "no
// seasons mod"
#if defined EP_ACTIVE && defined EUPHORIA_PATCHES_UNIFORMS
#define EP_UNIFORMS

// True while the world clock is advancing (false when the game is paused or the
// doDaylightCycle gamerule is off)
uniform bool euphoriaPatchesIsDayAdvancing;

// Milliseconds since midnight, UTC and in the player's local timezone
// respectively
uniform int euphoriaPatchesCurrentDayMillis;
uniform int euphoriaPatchesCurrentDayMillisLocal;

// Season cycle, provided by Serene Seasons, Fabric Seasons or Ecliptic Seasons.
// euphoriaPatchesCurrentSeasonTick counts from the start of spring up to
// euphoriaPatchesTotalSeasonDuration; all three are zero without a seasons mod
uniform int euphoriaPatchesCurrentSeasonTick;
uniform int euphoriaPatchesSeasonDuration;
uniform int euphoriaPatchesTotalSeasonDuration;
#endif

#if defined EP_UNIFORMS && defined EUPHORIA_PATCHES_IS_SEASONS_MOD_INSTALLED \
    && defined EP_SEASONS
#define EP_SEASONS_ACTIVE
#endif

#if defined EP_ACTIVE && defined EP_SKY_MOD_COMPAT \
    && (defined EUPHORIA_PATCHES_IS_SKYBOX_MOD_INSTALLED \
        || defined EUPHORIA_PATCHES_IS_SPACE_MOD_INSTALLED)
#define EP_SKY_MOD_COMPAT_ACTIVE
#endif

const vec3 ep_luminance_weights = vec3(0.2126, 0.7152, 0.0722);

// -----------
//   Helpers
// -----------

// Whether the world clock is advancing. Always true without the mod, so that
// time dependent effects keep animating in vanilla Photon
bool ep_is_world_time_advancing() {
#ifdef EP_UNIFORMS
    return euphoriaPatchesIsDayAdvancing;
#else
    return true;
#endif
}

// Position in the season cycle: 0 at the start of spring, 1 at the end of
// winter
float ep_year_progress() {
#ifdef EP_SEASONS_ACTIVE
    if (euphoriaPatchesTotalSeasonDuration <= 0) {
        return 0.0;
    }

    return fract(
        float(euphoriaPatchesCurrentSeasonTick)
        / float(euphoriaPatchesTotalSeasonDuration)
    );
#else
    return 0.0;
#endif
}

// Normalized blend weights for spring, summer, autumn and winter. Seasons
// overlap so that the transition between them is gradual instead of snapping on
// the season change
vec4 ep_season_weights() {
    const vec4 season_centers = vec4(0.125, 0.375, 0.625, 0.875);

    float year = ep_year_progress();

    vec4 distance_to_center = abs(vec4(year) - season_centers);
    // The year wraps around, so winter is adjacent to spring
    distance_to_center = min(distance_to_center, 1.0 - distance_to_center);

    vec4 weights = clamp01(1.0 - 4.0 * distance_to_center);
    // cubic_smooth() has no vec4 overload
    weights = sqr(weights) * (3.0 - 2.0 * weights);

    float total = weights.x + weights.y + weights.z + weights.w;

    return total > eps ? weights / total : vec4(1.0, 0.0, 0.0, 0.0);
}

// ---------------------
//   Seasonal foliage
// ---------------------

bool ep_is_foliage(uint material_mask) {
    return material_mask == MATERIAL_SMALL_PLANTS
        || material_mask == MATERIAL_TALL_PLANTS_LOWER
        || material_mask == MATERIAL_TALL_PLANTS_UPPER
        || material_mask == MATERIAL_LEAVES;
}

// Tints grass, plants and leaves according to the current season. Returns the
// albedo unchanged when no seasons mod is present or the setting is disabled
vec3 ep_apply_seasonal_tint(vec3 albedo, uint material_mask) {
#ifdef EP_SEASONS_ACTIVE
    if (!ep_is_foliage(material_mask)) {
        return albedo;
    }

    const vec3 spring_tint = vec3(1.04, 1.10, 0.90);
    const vec3 summer_tint = vec3(1.00, 1.00, 1.00);
    const vec3 autumn_tint = vec3(1.40, 0.84, 0.42);
    const vec3 winter_tint = vec3(0.82, 0.86, 0.94);

    vec4 weights = ep_season_weights();

    vec3 tint = weights.x * spring_tint + weights.y * summer_tint
        + weights.z * autumn_tint + weights.w * winter_tint;
    tint = mix(vec3(1.0), tint, EP_SEASONS_INTENSITY);

    vec3 tinted = albedo * tint;

    // Winter drains the colour out of what is left of the vegetation
    float desaturation = weights.w * 0.45 * EP_SEASONS_INTENSITY;
    float luminance = dot(tinted, ep_luminance_weights);

    return mix(tinted, vec3(luminance), desaturation);
#else
    return albedo;
#endif
}

// --------------------------
//   Sky replacement mods
// --------------------------

// Factor applied to Photon's own stars and galaxy. Skybox and space mods
// (Stellar View, AstroCraft, Caelum, FabricSkyboxes, ...) draw their own night
// sky, which otherwise ends up layered on top of Photon's
float ep_celestial_dimming() {
#ifdef EP_SKY_MOD_COMPAT_ACTIVE
    return EP_SKY_MOD_DIMMING;
#else
    return 1.0;
#endif
}

#endif // INCLUDE_MISC_EUPHORIA_PATCHES
