# Jarl Engine

A real-time raymarching engine written in [Odin](https://odin-lang.org/).

## Goal

Jarl is a hobby rendering engine focused on exploring **raymarched scenes with non-Euclidean geometry via portals**. Primitives (spheres, boxes) and portals (ellipses, rectangles) are defined on the CPU, uploaded to the GPU via SSBOs, and rendered entirely in a fragment shader using signed-distance functions. In the future I plan on implementing Lua scripting so that it works more like a LÖVE-style game development framework.

---

## Project Map

```
jarl/
└── src/
    ├── main.odin           # Entry point
    └── jarl/               # Core engine package
        ├── app.odin        # App lifecycle: init, loop, shutdown
        ├── camera.odin     # First-person camera (pitch/yaw, movement)
        ├── consts.odin     # Compile-time constants (GL version, ray params, etc.)
        ├── enums.odin      # Shared enums
        ├── imgui.odin      # ImGui debug overlay integration
        ├── input.odin      # Keyboard/mouse input state and some window stuff, for some reason
        ├── scene.odin      # Scene data: primitives, portals, SSBO management
        ├── shader.odin     # GLSL shader compilation and uniform management
        ├── timing.odin     # Delta time and frame history
        ├── window.odin     # GLFW window creation and callbacks
        └── res/
            ├── vert.glsl   # Dummy passthrough vertex shader
            └── frag.glsl   # Raymarching fragment shader (SDF, portals)
```

---

## Build Instructions

**NOTE:** This'll require OpenGL 4.3 since I use SSBOs for scene data

```
odin build src -debug -out:build/debug.exe
```

---

## Disclaimer

This is a personal hobby project in active, early-stage development. APIs, file layout, and features will change without notice. It is not intended for production use.
