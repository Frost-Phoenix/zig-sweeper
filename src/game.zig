const std = @import("std");
const Allocator = std.mem.Allocator;

const rl = @import("raylib");
const Color = rl.Color;
const Vector2 = rl.Vector2;

const Pos = @import("grid.zig").Pos;
const Cell = @import("grid.zig").Cell;
const Grid = @import("grid.zig").Grid;
const GridSpec = @import("grid.zig").GridSpec;

const Camera = @import("camera.zig").Camera;

const loadTexture = @import("common.zig").loadTexture;
const CELL_SIZE = @import("common.zig").CELL_SIZE;

// ***** //

const FPS = 60;

pub const BORDER_SIZE_RIGHT = 8;
pub const BORDER_SIZE_LEFT = 12;
pub const BORDER_SIZE_TOP = 55;
pub const BORDER_SIZE_BOTTOM = 8;

const NUMBER_WIDTH = 13;
const NUMBER_HEIGHT = 23;
const BUTTON_SIZE = 24;

var screen_width: i32 = undefined;
var screen_height: i32 = undefined;

var camera: Camera = undefined;
var grid: Grid = undefined;
var game_state: GameState = undefined;
var game_time: f64 = 0;
var game_start_time: f64 = undefined;
var has_made_first_move: bool = false;
var button_state: ButtonState = undefined;

var cells_texture: rl.Texture2D = undefined;
var numbers_texture: rl.Texture2D = undefined;
var buttons_texture: rl.Texture2D = undefined;

pub const GameState = enum {
    playing,
    win,
    lost,
};

const ButtonState = enum {
    normal,
    pressed,
    cell_pressed,
    win,
    lost,
};

pub fn init(allocator: Allocator, grid_spec: GridSpec) !void {
    game_state = .playing;
    button_state = .normal;
    grid = Grid.init(allocator, grid_spec);

    initWindow(grid_spec.nb_rows, grid_spec.nb_cols);
    cells_texture = try loadTexture("cells_png");
    numbers_texture = try loadTexture("numbers_png");
    buttons_texture = try loadTexture("button_png");
    camera = try Camera.init(
        @intCast(grid_spec.nb_cols * CELL_SIZE),
        @intCast(grid_spec.nb_rows * CELL_SIZE),
        1,
        Vector2.init(BORDER_SIZE_LEFT, BORDER_SIZE_TOP),
    );
}

fn initWindow(nb_rows: usize, nb_cols: usize) void {
    screen_width = @as(i32, @intCast(nb_cols)) * CELL_SIZE + BORDER_SIZE_LEFT + BORDER_SIZE_RIGHT;
    screen_height = @as(i32, @intCast(nb_rows)) * CELL_SIZE + BORDER_SIZE_TOP + BORDER_SIZE_BOTTOM;

    rl.initWindow(screen_width, screen_height, "zig-sweeper");
}

pub fn deinit(allocator: Allocator) void {
    grid.deinit(allocator);

    rl.unloadTexture(cells_texture);
    rl.unloadTexture(numbers_texture);
    rl.unloadTexture(buttons_texture);
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
    if (game_state == .playing) updateGrid();
    camera.update();
    updateButton();
    updateKeyboard();
}

fn updateGrid() void {
    const mouse_pos = rl.getMousePosition();

    if (!mouseInsideGrid(mouse_pos)) {
        grid.unpressAll();
        return;
    }

    const pos = camera.getGridPosFromMouse(mouse_pos);

    if (rl.isMouseButtonPressed(.right)) {
        if (!has_made_first_move) {
            game_start_time = rl.getTime();
            has_made_first_move = true;
        }

        grid.flaggCell(pos);
    } else if (rl.isMouseButtonReleased(.left)) {
        if (!has_made_first_move) {
            game_start_time = rl.getTime();
            has_made_first_move = true;
        }

        grid.unpressAll();
        game_state = grid.openCell(pos);
    } else if (rl.isMouseButtonDown(.left)) {
        grid.pressCell(pos);
    }
}

fn mouseInsideGrid(mouse_pos: Vector2) bool {
    const x = @as(i32, @intFromFloat(mouse_pos.x));
    const y = @as(i32, @intFromFloat(mouse_pos.y));

    return BORDER_SIZE_LEFT <= x and
        BORDER_SIZE_TOP <= y and
        x < screen_width - BORDER_SIZE_RIGHT and
        y < screen_height - BORDER_SIZE_BOTTOM;
}

