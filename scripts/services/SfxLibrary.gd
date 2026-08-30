extends Node

## 程序化音效库（v0.16.0，阶段 5 提交 2）：全部音效运行时合成（AudioStreamWAV
## 16-bit PCM），零外部资产；走 Master 总线（设置面板"主音量"统一控制）。
## 播放池轮换避免多塔同帧触发时互相打断。

const MIX_RATE := 22050
const PLAYER_POOL_SIZE := 10
const SFX_IDS: Array[StringName] = [
	&"attack", &"skill", &"ultimate", &"kill", &"build", &"victory", &"defeat",
]

var _players: Array[AudioStreamPlayer] = []
var _pool_index := 0
var _cache: Dictionary = {}


func _ready() -> void:
	for index in range(PLAYER_POOL_SIZE):
		var player := AudioStreamPlayer.new()
		player.bus = "Master"
		add_child(player)
		_players.append(player)
	for sfx_id in SFX_IDS:
		_cache[sfx_id] = _synthesize(sfx_id)


## 播放指定音效（id 未合成过则忽略，保证测试/旧存档安全）。
func play(sfx_id: StringName, volume_db: float = -10.0) -> void:
	var stream: AudioStreamWAV = _cache.get(sfx_id)
	if stream == null:
		return
	var player := _players[_pool_index]
	_pool_index = (_pool_index + 1) % _players.size()
	player.stream = stream
	player.volume_db = volume_db
	player.play()


func get_synthesized_count() -> int:
	return _cache.size()


func _synthesize(sfx_id: StringName) -> AudioStreamWAV:
	match sfx_id:
		&"attack":
			return _tone(760.0, 520.0, 0.055, 0.22)
		&"skill":
			return _tone(880.0, 1320.0, 0.16, 0.28)
		&"ultimate":
			return _mixed_tone_noise(170.0, 520.0, 0.5, 0.3, 0.16)
		&"kill":
			return _tone(340.0, 130.0, 0.17, 0.28)
		&"build":
			return _tone(523.0, 784.0, 0.13, 0.26)
		&"victory":
			return _triplet([523.0, 659.0, 784.0], 0.5, 0.28)
		&"defeat":
			return _triplet([330.0, 247.0, 165.0], 0.6, 0.28)
	return _tone(440.0, 440.0, 0.1, 0.2)


## 单音：正弦扫频 + 平方衰减包络。
static func _tone(freq_from: float, freq_to: float, duration: float, amp: float) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	var sample_count := maxi(1, int(duration * MIX_RATE))
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	var phase := 0.0
	for index in range(sample_count):
		var t := float(index) / sample_count
		var freq := lerpf(freq_from, freq_to, t)
		phase += freq * TAU / MIX_RATE
		var envelope := (1.0 - t) * (1.0 - t)
		var value := int(clampf(sin(phase) * envelope * amp, -1.0, 1.0) * 32767.0)
		data.encode_s16(index * 2, value)
	wav.data = data
	return wav


## 正弦 + 噪声混合（大招等"重"音效）。
static func _mixed_tone_noise(
	freq_from: float, freq_to: float, duration: float, amp: float, noise_amp: float
) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	var sample_count := maxi(1, int(duration * MIX_RATE))
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	var phase := 0.0
	for index in range(sample_count):
		var t := float(index) / sample_count
		var freq := lerpf(freq_from, freq_to, t)
		phase += freq * TAU / MIX_RATE
		var envelope := (1.0 - t) * (1.0 - t)
		var sample := sin(phase) * amp + randf_range(-noise_amp, noise_amp)
		var value := int(clampf(sample * envelope, -1.0, 1.0) * 32767.0)
		data.encode_s16(index * 2, value)
	wav.data = data
	return wav


## 三连音（胜利/失败等结算提示）。
static func _triplet(frequencies: Array, duration: float, amp: float) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	var per_note := duration / frequencies.size()
	var sample_count := maxi(1, int(duration * MIX_RATE))
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	var phase := 0.0
	var note_index := 0
	for index in range(sample_count):
		var t := float(index) / sample_count
		var note_progress := float(index % maxi(1, int(per_note * MIX_RATE))) / maxi(1, int(per_note * MIX_RATE))
		note_index = mini(int(index / maxi(1, int(per_note * MIX_RATE))), frequencies.size() - 1)
		var freq := float(frequencies[note_index])
		phase += freq * TAU / MIX_RATE
		var envelope := (1.0 - note_progress) * (1.0 - note_progress)
		var value := int(clampf(sin(phase) * envelope * amp, -1.0, 1.0) * 32767.0)
		data.encode_s16(index * 2, value)
	wav.data = data
	return wav