Verlet Rope Simulator in Godot

Hi! I'm building a rope simulator from scratch in Godot using Verlet integration.

I'm doing all the physics math completely manually without relying on Godot's built-in physics engine!

A pre-compiled HTML5 version is included in the repository.

Browsers restrict WebAssembly execution over local file paths (file://), which causes a "Network error when attempting to fetch resource". To play locally:

    Clone the repository to your machine.

    Open a terminal in the project directory and start a local HTTP server:
    Bash

    python3 -m http.server 8000

    Open your browser and navigate to http://localhost:8000.
