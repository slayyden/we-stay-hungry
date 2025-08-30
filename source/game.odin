/*
This file is the starting point of your game.

Some important procedures are:
- game_init_window: Opens the window
- game_init: Sets up the game state
- game_update: Run once per frame
- game_should_close: For stopping your game when close button is pressed
- game_shutdown: Shuts down game and frees memory
- game_shutdown_window: Closes window

The procs above are used regardless if you compile using the `build_release`
script or the `build_hot_reload` script. However, in the hot reload case, the
contents of this file is compiled as part of `build/hot_reload/game.dll` (or
.dylib/.so on mac/linux). In the hot reload cases some other procedures are
also used in order to facilitate the hot reload functionality:

- game_memory: Run just before a hot reload. That way game_hot_reload.exe has a
	pointer to the game's memory that it can hand to the new game DLL.
- game_hot_reloaded: Run after a hot reload so that the `g` global
	variable can be set to whatever pointer it was in the old DLL.

NOTE: When compiled as part of `build_release`, `build_debug` or `build_web`
then this whole package is just treated as a normal Odin package. No DLL is
created.
*/

package game

import clay "../lib/clay-odin"
import sa "core:container/small_array"
import "core:fmt"
import la "core:math/linalg"
import rl "vendor:raylib"

PIXEL_WINDOW_HEIGHT :: 180
MAX_ENTITIES :: 16
WINDOW_WIDTH_INIT :: 1280
WINDOW_HEIGHT_INIT :: 720

// from https://github.com/nicbarker/clay/issues/420
// enough for 64 elements
CLAY_MEMORY_SIZE :: 53504

Game_Memory :: struct {
	// stuff that's on the map
	tilemap:              TileMap,
	entities:             sa.Small_Array(MAX_ENTITIES, AnyEntity), // sparse array
	animation_database:   AnimationDatabase,
	frame_time:           f32,
	camera_pos:           rl.Vector2,
	player_texture:       rl.Texture,
	some_number:          int,
	run:                  bool,

	// important entities
	player:               EntityHandle,

	// turn ordering
	round:                u32,
	turn:                 u32,
	is_player_turn:       bool,

	// hover state
	hover_state:          HoverState,

	// overlays
	entity_select:        TileTypeData,
	clay_arena:           clay.Arena,
	clay_memory:          [^]u8,
	attack_menu:          Maybe(FloatingMenuState),
	attack_menu_commands: clay.ClayArray(clay.RenderCommand),
}


@(export)
game_init :: proc() {
	g = new(Game_Memory)

	g^ = Game_Memory {
		run = true,
		some_number = 100,
		player_texture = rl.LoadTexture("assets/round_cat.png"),
		hover_state = HoverState {
			selection = HIGHLIGHT_STATE_INVALID,
			hover_region = HIGHLIGHT_STATE_INVALID,
			selected_action = .NONE,
		},
		player = 0,
	}

	tilemap_init(&g.tilemap)
	animation_database_init(&g.animation_database)
	sa.append(
		&g.entities,
		PlayerChar{pos = {1, 0}, health = 10, animation_state = AnimationState{loop = true}},
	)

	for &entity in sa.slice(&g.entities) {
		entity_base := get_base_entity_from_union(&entity)
		tile_set_occupied(&g.tilemap, entity_base.pos)
	}

	g.entity_select = tile_type_data("assets/tile_select.png")


	game_hot_reloaded(g)
}

g: ^Game_Memory
game_camera :: proc() -> rl.Camera2D {
	w := f32(rl.GetScreenWidth())
	h := f32(rl.GetScreenHeight())

	return {zoom = h / PIXEL_WINDOW_HEIGHT, target = g.camera_pos, offset = {w / 2, h / 2}}
}

ui_camera :: proc() -> rl.Camera2D {
	return {zoom = f32(rl.GetScreenHeight()) / PIXEL_WINDOW_HEIGHT}
}

