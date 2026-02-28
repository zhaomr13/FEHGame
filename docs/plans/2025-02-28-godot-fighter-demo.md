# Godot Fighter Demo Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Create a minimal Godot 4 project that demonstrates ssbp_viewer-generated atlases work correctly.

**Architecture:** Simple 2D fighter with two AnimatedSprite2D characters using Aseprite-imported spritesheets. GDScript state machine handles Idle/Walk/Attack animations.

**Tech Stack:** Godot 4.x, GDScript, Aseprite Wizard plugin (for JSON import)

---

### Task 1: Create Godot Project Structure

**Files:**
- Create: `godot/project.godot`

**Step 1: Initialize Godot project**

Run:
```bash
mkdir -p /Users/mzhao/workdir/feh/godot
cd /Users/mzhao/workdir/feh/godot
godot --headless --new-project
```

**Step 2: Configure project settings**

Create `project.godot`:
```ini
; Engine Configuration File
; Godot version: 4.x

[application]
config/name="SSBP Fighter Demo"
config/features=PackedStringArray("4.2", "Mobile")
config/icon="res://icon.svg"

[display]
window/size/viewport_width=1280
window/size/viewport_height=720
window/stretch/mode="canvas_items"

[rendering]
renderer/rendering_method="mobile"
```

**Step 3: Commit**
```bash
cd /Users/mzhao/workdir/feh
git add godot/project.godot
git commit -m "feat: initialize Godot project"
```

---

### Task 2: Import Character Atlases

**Files:**
- Copy: `ssbp_VV/Diadora.png` → `godot/assets/Diadora.png`
- Copy: `ssbp_VV/Diadora.json` → `godot/assets/Diadora.json`
- Copy: `ssbp_VV/ArmorAX.png` → `godot/assets/ArmorAX.png`
- Copy: `ssbp_VV/ArmorAX.json` → `godot/assets/ArmorAX.json`

**Step 1: Create assets directory**

```bash
mkdir -p /Users/mzhao/workdir/feh/godot/assets
```

**Step 2: Copy atlas files**

```bash
cp /Users/mzhao/workdir/feh/ssbp_VV/Diadora.png /Users/mzhao/workdir/feh/godot/assets/
cp /Users/mzhao/workdir/feh/ssbp_VV/Diadora.json /Users/mzhao/workdir/feh/godot/assets/
cp /Users/mzhao/workdir/feh/ssbp_VV/ArmorAX.png /Users/mzhao/workdir/feh/godot/assets/
cp /Users/mzhao/workdir/feh/ssbp_VV/ArmorAX.json /Users/mzhao/workdir/feh/godot/assets/
```

**Step 3: Create import configuration**

Create `godot/assets/Diadora.json.import`:
```ini
[remap]

importer="aseprite_wizard.plugin"
type="SpriteFrames"
uid="uid://diadora_anim"
path="res://.godot/imported/Diadora.json-xxxxxxxx.spriteframes"

[deps]

source_file="res://assets/Diadora.json"
dest_files=["res://.godot/imported/Diadora.json-xxxxxxxx.spriteframes"]

[params]

extrude=false

[animation]

default/loops=true
```

Create `godot/assets/ArmorAX.json.import` (same pattern with uid `uid://armorax_anim`).

**Step 4: Commit**
```bash
git add godot/assets/
git commit -m "feat: import character atlas files"
```

---

### Task 3: Create Character Scene

**Files:**
- Create: `godot/scenes/Character.tscn`
- Create: `godot/scripts/Character.gd`

**Step 1: Create scene directory**

```bash
mkdir -p /Users/mzhao/workdir/feh/godot/scenes
mkdir -p /Users/mzhao/workdir/feh/godot/scripts
```

**Step 2: Create Character script**

Create `godot/scripts/Character.gd`:
```gdscript
extends CharacterBody2D

@export var sprite_frames: SpriteFrames
@export var is_player: bool = true
@export var move_speed: float = 200.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

enum State { IDLE, WALK, ATTACK }
var current_state: State = State.IDLE
var facing_right: bool = true

func _ready():
    if sprite_frames:
        animated_sprite.sprite_frames = sprite_frames
    animated_sprite.play("Idle")

    # Flip if not player (face left)
    if not is_player:
        facing_right = false
        animated_sprite.flip_h = true

func _physics_process(delta):
    match current_state:
        State.IDLE:
            handle_idle(delta)
        State.WALK:
            handle_walk(delta)
        State.ATTACK:
            handle_attack(delta)

func handle_idle(delta):
    var input_dir = get_input_direction()

    if Input.is_action_just_pressed("attack") and is_player:
        change_state(State.ATTACK)
    elif input_dir != 0:
        change_state(State.WALK)

func handle_walk(delta):
    var input_dir = get_input_direction()

    if Input.is_action_just_pressed("attack") and is_player:
        change_state(State.ATTACK)
        return

    if input_dir == 0:
        change_state(State.IDLE)
    else:
        velocity.x = input_dir * move_speed
        # Flip sprite based on direction
        if input_dir > 0 and not facing_right:
            facing_right = true
            animated_sprite.flip_h = false
        elif input_dir < 0 and facing_right:
            facing_right = false
            animated_sprite.flip_h = true

        move_and_slide()

func handle_attack(delta):
    # Wait for animation to finish
    pass

func change_state(new_state: State):
    current_state = new_state

    match new_state:
        State.IDLE:
            animated_sprite.play("Idle")
            velocity = Vector2.ZERO
        State.WALK:
            animated_sprite.play("Idle")  # Use Idle for walk (no walk anim)
        State.ATTACK:
            animated_sprite.play("Attack1")
            animated_sprite.animation_finished.connect(_on_attack_finished, CONNECT_ONE_SHOT)

func _on_attack_finished():
    change_state(State.IDLE)

func get_input_direction() -> int:
    if not is_player:
        return 0

    var dir = 0
    if Input.is_action_pressed("ui_left"):
        dir -= 1
    if Input.is_action_pressed("ui_right"):
        dir += 1
    return dir
```

