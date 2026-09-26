class_name PotionData
extends Resource
## A rechargeable potion. Drinking spends charges and restores `amount` over
## `duration`; drinking again while active restarts the duration.

enum Restores { LIFE, MANA }

@export var display_name: String
@export var restores: Restores = Restores.LIFE
@export var amount: float = 50.0
@export var duration: float = 1.0
@export var max_charges: float = 30.0
@export var charges_per_use: float = 10.0
@export var color: Color = Color(0.7, 0.1, 0.1)
