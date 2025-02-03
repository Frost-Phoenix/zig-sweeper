const std = @import("std");
const rl = @import("raylib");

const cell = @import("cell.zig");
const grid = @import("grid.zig");

const screenWidth = 20 * cell.CELL_SIZE * SCALE;
const screenHeight = 20 * cell.CELL_SIZE * SCALE;

const SCALE = 2;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    rl.initWindow(screenWidth, screenHeight, "zig-sweeper");
    defer rl.closeWindow();

    var camera = rl.Camera2D{
        .target = .{ .x = 0, .y = 0 },
        .offset = .{ .x = 0, .y = 0 },
        .zoom = SCALE,
        .rotation = 0,
    };

    rl.setTargetFPS(60);

    const cells_texture = try rl.loadTexture("assets/cells.png");

    var board: grid.Grid = try grid.Grid.init(allocator, 20, 20);
    defer board.deinit(allocator);

    while (!rl.windowShouldClose()) {
        // Update
        updateCamera(&camera);

        // std.debug.print("target: {}, offset: {}\n", .{ camera.target, camera.offset });

        // Draw
        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(rl.Color.gray);

        {
            camera.begin();
            defer camera.end();

            board.render(cells_texture);
        }
    }
}

fn updateCamera(camera: *rl.Camera2D) void {
    // Move
    if (rl.isMouseButtonDown(.right)) {
        var delta = rl.getMouseDelta();
        delta = rl.math.vector2Scale(delta, -1.0 / camera.zoom);
        camera.target = rl.math.vector2Add(camera.target, delta);
    }

    // Zoom
    const wheel = rl.getMouseWheelMove();
    if (wheel != 0) {
        const mouseWorldPos = rl.getScreenToWorld2D(rl.getMousePosition(), camera.*);
        camera.offset = rl.getMousePosition();
        // Set the target to match, so that the camera maps the world space point
        // under the cursor to the screen space point under the cursor at any zoom
        camera.target = mouseWorldPos;

        // Zoom increment
        var scaleFactor = 1.0 + (0.25 * @abs(wheel));
        if (wheel < 0) {
            scaleFactor = 1.0 / scaleFactor;
        }
        camera.zoom = rl.math.clamp(camera.zoom * scaleFactor, SCALE, 16);
    }

    // Clamp to screen edges
    const min = rl.getWorldToScreen2D(.{ .x = 0, .y = 0 }, camera.*);
    const max = rl.getWorldToScreen2D(.{ .x = 20 * cell.CELL_SIZE, .y = 20 * cell.CELL_SIZE }, camera.*);

    if (min.x > 0) {
        camera.target.x = 0;
        camera.offset.x = 0;
    }
    if (min.y > 0) {
        camera.target.y = 0;
        camera.offset.y = 0;
    }
    if (max.x < screenWidth) {
        camera.offset.x += screenWidth - max.x;
    }
    if (max.y < screenHeight) {
        camera.offset.y += screenHeight - max.y;
    }
}
