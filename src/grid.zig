const std = @import("std");
const Allocator = std.mem.Allocator;

const Queue = @import("common.zig").Queue;

const GameState = @import("game.zig").GameState;

// ***** //

const DIRS = [_][2]i32{
    .{ 1, 1 },
    .{ 0, 1 },
    .{ -1, 1 },
    .{ -1, 0 },
    .{ -1, -1 },
    .{ 0, -1 },
    .{ 1, -1 },
    .{ 1, 0 },
};

pub const GridSpec = struct {
    nb_rows: usize,
    nb_cols: usize,
    nb_bombs: i32,

    pub const beginner: GridSpec = .{ .nb_rows = 9, .nb_cols = 9, .nb_bombs = 10 };
    pub const intermediate: GridSpec = .{ .nb_rows = 16, .nb_cols = 16, .nb_bombs = 40 };
    pub const expert: GridSpec = .{ .nb_rows = 16, .nb_cols = 30, .nb_bombs = 99 };
};

pub const Pos = struct {
    row: usize,
    col: usize,
};

pub const Cell = packed struct(u8) {
    is_closed: bool,
    is_flagged: bool,
    is_pressed: bool,
    is_bomb: bool,
    number: u4, // number = 0 => empty cell
};

pub const Grid = struct {
    cells: []Cell,
    nb_rows: usize,
    nb_cols: usize,
    nb_bombs: i32,
    nb_cells_opened: i32,
    nb_cells_flagged: i32,
    pressed_cells: [8]?*Cell,

    allocator: Allocator,

    pub fn init(allocator: Allocator, grid_spec: GridSpec) @This() {
        var grid: Grid = Grid{
            .cells = allocator.alloc(Cell, grid_spec.nb_rows * grid_spec.nb_cols) catch unreachable,
            .nb_rows = grid_spec.nb_rows,
            .nb_cols = grid_spec.nb_cols,
            .nb_bombs = grid_spec.nb_bombs,
            .nb_cells_opened = 0,
            .nb_cells_flagged = 0,
            .pressed_cells = undefined,

            .allocator = allocator,
        };

        grid.reset();

        return grid;
    }

    pub fn deinit(self: *Grid, allocator: Allocator) void {
        allocator.free(self.cells);
    }

    fn plantBombs(self: *Grid) void {
        // TODO: change this prng
        var prng = std.rand.DefaultPrng.init(blk: {
            var seed: u64 = undefined;
            std.posix.getrandom(std.mem.asBytes(&seed)) catch unreachable;
            break :blk seed;
        });
        const rand = prng.random();

        var nb_bomb_planted: i32 = 0;

        while (nb_bomb_planted < self.nb_bombs) {
            const pos = Pos{
                .row = rand.intRangeLessThan(usize, 0, self.nb_rows),
                .col = rand.intRangeLessThan(usize, 0, self.nb_cols),
            };

            const cell = self.getCell(pos);

            if (cell.is_bomb) continue;

            cell.is_bomb = true;

            self.incrementNeighbourCells(pos);

            nb_bomb_planted += 1;
        }
    }

    fn isInBound(self: *Grid, row: i32, col: i32) bool {
        return 0 <= row and row < self.nb_rows and 0 <= col and col < self.nb_cols;
    }

    fn incrementNeighbourCells(self: *Grid, bomb_pos: Pos) void {
        for (DIRS) |dir| {
            const row = @as(i32, @intCast(bomb_pos.row)) + dir[0];
            const col = @as(i32, @intCast(bomb_pos.col)) + dir[1];

            if (!self.isInBound(row, col)) continue;

            const cell = self.getCell(.{
                .row = @as(usize, @intCast(row)),
                .col = @as(usize, @intCast(col)),
            });

            cell.number += 1;
        }
    }

    fn getIdx(self: *Grid, pos: Pos) usize {
        // TODO: assert: test if pos in bound
        return self.nb_cols * pos.row + pos.col;
    }

    pub fn getCell(self: *Grid, pos: Pos) *Cell {
        const idx = self.getIdx(pos);

        return &self.cells[idx];
    }

    fn openConnectedEmptyCell(self: *Grid, start_pos: Pos) void {
        var queue = Queue(Pos).init(self.allocator);
        defer queue.deinit();

        queue.enqueue(start_pos);

        while (!queue.isEmpty()) {
            const pos = queue.dequeue() catch unreachable;

            for (DIRS) |dir| {
                const row = @as(i32, @intCast(pos.row)) + dir[0];
                const col = @as(i32, @intCast(pos.col)) + dir[1];

                if (!self.isInBound(row, col)) continue;

                const offset_pos = Pos{
                    .row = @as(usize, @intCast(row)),
                    .col = @as(usize, @intCast(col)),
                };

                const cell = self.getCell(offset_pos);

                if (!cell.is_closed or cell.is_flagged) continue;

                cell.is_closed = false;
                self.nb_cells_opened += 1;

                if (cell.number != 0) continue;

                queue.enqueue(offset_pos);
            }
        }
    }

    fn getNbConnectedFlags(self: *Grid, pos: Pos) i32 {
        var nb_flags: i32 = 0;

        for (DIRS) |dir| {
            const row = @as(i32, @intCast(pos.row)) + dir[0];
            const col = @as(i32, @intCast(pos.col)) + dir[1];

            if (!self.isInBound(row, col)) continue;

            const offset_cell = self.getCell(.{
                .row = @as(usize, @intCast(row)),
                .col = @as(usize, @intCast(col)),
            });

            if (offset_cell.is_flagged) {
                nb_flags += 1;
            }
        }

        return nb_flags;
    }

    pub fn openCell(self: *Grid, pos: Pos) GameState {
        const cell = self.getCell(pos);
        var res_game_state: GameState = .playing;

        if (cell.is_flagged) return res_game_state;

        if (cell.is_closed) {
            cell.is_closed = false;
            self.nb_cells_opened += 1;

            if (cell.is_bomb) {
                res_game_state = .lost;
                cell.is_pressed = true;
            } else if (cell.number == 0) {
                self.openConnectedEmptyCell(pos);
            }
        } else if (cell.number != 0) {
            const nb_flags = self.getNbConnectedFlags(pos);

            if (nb_flags == cell.number) {
                for (DIRS) |dir| {
                    const row = @as(i32, @intCast(pos.row)) + dir[0];
                    const col = @as(i32, @intCast(pos.col)) + dir[1];

                    if (!self.isInBound(row, col)) continue;

                    const offset_pos = .{
                        .row = @as(usize, @intCast(row)),
                        .col = @as(usize, @intCast(col)),
                    };

                    const offset_cell = self.getCell(offset_pos);

                    if (offset_cell.is_flagged or !offset_cell.is_closed) continue;

                    const game_state = self.openCell(offset_pos);

                    if (game_state == .lost) {
                        res_game_state = game_state;
                    }
                }
            }
        }

        if (self.nb_cells_opened == self.nb_cols * self.nb_rows - @as(usize, @intCast(self.nb_bombs))) {
            res_game_state = .win;
            self.flaggAllClosedBombs();
        }

        if (res_game_state == .lost) {
            self.openAllBombCells();
        }

        return res_game_state;
    }

    pub fn flaggAllClosedBombs(self: *Grid) void {
        self.nb_cells_flagged = self.nb_bombs;

        for (self.cells) |*cell| {
            if (!cell.is_bomb) continue;

            if (cell.is_closed) {
                cell.is_flagged = true;
            }
        }
    }

    pub fn openAllBombCells(self: *Grid) void {
        for (self.cells) |*cell| {
            if (!cell.is_bomb) continue;

            cell.is_closed = false;
        }
    }

    pub fn flaggCell(self: *Grid, pos: Pos) void {
        const cell = self.getCell(pos);

        if (!cell.is_closed) {
            return;
        }

        switch (cell.is_flagged) {
            true => {
                cell.is_flagged = false;
                self.nb_cells_flagged -= 1;
            },
            false => {
                cell.is_flagged = true;
                self.nb_cells_flagged += 1;
            },
        }
    }

    pub fn pressCell(self: *Grid, pos: Pos) void {
        self.unpressAll();

        const cell = self.getCell(pos);

        if (cell.is_flagged) return;

        if (cell.is_closed) {
            cell.is_pressed = true;
            self.pressed_cells[0] = cell;
            self.pressed_cells[1] = null;

            return;
        }

        var i: usize = 0;
        for (DIRS) |dir| {
            const row = @as(i32, @intCast(pos.row)) + dir[0];
            const col = @as(i32, @intCast(pos.col)) + dir[1];

            if (!self.isInBound(row, col)) continue;

            const offset_cell = self.getCell(.{
                .row = @as(usize, @intCast(row)),
                .col = @as(usize, @intCast(col)),
            });

            if (offset_cell.is_flagged or !offset_cell.is_closed) continue;

            offset_cell.is_pressed = true;
            self.pressed_cells[i] = offset_cell;

            i += 1;
        }

        if (i < self.pressed_cells.len) {
            self.pressed_cells[i] = null;
        }
    }

    pub fn getNbCellsFalgged(self: *Grid) i32 {
        return self.nb_cells_flagged;
    }

    pub fn getNbBombs(self: *Grid) i32 {
        return self.nb_bombs;
    }

    pub fn unpressAll(self: *Grid) void {
        for (self.pressed_cells) |cell| {
            if (cell) |c| {
                c.is_pressed = false;
            } else {
                break;
            }
        }
    }

    pub fn openAllCells(self: *Grid) void {
        self.nb_cells_flagged = self.nb_bombs;

        for (self.cells) |*cell| {
            if (cell.is_bomb) {
                cell.is_flagged = true;
                continue;
            }

            cell.is_flagged = false;
            cell.is_closed = false;
        }
    }

    pub fn reset(self: *Grid) void {
        self.nb_cells_opened = 0;
        self.nb_cells_flagged = 0;
        self.pressed_cells[0] = null;

        for (0..self.nb_rows * self.nb_cols) |idx| {
            self.cells[idx] = Cell{
                .is_closed = true,
                .is_flagged = false,
                .is_pressed = false,
                .is_bomb = false,
                .number = 0,
            };
        }

        self.plantBombs();
    }
};
