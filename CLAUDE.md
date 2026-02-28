# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a C++ OpenGL application for viewing SSBP (Sprite Studio Binary Protocol) version 3 animation files. It is specifically designed for viewing Fire Emblem Heroes character sprite animations.

## Build Commands

The project is a simple C++ application that uses g++ directly (no Makefile or CMake).

### Dependencies (macOS with Homebrew)
```bash
brew install glfw glm webp
```

### Compile
```bash
cd /Users/mzhao/workdir/feh/ssbp_VV
g++ -g -std=c++11 -I./glad/include -I/opt/homebrew/include -I./stb \
    main.cpp sprite.cpp shader.cpp texture.cpp glad.c \
    ssbp/SS5Player.cpp ssbp/SS5PlayerPlatform.cpp \
    ssbp/Common/Animator/ssplayer_PartState.cpp \
    ssbp/Common/Animator/ssplayer_effect.cpp \
    ssbp/Common/Animator/ssplayer_effectfunction.cpp \
    ssbp/Common/Animator/ssplayer_matrix.cpp \
    ssbp/Common/Helper/DebugPrint.cpp \
    -framework OpenGL -L/opt/homebrew/lib -lglfw -lWebP -o ssbp_viewer
```

**Note:** On Intel Macs, replace `/opt/homebrew` with `/usr/local` in the include and library paths.

### Run
```bash
# Run with drag-and-drop prompt
./ssbp_viewer

# Run with specific file
./ssbp_viewer path/to/file.ssbp
```

## Project Architecture

### Core Rendering Pipeline
The application follows a simple OpenGL rendering pipeline:

1. **main.cpp** - Entry point, GLFW window setup, input handling, render loop
2. **Sprite class** (sprite.h/cpp) - Wraps the SS5Player library, manages animation state (play/pause/loop/speed)
3. **Quad class** (quad.h) - Base OpenGL geometry (VAO/VBO/EBO) for rendering quads
4. **Shader class** (shader.h/cpp) - OpenGL shader program compilation and uniform management
5. **Texture class** (texture.h/cpp) - Loads PNG/WebP textures using stb_image and libwebp

### SS5Player Library (ssbp/)
This is the Sprite Studio playback engine from Web Technology Corp:
- **SS5Player.h/cpp** - Core animation player with timeline, parts, and keyframe interpolation
- **SS5PlayerData.h** - SSBP file format structures
- **SS5PlayerPlatform.h** - Platform abstraction layer
- **Common/** - Effect system, matrix math, cell maps, MersenneTwister RNG

The library uses OpenGL 3.3 Core Profile and renders sprite animations from .ssbp files.

### File Loading
**File_reader.h** - Custom file reader that:
- Reads binary files for textures (PNG/WebP detection via magic bytes)
- Reads text files for shaders
- Supports retry logic for texture paths (walks up directory tree)

### Shaders
Located in `shaders/`:
- **sprite.vertex/sprite.fragment** - For rendering sprite animations
- **background.vertex/background.fragment** - For the background quad
- **background.png** - Default background texture

## Key Dependencies

- **GLFW** - Window creation and input handling
- **GLAD** - OpenGL function loading (OpenGL 3.3 Core)
- **GLM** - Vector/matrix math
- **stb_image** - PNG image loading (in stb/ directory)
- **stb_image_write** - PNG export for screenshots
- **libwebp** - WebP texture support

## Input Controls

- **A/Left Arrow** - Previous animation
- **S/Right Arrow** - Next animation
- **L** - Toggle animation loop
- **Space** - Pause/replay (when not looping)
- **X** - Flip horizontally
- **C** - Center camera
- **Q** - Screenshot (exports all frames when Shift+Q)
- **W** - Toggle wireframe mode
- **1/2/3** - Change animation speed
- **H** - Display help
- **Mouse Drag** - Pan camera
- **Scroll** - Zoom

## Data Files

The application expects:
- **.ssbp files** - Sprite Studio animation files (binary format version 3)
- **Texture files** - PNG or WebP images referenced by the .ssbp

### Run with Character Name

```bash
# Using character name (looks in sprites/<Name>/ for .ssbp file)
./ssbp_viewer Abel
./ssbp_viewer Byleth_Female
./ssbp_viewer Alfonse

# With custom weapon
./ssbp_viewer Abel -w wep_ax.png          # Use axe instead of lance
./ssbp_viewer Byleth_Female --weapon wep_sw.png  # Use sword

# Still works with direct paths
./ssbp_viewer sprites/Abel/ch01_16_Abel_M_Normal.ssbp
```

### Weapon & Effect Selection

Use `-w` or `--weapon` to override the default weapon:
Use `-e` or `--effect` to override the weapon swing effect:

```bash
./ssbp_viewer <character> -w <weapon_file>
./ssbp_viewer <character> -e <effect_file>
./ssbp_viewer <character> -w <weapon_file> -e <effect_file>
```

**Common weapon files in `Wep/`:**
- `wep_sw.png` - Sword
- `wep_lc.png` - Lance
- `wep_ax.png` - Axe
- `wep_bw.png` - Bow
- `wep_mg.png` - Magic/Tome
- `wep_rd.png` - Rod/Staff
- `wep_dg.png` - Dagger

Many variants available (e.g., `wep_sw001.png`, `wep_ax024.png`, etc.)

**Common effect files in `Wep/`:**
- `eff_WepSwing.png` - Default weapon swing effect
- `Btl_Hit01.png`, `Btl_Hit02.png` - Hit effects
- `Blt_Mag01.png` - Magic bullet effect
- Many other effect files available

## Godot Export Workflow

### Prerequisites
```bash
pip3 install Pillow
```

### Step 1: Export SSBP to PNG Frames
```bash
./ssbp_viewer path/to/file.ssbp
# This auto-exports all animations to: file_name_Screenshots/
```

### Step 2: Convert to Godot Atlas
```bash
python3 ssbp_to_godot_atlas.py <input_folder> <output_name> [fps]

# Example:
python3 ssbp_to_godot_atlas.py ch90_06_ArmorAX_M_Normal_Screenshots ArmorAX 30
```

This generates:
- `ArmorAX.png` - Spritesheet atlas (all frames packed)
- `ArmorAX.json` - Aseprite-compatible animation metadata
- `ArmorAX.json.import.cfg` - Godot import hints

### Step 3: Import to Godot

1. Install **Aseprite Wizard** plugin from Godot Asset Library
2. Copy `ArmorAX.png` and `ArmorAX.json` to your Godot project
3. Godot will auto-import with animation tags preserved
4. Use `AnimatedSprite2D` node - animations will be available by name (Attack1, Idle, etc.)

### Atlas Converter Features
- Packs all animation frames into optimized spritesheet
- Generates Aseprite-compatible JSON with animation tags
- Preserves frame order and timing
- Supports variable FPS (default: 30)
- Handles transparent PNGs correctly
- Pads atlas to power-of-2 for GPU compatibility
