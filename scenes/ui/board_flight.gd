class_name BoardFlight
extends MiniBoard

## A board that moves and grows from one rectangle on screen to another, over everything else.
## The game opens from the resume card with one: the card's miniature grows into the game's
## board, and on leaving the game it shrinks back into the card. It is a MiniBoard, which draws
## its digits at any size, so it stays sharp all the way.
##   var flight := BoardFlight.new()
##   flight.set_board(current, initial)
##   host.add_child(flight)
##   await flight.fly(from, to, 0.4).finished

var _from: Rect2 = Rect2()
var _to: Rect2 = Rect2()

func _init() -> void:
	super()
	# A MiniBoard asks for room (148 px); this one is told its size
	custom_minimum_size = Vector2.ZERO
	set_anchors_preset(Control.PRESET_TOP_LEFT)

## The rectangle it is in at `t` of its way (0 at `from`, 1 at `to`)
func place(t: float) -> void:
	global_position = _from.position.lerp(_to.position, t)
	size = _from.size.lerp(_to.size, t)

## Flies from `from` to `to` (global rectangles); the tween ends when it has arrived
func fly(from: Rect2, to: Rect2, seconds: float) -> Tween:
	_from = from
	_to = to
	place(0.0)
	var tween := create_tween()
	tween.tween_method(place, 0.0, 1.0, seconds).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	return tween
