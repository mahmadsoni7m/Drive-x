extends Node
## All audio is synthesized at startup (no external audio files required).
## Drop real files into assets/audio and extend play() later without touching callers.

const RATE := 22050
const MUSIC_RATE := 11025

var _streams: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _pool_i := 0
var _engine: AudioStreamPlayer
var _boost: AudioStreamPlayer
var _music: AudioStreamPlayer


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    _streams["click"] = _tone([880.0, 1320.0], 0.07, 0.5, 35.0)
    _streams["coin"] = _tone([1318.0, 1760.0], 0.22, 0.5, 9.0)
    _streams["beep"] = _tone([660.0], 0.2, 0.55, 4.0)
    _streams["go"] = _tone([990.0, 1485.0], 0.5, 0.55, 3.0)
    _streams["boost"] = _tone([440.0, 660.0, 880.0], 0.4, 0.5, 5.0, 600.0)
    _streams["finish"] = _tone([523.0, 659.0, 784.0], 0.9, 0.5, 2.5)
    _streams["punch"] = _noise(0.12, 0.7, 25.0, 0.5)
    _streams["hit"] = _tone([180.0, 120.0], 0.18, 0.7, 14.0)
    _streams["crash"] = _noise(0.35, 0.9, 9.0, 0.2)
    for i in 8:
        var p := AudioStreamPlayer.new()
        add_child(p)
        _pool.append(p)
    _engine = AudioStreamPlayer.new()
    _engine.stream = _engine_stream()
    add_child(_engine)
    _boost = AudioStreamPlayer.new()
    _boost.stream = _boost_stream()
    add_child(_boost)
    _music = AudioStreamPlayer.new()
    _music.stream = _music_stream()
    add_child(_music)
    apply_volumes()
    play_music()


func _vol(key: String, fallback: float) -> float:
    var v: Variant = GameData.setting(key)
    if v == null:
        return fallback
    return float(v)


func apply_volumes() -> void:
    var sfx := _vol("sfx", 0.8)
    for p in _pool:
        p.volume_db = linear_to_db(maxf(sfx, 0.0001))
    _boost.volume_db = linear_to_db(maxf(sfx * 0.5, 0.0001))
    _music.volume_db = linear_to_db(maxf(_vol("music", 0.5) * 0.45, 0.0001))


func play(sound: String, pitch: float = 1.0) -> void:
    if not _streams.has(sound) or _pool.is_empty():
        return
    var p := _pool[_pool_i]
    _pool_i = (_pool_i + 1) % _pool.size()
    p.stream = _streams[sound]
    p.pitch_scale = pitch
    p.play()


func play_music() -> void:
    if _music != null and not _music.playing:
        _music.play()


func start_engine() -> void:
    if not _engine.playing:
        _engine.play()
    _engine.stream_paused = false


func stop_engine() -> void:
    _engine.stop()
    _boost.stop()


func pause_engine(paused: bool) -> void:
    _engine.stream_paused = paused
    _boost.stream_paused = paused


func set_engine(speed_ratio: float, throttle: float, boosting: bool) -> void:
    _engine.pitch_scale = lerpf(0.7, 3.2, clampf(speed_ratio, 0.0, 1.2))
    var sfx := _vol("sfx", 0.8)
    _engine.volume_db = linear_to_db(maxf(sfx * (0.12 + 0.2 * throttle), 0.0001))
    if boosting and not _boost.playing:
        _boost.play()
    elif not boosting and _boost.playing:
        _boost.stop()


# --- synthesis -----------------------------------------------------------------
func _wav(samples: PackedFloat32Array, rate: int, loop: bool) -> AudioStreamWAV:
    var bytes := PackedByteArray()
    bytes.resize(samples.size() * 2)
    for i in samples.size():
        bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
    var w := AudioStreamWAV.new()
    w.format = AudioStreamWAV.FORMAT_16_BITS
    w.mix_rate = rate
    w.stereo = false
    w.data = bytes
    if loop:
        w.loop_mode = AudioStreamWAV.LOOP_FORWARD
        w.loop_begin = 0
        w.loop_end = samples.size()
    return w


func _tone(freqs: Array, dur: float, vol: float, decay: float, sweep: float = 0.0) -> AudioStreamWAV:
    var n := int(RATE * dur)
    var s := PackedFloat32Array()
    s.resize(n)
    for i in n:
        var t := float(i) / RATE
        var v := 0.0
        for f in freqs:
            v += sin(TAU * (float(f) + sweep * t) * t)
        s[i] = v / float(freqs.size()) * exp(-decay * t) * vol
    return _wav(s, RATE, false)


func _noise(dur: float, vol: float, decay: float, smooth: float) -> AudioStreamWAV:
    var rng := RandomNumberGenerator.new()
    rng.seed = 7
    var n := int(RATE * dur)
    var s := PackedFloat32Array()
    s.resize(n)
    var y := 0.0
    for i in n:
        y += (rng.randf_range(-1.0, 1.0) - y) * smooth
        s[i] = y * exp(-decay * float(i) / RATE) * vol * 2.5
    return _wav(s, RATE, false)


func _boost_stream() -> AudioStreamWAV:
    var rng := RandomNumberGenerator.new()
    rng.seed = 11
    var n := RATE / 2
    var s := PackedFloat32Array()
    s.resize(n)
    var y := 0.0
    for i in n:
        y += (rng.randf_range(-1.0, 1.0) - y) * 0.3
        s[i] = y * 0.9
    return _wav(s, RATE, true)


func _engine_stream() -> AudioStreamWAV:
    # 441 samples @ 22050 Hz = exactly one 50 Hz cycle, so the 4-cycle loop is seamless.
    var n := 441 * 4
    var s := PackedFloat32Array()
    s.resize(n)
    for i in n:
        var ph := TAU * float(i) / 441.0
        var v := sin(ph) + 0.5 * sin(2.0 * ph) + 0.35 * sin(3.0 * ph) + 0.25 * sin(4.0 * ph + 0.5) + 0.15 * sin(6.0 * ph)
        s[i] = clampf(v * 0.45, -0.9, 0.9)
    return _wav(s, RATE, true)


func _music_stream() -> AudioStreamWAV:
    var chords := [
        [220.0, 261.63, 329.63], [174.61, 220.0, 261.63],
        [261.63, 329.63, 392.0], [196.0, 246.94, 293.66],
    ]
    var per_note := MUSIC_RATE / 4
    var per_chord := per_note * 8
    var s := PackedFloat32Array()
    s.resize(per_chord * chords.size())
    for c in chords.size():
        var ch: Array = chords[c]
        var root: float = ch[0]
        for i in per_chord:
            var note := i / per_note
            var f: float = ch[note % 3] * (2.0 if note % 4 == 3 else 1.0)
            var t := float(i % per_note) / MUSIC_RATE
            var arp := (sin(TAU * f * t) + 0.4 * sin(TAU * 2.0 * f * t)) * exp(-6.0 * t) * 0.4
            var tc := float(i) / MUSIC_RATE
            var bass := sin(TAU * root * 0.5 * tc) * 0.28 * (0.6 + 0.4 * exp(-3.0 * fmod(tc, 0.5)))
            s[c * per_chord + i] = (arp + bass) * 0.7
    return _wav(s, MUSIC_RATE, true)
