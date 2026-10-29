class_name SoundBank
extends Node
## Простые звуки, синтезированные кодом при запуске (без звуковых файлов): выстрелы трёх школ,
## смерть моба, прорыв, покупка, слияние, продажа, рожок волны, колокол раунда, щелчок кнопки.
## Выключатель звука общий для всех сцен и сохраняется в user://settings.cfg.

const MIX_RATE: int = 22050
const PLAYER_COUNT: int = 10
const SETTINGS_PATH: String = "user://settings.cfg"
## Не чаще одного раза за столько секунд для каждого звука: десяток башен не оглушит.
const MIN_INTERVAL: float = 0.07
const VOLUME_DB: float = -8.0

static var _is_muted: bool = false
static var _is_settings_loaded: bool = false
## Звуки генерируются один раз за запуск игры (~50 мс) и дальше общие для всех сцен.
static var _streams: Dictionary[StringName, AudioStreamWAV] = {}
static var _volumes: Dictionary[StringName, float] = {}

var _last_played: Dictionary[StringName, float] = {}
var _players: Array[AudioStreamPlayer] = []
var _next_player: int = 0
var _noise: RandomNumberGenerator = RandomNumberGenerator.new()
var _clock: float = 0.0


static func is_muted() -> bool:
	_load_settings()
	return _is_muted


static func set_muted(muted: bool) -> void:
	_is_muted = muted
	var settings: ConfigFile = ConfigFile.new()
	settings.load(SETTINGS_PATH)
	settings.set_value("audio", "muted", muted)
	if settings.save(SETTINGS_PATH) != OK:
		push_warning("Не удалось сохранить настройки звука")


func _ready() -> void:
	_noise.seed = 7
	for i: int in PLAYER_COUNT:
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)
	if _streams.is_empty():
		_build_sounds()


func _process(delta: float) -> void:
	_clock += delta


## Играет звук по id, если звук включён и этот звук не звучал только что.
func play(sound_id: StringName, pitch_spread: float = 0.06) -> void:
	if is_muted() or not _streams.has(sound_id):
		return
	if _clock - _last_played.get(sound_id, -1.0) < MIN_INTERVAL:
		return
	_last_played[sound_id] = _clock
	var player: AudioStreamPlayer = _players[_next_player]
	_next_player = (_next_player + 1) % _players.size()
	player.stream = _streams[sound_id]
	player.volume_db = VOLUME_DB + _volumes.get(sound_id, 0.0)
	player.pitch_scale = 1.0 + randf_range(-pitch_spread, pitch_spread)
	player.play()


static func _load_settings() -> void:
	if _is_settings_loaded:
		return
	_is_settings_loaded = true
	var settings: ConfigFile = ConfigFile.new()
	if settings.load(SETTINGS_PATH) == OK:
		_is_muted = settings.get_value("audio", "muted", false)


#region Синтез

func _build_sounds() -> void:
	_add(&"shot_fire", _whoosh(0.2), -6.0)
	_add(&"shot_ice", _tones([1760.0, 2640.0], 0.14, 30.0), -10.0)
	_add(&"shot_mech", _pluck(180.0, 0.12), -4.0)
	_add(&"death", _puff(0.22), -3.0)
	_add(&"breach", _thud(0.45), 2.0)
	_add(&"buy", _arpeggio([1046.0, 1568.0], 0.08, 0.3), -6.0)
	_add(&"merge", _arpeggio([784.0, 988.0, 1175.0, 1568.0], 0.07, 0.45), -6.0)
	_add(&"sell", _arpeggio([988.0, 659.0], 0.08, 0.3), -8.0)
	_add(&"wave", _horn(196.0, 0.8), -2.0)
	_add(&"round", _bell(330.0, 1.4), -4.0)
	_add(&"siege", _bell(220.0, 1.8), 0.0)
	_add(&"click", _tones([1400.0], 0.04, 80.0), -14.0)


func _add(sound_id: StringName, samples: PackedFloat32Array, volume_db: float) -> void:
	var data: PackedByteArray = PackedByteArray()
	data.resize(samples.size() * 2)
	for i: int in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = data
	_streams[sound_id] = stream
	_volumes[sound_id] = volume_db


func _new_buffer(seconds: float) -> PackedFloat32Array:
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(int(seconds * MIX_RATE))
	return samples


## Сумма синусов с экспоненциальным затуханием: «звяк» льда, щелчок.
func _tones(frequencies: Array[float], seconds: float, decay: float) -> PackedFloat32Array:
	var samples: PackedFloat32Array = _new_buffer(seconds)
	for i: int in samples.size():
		var t: float = float(i) / MIX_RATE
		var value: float = 0.0
		for frequency: float in frequencies:
			value += sin(TAU * frequency * t)
		samples[i] = value / frequencies.size() * exp(-decay * t) * minf(1.0, t * 400.0)
	return samples


