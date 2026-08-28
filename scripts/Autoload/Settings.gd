extends Node

## Global game state: what the player picked in the menu, the saved game and
## the local leaderboard. Autoloaded, so it survives scene changes.

signal GameStart
signal GameOver(state: String)
signal GetMenu

var GRID_SIZE = 9
var DIFFICULTY = SudokuBoard.TypeDifficulty.EASY
var ZONES: bool = false

var ui_sounds: UISounds = null

var history = {}
var saved_game = {} # { 4: grid:Dictionary, 9: ... , 16: ... }

# Accent palette, chosen to read well against the near-black background.
var accent_colors: Array[Color] = [
	Color("#007F5F"), # Dark emerald
	Color("#0A3D62"), # Midnight blue
	Color("#6A040F"), # Deep burgundy
	Color("#C9A227"), # Old gold
	Color("#B3541E"), # Dark copper
	Color("#4B3F72"), # Charcoal purple
	Color("#1B6B6F"), # Petrol blue
	Color("#E8E8E8"), # Ice grey (cool white)
	Color("#A67C52"), # Bronze brown
	Color("#2E2E2E"), # Deep anthracite (transitions into the background)
	Color("#5C5C5C"), # Mid grey (neutral, for secondary text)
	Color("#8A8A8A"), # Matte silver
	Color("#009688"), # Elegant teal
	Color("#3D5A80"), # Sober slate blue
	Color("#9E2A2B"), # Modern wine red
	Color("#FFD166")  # Soft yellow (warm, high-contrast accent)
]

## One entry list per difficulty, keyed by SudokuBoard.TypeDifficulty.
var leaderboard: Dictionary = { 0: [], 1: [], 2: [] }

## stats: { "global_time": Dictionary, "time": int, "difficulty": int }
func save_stats(stats: Dictionary) -> void:
	leaderboard[stats["difficulty"]].append(stats)
