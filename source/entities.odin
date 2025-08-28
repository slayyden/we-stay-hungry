package game

import "base:intrinsics"
import sa "core:container/small_array"
// import "core:fmt"
import rl "vendor:raylib"

EntityHandle :: distinct u32
AnimationHandle :: distinct u32
ENTITY_HANDLE_INVALID :: EntityHandle(~u32(0))


EntityBase :: struct {
	pos:             [2]u32,
	health:          i32,
	animation_state: AnimationState,
}

AnimationState :: struct {
	animation:      EntityAnim,
	frame:          u32,
	seconds_played: f32,
	loop:           bool,
}

PlayerAnim :: enum {
	IDLE,
	WALKING,
	ATTACK,
}

EntityAnim :: struct #raw_union {
	player_anim:   PlayerAnim,
	die_yaki_anim: DieYakiAnim,
}

AnimationData :: struct {
	texture:    rl.Texture2D,
	scale:      f32,
	num_frames: u32,
	frame_rate: u32,
}

animation_data_new :: proc(filename: cstring, num_frames: u32, frame_rate: u32) -> AnimationData {
	texture := rl.LoadTexture(filename)
	scale := f32(TEXTURE_SCALE_GLOBAL) / f32(texture.height)
	assert(rl.IsTextureValid(texture))
	ret := AnimationData {
		texture    = texture,
		scale      = scale,
		num_frames = num_frames,
		frame_rate = frame_rate,
	}
	return ret
}

// fuck you *exchanges increased binary size due to monomorphization for type safety*
get_base_entity :: #force_inline proc(
	entity: ^$T,
) -> ^EntityBase where intrinsics.type_has_field(T, "entity_base"),
	intrinsics.type_field_type(T, "entity_base") ==
	EntityBase {
	return &(entity.entity_base)
}

get_base_entity_from_union :: #force_inline proc(entity: ^AnyEntity) -> ^EntityBase {
	switch &e in entity {
	case PlayerChar:
		return get_base_entity(&e)
	case DieYaki:
		return get_base_entity(&e)

	}
	assert(false)
	return nil
}

get_animation :: proc(entity: ^AnyEntity) -> (AnimationData, ^AnimationState) {
	entity_base := get_base_entity_from_union(entity)
	animation_state := &entity_base.animation_state
	animation: AnimationData
	switch &e in entity {
	case PlayerChar:
		animation = g.animation_database.player_animations[animation_state.animation.player_anim]
	case DieYaki:
		animation =
			g.animation_database.die_yaki_animations[animation_state.animation.die_yaki_anim]
	}
	return animation, animation_state
}

PlayerChar :: struct {
	using entity_base: EntityBase,
}

AnimationDatabase :: struct {
	player_animations:   [PlayerAnim]AnimationData,
	die_yaki_animations: [DieYakiAnim]AnimationData,
}

animation_database_init :: proc(animation_database: ^AnimationDatabase) {
	animation_database.player_animations[.IDLE] = animation_data_new(
		"assets/player_idle.png",
		4,
		6,
	)
	animation_database.player_animations[.ATTACK] = animation_data_new(
		"assets/player_attack.png",
		24,
		12,
	)
}

DieYakiAnim :: enum {
	IDLE,
	ATTACK,
	MOVE,
}


DieYaki :: struct {
	using entity_base: EntityBase,
}

Enemy2 :: struct {
	using entity_base: EntityBase,
}

AnyEntity :: union {
	PlayerChar,
	DieYaki,
}

// caller is expected to ensure `dest` is unoccupied
entity_move :: proc(entity: ^EntityBase, tilemap: ^TileMap, dest: [2]u32) {
	assert(tile_is_occupied(tilemap, entity.pos))
	assert(!tile_is_occupied(tilemap, dest))

	tile_unset_occupied(tilemap, entity.pos)
	entity.pos = dest
	tile_set_occupied(tilemap, dest)
}
entity_update_animation :: proc(entity: ^AnyEntity, frame_time_seconds: f32) {
	animation_data, animation_state := get_animation(entity)
	frame_index := u32(animation_state.seconds_played * f32(animation_data.frame_rate))
	if animation_state.loop {
		frame_index %= animation_data.num_frames
	} else if (animation_state.frame > animation_data.num_frames) {
		animation_state.animation = EntityAnim{} // idle animation
		animation_state.loop = true
	}
	animation_state.frame = frame_index
	animation_state.seconds_played += frame_time_seconds
}

draw_entities :: proc(
	entities: ^sa.Small_Array(MAX_ENTITIES, AnyEntity),
	frame_time_seconds: f32,
) {
	for &entity in sa.slice(entities) {
		entity_base := get_base_entity_from_union(&entity)
		animation_data, animation_state := get_animation(&entity)
		texture := animation_data.texture
		frame_width := f32(texture.width) / f32(animation_data.num_frames)
		// fmt.println(animation_data.num_frames)
		source_rec := rl.Rectangle {
			x      = frame_width * f32(animation_state.frame),
			y      = 0,
			width  = f32(texture.width) / 4.0,
			height = f32(texture.height),
		}
		dest_rect := rl.Rectangle {
			x      = TEXTURE_SCALE_GLOBAL * f32(entity_base.pos.x),
			y      = TEXTURE_SCALE_GLOBAL * f32(entity_base.pos.y),
			width  = TEXTURE_SCALE_GLOBAL,
			height = TEXTURE_SCALE_GLOBAL,
		}

		rl.DrawTexturePro(texture, source_rec, dest_rect, rl.Vector2{0, 0}, 0.0, rl.WHITE) // Draw a part of a texture defined by a rectangle with 'pro' parameters
	}
}
