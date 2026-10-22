class_name ListPager
extends RefCounted

## Builds a long list a page at a time: the first page at once, the next one when scrolling gets
## near the end. Someone with a thousand finished games gets the rows they look at instead of a
## thousand rows (about 15 nodes each) built in the background and laid out on every frame.

var scroll: ScrollContainer
var page_size: int = 20
## Rows built so far / rows in the list
var built: int = 0
var total: int = 0

var _build_row: Callable = Callable()
var _token: int = 0
var _queued: bool = false

func _init(p_scroll: ScrollContainer, p_page_size: int = 20) -> void:
	scroll = p_scroll
	page_size = p_page_size
	var bar := scroll.get_v_scroll_bar()
	# Scrolling, and the list growing or the screen resizing (both change the bar's range)
	bar.value_changed.connect(func(_v): _check())
	bar.changed.connect(_check)

## Starts a new list of `count` rows; `build_row(i)` adds row i
func start(count: int, build_row: Callable) -> void:
	_token += 1
	total = count
	built = 0
	_build_row = build_row
	_queued = false
	_add_page()

func has_more() -> bool:
	return built < total

## Adds the next page now (also used by tests)
func add_page() -> void:
	_add_page()

func _add_page() -> void:
	var end: int = mini(built + page_size, total)
	for i in range(built, end):
		_build_row.call(i)
	built = end
	# A short first page may not fill the screen; the bar's range change re-checks once laid out

func _check() -> void:
	if _queued or not has_more() or scroll == null or not scroll.is_visible_in_tree():
		return
	var bar := scroll.get_v_scroll_bar()
	var view: float = scroll.size.y
	if bar.max_value - (bar.value + bar.page) <= view * 0.5:
		# Not from inside the scroll container's layout pass
		_queued = true
		_add_queued.call_deferred(_token)

func _add_queued(token: int) -> void:
	_queued = false
	if token != _token or not has_more():
		return
	_add_page()
