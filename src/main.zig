const std = @import("std");

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

    game.run();
}
