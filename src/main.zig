const std = @import("std");
const printD = std.debug.print;

const rl = @import("raylib");
const Color = rl.Color;

const FPS = 60;
const CELL_SIZE = 16;

var screen_width: i32 = undefined;
var screen_height: i32 = undefined;

const Cell = packed struct(u8) {
    is_closed: bool,
    is_flagged: bool,
    is_pressed: bool,
    is_bomb: bool,
    number: u4, // number = 0 => empty cell
};

const Grid = struct {
    cells: []Cell,
    nb_rows: usize,
    nb_cols: usize,
    nb_bombs: i32,

    pub fn init(allocator: std.mem.Allocator, nb_rows: usize, nb_cols: usize, nb_bombs: i32) @This() {
        var grid: Grid = Grid{
            .cells = allocator.alloc(Cell, nb_rows * nb_cols) catch unreachable,
            .nb_rows = nb_rows,
            .nb_cols = nb_cols,
            .nb_bombs = nb_bombs,
        };

        for (0..nb_rows * nb_cols) |idx| {
            grid.cells[idx] = Cell{
                .is_closed = false,
                .is_flagged = false,
                .is_pressed = false,
                .is_bomb = false,
                .number = 0,
            };
        }

        grid.plantBombs();

        return grid;
    }

    pub fn deinit(self: *Grid, allocator: std.mem.Allocator) void {
        allocator.free(self.cells);
    }

    fn plantBombs(self: *Grid) void {
        // assert: nb_bombs <= nb_rows * nb_cols

        // TODO: change this prng
        var prng = std.rand.DefaultPrng.init(blk: {
            var seed: u64 = undefined;
            std.posix.getrandom(std.mem.asBytes(&seed)) catch unreachable;
            break :blk seed;
        });
        const rand = prng.random();

        var nb_bomb_planted: i32 = 0;

        while (nb_bomb_planted < self.nb_bombs) {
            const row = rand.intRangeLessThan(usize, 0, self.nb_rows);
            const col = rand.intRangeLessThan(usize, 0, self.nb_cols);

            const cell = self.getCell(row, col);

            if (cell.is_bomb) {
                continue;
            }

            cell.is_bomb = true;

            self.incrementNeighbourCells(row, col);

            nb_bomb_planted += 1;
        }
    }

    pub fn isInBound(self: *Grid, row: i32, col: i32) bool {
        return 0 <= row and row < self.nb_rows and 0 <= col and col < self.nb_cols;
    }

    fn incrementNeighbourCells(self: *Grid, bomb_row: usize, bomb_col: usize) void {
        const dirs = [_][2]i32{
            .{ 1, 1 },
            .{ 0, 1 },
            .{ -1, 1 },
            .{ -1, 0 },
            .{ -1, -1 },
            .{ 0, -1 },
            .{ 1, -1 },
            .{ 1, 0 },
        };

        for (dirs) |dir| {
            const row = @as(i32, @intCast(bomb_row)) + dir[0];
            const col = @as(i32, @intCast(bomb_col)) + dir[1];

            if (!self.isInBound(row, col)) continue;

            const cell = self.getCell(
                @as(usize, @intCast(row)),
                @as(usize, @intCast(col)),
            );

            cell.number += 1;
        }
    }

    fn getIdx(self: *Grid, row: usize, col: usize) usize {
        // assert: test if pos in bound
        return self.nb_cols * row + col;
    }

    pub fn getCell(self: *Grid, row: usize, col: usize) *Cell {
        const idx = self.getIdx(row, col);

        return &self.cells[idx];
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    const nb_rows: usize = 16;
    const nb_cols: usize = 30;
    const nb_bombs = 99;

    screen_width = @as(i32, @intCast(nb_cols)) * CELL_SIZE;
    screen_height = @as(i32, @intCast(nb_rows)) * CELL_SIZE;

    rl.initWindow(screen_width, screen_height, "zig-sweeper");
    defer rl.closeWindow();

    rl.setTargetFPS(FPS);

    const cell_texture: rl.Texture2D = try rl.loadTexture("res/cells.png");
    defer rl.unloadTexture(cell_texture);

    var grid: Grid = Grid.init(allocator, nb_rows, nb_cols, nb_bombs);
    defer grid.deinit(allocator);

    while (!rl.windowShouldClose()) {
        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(Color.gray);

        renderGrid(&grid, cell_texture);
    }
}

fn getCellTextureOffset(cell: *const Cell) usize {
    if (cell.is_flagged) return 2;
    if (cell.is_pressed) return 1;
    if (cell.is_closed) return 0;

    if (cell.is_bomb) return 3;
    if (cell.number == 0) return 1;

    return cell.number + 5;
}

fn renderGrid(grid: *Grid, cell_texture: rl.Texture2D) void {
    for (0..grid.nb_rows) |row| {
        for (0..grid.nb_cols) |col| {
            const x = @as(f32, @floatFromInt(col * CELL_SIZE));
            const y = @as(f32, @floatFromInt(row * CELL_SIZE));

            const cell = grid.getCell(row, col);

            const offset_idx = getCellTextureOffset(cell);
            const offset_px = @as(f32, @floatFromInt(offset_idx * CELL_SIZE));

            const src = rl.Rectangle.init(offset_px, 0, CELL_SIZE, CELL_SIZE);
            const dest = rl.Vector2.init(x, y);

            rl.drawTextureRec(cell_texture, src, dest, Color.white);
        }
    }
}
