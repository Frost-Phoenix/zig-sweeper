const std = @import("std");
const print = std.debug.print;

const rl = @import("raylib");
const Color = rl.Color;

const CELL_SIZE = @import("common.zig").CELL_SIZE;

const game = @import("game.zig");

// ***** //

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    const nb_rows: usize = 16;
    const nb_cols: usize = 30;
    const nb_bombs = 99;

    try game.init(allocator, nb_rows, nb_cols, nb_bombs);
    defer game.deinit(allocator);

    try game.run();
}
