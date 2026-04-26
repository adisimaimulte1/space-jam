extends RefCounted
class_name PlanetData

const DEFAULT_MIN_SIZE := 420.0
const DEFAULT_MAX_SIZE := 460.0

static func get_planet_scenes() -> Dictionary:
	return {
		"BlackHole": preload("res://scenes/entities/planets/catalog/BlackHole/BlackHole.tscn"),
		"DryTerran": preload("res://scenes/entities/planets/catalog/DryTerran/DryTerran.tscn"),
		"Galaxy": preload("res://scenes/entities/planets/catalog/Galaxy/Galaxy.tscn"),
		"GasPlanet": preload("res://scenes/entities/planets/catalog/GasPlanet/GasPlanet.tscn"),
		"GasPlanetLayers": preload("res://scenes/entities/planets/catalog/GasPlanetLayers/GasPlanetLayers.tscn"),
		"IceWorld": preload("res://scenes/entities/planets/catalog/IceWorld/IceWorld.tscn"),
		"LandMasses": preload("res://scenes/entities/planets/catalog/LandMasses/LandMasses.tscn"),
		"LavaWorld": preload("res://scenes/entities/planets/catalog/LavaWorld/LavaWorld.tscn"),
		"NoAtmosphere": preload("res://scenes/entities/planets/catalog/NoAtmosphere/NoAtmosphere.tscn"),
		"Rivers": preload("res://scenes/entities/planets/catalog/Rivers/Rivers.tscn"),
		"Star": preload("res://scenes/entities/planets/catalog/Star/Star.tscn")
	}

static func get_planet_type_names() -> Array[String]:
	return [
		"BlackHole",
		"DryTerran",
		"Galaxy",
		"GasPlanet",
		"GasPlanetLayers",
		"IceWorld",
		"LandMasses",
		"LavaWorld",
		"NoAtmosphere",
		"Rivers",
		"Star"
	]

static func get_starter_planet_type_names() -> Array[String]:
	return [
		"LandMasses",
		"Rivers"
	]

static func get_type_config(type_name: String) -> Dictionary:
	var configs := {
		"BlackHole": {
			"min_size": 1400.0,
			"max_size": 1600.0,
			"pixels_min": 76,
			"pixels_max": 92,
			"light_min": 0.45,
			"light_max": 0.55,
			"rotates": true,
			"effect_type": "gravity_pull",
			"influence_radius": 700.0,
			"pull_strength": 900.0,
			"dangerous": true
		},
		"DryTerran": {
			"min_size": 250.0,
			"max_size": 350.0,
			"pixels_min": 58,
			"pixels_max": 72,
			"light_min": 0.40,
			"light_max": 0.60,
			"rotates": true,
			"effect_type": "dust_field",
			"influence_radius": 520.0,
			"accuracy_reduction": 0.15
		},
		"Galaxy": {
			"min_size": 1500.0,
			"max_size": 1900.0,
			"pixels_min": 228,
			"pixels_max": 284,
			"light_min": 0.48,
			"light_max": 0.52,
			"rotates": true,
			"effect_type": "anomaly_field",
			"influence_radius": 760.0,
			"anomaly_strength": 1.0
		},
		"GasPlanet": {
			"min_size": 350.0,
			"max_size": 450.0,
			"pixels_min": 72,
			"pixels_max": 88,
			"light_min": 0.42,
			"light_max": 0.58,
			"rotates": true,
			"effect_type": "wind_current",
			"influence_radius": 640.0,
			"flow_strength": 280.0
		},
		"GasPlanetLayers": {
			"min_size": 850.0,
			"max_size": 950.0,
			"pixels_min": 74,
			"pixels_max": 90,
			"light_min": 0.42,
			"light_max": 0.58,
			"rotates": true,
			"effect_type": "storm_bands",
			"influence_radius": 700.0,
			"flow_strength": 360.0
		},
		"IceWorld": {
			"min_size": 250.0,
			"max_size": 350.0,
			"pixels_min": 58,
			"pixels_max": 74,
			"light_min": 0.40,
			"light_max": 0.60,
			"rotates": true,
			"effect_type": "slow_field",
			"influence_radius": 560.0,
			"slow_outer": 0.10,
			"slow_inner": 0.20
		},
		"LandMasses": {
			"min_size": 280.0,
			"max_size": 360.0,
			"pixels_min": 60,
			"pixels_max": 78,
			"light_min": 0.40,
			"light_max": 0.60,
			"rotates": true,
			"effect_type": "healing_field",
			"influence_radius": 520.0,
			"regen_rate": 4.0
		},
		"LavaWorld": {
			"min_size": 260.0,
			"max_size": 330.0,
			"pixels_min": 56,
			"pixels_max": 72,
			"light_min": 0.42,
			"light_max": 0.58,
			"rotates": true,
			"effect_type": "burn_field",
			"influence_radius": 540.0,
			"burn_dps": 8.0
		},
		"NoAtmosphere": {
			"min_size": 250.0,
			"max_size": 300.0,
			"pixels_min": 20,
			"pixels_max": 30,
			"light_min": 0.40,
			"light_max": 0.60,
			"rotates": true,
			"effect_type": "low_gravity",
			"influence_radius": 360.0,
			"gravity_reduction": 0.25,
			"is_moon_system": true,
			"orbit_radius": 260.0,
			"orbit_speed": 0.55,
			"parent_type": "LandMasses",
			"parent_size_multiplier": 2.5
		},
		"Rivers": {
			"min_size": 280.0,
			"max_size": 360.0,
			"pixels_min": 60,
			"pixels_max": 78,
			"light_min": 0.40,
			"light_max": 0.60,
			"rotates": true,
			"effect_type": "flow_charge",
			"influence_radius": 520.0,
			"cooldown_multiplier": 0.85
		},
		"Star": {
			"min_size": 1300.0,
			"max_size": 1500.0,
			"pixels_min": 72,
			"pixels_max": 88,
			"light_min": 0.48,
			"light_max": 0.52,
			"rotates": true,
			"effect_type": "unstable_star",
			"influence_radius": 650.0,
			"absorb_radius": 240.0,
			"explosion_radius": 800.0,
			"instability_threshold": 25
		}
	}

	return configs.get(type_name, {
		"min_size": DEFAULT_MIN_SIZE,
		"max_size": DEFAULT_MAX_SIZE,
		"pixels_min": 60,
		"pixels_max": 80,
		"light_min": 0.4,
		"light_max": 0.6,
		"rotates": true
	})

