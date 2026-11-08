class_name NoirWind
extends RefCounted
## Общий ветер арены — только отображение (не sim). Порывы зависят лишь от времени, поэтому
## обе арены (своё поле и поле соперника) видят один и тот же ветер.
## Значения уходят в глобальные параметры шейдеров (project.godot, [shader_globals]):
## noir_wind — сила порыва 0..1 (качание крон и травы), noir_wind_drift — накопленный снос тумана, м.

## Куда дует: как прежний снос лесной дымки (−0,10; 0,053 м/с).
const DIRECTION: Vector3 = Vector3(-0.884, 0.0, 0.468)
const BASE_SPEED: float = 0.113
## Добавка к сносу в самый сильный порыв, м/с.
const GUST_SPEED: float = 0.9

static var strength: float = 0.0
static var _drift: Vector3 = Vector3.ZERO
static var _frame: int = -1


## Вызывать каждый кадр из любого числа узлов: считается один раз за кадр.
static func update(delta: float) -> void:
	var frame: int = Engine.get_process_frames()
	if frame == _frame:
		return
	_frame = frame
	strength = gust_at(Time.get_ticks_msec() * 0.001)
	_drift += DIRECTION * (BASE_SPEED + GUST_SPEED * strength) * delta
	RenderingServer.global_shader_parameter_set(&"noir_wind", strength)
	RenderingServer.global_shader_parameter_set(&"noir_wind_drift", _drift)


## Порывы: раз в ~16 с (сдвиг внутри периода и сила — от номера периода): нарастает 1,2 с,
## держится ~2 с, стихает к 6,5 с. В промежутках — лёгкий бриз.
const GUST_PERIOD: float = 16.0


static func gust_at(seconds: float) -> float:
	var index: float = floorf(seconds / GUST_PERIOD)
	var strongest: float = 0.0
	for k: float in [index - 1.0, index]:
		var start: float = k * GUST_PERIOD + _hash01(k) * 6.0
		var local: float = seconds - start
		if local < 0.0:
			continue
		var power: float = 0.7 + 0.3 * _hash01(k + 17.0)
		strongest = maxf(strongest, power * smoothstep(0.0, 1.2, local) * (1.0 - smoothstep(3.2, 6.5, local)))
	var breeze: float = 0.08 * (0.5 + 0.5 * sin(seconds * 0.37))
	return clampf(maxf(strongest, breeze), 0.0, 1.0)


static func _hash01(value: float) -> float:
	var x: float = sin(value * 12.9898) * 43758.5453
	return x - floorf(x)
