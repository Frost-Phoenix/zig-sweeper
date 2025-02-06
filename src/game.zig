const std = @import("std");
const Allocator = std.mem.Allocator;

const rl = @import("raylib");

const camera = @import("camera.zig");
const cell = @import("cell.zig");
const grid = @import("grid.zig");
const common = @import("common.zig");

const CELL_SIZE = common.CELL_SIZE;
const screenWidth = common.screenWidth;
const screenHeight = common.screenHeight;

const GameState = enum {
    play,
    lost,
};

var cam: rl.Camera2D = undefined;
var board: grid.Grid = undefined;
var cells_texture: rl.Texture2D = undefined;
var game_state: GameState = undefined;

pub fn init(allocator: Allocator) !void {
    cells_texture = try rl.loadTexture("res/cells.png");

    cam = camera.init();
    board = try grid.Grid.init(allocator, 20, 20);

    game_state = .play;
}

pub fn deinit(allocator: Allocator) void {
    rl.unloadTexture(cells_texture);
    board.deinit(allocator);
}

fn isMouseInBounds(pos: rl.Vector2) bool {
    return !(pos.x < 0 or pos.x >= screenWidth or pos.y < 0 or pos.y >= screenWidth);
}

fn updateMouse() void {
    const mouse_pos = rl.getMousePosition();
    const pos: rl.Vector2 = rl.getScreenToWorld2D(mouse_pos, cam);

    if (!isMouseInBounds(mouse_pos)) {
        board.closePressedCells();
        return;
    }

    if (rl.isMouseButtonDown(rl.MouseButton.left)) {
        board.pressCell(pos);
    } else if (rl.isMouseButtonReleased(rl.MouseButton.left)) {
        board.closePressedCells();
        board.openCell(pos);
    } else if (rl.isMouseButtonPressed(rl.MouseButton.right)) {
        board.flagCell(pos);
    }
}

fn updateKeyboard() void {
    if (rl.isKeyPressed(rl.KeyboardKey.r)) {
        camera.reset(&cam);
    }
}

fn updateInputs() void {
    updateKeyboard();
    updateMouse();
}

pub fn update() void {
    camera.updateCamera(&cam);
    updateInputs();
}

pub fn render() !void {
    rl.beginDrawing();
    defer rl.endDrawing();

    rl.clearBackground(rl.Color.gray);

    {
        cam.begin();
        defer cam.end();

        board.render(cells_texture);
    }

    if (game_state == .lost) {
        const text_size = rl.measureTextEx(try rl.getFontDefault(), "- Game Over -", 40, 5);
        const text_pos = rl.Vector2.init(screenWidth / 2 - text_size.x / 2, screenHeight / 2 - text_size.y / 2);
        rl.drawRectangle(
            @as(i32, @intFromFloat(text_pos.x - 10)),
            @as(i32, @intFromFloat(text_pos.y - 10)),
            @as(i32, @intFromFloat(text_size.x + 20)),
            @as(i32, @intFromFloat(text_size.y + 20)),
            rl.Color.black,
        );
        rl.drawTextEx(
            try rl.getFontDefault(),
            rl.textFormat("- Game Over -", .{}),
            text_pos,
            40,
            5,
            rl.Color.red,
        );
    }
}
