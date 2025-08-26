package game

EntityHandle :: distinct u32

EntityBase :: struct {
	pos:    [2]u32,
	health: i32,
}

PlayerChar :: struct {
	using entity: EntityBase,
}

Enemy1 :: struct {
	using entity: EntityBase,
}

Enemy2 :: struct {
	using entity: EntityBase,
}


EntityAny :: union {
	PlayerChar,
	Enemy1,
	Enemy2,
}

// caller is expected to ensure `dest` is unoccupied
entity_move :: proc(entity: ^EntityBase, tilemap: ^TileMap, dest: [2]u32) {
	assert(tile_is_occupied(tilemap, entity.pos))
	assert(!tile_is_occupied(tilemap, dest))

	tile_unset_occupied(tilemap, entity.pos)
	entity.pos = dest
	tile_set_occupied(tilemap, dest)
}
