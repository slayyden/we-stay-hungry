package game

import "base:intrinsics"
import sa "core:container/small_array"
import rl "vendor:raylib"
EntityHandle :: distinct u32
AnimationHandle :: distinct u32
ENTITY_HANDLE_INVALID :: EntityHandle(~u32(0))
PLAYER_SPEED :: 3

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
	animation_database.die_yaki_animations[.IDLE] = animation_data_new(
		"assets/die_yaki_idle.png",
		4,
		5,
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

MoveTile :: struct {
	pos:      [2]u32, // index in tilemap
	distance: u8,
	prev:     u8, // pointer in move_tile array
}

/*
00 00 00 XX 00 00 00
00 00 XX XX XX 00 00
00 XX XX XX XX XX 00
XX XX XX XX XX XX XX
00 XX XX XX XX XX 00
00 00 XX XX XX 00 00
00 00 00 XX 00 00 00
*/

MAX_MOVE_TILES :: 4 * ((PLAYER_SPEED * (PLAYER_SPEED + 1)) / 2) + 1
// frontier can extend 1 further than the move span
MAX_FRONTIER_COVERAGE :: 4 * (((PLAYER_SPEED + 1) * (PLAYER_SPEED + 2)) / 2) + 1
// get the perimeter by subtracting the bigger footprint from the smaller one
MAX_FRONTIER_SIZE :: MAX_FRONTIER_COVERAGE - MAX_MOVE_TILES


MoveTiles :: sa.Small_Array(MAX_MOVE_TILES, MoveTile)


TileNeighbors :: sa.Small_Array(4, [2]u32)

get_in_bounds_neighbors :: proc(source: [2]u32) -> (neighbors: TileNeighbors) {
	if source.x > 0_____________ do sa.append(&neighbors, source - [2]u32{1, 0}) // left valid
	if source.x + 1_ < MAP_WIDTH do sa.append(&neighbors, source + [2]u32{1, 0}) // right valid
	if source.y > 0_____________ do sa.append(&neighbors, source - [2]u32{0, 1}) // top valid
	if source.y + 1 < MAP_HEIGHT do sa.append(&neighbors, source + [2]u32{0, 1}) // neighbor valid
	return
}

remove_occupied_neighbors_in_place :: proc(neighbors: ^TileNeighbors, tilemap: ^TileMap) {
	for i := 0; i < sa.len(neighbors^); {
		if tile_is_occupied(tilemap, sa.get(neighbors^, i)) {
			sa.unordered_remove(neighbors, i)
		} else {
			// removing puts the last element in neighbors[i]
			// to check the former last element, we don't want to advance i
			// if we've removed an element
			i += 1
		}
	}
}

get_attack_tiles :: #force_inline proc(
	source: [2]u32,
	tilemap: ^TileMap,
) -> (
	TileNeighbors,
	TileNeighbors,
) {
	neighbors := get_in_bounds_neighbors(source)
	attack_tiles: TileNeighbors
	for neighbor in sa.slice(&neighbors) {
		if !tile_is_occupied(tilemap, neighbor) do continue
		sa.push_back(&attack_tiles, neighbor)
	}
	return neighbors, attack_tiles
}

get_move_tiles :: proc(move_tiles: ^MoveTiles, tilemap: ^TileMap) {
	// reset everything
	sa.clear(move_tiles)
	initial_position := get_base_entity_from_union(sa.get_ptr(&g.entities, int(g.player))).pos
	initial_tile := MoveTile {
		pos      = initial_position,
		distance = 0,
		prev     = ~u8(0),
	}
	frontier: sa.Small_Array(MAX_FRONTIER_SIZE, MoveTile)

	assert(sa.append_elem(&frontier, initial_tile))
	for sa.len(frontier) > 0 {
		// pop min
		curr := sa.get(frontier, 0)
		min_idx := 0
		for elem, i in sa.slice(&frontier)[1:] {
			if elem.distance < curr.distance {
				curr = elem
				min_idx = i + 1
			}
		}
		// we do not care about further paths
		if curr.distance > PLAYER_SPEED do break

		// now curr is the element with minimum distance
		// we do not want to visit curr again
		sa.unordered_remove(&frontier, min_idx)

		// insert curr into the finalized list
		curr_insertion_idx := u8(sa.len(move_tiles^))
		assert(sa.append(move_tiles, curr))

		// find valid neighbors
		neighbors := get_in_bounds_neighbors(curr.pos)
		remove_occupied_neighbors_in_place(&neighbors, tilemap)

		// remove finalized neighbors (in place filter)
		for tile in sa.slice(move_tiles) {
			for i := 0; i < sa.len(neighbors); i += 1 {
				if sa.get(neighbors, i) == tile.pos {
					sa.unordered_remove(&neighbors, i)
					break // neighbors aren't duplicated so we can stop early
				}
			}
		}

		// update neighbors that are in the frontier
		// or add them if they're not there
		for neighbor in sa.slice(&neighbors) {
			distance := curr.distance + 1

			// replacement element
			new_elem := MoveTile {
				pos      = neighbor,
				distance = distance,
				prev     = curr_insertion_idx,
			}

			// is the neighbor already in the frontier?
			// if so update it if it's better
			neighbor_in_frontier := false
			for &elem in sa.slice(&frontier) {
				if elem.pos == neighbor {
					neighbor_in_frontier = true
					if distance < elem.distance do elem = new_elem
					break
				}
			}

			// otherwise, append it to the frontier
			if !neighbor_in_frontier {
				sa.append(&frontier, new_elem)
			}
		}
	}
}

