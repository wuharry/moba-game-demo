extends RefCounted

# Authoring hours for this terrace. The three endpoints retain the P15-C light rigs.
const DAY_HOUR := 12.0
const AFTERNOON_HOUR := 16.0
const DUSK_HOUR := 18.5
const DAY := {
	"sun_pitch": -44.0, "sun_yaw": -77.0, "direct": Color(1.0, .96, .87), "direct_energy": .95,
	"fill": Color(.55, .72, .90), "ambient_energy": .38, "material_fill": .27,
	"fog": Color(.53, .75, .82), "haze": Vector3(.48, .67, .78), "sky_energy": 1.0,
	"clear_tint": 1.0, "cloud_warmth": 0.0, "transmission": 0.0, "planes": 1.0,
}
const AFTERNOON := {
	"sun_pitch": -26.5, "sun_yaw": -74.0, "direct": Color(1.0, .895, .715), "direct_energy": 1.12,
	"fill": Color(.68, .77, .94), "ambient_energy": .43, "material_fill": .30,
	"fog": Color(.74, .80, .92), "haze": Vector3(.68, .77, .89), "sky_energy": 1.0,
	"clear_tint": 1.0, "cloud_warmth": 1.0, "transmission": .28, "planes": .24,
}
const DUSK := {
	"sun_pitch": -14.0, "sun_yaw": -75.0, "direct": Color(1.0, .70, .45), "direct_energy": .63,
	"fill": Color(.48, .54, .76), "ambient_energy": .52, "material_fill": .20,
	"fog": Color(.65, .64, .76), "haze": Vector3(.62, .62, .76), "sky_energy": .68,
	"clear_tint": 0.0, "cloud_warmth": 0.0, "transmission": 0.0, "planes": 1.0,
}

static func at_hour(hour: float) -> Dictionary:
	if hour <= DAY_HOUR: return DAY
	if hour == AFTERNOON_HOUR: return AFTERNOON
	if hour >= DUSK_HOUR: return DUSK
	var before := DAY if hour < AFTERNOON_HOUR else AFTERNOON
	var after := AFTERNOON if hour < AFTERNOON_HOUR else DUSK
	var from_hour := DAY_HOUR if hour < AFTERNOON_HOUR else AFTERNOON_HOUR
	var to_hour := AFTERNOON_HOUR if hour < AFTERNOON_HOUR else DUSK_HOUR
	var weight := smoothstep(from_hour, to_hour, hour)
	var state := {}
	for key in before:
		state[key] = lerp(before[key], after[key], weight)
	return state
