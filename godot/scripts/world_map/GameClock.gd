class_name GameClock
extends Node

signal month_passed
signal year_passed

var time_tick: float = 0.0
var tick_count: int = 0
var current_month: int = 0
var current_year: int = 190

const TICK_INTERVAL: float = 0.5
const TICKS_PER_MONTH: int = 10
const MONTHS_PER_YEAR: int = 12

var is_running: bool = true

func _process(delta):
	if not is_running:
		return

	time_tick += delta
	if time_tick >= TICK_INTERVAL:
		time_tick = 0.0
		tick_count += 1

		if tick_count >= TICKS_PER_MONTH:
			tick_count = 0
			current_month += 1
			if current_month >= MONTHS_PER_YEAR:
				current_month = 0
				current_year += 1
				year_passed.emit()
			month_passed.emit()

func get_date_string() -> String:
	return str(current_year) + "年 " + str(current_month + 1) + "月"

func reset():
	time_tick = 0.0
	tick_count = 0
	current_month = 0
