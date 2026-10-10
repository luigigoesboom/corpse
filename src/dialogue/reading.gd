class_name Reading
extends RefCounted
## A mural or tablet being read (week 35), for data/dialogue/reading.dialogue:
## a title and a few pages, one per balloon line.

var title := ""
var pages: Array = []


func _init(title_text: String, text: String) -> void:
	title = title_text
	pages = Array(text.split("\n", false))


var count: int:
	get: return pages.size()


func page(i: int) -> String:
	return pages[i] if i < pages.size() else ""
