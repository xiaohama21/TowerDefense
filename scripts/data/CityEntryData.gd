extends Resource
class_name CityEntryData

@export var entry_id: StringName
@export var display_name: String
@export var action: String
@export_multiline var description: String
@export_multiline var introduction: String
@export var prerequisite_stage: StringName
@export var implemented := true
@export var building := true
@export var position := Vector2.ZERO