## Шум через простой фильтр с огибающей «нарастание-спад» — свист огненного шара.
func _whoosh(seconds: float) -> PackedFloat32Array:
	var samples: PackedFloat32Array = _new_buffer(seconds)
	var filtered: float = 0.0
	for i: int in samples.size():
		var progress: float = float(i) / samples.size()
		var cutoff: float = 0.05 + 0.25 * sin(progress * PI)
		filtered += cutoff * (_noise.randf_range(-1.0, 1.0) - filtered)
		samples[i] = filtered * sin(progress * PI) * 1.6
	return samples


## Щипок тетивы: синус с падающей высотой плюс щелчок шума в начале.
func _pluck(frequency: float, seconds: float) -> PackedFloat32Array:
	var samples: PackedFloat32Array = _new_buffer(seconds)
	var phase: float = 0.0
	for i: int in samples.size():
		var t: float = float(i) / MIX_RATE
		phase += TAU * frequency * (1.0 + 2.0 * exp(-40.0 * t)) / MIX_RATE
		var click: float = _noise.randf_range(-1.0, 1.0) * exp(-300.0 * t)
		samples[i] = (sin(phase) * 0.8 + click * 0.5) * exp(-25.0 * t)
	return samples


## «Пых»: мягкий шум и падающий тон.
func _puff(seconds: float) -> PackedFloat32Array:
	var samples: PackedFloat32Array = _new_buffer(seconds)
	var filtered: float = 0.0
	var phase: float = 0.0
	for i: int in samples.size():
		var t: float = float(i) / MIX_RATE
		filtered += 0.12 * (_noise.randf_range(-1.0, 1.0) - filtered)
		phase += TAU * (420.0 * exp(-12.0 * t) + 90.0) / MIX_RATE
		samples[i] = (filtered * 1.8 + sin(phase) * 0.5) * exp(-16.0 * t) * minf(1.0, t * 300.0)
	return samples


## Глухой удар по терему.
func _thud(seconds: float) -> PackedFloat32Array:
	var samples: PackedFloat32Array = _new_buffer(seconds)
	var phase: float = 0.0
	var filtered: float = 0.0
	for i: int in samples.size():
		var t: float = float(i) / MIX_RATE
		phase += TAU * (70.0 + 80.0 * exp(-20.0 * t)) / MIX_RATE
		filtered += 0.06 * (_noise.randf_range(-1.0, 1.0) - filtered)
		samples[i] = (sin(phase) + filtered * 2.0) * 0.7 * exp(-7.0 * t)
	return samples


## Ноты по очереди — звон монет при покупке, слиянии, продаже.
func _arpeggio(frequencies: Array[float], step: float, seconds: float) -> PackedFloat32Array:
	var samples: PackedFloat32Array = _new_buffer(seconds)
	for note: int in frequencies.size():
		var start: int = int(note * step * MIX_RATE)
		for i: int in range(start, samples.size()):
			var t: float = float(i - start) / MIX_RATE
			var angle: float = TAU * frequencies[note] * t
			var tone: float = sin(angle) + 0.3 * sin(angle * 3.0)
			samples[i] += tone * 0.35 * exp(-14.0 * t) * minf(1.0, t * 500.0)
	return samples


## Рожок: «пилообразный» тон с вибрато, смягчённый фильтром.
func _horn(frequency: float, seconds: float) -> PackedFloat32Array:
	var samples: PackedFloat32Array = _new_buffer(seconds)
	var phase: float = 0.0
	var filtered: float = 0.0
	for i: int in samples.size():
		var t: float = float(i) / MIX_RATE
		var progress: float = t / seconds
		phase += frequency * (1.0 + 0.012 * sin(TAU * 5.0 * t)) / MIX_RATE
		var saw: float = 2.0 * (phase - floorf(phase)) - 1.0
		filtered += 0.18 * (saw - filtered)
		var envelope: float = minf(1.0, t * 12.0) * minf(1.0, (1.0 - progress) * 5.0)
		samples[i] = filtered * envelope * 0.8
	return samples


## Колокол: негармоничные призвуки с долгим затуханием.
func _bell(frequency: float, seconds: float) -> PackedFloat32Array:
	var samples: PackedFloat32Array = _new_buffer(seconds)
	var partials: Array[float] = [1.0, 2.0, 2.4, 3.0, 4.5]
	var gains: Array[float] = [1.0, 0.6, 0.45, 0.3, 0.2]
	for i: int in samples.size():
		var t: float = float(i) / MIX_RATE
		var value: float = 0.0
		for p: int in partials.size():
			value += sin(TAU * frequency * partials[p] * t) * gains[p] * exp(-(2.5 + p) * t)
		samples[i] = value * 0.32 * minf(1.0, t * 800.0)
	return samples

#endregion
