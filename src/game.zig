const std = @import("std");
const Allocator = std.mem.Allocator;

const rl = @import("raylib");
const Color = rl.Color;

const Pos = @import("grid.zig").Pos;
const Cell = @import("grid.zig").Cell;
const Grid = @import("grid.zig").Grid;
const GridSpec = @import("grid.zig").GridSpec;

const loadTexture = @import("common.zig").loadTexture;
const CELL_SIZE = @import("common.zig").CELL_SIZE;

// ***** //

const FPS = 60;

var screen_width: i32 = undefined;
var screen_height: i32 = undefined;

var grid: Grid = undefined;
var game_state: GameState = undefined;
var cell_texture: rl.Texture2D = undefined;

pub const GameState = enum {
    playing,
    win,
    lost,
};

pub fn init(allocator: Allocator, grid_spec: GridSpec) !void {
    game_state = .playing;
    grid = Grid.init(allocator, grid_spec);

    initWindow(grid_spec.nb_rows, grid_spec.nb_cols);
    cell_texture = try loadTexture("cells_png");
}

fn initWindow(nb_rows: usize, nb_cols: usize) void {
    screen_width = @as(i32, @intCast(nb_cols)) * CELL_SIZE;
    screen_height = @as(i32, @intCast(nb_rows)) * CELL_SIZE;

    rl.initWindow(screen_width, screen_height, "zig-sweeper");
}

pub fn deinit(allocator: Allocator) void {
    grid.deinit(allocator);

    rl.unloadTexture(cell_texture);
    rl.closeWindow();
}

pub fn run() void {
    rl.setTargetFPS(FPS);

    while (!rl.windowShouldClose()) {
        update();
        render();
    }
}

pub fn update() void {
    if (game_state == .playing) {
        updateMouse();
    }

    updateKeyboard();
}

fn updateMouse() void {
    const mouse_pos = rl.getMousePosition();

    if (!mouseInsideWindow(mouse_pos)) {
        grid.unpressAll();
        return;
    }

    const pos = getPosFromMousePos(mouse_pos);

    if (rl.isMouseButtonPressed(.right)) {
        grid.flaggCell(pos);
    } else if (rl.isMouseButtonReleased(.left)) {
        grid.unpressAll();
        game_state = grid.openCell(pos);
    } else if (rl.isMouseButtonDown(.left)) {
        grid.pressCell(pos);
    }
}

fn getPosFromMousePos(mouse_pos: rl.Vector2) Pos {
    return Pos{
        .row = @divFloor(@as(usize, @intFromFloat(mouse_pos.y)), CELL_SIZE),
        .col = @divFloor(@as(usize, @intFromFloat(mouse_pos.x)), CELL_SIZE),
    };
}

fn mouseInsideWindow(mouse_pos: rl.Vector2) bool {
    const x = @as(i32, @intFromFloat(mouse_pos.x));
    const y = @as(i32, @intFromFloat(mouse_pos.y));

    return 0 <= x and x < screen_width and 0 <= y and y < screen_height;
}

fn updateKeyboard() void {
    if (rl.isKeyPressed(.r)) {
        game_state = .playing;
        grid.reset();
    }
}

pub fn render() void {
    rl.beginDrawing();
    defer rl.endDrawing();

    rl.clearBackground(Color.gray);

    renderGrid();

    if (game_state != .playing) {
        renderEndMessage();
    }
}

fn renderGrid() void {
    for (0..grid.nb_rows) |row| {
        for (0..grid.nb_cols) |col| {
            const x = @as(f32, @floatFromInt(col * CELL_SIZE));
            const y = @as(f32, @floatFromInt(row * CELL_SIZE));

            const cell = grid.getCell(.{ .row = row, .col = col });

            const offset_idx = getCellTextureOffset(cell);
            const offset_px = @as(f32, @floatFromInt(offset_idx * CELL_SIZE));

            const src = rl.Rectangle.init(offset_px, 0, CELL_SIZE, CELL_SIZE);
            const dest = rl.Vector2.init(x, y);

            rl.drawTextureRec(cell_texture, src, dest, Color.white);
        }
    }
}

fn getCellTextureOffset(cell: *const Cell) usize {
    if (game_state == .lost) {
        if (cell.is_flagged and !cell.is_bomb) return 5;
        if (cell.is_bomb and cell.is_pressed) return 4;
    }

    if (cell.is_flagged) return 2;
    if (cell.is_pressed) return 1;
    if (cell.is_closed) return 0;

    if (cell.is_bomb) return 3;
    if (cell.number == 0) return 1;

    return cell.number + 5;
}

fn renderEndMessage() void {
    const rect = rl.Rectangle.init(
        @as(f32, @floatFromInt(@divFloor(screen_width, 2) - 100)),
        @as(f32, @floatFromInt(@divFloor(screen_height, 2) - 30)),
        200,
        60,
    );
    rl.drawRectangleRec(rect, Color.black);

    const txt = switch (game_state) {
        .lost => "You lose",
        .win => "You win !",
        else => unreachable,
    };

    rl.drawText(
        txt,
        @divFloor(screen_width, 2) - 43,
        @divFloor(screen_height, 2) - 15,
        20,
        Color.white,
    );

    rl.drawText(
        "<R> to replay",
        @divFloor(screen_width, 2) - 33,
        @divFloor(screen_height, 2) + 10,
        10,
        Color.white,
    );
}
