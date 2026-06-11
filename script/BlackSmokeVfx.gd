extends Node2D
class_name BlackSmokeVfx

const FRAME_COUNT: int = 25
const FRAME_TEMPLATE: String = "res://asset/vfx/Black smoke/blackSmoke%02d.png"
const ANIMATION_NAME: StringName = &"default"
const ANIMATION_SPEED: float = 16.0

static var _shared_frames: SpriteFrames = null

@export_range(0.1, 10.0, 0.01) var puff_interval: float = 0.95
@export_range(0.0, 5.0, 0.01) var puff_interval_jitter: float = 0.2
@export var puff_offset_jitter: Vector2 = Vector2(4.0, 2.5)
@export_range(0.0, 0.5, 0.01) var puff_scale_jitter: float = 0.12
@export var start_immediately: bool = true

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _puff_timer: Timer = $PuffTimer

var _base_sprite_position: Vector2 = Vector2.ZERO
var _base_sprite_scale: Vector2 = Vector2.ONE
var _is_emitting: bool = false
var _sprite_frames_ready: bool = false
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _time_flow_paused: bool = false
var _paused_time_left: float = 0.0
var _paused_animation_in_progress: bool = false

func _ready() -> void:
	_rng.randomize()
	set_process(true)
	if _sprite == null or _puff_timer == null:
		return
	_base_sprite_position = _sprite.position
	_base_sprite_scale = _sprite.scale
	_ensure_sprite_frames()
	_hide_sprite()
	if not _sprite.animation_finished.is_connected(_on_animation_finished):
		_sprite.animation_finished.connect(_on_animation_finished)
	_puff_timer.one_shot = true
	if not _puff_timer.timeout.is_connected(_on_puff_timer_timeout):
		_puff_timer.timeout.connect(_on_puff_timer_timeout)
	_sync_time_flow_state(true)

func _process(_delta: float) -> void:
	_sync_time_flow_state()

func set_emitting(enabled: bool) -> void:
	if _sprite == null or _puff_timer == null:
		return
	if _is_emitting == enabled:
		if enabled and not _time_flow_paused and _puff_timer.is_stopped() and not _sprite.is_playing():
			if start_immediately:
				_play_puff()
			else:
				_schedule_next_puff()
		return
	_is_emitting = enabled
	if _is_emitting:
		if _time_flow_paused:
			return
		if _sprite.is_playing():
			return
		if start_immediately:
			_play_puff()
		else:
			_schedule_next_puff()
		return
	_puff_timer.stop()
	if not _sprite.is_playing():
		_hide_sprite()

func _ensure_sprite_frames() -> void:
	if _sprite_frames_ready or _sprite == null:
		return
	if _shared_frames == null:
		var frames := SpriteFrames.new()
		frames.add_animation(ANIMATION_NAME)
		frames.set_animation_loop(ANIMATION_NAME, false)
		frames.set_animation_speed(ANIMATION_NAME, ANIMATION_SPEED)
		var added_frame_count: int = 0
		for frame_index in range(FRAME_COUNT):
			var frame_path: String = FRAME_TEMPLATE % frame_index
			var texture: Texture2D = load(frame_path) as Texture2D
			if texture == null:
				push_warning("BlackSmokeVfx: missing frame %s" % frame_path)
				continue
			frames.add_frame(ANIMATION_NAME, texture)
			added_frame_count += 1
		if added_frame_count == 0:
			push_warning("BlackSmokeVfx: no black smoke frames loaded.")
			return
		_shared_frames = frames
	_sprite.sprite_frames = _shared_frames
	_sprite_frames_ready = true

func _play_puff() -> void:
	if _sprite == null:
		return
	if _time_flow_paused:
		return
	_ensure_sprite_frames()
	if not _sprite_frames_ready:
		return
	_apply_puff_variation()
	_sprite.frame = 0
	_sprite.show()
	_sprite.play(ANIMATION_NAME)

func _apply_puff_variation() -> void:
	var offset := Vector2(
		_rng.randf_range(-puff_offset_jitter.x, puff_offset_jitter.x),
		_rng.randf_range(-puff_offset_jitter.y, puff_offset_jitter.y)
	)
	var scale_factor: float = 1.0 + _rng.randf_range(-puff_scale_jitter, puff_scale_jitter)
	_sprite.position = _base_sprite_position + offset
	_sprite.scale = _base_sprite_scale * scale_factor

func _schedule_next_puff(delay: float = -1.0) -> void:
	if not _is_emitting or _puff_timer == null or _time_flow_paused:
		return
	var next_delay: float = delay
	if next_delay < 0.0:
		next_delay = _compute_next_delay()
	_puff_timer.start(maxf(0.05, next_delay))

func _compute_next_delay() -> float:
	return maxf(0.05, puff_interval + _rng.randf_range(-puff_interval_jitter, puff_interval_jitter))

func _hide_sprite() -> void:
	if _sprite == null:
		return
	_sprite.stop()
	_sprite.frame = 0
	_sprite.position = _base_sprite_position
	_sprite.scale = _base_sprite_scale
	_sprite.hide()

func _on_puff_timer_timeout() -> void:
	if _time_flow_paused:
		return
	if _is_emitting and not _sprite.is_playing():
		_play_puff()

func _on_animation_finished() -> void:
	_hide_sprite()
	if _is_emitting and not _time_flow_paused:
		_schedule_next_puff()

func _sync_time_flow_state(force: bool = false) -> void:
	var should_pause: bool = _should_pause_for_time_flow()
	if not force and _time_flow_paused == should_pause:
		return
	_time_flow_paused = should_pause
	if _time_flow_paused:
		_pause_for_time_flow()
		return
	_resume_from_time_flow()

func _should_pause_for_time_flow() -> bool:
	return TimeManager != null and (not TimeManager.is_time_running or TimeManager.time_speed <= 0.0)

func _pause_for_time_flow() -> void:
	if _puff_timer != null and not _puff_timer.is_stopped():
		_paused_time_left = maxf(_puff_timer.time_left, 0.0)
		_puff_timer.stop()
	else:
		_paused_time_left = 0.0
	if _sprite != null and _sprite.is_playing():
		_sprite.pause()
		_paused_animation_in_progress = true
	else:
		_paused_animation_in_progress = false

func _resume_from_time_flow() -> void:
	if _sprite != null and _paused_animation_in_progress:
		_sprite.play()
		_paused_animation_in_progress = false
		return
	if not _is_emitting or _puff_timer == null:
		_paused_time_left = 0.0
		return
	if _paused_time_left > 0.0:
		_puff_timer.start(maxf(0.05, _paused_time_left))
		_paused_time_left = 0.0
		return
	if not _sprite.is_playing() and _puff_timer.is_stopped():
		_schedule_next_puff(0.05 if start_immediately else -1.0)