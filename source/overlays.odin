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

Action :: enum {
	NONE,
	// ATTACK,
	MOVE,
}

HoverState :: struct {
	selection:       HighlightState,
	hover_region:    HighlightState,
	selected_action: Action,
}
