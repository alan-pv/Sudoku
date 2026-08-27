# Sudoku

A Sudoku game for mobile, built with **Godot 4.5** (GDScript).

Supports classic 4x4 and 9x9 boards as well as **jigsaw (irregular) regions**,
with three difficulty levels, a saved game per board size and a local
leaderboard.

## Running it

Open the project with Godot 4.5 or newer and press <kbd>F5</kbd>.
The window is portrait (720x1280, 360x640 while developing).

Exports are written to `build/`, which is ignored by git — never commit the
generated binaries.

## Layout

```
scripts/Autoload/Settings.gd       global state: grid size, difficulty, saves
scripts/Autoload/SudokuBoard.gd    board generation and solving
scripts/sudoku.gd                  the board on screen
scripts/game.gd, game_ui.gd        match flow and HUD
scripts/menu.gd, popup.gd          menus
scenes/                            Game.tscn, button.tscn
Sprites/ Font/ Resource/           assets and themes
```

`SudokuBoard.generate_board(n, difficulty, zones)` is the entry point: it builds
a full solution by backtracking over bitmasks, then carves out cells while
checking that the puzzle keeps a unique solution and stays solvable with the
techniques allowed by the difficulty. With `zones = true` the regions are
generated jigsaw-style instead of using the standard boxes.

## Related

The research side of this project — the ASP encoding, the dataset generator and
the published puzzle collection — lives in a separate repository:
[irregular-sudoku-dataset](https://github.com/alan-pv/irregular-sudoku-dataset).