static func get_palette(type_name: String) -> Array[Color]:
	match type_name:
		"BlackHole":
			return [Color("272736"), Color("ffddaa"), Color("ff9955"), Color("ff6600"), Color("aa3300"), Color("662200"), Color("331100"), Color("110000")]
		"DryTerran":
			return [Color("d8c29d"), Color("b08968"), Color("7f5539"), Color("5e3b22"), Color("3a2415")]
		"Galaxy":
			return [Color("12051a"), Color("3b1c5a"), Color("6a2c91"), Color("9d4edd"), Color("c77dff"), Color("e0aaff")]
		"GasPlanet":
			return [Color("3b224c"), Color("6c3fa1"), Color("9f67ff"), Color("d5b3ff"), Color("2a4066"), Color("4e7ac7"), Color("7fb3ff"), Color("cfe8ff")]
		"GasPlanetLayers":
			return [Color("e9c46a"), Color("f4a261"), Color("e76f51"), Color("a86c42"), Color("7f5539"), Color("5b3a29")]
		"IceWorld":
			return [Color("dff6ff"), Color("8dd8ff"), Color("4ba3ff"), Color("bde0fe"), Color("89c2ff"), Color("3a86ff"), Color("ffffff"), Color("dcefff"), Color("b8d8ff"), Color("8cbcff")]
		"LandMasses":
			return [Color("1d4e89"), Color("3e7cb1"), Color("a9d6e5"), Color("1b5e20"), Color("2e7d32"), Color("4caf50"), Color("81c784"), Color("ffffff"), Color("dfefff"), Color("b0c4de"), Color("90a4ae")]
		"LavaWorld":
			return [Color("3a1111"), Color("5c1d1d"), Color("7a2b1d"), Color("5c1d1d"), Color("7a2b1d"), Color("ff6b00"), Color("ff9e00"), Color("ffd166")]
		"NoAtmosphere":
			return [Color("b0a99f"), Color("7f7a73"), Color("4f4b46"), Color("7f7a73"), Color("4f4b46")]
		"Rivers":
			return [Color("355e3b"), Color("4f7942"), Color("6b8e23"), Color("8fbc8f"), Color("1e3a8a"), Color("60a5fa"), Color("ffffff"), Color("ddefff"), Color("bcdcff"), Color("9ec5fe")]
		"Star":
			return [Color("fff7cc"), Color("fff1a8"), Color("ffe066"), Color("ffb703"), Color("fb8500"), Color("ff6d00"), Color("ffe066"), Color("fff1a8"), Color("fff7cc"), Color("ffffff")]
		_:
			return []