**Step 3: Create Character scene**

Create `godot/scenes/Character.tscn`:
```
[gd_scene load_steps=2 format=3 uid="uid://character_scene"]

[ext_resource type="Script" path="res://scripts/Character.gd" id="1_script"]

[node name="Character" type="CharacterBody2D"]
script = ExtResource("1_script")

[node name="AnimatedSprite2D" type="AnimatedSprite2D" parent="."]
scale = Vector2(0.5, 0.5)

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
```

**Step 4: Commit**
```bash
git add godot/scenes/ godot/scripts/
git commit -m "feat: create character scene with state machine"
```

---

### Task 4: Create Main Game Scene

**Files:**
- Create: `godot/scenes/Main.tscn`
- Modify: `godot/project.godot` (set main scene)

**Step 1: Create Main scene**

Create `godot/scenes/Main.tscn`:
```
[gd_scene load_steps=5 format=3 uid="uid://main_scene"]

[ext_resource type="PackedScene" uid="uid://character_scene" path="res://scenes/Character.tscn" id="1_character"]

[sub_resource type="CompressedTexture2D" id="1_diadora"]
load_path = "res://assets/Diadora.png"

[sub_resource type="SpriteFrames" id="2_diadora_frames"]
animations = []

[sub_resource type="CompressedTexture2D" id="3_armorax"]
load_path = "res://assets/ArmorAX.png"

[sub_resource type="SpriteFrames" id="4_armorax_frames"]
animations = []

[node name="Main" type="Node2D"]

[node name="Background" type="ColorRect" parent="."]
offset_right = 1280.0
offset_bottom = 720.0
color = Color(0.2, 0.3, 0.4, 1.0)

[node name="Player1" parent="." instance=ExtResource("1_character")]
position = Vector2(400, 500)
sprite_frames = SubResource("2_diadora_frames")
is_player = true

[node name="Player2" parent="." instance=ExtResource("1_character")]
position = Vector2(880, 500)
sprite_frames = SubResource("4_armorax_frames")
is_player = false
```

**Step 2: Set main scene in project**

Modify `godot/project.godot`:
```ini
[application]
config/name="SSBP Fighter Demo"
run/main_scene="res://scenes/Main.tscn"
config/features=PackedStringArray("4.2", "Mobile")
```

**Step 3: Commit**
```bash
git add godot/scenes/Main.tscn godot/project.godot
git commit -m "feat: create main game scene with two characters"
```

---

### Task 5: Configure Input Actions

**Files:**
- Modify: `godot/project.godot`

**Step 1: Add attack input action**

Add to `godot/project.godot`:
```ini
[input]

attack={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":32,"key_label":0,"unicode":32,"echo":false,"script":null)
]
}
```

**Step 2: Commit**
```bash
git add godot/project.godot
git commit -m "feat: add attack input action"
```

---

### Task 6: Test and Verify

**Step 1: Open project in Godot**

```bash
cd /Users/mzhao/workdir/feh/godot
godot .
```

**Step 2: Verify in editor**
- Check that both atlases import without errors
- Verify AnimatedSprite2D shows animation frames
- Confirm Main scene displays both characters

**Step 3: Run the game**

Press F5 or click "Run Project".

**Expected behavior:**
- Window opens at 1280x720
- Blue background displays
- Two characters visible (Diadora left, ArmorAX right)
- Left/Right arrows move player
- Space triggers Attack1 animation
- Characters return to Idle after attack

**Step 4: Commit final version**
```bash
git add -A
git commit -m "feat: complete godot fighter demo"
```

---

## Post-Implementation Notes

### Using Without Aseprite Wizard

If the Aseprite Wizard plugin isn't available, manually create SpriteFrames:
1. Select AnimatedSprite2D
2. In Inspector, click "Sprite Frames" → "New SpriteFrames"
3. Add animations matching names in JSON (Idle, Attack1, etc.)
4. Add frames from the PNG atlas manually

### Troubleshooting

**Issue: Animations not playing**
- Check JSON import created SpriteFrames resource
- Verify animation names match (case-sensitive)

**Issue: Black squares instead of sprites**
- Atlas texture not imported correctly
- Try reimporting assets in Godot

**Issue: Crash on startup**
- Check Godot version (4.x required)
- Verify file paths are correct
