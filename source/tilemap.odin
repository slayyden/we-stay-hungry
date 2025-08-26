
// a tile has
// 1. visual type
//  same visual type => same gameplay type
// 2. state
//  - state is stored in the tile struct and depends on gameplay type
// 3. gameplay type

package game
import la "core:math/linalg"
import rl "vendor:raylib"

MAP_WIDTH :: 64
MAP_HEIGHT :: 64
MAP_WIDTH_64 :: (MAP_WIDTH + 63 / 64) * 64
MAP_HEIGHT_64 :: (MAP_HEIGHT + 63 / 64) * 64

TEXTURE_SCALE_GLOBAL :: 64

TileVisuals :: enum {
	EMPTY,
	FLOOR_DEBUG,
	WALL_DEBUG,
}

TileTypeData :: struct {
	texture:       rl.Texture2D,
	texture_scale: f32,
}

empty_tile :: distinct struct {
}
floor_tile :: distinct struct {
}
wall_tile :: distinct struct {
}

GameplayTile :: union {
	empty_tile,
	floor_tile,
	wall_tile,
}

TileLayers :: enum {
	BASE,
}

TileMap :: struct {
	// same column is contiguous
	// indexed col, row
	occupied:        [MAP_WIDTH][MAP_HEIGHT_64]u64,
	gameplay_layers: [TileLayers][MAP_WIDTH][MAP_HEIGHT]GameplayTile,
	visual_layers:   [TileLayers][MAP_WIDTH][MAP_HEIGHT]TileVisuals,
	tile_type_data:  [TileVisuals]TileTypeData,
}


get_occupancy_mask_and_index :: proc(coord: [2]u32) -> (mask: u64, index_in_array: u32) {
	index_in_array = coord.y / 64
	index_of_bit := coord.y % 64
	mask = u64(1) << index_of_bit
	return mask, index_in_array
}

tile_is_occupied :: proc(tilemap: ^TileMap, coord: [2]u32) -> bool {
	mask, index_in_array := get_occupancy_mask_and_index(coord)
	occupied := (tilemap.occupied[coord.x][index_in_array] & mask) != 0
	return occupied
}

tile_set_occupied :: proc(tilemap: ^TileMap, coord: [2]u32) {
	mask, index_in_array := get_occupancy_mask_and_index(coord)
	tilemap.occupied[coord.x][index_in_array] |= mask
}

tile_unset_occupied :: proc(tilemap: ^TileMap, coord: [2]u32) {
	mask, index_in_array := get_occupancy_mask_and_index(coord)
	tilemap.occupied[coord.x][index_in_array] &= (~mask)
}

tile_type_data :: proc(filename : cstring)  -> TileTypeData {
    texture := rl.LoadTexture(filename)
    scale := f32(TEXTURE_SCALE_GLOBAL)/f32(texture.width)
    ret := TileTypeData {
        texture = texture,
        texture_scale = scale,
    }
    return ret
}


tilemap_init :: proc(tilemap: ^TileMap) {
	tile_type_data := [TileVisuals]TileTypeData {
		.EMPTY = TileTypeData{},
		.FLOOR_DEBUG = tile_type_data("assets/test_64.png"),
		.WALL_DEBUG = tile_type_data("assets/test_128.png"),
	}
	tilemap.tile_type_data = tile_type_data
	tilemap.visual_layers[.BASE][0][0] = .FLOOR_DEBUG
	tilemap.visual_layers[.BASE][0][1] = .WALL_DEBUG
}

tilemap_draw :: proc(tilemap: ^TileMap) {
	for layer_idx in TileLayers {
		for row_idx in 0 ..< u32(MAP_WIDTH) {
			for col_idx in 0 ..< u32(MAP_HEIGHT) {
				visual := tilemap.visual_layers[layer_idx][row_idx][col_idx]
				if visual == .EMPTY do continue
				texture := tilemap.tile_type_data[visual].texture
				scale: = tilemap.tile_type_data[visual].texture_scale

				offset := [2]f32{0, 0}
				rl.DrawTextureEx(
					texture,
					la.to_f32([2]u32{col_idx * 64, row_idx * 64}) - offset,
					0,
					scale,
					rl.WHITE,
				)
			}
		}
	}
}
