class_name Grid
extends RefCounted

const TILE_SIZE: int = 16
const HALF_TILE: float = 8.0
const ROOM_TILES_WIDTH: int = 30
const ROOM_TILES_HEIGHT: int = 15
const ROOM_PIXEL_WIDTH: int = 480
const ROOM_PIXEL_HEIGHT: int = 240
const HUD_HEIGHT: int = 30

static func tile_to_pixel(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * TILE_SIZE + HALF_TILE, cell.y * TILE_SIZE + HALF_TILE)

static func pixel_to_tile(pixel: Vector2) -> Vector2i:
	return Vector2i(int(floor(pixel.x / TILE_SIZE)), int(floor(pixel.y / TILE_SIZE)))

static func is_in_room_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < ROOM_TILES_WIDTH and cell.y >= 0 and cell.y < ROOM_TILES_HEIGHT