fn updateButton() void {
    const mouse_pos = rl.getMousePosition();

    if (isMouseOnButton(mouse_pos)) {
        if (rl.isMouseButtonDown(.left)) {
            button_state = .pressed;
        } else if (game_state == .playing) {
            button_state = .normal;
        }

        if (rl.isMouseButtonReleased(.left)) {
            resetGame();
        }
    } else if (game_state == .playing) {
        if (rl.isMouseButtonDown(.left) and mouseInsideGrid(mouse_pos)) {
            button_state = .cell_pressed;
        } else {
            button_state = .normal;
        }
    } else {
        if (game_state == .win) button_state = .win;
        if (game_state == .lost) button_state = .lost;
    }
}

fn isMouseOnButton(mouse_pos: Vector2) bool {
    const x = mouse_pos.x;
    const y = mouse_pos.y;

    const sw_f = @as(f32, @floatFromInt(screen_width));
    const sw_h = @divFloor(sw_f, 2);

    const start = Vector2.init(sw_h - 10, 16);
    const end = Vector2.init(sw_h - 10 + BUTTON_SIZE, 16 + BUTTON_SIZE);

    return start.x <= x and x <= end.x and start.y <= y and y <= end.y;
}

fn updateKeyboard() void {
    if (rl.isKeyPressed(.n)) {
        resetGame();
        camera.reset();
    }
    if (rl.isKeyPressed(.r)) {
        camera.reset();
    }
    if (rl.isKeyPressed(.o)) {
        grid.openAllCells();
        game_state = .win;
    }
}

fn resetGame() void {
    has_made_first_move = false;
    game_state = .playing;
    game_time = 0;
    grid.reset();
}

pub fn render() void {
    rl.beginDrawing();
    defer rl.endDrawing();

    renderBorders();
    renderBombCount();
    renderButton();
    renderTimer();
    {
        camera.renderStart();
        defer camera.renderEnd();
        renderGrid();
    }
}

fn renderBorders() void {
    const bg0 = rl.getColor(0x1D2021ff);
    const bg1 = Color.fromInt(0x282828ff);
    const fg0 = rl.getColor(0x504945ff);

    const sw = screen_width;
    const sh = screen_height;
    const sw_h = @divFloor(sw, 2);
    const sw_f = @as(f32, @floatFromInt(sw));
    const sh_f = @as(f32, @floatFromInt(sh));

    rl.clearBackground(bg1);

    // Main border
    rl.drawLineEx(Vector2.init(0, 2), Vector2.init(sw_f, 2), 3, fg0);
    rl.drawLineEx(Vector2.init(2, 0), Vector2.init(2, sh_f), 3, fg0);

    // Grid border
    rl.drawLineEx(Vector2.init(9, 54), Vector2.init(sw_f - 6, 54), 3, bg0);
    rl.drawLineEx(Vector2.init(11, 54), Vector2.init(11, sh_f - 6), 3, bg0);
    rl.drawLineEx(Vector2.init(10, sh_f - 6), Vector2.init(sw_f - 5, sh_f - 6), 3, fg0);
    rl.drawLineEx(Vector2.init(sw_f - 6, 53), Vector2.init(sw_f - 6, sh_f - 6), 3, fg0);
    rl.drawPixelV(Vector2.init(sw_f - 8, 53), bg0);
    rl.drawPixelV(Vector2.init(sw_f - 8, 54), bg1);
    rl.drawPixelV(Vector2.init(sw_f - 7, 53), bg1);
    rl.drawPixelV(Vector2.init(10, sh_f - 8), bg0);
    rl.drawPixelV(Vector2.init(11, sh_f - 8), bg1);
    rl.drawPixelV(Vector2.init(10, sh_f - 7), bg1);

    // Top box (nb_bombs, clock, button)
    rl.drawLineEx(Vector2.init(9, 10), Vector2.init(sw_f - 6, 10), 2, bg0);
    rl.drawLineEx(Vector2.init(10, 9), Vector2.init(10, 45), 2, bg0);
    rl.drawLineEx(Vector2.init(10, 45), Vector2.init(sw_f - 5, 45), 2, fg0);
    rl.drawLineEx(Vector2.init(sw_f - 6, 10), Vector2.init(sw_f - 6, 45), 2, fg0);
    rl.drawPixelV(Vector2.init(10, 44), bg1);
    rl.drawPixelV(Vector2.init(sw_f - 7, 10), bg1);

    // Button border
    rl.drawLine(sw_h - 11, 16, sw_h + 14, 16, bg0);
    rl.drawLine(sw_h - 10, 16, sw_h - 10, 40, bg0);
    rl.drawLine(sw_h - 10, 41, sw_h + 15, 41, bg0);
    rl.drawLine(sw_h + 15, 16, sw_h + 15, 41, bg0);

    // Bomb count border
    rl.drawLine(16, 15, 55 + 1, 15 + 1, bg0);
    rl.drawLine(16, 15, 16 + 1, 38 + 1, bg0);
    rl.drawLine(56, 16, 56 + 1, 39 + 1, fg0);
    rl.drawLine(17, 39, 56 + 1, 39 + 1, fg0);

    // Timer border
    rl.drawLine(sw - 54, 15, sw - 15, 15 + 1, bg0);
    rl.drawLine(sw - 54, 15, sw - 54, 38 + 1, bg0);
    rl.drawLine(sw - 54, 39, sw - 14, 39 + 1, fg0);
    rl.drawLine(sw - 15, 16, sw - 14, 39 + 1, fg0);
}

