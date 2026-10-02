extends CanvasLayer
## Prepare the title before playback so the intro can fade straight into it.
## Returning to the title within a session continues to use Main's normal flow.

const INTRO_STREAM: VideoStream = preload("res://videos/intro/startup.ogv")
const MAIN_SCENE := "res://scenes/main.tscn"
const TITLE_FADE_SECONDS := 0.8

var _presentation: Control
var _video: VideoStreamPlayer
var _main: Node
var _transitioning := false


func _ready() -> void:
	layer = 110 # Above the title and gameplay post-processing.
	var options := CliOptions.parse()
	if options.skips_title() or options.quick_exit():
		call_deferred("_boot_without_video")
		return

	var settings := GameSettings.new()
	get_window().mode = Window.MODE_FULLSCREEN if bool(settings.get_value("fullscreen")) \
		else Window.MODE_WINDOWED
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	_presentation = Control.new()
	_presentation.set_anchors_preset(Control.PRESET_FULL_RECT)
	_presentation.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_presentation)
	var backdrop := ColorRect.new()
	backdrop.color = Color.BLACK
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_presentation.add_child(backdrop)
	var frame := AspectRatioContainer.new()
	frame.ratio = 16.0 / 9.0
	frame.stretch_mode = AspectRatioContainer.STRETCH_FIT
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_presentation.add_child(frame)
	_video = VideoStreamPlayer.new()
	_video.stream = INTRO_STREAM
	_video.expand = true
	_video.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_video.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_video.mouse_filter = Control.MOUSE_FILTER_IGNORE
	SoundBank.ensure_dialogue_bus()
	_video.bus = SoundBank.DIALOGUE_BUS
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(_video.bus),
		linear_to_db(maxf(0.0001, float(settings.get_value("dialogue_volume")))))
	_video.finished.connect(_on_video_finished)
	frame.add_child(_video)
	call_deferred("_prepare_title")


func _prepare_title() -> void:
	# Finish synchronous scene construction before the clip starts. Main's
	# processing and score stay held until the title is fully revealed.
	_main = _start_main(true)
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	_video.play()


func _input(_event: InputEvent) -> void:
	# Launch input must not activate a title button during its fade-in.
	get_viewport().set_input_as_handled()


func _on_video_finished() -> void:
	if _transitioning:
		return
	_transitioning = true
	_video.paused = true
	# The title is already rendered below the video. Crossfade immediately;
	# no loading work, black hold or frame waits belong after the clip ends.
	var fade := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	fade.tween_property(_presentation, "modulate:a", 0.0, TITLE_FADE_SECONDS)
	await fade.finished
	_video.stop()
	_video.stream = null
	_main.process_mode = Node.PROCESS_MODE_INHERIT
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	queue_free()


func _start_main(hold := false) -> Node:
	var main := (load(MAIN_SCENE) as PackedScene).instantiate()
	if hold:
		main.process_mode = Node.PROCESS_MODE_DISABLED
	get_tree().root.add_child(main)
	get_tree().current_scene = main
	return main


func _boot_without_video() -> void:
	_start_main()
	queue_free()
