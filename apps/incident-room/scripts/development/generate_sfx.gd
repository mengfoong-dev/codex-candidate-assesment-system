extends SceneTree

# Throwaway/dev: synthesizes the two retro UI sounds to assets/ui/sfx/*.wav.
# Procedural (no third-party audio, no license). Re-run to regenerate.
#   text_blip.wav  - short square blip per revealed dialogue char (Pokémon-style)
#   ui_click.wav   - short click for buttons / advance

const RATE := 44100
const OUT_DIR := "res://assets/ui/sfx"

func _initialize() -> void:
	_write(OUT_DIR + "/text_blip.wav", _blip())
	_write(OUT_DIR + "/ui_click.wav", _click())
	print("SFX written to %s" % OUT_DIR)
	quit()

# ~28ms 720 Hz square wave with a fast linear decay — a soft typewriter blip.
func _blip() -> PackedFloat32Array:
	var n := int(RATE * 0.028)
	var s := PackedFloat32Array()
	s.resize(n)
	var freq := 720.0
	for i in range(n):
		var t := float(i) / RATE
		var env := 1.0 - float(i) / n           # linear decay
		var sq := 1.0 if fmod(t * freq, 1.0) < 0.5 else -1.0
		s[i] = sq * env * 0.28
	return s

# ~18ms downward pitch chirp + decay — a crisp UI click.
func _click() -> PackedFloat32Array:
	var n := int(RATE * 0.018)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in range(n):
		var frac := float(i) / n
		var freq := 1400.0 - 900.0 * frac        # 1400 -> 500 Hz
		var env := pow(1.0 - frac, 2.0)          # sharp decay
		s[i] = sin(TAU * freq * (float(i) / RATE)) * env * 0.35
	return s

# Write mono 16-bit PCM WAV.
func _write(path: String, samples: PackedFloat32Array) -> void:
	var data := PackedByteArray()
	for v: float in samples:
		var q := int(clampf(v, -1.0, 1.0) * 32767.0)
		data.append(q & 0xFF)
		data.append((q >> 8) & 0xFF)
	var out := StreamPeerBuffer.new()
	out.big_endian = false
	out.put_data("RIFF".to_ascii_buffer())
	out.put_u32(36 + data.size())
	out.put_data("WAVE".to_ascii_buffer())
	out.put_data("fmt ".to_ascii_buffer())
	out.put_u32(16)          # PCM chunk size
	out.put_u16(1)           # format = PCM
	out.put_u16(1)           # channels = mono
	out.put_u32(RATE)
	out.put_u32(RATE * 2)    # byte rate (rate * channels * bytes/sample)
	out.put_u16(2)           # block align
	out.put_u16(16)          # bits/sample
	out.put_data("data".to_ascii_buffer())
	out.put_u32(data.size())
	out.put_data(data)
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer(out.data_array)
	f.close()