fn renderBombCount() void {
    const nb_bombs = grid.getNbBombs();
    const nb_flags = grid.getNbCellsFalgged();

    var number: f32 = @as(f32, @floatFromInt(nb_bombs - nb_flags));
    if (number > 999) number = 999;
    if (number < -99) number = -99;

    var texture_offsets: [3]f32 = undefined;

    if (number >= 0) {
        texture_offsets = .{
            @floor(@mod(number / 100, 10)),
            @floor(@mod(number / 10, 10)),
            @floor(@mod(number, 10)),
        };
    } else if (number > -10) {
        texture_offsets = .{
            11,
            10,
            @floor(@mod(@abs(number), 10)),
        };
    } else {
        texture_offsets = .{
            10,
            @floor(@mod(@abs(number) / 10, 10)),
            @floor(@mod(@abs(number), 10)),
        };
    }

    for (0..3) |i| {
        const offset = @as(f32, @floatFromInt(i));
        const texture_offset = texture_offsets[i] * NUMBER_WIDTH;

        const src = rl.Rectangle.init(texture_offset, 0, NUMBER_WIDTH, NUMBER_HEIGHT);
        const dest = Vector2.init(17 + offset * NUMBER_WIDTH, 16);

        rl.drawTextureRec(numbers_texture, src, dest, Color.white);
    }
}

fn renderButton() void {
    const sw_f = @as(f32, @floatFromInt(screen_width));
    const sw_h = @divFloor(sw_f, 2);

    const offset: i32 = @intCast(@intFromEnum(button_state));
    const texture_offset = @as(f32, @floatFromInt(offset * BUTTON_SIZE));

    const src = rl.Rectangle.init(texture_offset, 0, BUTTON_SIZE, BUTTON_SIZE);
    const dest = Vector2.init(sw_h - 10, 16);

    rl.drawTextureRec(buttons_texture, src, dest, Color.white);
}

fn renderTimer() void {
    const sw_f = @as(f32, @floatFromInt(screen_width));

    if (game_state == .playing and has_made_first_move) {
        game_time = rl.getTime() - game_start_time;
        if (game_time > 999) game_time = 999;
    }

    const texture_offsets = [_]f64{
        @floor(@mod(game_time / 100, 10)),
        @floor(@mod(game_time / 10, 10)),
        @floor(@mod(game_time, 10)),
    };

    for (0..3) |i| {
        const offset = @as(f32, @floatFromInt(i));
        var texture_offset: f32 = undefined;

        if (has_made_first_move) {
            texture_offset = @floatCast(texture_offsets[i]);
            texture_offset *= NUMBER_WIDTH;
        } else {
            texture_offset = 0;
        }

        const src = rl.Rectangle.init(texture_offset, 0, NUMBER_WIDTH, NUMBER_HEIGHT);
        const dest = Vector2.init(sw_f - 54 + offset * NUMBER_WIDTH, 16);

        rl.drawTextureRec(numbers_texture, src, dest, Color.white);
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
            const dest = Vector2.init(x, y);

            rl.drawTextureRec(cells_texture, src, dest, Color.white);
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
