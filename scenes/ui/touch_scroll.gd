class_name TouchScroll
extends Node

const AppModal = preload("res://scenes/ui/app_modal.gd")

## Phone-style scrolling for a ScrollContainer: the content follows the finger one to one, keeps
## gliding after a flick and slows down smoothly, and a drag never presses what it started on.
##
## Godot's ScrollContainer only sees a drag that its children let through, and the button or
## checkbox under the finger still clicks when it is lifted, so lists either did not scroll or
## ticked boxes while scrolling. This node reads the pointer before the controls do (_input),
## keeps a press to itself until it knows whether it is a tap or a drag (like Android's touch
## slop and tap timeout), and passes taps on to the controls as if nothing was in between.
##   TouchScroll.attach(scroll_container)

## How far the finger may move and still be a tap (Android's touch slop is 8 dp)
const SLOP: float = 10.0
## A finger held this long without moving presses the control under it, so a held button shows
## that it is pressed; moving on from there still scrolls and cancels the press
const TAP_TIMEOUT: float = 0.09
## After a flick the speed falls by e every FRICTION_TIME seconds
const FRICTION_TIME: float = 0.32
## Flicks slower than this (px/s) do not glide; a glide stops below it
const MIN_FLING_SPEED: float = 60.0
const MAX_FLING_SPEED: float = 6000.0
## Pointer samples that set the flick's speed, from the last this many seconds
const VELOCITY_WINDOW: float = 0.08

enum State { IDLE, PENDING, PRESSED, DRAGGING, CAUGHT }

## The ScrollContainers that scroll this way, to pick the innermost one under a finger
static var _all: Array[TouchScroll] = []
## True while a held-back press or release is being handed on, so _input lets it through
static var _replaying: bool = false

var scroll: ScrollContainer
var state: State = State.IDLE
## Glide speed in px/s, positive when the content moves up (scroll value grows)
var velocity: float = 0.0

var _down_event: InputEventMouseButton = null
var _down_pos: Vector2 = Vector2.ZERO
var _down_time: float = 0.0
var _start_scroll: float = 0.0
var _samples: Array[Vector2] = []

static func attach(target: ScrollContainer) -> TouchScroll:
	for child in target.get_children(true):
		if child is TouchScroll:
			return child
	var ts := TouchScroll.new()
	ts.scroll = target
	target.add_child(ts, false, Node.INTERNAL_MODE_BACK)
	return ts

func _enter_tree() -> void:
	if not _all.has(self):
		_all.append(self)
	set_process(false)

func _exit_tree() -> void:
	_all.erase(self)

func _now() -> float:
	return Time.get_ticks_usec() / 1000000.0

## How far the content can scroll, 0 when it fits
func max_scroll() -> float:
	var bar := scroll.get_v_scroll_bar()
	return maxf(0.0, bar.max_value - bar.page)

func _can_scroll() -> bool:
	return scroll.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED and max_scroll() > 0.5

## Whether this scroller should handle a press at `pos`: on show, under the finger, not covered
## by a dialog it is not part of, and the innermost such scroller
func _claims(pos: Vector2) -> bool:
	if not scroll.is_visible_in_tree() or not scroll.get_global_rect().has_point(pos) or not _can_scroll():
		return false
	for m in scroll.get_tree().get_nodes_in_group(AppModal.GROUP):
		if m is CanvasItem and m.visible and not m.is_ancestor_of(scroll):
			return false
	for other in _all:
		if other != self and other.scroll.is_visible_in_tree() and other._can_scroll() \
				and other.scroll.get_global_rect().has_point(pos) and scroll.is_ancestor_of(other.scroll):
			return false
	return true

func _input(event: InputEvent) -> void:
	if _replaying or scroll == null:
		return
	# Touch screens send every touch twice, as a touch and as an emulated mouse event; the mouse
	# one drives this, and the touch one must not reach ScrollContainer's own drag scrolling
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		if state != State.IDLE or (event is InputEventScreenTouch and event.pressed and _claims(event.position)):
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_on_down(event)
		else:
			_on_up(event)
	elif event is InputEventMouseMotion and state != State.IDLE:
		_on_move(event)

