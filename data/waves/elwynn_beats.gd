# Elwynn Forest timed beats consumed by WaveDirector.
class_name ElwynnBeats
extends RefCounted

const LEVEL_TARGET := 900.0
const GRUNTS_AT := 120.0
const TROLLS_AT := 240.0
const OGRES_AT := 360.0
const RAMP_AT := 600.0
# Leave about a minute for the finale. Victory still requires killing Hogger.
const HOGGER_AT := 840.0
const HARD_CAP := 500

# time, crowd ceiling, skeleton pack, skeleton interval, stage name
const STAGES := [
	[0.0, 32, 1, 1.1, "Goldshire Road"],
	[120.0, 65, 2, 0.95, "Horde Scouts"],
	[240.0, 100, 3, 0.85, "Spearhead"],
	[360.0, 150, 4, 0.75, "Heavy Footsteps"],
	[480.0, 210, 5, 0.65, "Encircled"],
	[600.0, 290, 7, 0.55, "Horde Assault"],
	[720.0, 400, 10, 0.45, "Last Stand"],
	[840.0, 280, 5, 0.9, "Hogger's Warband"],
]


static func stage_index(seconds: float) -> int:
	var index := 0
	for i in STAGES.size():
		if seconds >= float(STAGES[i][0]):
			index = i
	return index


static func pressure(seconds: float) -> float:
	# Each minute starts with recovery and ends in a surge. No enemies vanish
	# when the ceiling falls: the player has to clear the previous wave.
	var beat := fmod(maxf(seconds, 0.0), 60.0)
	if beat < 18.0:
		return 0.65
	if beat < 42.0:
		return 1.0
	return 1.4


static func crowd_cap(seconds: float) -> int:
	var index := stage_index(seconds)
	var base := float(STAGES[index][1])
	if index < STAGES.size() - 2:
		var next: Array = STAGES[index + 1]
		var blend := clampf((seconds - float(STAGES[index][0])) / (float(next[0]) - float(STAGES[index][0])), 0.0, 1.0)
		base = lerpf(base, float(next[1]), blend)
	return mini(HARD_CAP, roundi(base * (0.85 if pressure(seconds) < 1.0 else (1.2 if pressure(seconds) > 1.0 else 1.0))))


static func health_multiplier(seconds: float) -> float:
	return lerpf(1.0, 2.8, clampf(seconds / HOGGER_AT, 0.0, 1.0))
