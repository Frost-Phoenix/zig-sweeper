const std = @import("std");

const game = @import("game.zig");
const parseArgs = @import("args.zig").parseArgs;

// ***** //

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    const grid_spec = try parseArgs(allocator);

    try game.init(allocator, grid_spec);
    defer game.deinit(allocator);

    game.run();
}
