const rl = @import("raylib");
const std = @import("std");
const Allocator = @import("std").mem.Allocator;

const map = @import("map.zig");
const CELL_SIZE = @import("common.zig").CELL_SIZE;

const GameState = struct {
    state: enum {
        WIN,
        LOST,
        PLAYING,
    },

    scale: i32,
    width: usize,
    height: usize,
    nb_bombs: i32,
    nb_flags: i32,

    grid: map.Grid,
};

var game_state: GameState = undefined;
var grid: map.Grid = undefined;

pub fn init(allocator: Allocator, width: usize, height: usize, nb_bombs: i32, scale: i32) void {
    game_state = GameState{
        .state = .PLAYING,
        .scale = scale,
        .width = width,
        .height = height,
        .nb_bombs = nb_bombs,
        .nb_flags = 0,
        .grid = map.Grid.init(allocator, height, width),
    };
    map.loadCellsTexture();
}

pub fn deinit(allocator: Allocator) void {
    map.deinit();
    game_state.grid.deinit(allocator);
}

fn resizeWindow() void {
    const width = @as(i32, @intCast(game_state.width));
    const height = @as(i32, @intCast(game_state.height));
    const screenWidth = width * CELL_SIZE * game_state.scale;
    const screenHeight = height * CELL_SIZE * game_state.scale;

    rl.setWindowSize(screenWidth, screenHeight);
}

fn updateKeyboard() void {
    // Scale
    if (rl.isKeyPressed(.equal)) {
        game_state.scale = @min(game_state.scale + 1, 5);
        resizeWindow();
    } else if (rl.isKeyPressed(.minus)) {
        game_state.scale = @max(game_state.scale - 1, 1);
        resizeWindow();
    }
}

fn updateInputs() void {
    updateKeyboard();
}

pub fn update() void {
    updateInputs();
}

pub fn render() void {
    rl.beginDrawing();
    defer rl.endDrawing();

    rl.clearBackground(rl.Color.light_gray);

    map.render(&game_state.grid);
}