update :: proc() {
	frame_time := rl.GetFrameTime()
	g.frame_time = frame_time
	input: rl.Vector2

	// rl.UpdateMusicStream()

	if rl.IsKeyDown(.UP) || rl.IsKeyDown(.W) {
		input.y -= 1
	}
	if rl.IsKeyDown(.DOWN) || rl.IsKeyDown(.S) {
		input.y += 1
	}
	if rl.IsKeyDown(.LEFT) || rl.IsKeyDown(.A) {
		input.x -= 1
	}
	if rl.IsKeyDown(.RIGHT) || rl.IsKeyDown(.D) {
		input.x += 1
	}
	if rl.IsKeyDown(.Q) {
		arr: [2][2]int

		fmt.println("0, 0:", &(arr[0][0]))
		fmt.println("0, 1:", &(arr[0][1]))
		fmt.println("1, 0:", &(arr[1][0]))
		fmt.println("1, 1:", &(arr[1][1]))
	}

	input = la.normalize0(input)
	g.camera_pos += input * frame_time * 100
	g.some_number += 1

	// ---------------------------------------------------------------------------
	// tile hovering
	mouse_position_screen: [2]f32 = {f32(rl.GetMouseX()), f32(rl.GetMouseY())}
	mouse_position_texel := rl.GetScreenToWorld2D(mouse_position_screen, game_camera())
	mouse_position_world := mouse_position_texel / TEXTURE_SCALE_GLOBAL

	if mouse_position_world.x >= 0 &&
	   mouse_position_world.y >= 0 &&
	   mouse_position_world.x < MAP_WIDTH &&
	   mouse_position_world.y < MAP_HEIGHT {

		hover_tile := la.to_u32(mouse_position_world)
		g.hover_state.hover_region.tile = hover_tile
		occupied := tile_is_occupied(&g.tilemap, hover_tile)
		if occupied {
			g.hover_state.hover_region.entity = ENTITY_HANDLE_INVALID
			for i in 0 ..< sa.len(g.entities) {
				entity := sa.get_ptr(&g.entities, i)
				base_entity := get_base_entity_from_union(entity)
				if base_entity.pos == hover_tile {
					g.hover_state.hover_region.entity = EntityHandle(i)
					break
				}
			}
		}
		if rl.IsMouseButtonPressed(.LEFT) {
			g.hover_state.selection =
				g.hover_state.hover_region if occupied else HIGHLIGHT_STATE_INVALID
			if occupied && g.hover_state.hover_region.entity == g.player {
				g.attack_menu = FloatingMenuState(rl.GetMousePosition())
			} else {
				g.attack_menu = nil
			}
		}
	}

	if attack_menu, ok := g.attack_menu.?; ok {
		g.attack_menu_commands = action_menu_layout_new(attack_menu)
	}


	for &entity in sa.slice(&g.entities) {
		entity_update_animation(&entity, frame_time)
	}

	if rl.IsKeyPressed(.ESCAPE) {
		g.run = false
	}
}

draw :: proc() {
	rl.BeginDrawing()
	rl.ClearBackground(rl.BLUE)

	rl.BeginMode2D(game_camera())
	tilemap_draw(&g.tilemap)
	draw_entities(&g.entities, g.frame_time)
	highlight_tile := g.hover_state.hover_region.tile
	if tile_in_bounds(highlight_tile) {
		rl.DrawRectangle(
			i32(highlight_tile.x) * TEXTURE_SCALE_GLOBAL,
			i32(highlight_tile.y) * TEXTURE_SCALE_GLOBAL,
			TEXTURE_SCALE_GLOBAL,
			TEXTURE_SCALE_GLOBAL,
			rl.Color{255, 255, 255, 25},
		)
	}
	if g.hover_state.selection.entity != ENTITY_HANDLE_INVALID {
		draw_tile(g.entity_select, g.hover_state.selection.tile)
	}
	rl.EndMode2D()

	rl.BeginMode2D(ui_camera())

	// NOTE: `fmt.ctprintf` uses the temp allocator. The temp allocator is
	// cleared at the end of the frame by the main application, meaning inside
	// `main_hot_reload.odin`, `main_release.odin` or `main_web_entry.odin`.
	rl.DrawText(
		fmt.ctprintf("some_number: %v\nplayer_pos: %v", g.some_number, g.camera_pos),
		5,
		5,
		8,
		rl.WHITE,
	)

	rl.EndMode2D()

	rl.EndDrawing()
}

@(export)
game_update :: proc() {
	update()
	draw()

	// Everything on tracking allocator is valid until end-of-frame.
	free_all(context.temp_allocator)
}

@(export)
game_init_window :: proc() {
	rl.SetConfigFlags({.WINDOW_RESIZABLE, .VSYNC_HINT})
	rl.InitWindow(WINDOW_WIDTH_INIT, WINDOW_HEIGHT_INIT, "Odin + Raylib + Hot Reload template!")
	rl.SetWindowPosition(200, 200)
	rl.SetTargetFPS(60)
	rl.SetExitKey(nil)
}


@(export)
game_should_run :: proc() -> bool {
	when ODIN_OS != .JS {
		// Never run this proc in browser. It contains a 16 ms sleep on web!
		if rl.WindowShouldClose() {
			return false
		}
	}

	return g.run
}

@(export)
game_shutdown :: proc() {
	free(g.clay_memory)
	free(g)
}

@(export)
game_shutdown_window :: proc() {
	rl.CloseWindow()
}

@(export)
game_memory :: proc() -> rawptr {
	return g
}

@(export)
game_memory_size :: proc() -> int {
	return size_of(Game_Memory)
}

@(export)
game_hot_reloaded :: proc(mem: rawptr) {
	g = (^Game_Memory)(mem)

	// Here you can also set your own global variables. A good idea is to make
	// your global variables into pointers that point to something inside `g`.
	//
	// initialize clay
	clay.SetMaxElementCount(128)
	min_memory_size := clay.MinMemorySize()
	fmt.println("min_memory_size:", min_memory_size)
	g.clay_memory = make([^]u8, min_memory_size)
	arena: clay.Arena = clay.CreateArenaWithCapacityAndMemory(uint(min_memory_size), g.clay_memory)
	clay.Initialize(arena, {1080, 720}, {handler = error_handler})
}

@(export)
game_force_reload :: proc() -> bool {
	return rl.IsKeyPressed(.F5)
}

@(export)
game_force_restart :: proc() -> bool {
	return rl.IsKeyPressed(.F6)
}

// In a web build, this is called when browser changes size. Remove the
// `rl.SetWindowSize` call if you don't want a resizable game.
game_parent_window_size_changed :: proc(w, h: int) {
	rl.SetWindowSize(i32(w), i32(h))
}
