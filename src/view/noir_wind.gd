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


## Порывы: сумма синусов разных периодов, выше порога — порыв (раз в 10–25 с, по 3–6 с).
static func gust_at(seconds: float) -> float:
	var wave: float = sin(seconds * 0.41) + sin(seconds * 0.23 + 1.3) + 0.6 * sin(seconds * 0.97 + 2.1)
	return clampf((wave - 0.9) / 1.4, 0.0, 1.0)
