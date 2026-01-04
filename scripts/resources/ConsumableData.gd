extends "res://scripts/resources/ItemData.gd"
class_name ConsumableData

enum EffectType { HEAL, STRESS_RELIEF, DAMAGE, BUFF, ABILITY }

@export var effect_type: EffectType = EffectType.HEAL
@export var value: int = 0  # HP Amount, Stress Amount, Damage Amount
@export var range_tiles: int = 0  # 0 = Self/Touch, >0 = Throw
@export var radius: float = 0.0  # 0 = Single Target, >0 = AoE
@export var vfx_path: String = ""  # Path to VFX scene for impact
@export var ability_ref: Script = null  # Optional: Ref to an Ability script (e.g. GrenadeToss) used for targeting/execution logic.

@export var consume_on_use: bool = true
