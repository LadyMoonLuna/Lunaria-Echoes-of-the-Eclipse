# NPC.gd — Script de compatibilidade herdando diretamente de NPCEntity
extends "res://scripts/NPCEntity.gd"

func set_npc_info(p_npc_id: int, p_npc_name: String, p_script_path: String = "") -> void:
	super.set_npc_info(p_npc_id, p_npc_name, p_script_path)
