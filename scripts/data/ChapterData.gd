extends Resource

class_name ChapterData

@export var chapter_id: StringName
@export_range(1, 99, 1) var chapter_number: int = 1
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var preview_image: Texture2D
@export var stages: Array[StageData] = []
@export var prerequisite_chapter_ids: Array[StringName] = []
@export var is_currently_available: bool = false


func is_valid() -> bool:
	if chapter_id.is_empty() or display_name.is_empty() or stages.is_empty():
		return false
	for stage in stages:
		if stage == null or not stage.is_valid() or stage.chapter_id != chapter_id:
			return false
	return true
