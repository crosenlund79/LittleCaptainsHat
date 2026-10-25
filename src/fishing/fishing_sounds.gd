class_name FishingSounds
extends RefCounted
## The small Iteration 13 cues (fishing, the galley, the anchor). Placeholder
## synthesized sounds (tools/generate_placeholder_audio.py); every one of them
## has a visible counterpart, so nothing depends on hearing it.

const DIR := "res://assets/audio/placeholder/"
## Their loudness on the SFX bus: quiet.
const DB := -8.0


static func _load(name: String) -> AudioStream:
	return load(DIR + name) as AudioStream


static func cast() -> AudioStream:
	return _load("fishing_cast.wav")


static func bite() -> AudioStream:
	return _load("fishing_bite.wav")


static func reel() -> AudioStream:
	return _load("fishing_reel.wav")


static func splash() -> AudioStream:
	return _load("fishing_splash.wav")


static func snap() -> AudioStream:
	return _load("fishing_snap.wav")


static func sizzle() -> AudioStream:
	return _load("galley_sizzle.wav")


static func chain() -> AudioStream:
	return _load("anchor_chain.wav")


static func warning() -> AudioStream:
	return _load("warning_beep.wav")
