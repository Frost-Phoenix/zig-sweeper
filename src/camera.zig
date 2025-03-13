const rl = @import("raylib");

const Grid = @import("grid.zig").Grid;

// ***** //

const MAX_ZOOM = 16;

pub const Camera = struct {
    scale: i32,
    width: i32,
    height: i32,

    cam: rl.Camera2D,
    render_texture: rl.RenderTexture2D,

    pub fn init(width: i32, height: i32, scale: i32) !@This() {
        return Camera{
            .scale = scale,
            .width = width,
            .height = height,
            .cam = rl.Camera2D{
                .target = .{ .x = 0, .y = 0 },
                .offset = .{ .x = 0, .y = 0 },
                .zoom = @as(f32, @floatFromInt(scale)),
                .rotation = 0,
            },
            .render_texture = try rl.loadRenderTexture(width, height),
        };
    }

    pub fn deinit(self: *Camera) void {
        rl.unloadRenderTexture(self.render_texture);
    }

    pub fn reset(self: *Camera) void {
        const cam = &self.cam;

        cam.target = .{ .x = 0, .y = 0 };
        cam.offset = .{ .x = 0, .y = 0 };
        cam.zoom = self.scale;
    }

    pub fn update(self: *Camera) void {
        const cam = &self.cam;

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
            cam.zoom = rl.math.clamp(cam.zoom * scaleFactor, self.scale, MAX_ZOOM);
        }

        // Clamp to screen edges
        const min = rl.getWorldToScreen2D(.{ .x = 0, .y = 0 }, cam.*);
        const max = rl.getWorldToScreen2D(.{ .x = self.width, .y = self.height }, cam.*);

        if (min.x > 0) {
            cam.target.x = 0;
            cam.offset.x = 0;
        }
        if (min.y > 0) {
            cam.target.y = 0;
            cam.offset.y = 0;
        }
        if (max.x < self.width) {
            cam.offset.x += self.width - max.x;
        }
        if (max.y < self.height) {
            cam.offset.y += self.height - max.y;
        }
    }

    pub fn renderGrid(self: *Camera, grid: *Grid) void {
        _ = grid; // autofix
        {
            self.render_texture.begin();
            defer self.render_texture.end();

            rl.clearBackground(rl.Color.white);

            self.cam.begin();
            defer self.cam.end();

            rl.drawRectangle(100, 100, 100, 100, rl.Color.red);
        }

        rl.drawTextureRec(
            self.render_texture.texture,
            rl.Rectangle.init(
                0,
                0,
                @as(f32, @floatFromInt(self.width)),
                @as(f32, @floatFromInt(self.height)),
            ),
            rl.Vector2.init(0, 0),
            rl.Color.white,
        );
    }
};