manhattan_distance_u32 :: proc(x: u32, y: u32) -> u32 {
	return max(x, y) - min(x, y)
}

manhattan_distance_u32_array :: proc(x: [$N]u32, y: [N]u32) -> u32 {
	sum: u32 = 0
	for i in 0 ..< N {
		sum += manhattan_distance_u32(x[i], y[i])
	}
	return sum
}

DIE_YAKI_RANGE :: PLAYER_SPEED * 2
DIE_YAKI_SEARCH_RANGE :: 16

ASTAR_SET_SIZE :: 4 * ((DIE_YAKI_SEARCH_RANGE * (DIE_YAKI_SEARCH_RANGE + 1)) / 2) + 1

import "core:fmt"
OpenSet :: sa.Small_Array(ASTAR_SET_SIZE, PathFindTile)
FinalSet :: sa.Small_Array(ASTAR_SET_SIZE, PathFindTile)
getNextTile :: #force_inline proc(
	start: [2]u32,
	final_set: FinalSet,
	goal: PathFindTile,
) -> [2]u32 {
	curr := goal
	for distance_to_player := 0; distance_to_player < DIE_YAKI_RANGE; distance_to_player += 1 {
		fmt.println("curr:", curr)
		curr = sa.get(final_set, int(curr.prev))
	}
	return curr.pos
}

PathFindTile :: struct {
	pos:     [2]u32, // index in tilemap
	g_score: u32,
	f_score: u32,
	prev:    u16, // pointer in move_tile array
}

aStar :: proc(start: [2]u32, goal: [2]u32, tilemap: ^TileMap) -> ([2]u32, bool) {
	fmt.println("astar set size:", ASTAR_SET_SIZE)
	assert(start != goal)
	// The set of discovered nodes that may need to be (re-)expanded.
	// Initially, only the start node is known.
	open_set: OpenSet
	final_set: FinalSet

	// For node n, cameFrom[n] is the node immediately preceding it on the cheapest path from the start
	// For node n, gScore[n] is the currently known cost of the cheapest path from start to n.
	// For node n, fScore[n] := gScore[n] + h(n). fScore[n] represents our current best guess as to
	// how cheap a path could be from start to finish if it goes through n.
	sa.append(
		&open_set,
		PathFindTile {
			pos = start,
			g_score = 0,
			f_score = manhattan_distance_u32_array(start, goal),
			prev = 255,
		},
	)

	for sa.len(open_set) > 0 {
		// This operation can occur in O(Log(N)) time if openSet is a min-heap or a priority queue
		// current := the node in openSet having the lowest fScore[] value
		curr := sa.get(open_set, 0)
		min := curr.f_score
		index_in_openSet := 0
		for open_elem, i in sa.slice(&open_set)[1:] {
			if open_elem.f_score < min {
				min = open_elem.f_score
				curr = open_elem
				index_in_openSet = i + 1 // we start on the 2nd element
			}
		}


		// we found the end
		if curr.pos == goal do return getNextTile(start, final_set, curr), true

		sa.unordered_remove(&open_set, index_in_openSet)

		// too far, terminate the search
		if curr.g_score > DIE_YAKI_SEARCH_RANGE do continue

		// update curr in final set if needed
		curr_in_finalset := false
		curr_insertion_idx := u16(sa.len(final_set))
		for &elem, i in sa.slice(&final_set) {
			if elem.pos == curr.pos {
				curr_in_finalset = true
				elem = curr
				curr_insertion_idx = u16(i)
			}
		}
		// otherwise, add curr to final set
		if !curr_in_finalset do assert(sa.push_back(&final_set, curr))

		// find valid neighbors
		neighbors := get_in_bounds_neighbors(curr.pos)
		// remove_occupied_neighbors_in_place(&neighbors, tilemap)
		d :: 1
		for neighbor in sa.slice(&neighbors) {
			tentative_gscore := curr.g_score + d

			new_elem := PathFindTile {
				pos     = neighbor,
				g_score = tentative_gscore,
				f_score = tentative_gscore + manhattan_distance_u32_array(neighbor, goal),
				prev    = curr_insertion_idx,
			}
			neighbor_in_openset := false
			for &elem in sa.slice(&open_set) {
				if elem.pos == neighbor {
					neighbor_in_openset = true
					if tentative_gscore < elem.g_score do elem = new_elem
					break
				}
			}
			if !neighbor_in_openset do assert(sa.push_back(&open_set, new_elem))
		}
	}

	// Open set is empty but goal was never reached
	return [2]u32{U32_MAX, U32_MAX}, false
}
