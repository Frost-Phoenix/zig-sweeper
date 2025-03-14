const rl = @import("raylib");

const Pos = @import("grid.zig").Pos;

const CELL_SIZE = @import("common.zig").CELL_SIZE;
const BORDER_SIZE_TOP = @import("game.zig").BORDER_SIZE_TOP;
const BORDER_SIZE_LEFT = @import("game.zig").BORDER_SIZE_LEFT;

// ***** //

const ZOOM_MAX = 16;
const ZOOM_DEFAULT = 1;

pub const Camera = struct {
    width: f32,
    height: f32,
    offset: rl.Vector2,

    camera: rl.Camera2D,
    render_texture: rl.RenderTexture2D,

    pub fn init(width: i32, height: i32, offset: rl.Vector2) !@This() {
        return Camera{
            .width = @as(f32, @floatFromInt(width)),
            .height = @as(f32, @floatFromInt(height)),
            .offset = offset,
            .camera = rl.Camera2D{
                .target = .{ .x = 0, .y = 0 },
                .offset = .{ .x = 0, .y = 0 },
                .zoom = ZOOM_DEFAULT,
                .rotation = 0,
            },
            .render_texture = try rl.loadRenderTexture(width, height),
        };
    }

    pub fn deinit(self: *Camera) void {
        rl.unloadRenderTexture(self.render_texture);
    }

    pub fn reset(self: *Camera) void {
        const camera = &self.camera;

        camera.target = .{ .x = 0, .y = 0 };
        camera.offset = .{ .x = 0, .y = 0 };
        camera.zoom = ZOOM_DEFAULT;
    }

    pub fn update(self: *Camera, mouse_pos: rl.Vector2) void {
        const camera = &self.camera;

        // Move
        if (rl.isMouseButtonDown(.middle)) {
            var delta = rl.getMouseDelta();
            delta = rl.math.vector2Scale(delta, -1.0 / camera.zoom);
            camera.target = rl.math.vector2Add(camera.target, delta);
        }

        // Zoom
        const wheel = rl.getMouseWheelMove();
        if (wheel != 0) {
            const mouse_pos_offset = rl.Vector2.init(
                mouse_pos.x - BORDER_SIZE_LEFT,
                mouse_pos.y - BORDER_SIZE_TOP,
            );

            const mouseWorldPos = rl.getScreenToWorld2D(mouse_pos_offset, camera.*);
            camera.offset = mouse_pos_offset;
            // Set the target to match, so that the camera maps the world space point
            // under the cursor to the screen space point under the cursor at any zoom
            camera.target = mouseWorldPos;

            // Zoom increment
            var scaleFactor = 1.0 + (0.25 * @abs(wheel));
            if (wheel < 0) {
                scaleFactor = 1.0 / scaleFactor;
            }
            camera.zoom = rl.math.clamp(camera.zoom * scaleFactor, ZOOM_DEFAULT, ZOOM_MAX);
        }

        // Clamp to screen edges
        const min = rl.getWorldToScreen2D(.{ .x = 0, .y = 0 }, camera.*);
        const max = rl.getWorldToScreen2D(.{ .x = self.width, .y = self.height }, camera.*);

        if (min.x > 0) {
            camera.target.x = 0;
            camera.offset.x = 0;
        }
        if (min.y > 0) {
            camera.target.y = 0;
            camera.offset.y = 0;
        }
        if (max.x < self.width) {
            camera.offset.x += self.width - max.x;
        }
        if (max.y < self.height) {
            camera.offset.y += self.height - max.y;
        }
    }

    pub fn getGridPosFromMouse(self: *Camera, mouse_pos: rl.Vector2) Pos {
        const grid_mouse_pos = rl.Vector2.init(
            mouse_pos.x - BORDER_SIZE_LEFT,
            mouse_pos.y - BORDER_SIZE_TOP,
        );
        const world_pos = rl.getScreenToWorld2D(grid_mouse_pos, self.camera);

        const grid_x = @as(usize, @intFromFloat(world_pos.x));
        const grid_y = @as(usize, @intFromFloat(world_pos.y));

        return Pos{
            .row = @divFloor(grid_y, CELL_SIZE),
            .col = @divFloor(grid_x, CELL_SIZE),
        };
    }

    pub fn renderStart(self: *Camera) void {
        self.render_texture.begin();
        self.camera.begin();

        rl.clearBackground(rl.Color.white);
    }

    pub fn renderEnd(self: *Camera) void {
        self.camera.end();
        self.render_texture.end();
    }

    pub fn renderTexture(self: *Camera) void {
        rl.drawTextureRec(
            self.render_texture.texture,
            rl.Rectangle.init(
                0,
                0,
                self.width,
                -self.height,
            ),
            self.offset,
            rl.Color.white,
        );
    }
};
