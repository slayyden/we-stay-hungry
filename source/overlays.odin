package game


U32_MAX :: ~u32(0)

HighlightState :: struct {
	tile:   [2]u32, // may be OOB
	entity: EntityHandle, // may be U32_MAX
}

HIGHLIGHT_STATE_INVALID :: HighlightState {
	tile   = {U32_MAX, U32_MAX},
	entity = ENTITY_HANDLE_INVALID,
}

tile_in_bounds :: proc(tile: [2]u32) -> bool {
	return tile.x < MAP_WIDTH && tile.y < MAP_HEIGHT
}

Action :: enum {
	NONE,
	MOVE,
	ATTACK,
}

MenuHover :: distinct struct {
}
HoverRegionInvalid :: distinct struct {
}

HoverState :: struct {
	selection:       HighlightState,
	hover_region:    union {
		struct {
		},
		MenuHover,
		HighlightState,
	},
	selected_action: Action,
}
