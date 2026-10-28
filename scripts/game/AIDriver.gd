
class_name OpenWorldAIDriver
extends RefCounted

## Waypoint-following AI:
## follows the track, brakes for corners, uses nitro on straights,
## drifts on tight corners, and recovers when stuck.

var v: Vehicle
var info: WorldTrackInfo

var skill: float = 0.9
var lane: float = 0.0
var _stuck: float = 0.0


func _init(
	vehicle: Vehicle,
	track: WorldTrackInfo,
	s: float,
	lane_offset: float
) -> void:
	v = vehicle
	info = track
	skill = s
	lane = lane_offset


func update(delta: float, rubber: float) -> void:
	if not is_instance_valid(v):
		return

	if not v.controllable:
		return

	if not is_instance_valid(info):
		return

	var spd: float = maxf(v.forward_speed, 0.0)
	var idx: int = v.track_idx
	var look: int = 5 + int(spd / 5.0)

	var target_index: int = idx + look
	var tgt: Vector3 = (
		info.point(target_index)
		+ info.right(target_index) * lane
	)

	var local_target: Vector3 = v.to_local(tgt)
	var ang: float = atan2(local_target.x, -local_target.z)

	v.input_steer = clampf(ang * 2.2, -1.0, 1.0)

	var t0: Vector3 = info.tangent(idx + 2)
	var t1: Vector3 = info.tangent(
		idx + look + int(spd / 3.0)
	)

	var dot_value: float = clampf(t0.dot(t1), -1.0, 1.0)
	var curv: float = acos(dot_value)

	var skill_factor: float = clampf(
		skill + rubber,
		0.6,
		1.08
	)

	var corner_factor: float = lerpf(
		1.0,
		0.42,
		clampf(curv / 0.9, 0.0, 1.0)
	)

	var target_speed: float = (
		v.top_speed * skill_factor * corner_factor
	)

	if v.offroad:
		target_speed = minf(
			target_speed,
			v.top_speed * 0.45
		)

	if spd < target_speed:
		v.input_throttle = 1.0
		v.input_brake = 0.0
	else:
		v.input_throttle = 0.0
		v.input_brake = clampf(
			(spd - target_speed - 4.0) / 12.0,
			0.0,
			1.0
		)

	v.input_nitro = (
		v.nitro > 0.35
		and curv < 0.12
		and absf(ang) < 0.15
		and spd > 20.0
		and skill > 0.85
	)

	v.input_drift = (
		absf(ang) > 0.55
		and spd > 28.0
		and skill > 0.88
	)

	if spd < 2.0:
		_stuck += delta
	else:
		_stuck = 0.0

	if _stuck > 3.0:
		_stuck = 0.0
		v.respawn(info)
