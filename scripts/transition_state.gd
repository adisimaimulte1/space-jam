extends Node

# main screen snapshot
var menu_camera_time := 0.0
var menu_zoom_point := Vector2(0.5, 0.5)

var menu_stars_position := Vector2.ZERO
var menu_planets_position := Vector2.ZERO
var menu_nebula_position := Vector2.ZERO

var menu_stars_scale := Vector2.ONE
var menu_planets_scale := Vector2.ONE
var menu_nebula_alpha := 1.0

var menu_logo_alpha := 1.0
var menu_text_alpha := 1.0
var menu_logo_position := Vector2.ZERO
var menu_text_position := Vector2.ZERO

var menu_stars_texture_path := ""
var menu_planets_texture_path := ""
var menu_nebula_texture_path := ""

# selected game assets/state
var game_star_texture_path := ""

# selected game stars grid state
var selected_game_star_tile_row := -1
var selected_game_star_tile_col := -1
var selected_game_star_tile_center_local := Vector2.ZERO
var selected_game_star_texture_path := ""
var selected_game_star_grid_paths: Array[String] = []

var game_camera_time := 0.0
var game_star_start_position := Vector2.ZERO
