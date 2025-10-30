extends Node

signal GameStart
signal GameOver(state: String)
signal GetMenu

var GRID_SIZE = 4
var DIFFICULTY = SudokuBoard.TypeDifficulty.EASY
var ZONES: bool = false

var saved_games = {} # { 4: grid:Dictionary, 9: ... , 16: ... }

# Paleta de colores que combinan con el negro (minimalista y profesional)
var colores_acentos: Array[Color] = [
	Color("#007F5F"), # Verde esmeralda oscuro
	Color("#0A3D62"), # Azul medianoche
	Color("#6A040F"), # Burdeos profundo
	Color("#C9A227"), # Oro viejo
	Color("#B3541E"), # Cobre oscuro
	Color("#4B3F72"), # Morado carbón
	Color("#1B6B6F"), # Azul petróleo
	Color("#E8E8E8"), # Gris hielo (blanco frío)
	Color("#A67C52"), # Marrón bronce
	Color("#2E2E2E"), # Gris antracita profundo (transición con negro)
	Color("#5C5C5C"), # Gris medio (neutral para textos secundarios)
	Color("#8A8A8A"), # Gris plata mate
	Color("#009688"), # Verde azulado (teal elegante)
	Color("#3D5A80"), # Azul grisáceo (corporativo sobrio)
	Color("#9E2A2B"), # Rojo vino moderno
	Color("#FFD166")  # Amarillo suave (acento cálido y contrastante)
]
