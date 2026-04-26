extends Node
class_name ScoreDatabase

const ENEMY_KILL_POINTS := {
	"type_1": 100,
	"type_2": 250,
	"type_3": 500
}

const PLANET_RELEASE_POINTS := {
	"LandMasses": 150,
	"IceWorld": 175,
	"LavaWorld": 225,
	"GasGiant": 300,
	"NoAtmosphere": 80
}

const PLANET_LOST_PENALTY := {
	"LandMasses": -100,
	"IceWorld": -125,
	"LavaWorld": -175,
	"GasGiant": -250,
	"NoAtmosphere": -60
}


static func get_enemy_kill_points(enemy_type: String) -> int:
	return ENEMY_KILL_POINTS.get(enemy_type, 50)


static func get_planet_release_points(planet_type: String) -> int:
	return PLANET_RELEASE_POINTS.get(planet_type, 100)


static func get_planet_lost_points(planet_type: String) -> int:
	return PLANET_LOST_PENALTY.get(planet_type, -50)
