# Zig Raylib
Fetch raysan5/raylib (master branch) directly using the package manager.

Link the Raylib C artifact directly in build.zig.

Use @cImport in src/main.zig to access Raylib functions.

## How to Run
Navigate to the project directory and run:

```
cd code/projects/timer-raylib
zig build run -- 5s
```


## Features

Windowed Interface: Opens a Raylib window ("Zig Timer").

Graphical Text: Renders the countdown status using Raylib's text rendering.

Color Coding: Changes color from Green -> Red as time runs out.

Argument Parsing: Accepts duration arguments just like the CLI version (e.g. 5s, 1m).