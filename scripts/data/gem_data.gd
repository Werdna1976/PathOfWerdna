class_name GemData
extends Resource
## Base for all gems. Active gems (SkillGem) grant a skill; support gems
## (Milestone 4) modify the active gems they're socketed with.

enum Kind { ACTIVE, SUPPORT }

@export var id: StringName
@export var display_name: String
## Shown on the skill bar.
@export var short_name: String
@export_multiline var description: String
@export var tags: Array[StringName] = []


func kind() -> Kind:
	return Kind.ACTIVE
