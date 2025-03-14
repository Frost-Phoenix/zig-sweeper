const std = @import("std");
const Allocator = std.mem.Allocator;
const memEql = std.mem.eql;
const parseInt = std.fmt.parseInt;
const parseUnsigned = std.fmt.parseUnsigned;

const GridSpec = @import("grid.zig").GridSpec;
const GameSpec = @import("game.zig").GameSpec;

// ***** //

const DEFAULT_SCALE = 2;

pub fn parseArgs(allocator: Allocator) !GameSpec {
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (!(args.len == 2 or args.len == 5)) {
        exitError();
    }

    if (memEql(u8, args[1], "-h") or memEql(u8, args[1], "--help")) {
        exitSuccess();
    }

    var game_spec: GameSpec = GameSpec{
        .grid_spec = undefined,
        .scale = DEFAULT_SCALE, // default scale
    };

    if (args.len == 2) {
        const grid_spec = getGridDifficulty(args[1]);

        if (grid_spec) |val| {
            game_spec.grid_spec = val;
        } else {
            exitError();
        }

        return game_spec;
    } else {
        game_spec.grid_spec = initCustomGrid(args) catch {
            exitError();
            unreachable;
        };
        return game_spec;
    }

    exitError();

    unreachable;
}

fn getGridDifficulty(difficulty: []const u8) ?GridSpec {
    if (memEql(u8, difficulty, "beginner")) return GridSpec.beginner;
    if (memEql(u8, difficulty, "intermediate")) return GridSpec.intermediate;
    if (memEql(u8, difficulty, "expert")) return GridSpec.expert;

    return null;
}

fn initCustomGrid(args: [][]u8) !GridSpec {
    const nb_cols = try parseUnsigned(usize, args[2], 10);
    const nb_rows = try parseUnsigned(usize, args[3], 10);
    const nb_bombs = try parseInt(i32, args[4], 10);

    if (!(5 <= nb_rows and nb_rows <= 70)) return error.SizeOutOfRange;
    if (!(5 <= nb_cols and nb_cols <= 115)) return error.SizeOutOfRange;
    if (nb_bombs > nb_rows * nb_cols) return error.ToManyBombs;

    return GridSpec{
        .nb_cols = nb_cols,
        .nb_rows = nb_rows,
        .nb_bombs = nb_bombs,
    };
}

fn exitError() void {
    const stderr = std.io.getStdErr();
    printHelp(stderr);
    std.process.exit(1);
}

fn exitSuccess() void {
    const stdout = std.io.getStdOut();
    printHelp(stdout);
    std.process.exit(0);
}

fn printHelp(writer: std.fs.File) void {
    writer.writeAll(
        \\Usage: zig-sweeper [difficulty] [custom_grid_options] [options]
        \\
        \\Difficulties:
        \\
        \\  beginner                 9x9  with 10 bombs
        \\  intermediate            16x16 with 40 bombs
        \\  expert                  30x16 with 99 bombs
        \\
        \\  custom <nb_cols> <nb_rows> <nb_bombs>
        \\
        \\Custom grid options:
        \\
        \\  <nb_cols>               between 5 and 115
        \\  <nb_rows>               between 5 and  70
        \\  <nb_bombs>              must be less that total number of cells
        \\
        \\General Options:
        \\
        \\  -s, --scale <amount>    Set window scale (default 2)
        \\  -h, --help              Print this help message and exit
        \\
        \\Keybinds:
        \\
        \\  <ESQ>                   Quit
        \\   <n>                    Generate new grid
        \\   <o>                    Open all cells
        \\   <r>                    Reset grid zoom and position
        \\
        \\Mouse:
        \\
        \\  left click              Open cell
        \\  right click             Flag cell
        \\  middle click            Drag grid when zoomed in
        \\  wheel scroll            Zoom grid in/out
    ) catch unreachable;
    writer.writeAll("\n") catch unreachable;
}
