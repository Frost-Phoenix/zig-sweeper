const std = @import("std");
const rl = @import("raylib");

const game = @import("game.zig");
const CELL_SIZE = @import("common.zig").CELL_SIZE;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len != 5) {
        std.debug.print("Error: Expected exactly 4 positive integers (width, height, nb_bombs, scale)\n", .{});
        return error.InvalidArguments;
    }

    const width = try parseI32(args[1]);
    const height = try parseI32(args[2]);
    const nb_bombs = try parseI32(args[3]);
    const scale = try parseI32(args[4]);

    const screen_width = width * CELL_SIZE * scale;
    const screen_height = height * CELL_SIZE * scale;

    rl.initWindow(screen_width, screen_height, "Zig-sweeper");
    defer rl.closeWindow();

    rl.setTargetFPS(60);

    game.init(
        allocator,
        @as(usize, @intCast(width)),
        @as(usize, @intCast(height)),
        nb_bombs,
        scale,
    );
    defer game.deinit(allocator);

    while (!rl.windowShouldClose()) {
        game.update();
        game.render();
    }
}

fn parseI32(buff: []const u8) !i32 {
    return std.fmt.parseInt(i32, buff, 10);
}
