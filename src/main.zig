const std = @import("std");
const rl = @import("raylib");

const common = @import("common.zig");
const game = @import("game.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    rl.initWindow(common.screenWidth, common.screenHeight, "zig-sweeper");
    defer rl.closeWindow();

    rl.setTargetFPS(60);

    try game.init(allocator);
    defer game.deinit(allocator);

    while (!rl.windowShouldClose()) {
        game.update();
        game.render();
    }
}