func _on_down(event: InputEventMouseButton) -> void:
	if not _claims(event.position):
		return
	get_viewport().set_input_as_handled()
	# A finger on a gliding list stops it, and only that: it does not also press what is under it
	var was_gliding := absf(velocity) > 0.0
	velocity = 0.0
	_down_event = event.duplicate()
	_down_pos = event.position
	_down_time = _now()
	_start_scroll = scroll.scroll_vertical
	_samples = [Vector2(_down_time, event.position.y)]
	state = State.CAUGHT if was_gliding else State.PENDING
	set_process(true)

func _on_move(event: InputEventMouseMotion) -> void:
	get_viewport().set_input_as_handled()
	_samples.append(Vector2(_now(), event.position.y))
	if state != State.DRAGGING:
		if event.position.distance_to(_down_pos) < SLOP:
			return
		if state == State.PRESSED:
			_cancel_press()
		state = State.DRAGGING
		# Follow from the edge of the slop, so the content neither jumps nor lags behind
		_down_pos.y += SLOP * signf(event.position.y - _down_pos.y)
		_start_scroll = scroll.scroll_vertical
	_set_scroll(_start_scroll - (event.position.y - _down_pos.y))

func _on_up(event: InputEventMouseButton) -> void:
	if state == State.IDLE:
		return
	get_viewport().set_input_as_handled()
	match state:
		State.PENDING:
			_replay(_down_event)
			_replay(event)
		State.PRESSED:
			_replay(event)
		State.DRAGGING:
			_samples.append(Vector2(_now(), event.position.y))
			velocity = clampf(_flick_speed(), -MAX_FLING_SPEED, MAX_FLING_SPEED)
			if absf(velocity) < MIN_FLING_SPEED:
				velocity = 0.0
	state = State.IDLE
	_down_event = null
	set_process(absf(velocity) > 0.0)

## Speed of the finger over the last VELOCITY_WINDOW, in scroll px/s
func _flick_speed() -> float:
	var last: Vector2 = _samples[_samples.size() - 1]
	var first: Vector2 = last
	for i in range(_samples.size() - 1, -1, -1):
		if last.x - _samples[i].x > VELOCITY_WINDOW:
			break
		first = _samples[i]
	var dt: float = last.x - first.x
	if dt <= 0.0:
		return 0.0
	return -(last.y - first.y) / dt

func _process(delta: float) -> void:
	if state == State.PENDING and _now() - _down_time >= TAP_TIMEOUT:
		# Held still: press now, so the control shows it is held
		_replay(_down_event)
		state = State.PRESSED
	if state == State.IDLE and absf(velocity) > 0.0:
		var before: float = scroll.scroll_vertical
		_set_scroll(scroll.scroll_vertical + velocity * delta)
		velocity *= exp(-delta / FRICTION_TIME)
		var at_end: bool = is_equal_approx(scroll.scroll_vertical, before) and absf(velocity * delta) >= 1.0
		if absf(velocity) < MIN_FLING_SPEED or at_end:
			velocity = 0.0
	if state == State.IDLE and velocity == 0.0:
		set_process(false)

func _set_scroll(value: float) -> void:
	scroll.scroll_vertical = int(roundf(clampf(value, 0.0, max_scroll())))

## The press that was handed on is taken back: the finger seems to slide far away and lift
## there, so nothing clicks
func _cancel_press() -> void:
	var away := InputEventMouseMotion.new()
	away.button_mask = MOUSE_BUTTON_MASK_LEFT
	away.position = Vector2(-100000, -100000)
	away.global_position = away.position
	_replay(away)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = Vector2(-100000, -100000)
	up.global_position = up.position
	_replay(up)

func _replay(event: InputEvent) -> void:
	if event == null or not is_inside_tree():
		return
	_replaying = true
	get_viewport().push_input(event, true)
	_replaying = false
