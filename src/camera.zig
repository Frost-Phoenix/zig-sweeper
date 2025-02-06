const rl = @import("raylib");

const common = @import("common.zig");
const CELL_SIZE = common.CELL_SIZE;
const screenWidth = common.screenWidth;
const screenHeight = common.screenHeight;

pub fn init() rl.Camera2D {
    return rl.Camera2D{
        .target = .{ .x = 0, .y = 0 },
        .offset = .{ .x = 0, .y = 0 },
        .zoom = common.SCALE,
        .rotation = 0,
    };
}

pub fn reset(cam: *rl.Camera2D) void {
    cam.target = .{ .x = 0, .y = 0 };
    cam.offset = .{ .x = 0, .y = 0 };
    cam.zoom = common.SCALE;
}

pub fn updateCamera(cam: *rl.Camera2D) void {
    // Move
    if (rl.isMouseButtonDown(.middle)) {
        var delta = rl.getMouseDelta();
        delta = rl.math.vector2Scale(delta, -1.0 / cam.zoom);
        cam.target = rl.math.vector2Add(cam.target, delta);
    }

    // Zoom
    const wheel = rl.getMouseWheelMove();
    if (wheel != 0) {
        const mouseWorldPos = rl.getScreenToWorld2D(rl.getMousePosition(), cam.*);
        cam.offset = rl.getMousePosition();
        // Set the target to match, so that the camera maps the world space point
        // under the cursor to the screen space point under the cursor at any zoom
        cam.target = mouseWorldPos;

        // Zoom increment
        var scaleFactor = 1.0 + (0.25 * @abs(wheel));
        if (wheel < 0) {
            scaleFactor = 1.0 / scaleFactor;
        }
        cam.zoom = rl.math.clamp(cam.zoom * scaleFactor, common.SCALE, 16);
    }

    // Clamp to screen edges
    const min = rl.getWorldToScreen2D(.{ .x = 0, .y = 0 }, cam.*);
    const max = rl.getWorldToScreen2D(.{ .x = 20 * CELL_SIZE, .y = 20 * CELL_SIZE }, cam.*);

    if (min.x > 0) {
        cam.target.x = 0;
        cam.offset.x = 0;
    }
    if (min.y > 0) {
        cam.target.y = 0;
        cam.offset.y = 0;
    }
    if (max.x < screenWidth) {
        cam.offset.x += screenWidth - max.x;
    }
    if (max.y < screenHeight) {
        cam.offset.y += screenHeight - max.y;
    }
}
