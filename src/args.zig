const std = @import("std");
const Allocator = std.mem.Allocator;
const memEql = std.mem.eql;
const parseInt = std.fmt.parseInt;
const parseUnsigned = std.fmt.parseUnsigned;

const GridSpec = @import("grid.zig").GridSpec;

// ***** //

const CustomGridError = error{
    ToManyBombs,
    SizeOutOfRange,
    WrongArgumentType,
};

pub fn parseArgs(allocator: Allocator) !GridSpec {
    // TODO: add min and max size + check nb bombs
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (!(args.len == 2 or args.len == 5)) {
        exitError();
    }

    if (memEql(u8, args[1], "-h") or memEql(u8, args[1], "--help")) {
        exitSuccess();
    }

    if (args.len == 2) {
        if (memEql(u8, args[1], "beginner")) return GridSpec.beginner;
        if (memEql(u8, args[1], "intermediate")) return GridSpec.intermediate;
        if (memEql(u8, args[1], "expert")) return GridSpec.expert;
    } else {
        return initCustomGrid(args) catch {
            exitError();
            unreachable;
        };
    }

    exitError();

    unreachable;
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
        \\Usage: zig-sweeper [difficulty] [options]
        \\
        \\Difficulties:
        \\
        \\  beginner         9x9  with 10 bombs
        \\  intermediate    16x16 with 40 bombs
        \\  expert          30x16 with 99 bombs
        \\
        \\  custom <nb_cols> <nb_rows> <nb_bombs>
        \\
        \\Options:
        \\
        \\  nb_cols         between 5 and 115
        \\  nb_rows         between 5 and  70
        \\  nb_bombs        must be less that total number of cells
        \\
        \\General Options:
        \\
        \\  -h, --help      Print this help message and exit
    ) catch unreachable;
    writer.writeAll("\n") catch unreachable;
}
