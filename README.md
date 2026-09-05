# TTRPG Simulator (Godot 4)

A customizable tabletop RPG simulator: character sheets, a virtual tabletop
with draggable tokens, a dice roller, chat, and simple password-protected
multiplayer — all in one Godot project you can open and edit directly.

## Requirements

- **Godot 4.3+** (Godot 4.x, standard or .NET build — this project uses only
  GDScript, no C#). Download: https://godotengine.org/download

## Running it

1. Open Godot, click **Import**, select the `project.godot` file in this
   folder.
2. Press the Play button (or F5). It opens on the main menu.
3. **To host**: enter your name and a password, leave the IP field alone,
   click **Host Game**. Godot will host on the port shown (default `8910`).
   Share your IP address (use your LAN IP for local play, or your public IP
   / a port-forward for internet play) and the password with your players.
4. **To join**: enter your name, the host's IP, the same password, and the
   same port, then click **Join Game**.
5. Everyone lands on the shared **Tabletop** screen: dice roller, chat,
   player list, "Load Map" (pick a background image), "Add Token" (pick an
   image, drag it onto the board), and "Character Sheet".

No dedicated server or account system is needed — one player just hosts
from their own machine.

## How the password/multiplayer works

Godot's multiplayer layer (ENet) doesn't have built-in authentication, so
`autoloads/network_manager.gd` adds a small handshake: when a client
connects, it immediately sends its password over RPC. The host checks it
against the room password and either accepts the player (registering them
in `GameState`) or disconnects them. This is fine for playing with friends;
it is **not** hardened against a determined attacker, so don't expose it to
the open internet for anything sensitive.

## Customizing character sheets — no code required

Open `data/character_template.json`. It defines sections and fields; the
sheet UI (`scripts/character_sheet.gd`) builds itself from this file at
runtime. To add a new field, add an entry like:

```json
{ "key": "inspiration", "label": "Inspiration", "type": "number", "default": 0, "min": 0, "max": 5 }
```

Supported `type` values: `"text"`, `"number"`, `"multiline"`. Add as many
sections/fields as your system needs — Curse of Strahd, a homebrew system,
a completely different game, whatever. Saved characters go to
`user://characters/*.json` (Save/Load buttons on the sheet).

## Project structure

```
project.godot
autoloads/
  network_manager.gd   # hosting/joining + password handshake
  game_state.gd         # shared state: players, tokens, dice, chat (networked)
scripts/
  dice_roller.gd        # dice notation parser (2d6+3, 4d6kh3, etc.)
  main_menu.gd
  tabletop.gd            # the board + side panel
  token.gd               # a single draggable token
  character_sheet.gd     # builds itself from the JSON template
scenes/
  main_menu.tscn
  tabletop.tscn
  token.tscn
  character_sheet.tscn
data/
  character_template.json
```

`GameState` is the important one to understand: it holds all shared data
and never assumes anything about how the board is drawn. Every other script
only talks to `GameState`, not to each other directly.

## Adding 3D later

The 2D board lives entirely inside one node: `BoardRoot` in
`scenes/tabletop.tscn` (currently a `Node2D` holding the map image and a
`TokenLayer`). To move to 3D:

1. Replace `BoardRoot` with a `Node3D` containing a `Camera3D` and a ground
   plane (a `MeshInstance3D` with a `PlaneMesh`, or a terrain of your
   choice).
2. Duplicate `scripts/token.gd` into a 3D version: same idea (drag to move,
   report position on release/while dragging), but driving a `Node3D`'s
   `position` and using `Vector3` — GameState's `x`/`y` fields can just map
   to `x`/`z` (keep `y` as height if you want vertical movement/flight).
3. In `tabletop.gd`, only `_on_token_added` / `_on_token_moved` need to
   instantiate the 3D token scene instead of the 2D one. `GameState`,
   `NetworkManager`, dice, chat, and character sheets don't change at all —
   they don't know or care whether the board is 2D or 3D.

Because networking and rules logic never reference `Sprite2D`, `Node2D`, or
screen-space coordinates directly, this swap is localized to the token and
board scripts/scenes.

## Extending the rules automation

Right now dice rolling is manual (type a formula, or click a quick-roll
button). If you want system-specific automation — e.g. a button that rolls
`1d20 + STR modifier` using values from the currently loaded character —
that logic belongs in `character_sheet.gd` or a new script that reads
`GameState.players[id]["character"]` and calls
`GameState.roll_and_broadcast(formula)` with a formula it builds itself.
