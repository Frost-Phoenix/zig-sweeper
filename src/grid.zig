const std = @import("std");
const Allocator = std.mem.Allocator;

const rl = @import("raylib");

const cell = @import("cell.zig");
const common = @import("common.zig");
const CELL_SIZE = common.CELL_SIZE;

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

var last_pressed_cells: [8]?usize = .{null} ** 8;

pub const Grid = struct {
    grid: []cell.Cell,

    nb_rows: u32,
    nb_cols: u32,

    pub fn init(allocator: Allocator, nb_rows: u32, nb_cols: u32) !Grid {
        var grid: Grid = .{
            .nb_rows = nb_rows,
            .nb_cols = nb_cols,
            .grid = try allocator.alloc(cell.Cell, nb_rows * nb_cols),
        };

        for (0..nb_rows) |row| {
            for (0..nb_cols) |col| {
                const idx = getIndex(&grid, @intCast(row), @intCast(col));
                grid.grid[idx] = .{
                    .state = .closed,
                    .type = .empty,
                    .number = null,
                    .row = @intCast(row),
                    .col = @intCast(col),
                };
            }
        }

        try plantBombs(&grid, 100);

        return grid;
    }

    fn plantBombs(self: *Grid, nb_bombs: u32) !void {
        var seed: u64 = undefined;
        try std.posix.getrandom(std.mem.asBytes(&seed));
        var prng = std.rand.DefaultPrng.init(seed);
        const rand = prng.random();

        var nb_bomb_planted: u32 = 0;
        while (nb_bomb_planted < nb_bombs) {
            const row = rand.intRangeLessThan(u32, 0, self.nb_rows);
            const col = rand.intRangeLessThan(u32, 0, self.nb_cols);

            const idx = getIndex(self, row, col);

            if (self.grid[idx].type == .bomb) {
                continue;
            }

            self.grid[idx].type = .bomb;

            for (dirs) |dir| {
                const offset_row = @as(i32, @intCast(row)) + dir[0];
                const offset_col = @as(i32, @intCast(col)) + dir[1];

                if (!self.isPosInBounds(offset_row, offset_col)) {
                    continue;
                }

                var c: *cell.Cell = &self.grid[getIndex(self, @as(u32, @intCast(offset_row)), @as(u32, @intCast(offset_col)))];

                switch (c.type) {
                    .bomb => continue,
                    .empty => {
                        c.type = .number;
                        c.number = 1;
                    },
                    .number => c.number.? += 1,
                    else => unreachable,
                }
            }

            nb_bomb_planted += 1;
        }
    }

    pub fn deinit(self: *Grid, allocator: Allocator) void {
        allocator.free(self.grid);
    }

    pub fn getIndex(self: *Grid, row: u32, col: u32) usize {
        return self.nb_cols * row + col;
    }

    pub fn getIndexPixel(self: *Grid, pos: rl.Vector2) usize {
        const row = @as(u32, @intFromFloat(pos.y / CELL_SIZE));
        const col = @as(u32, @intFromFloat(pos.x / CELL_SIZE));
        return self.nb_cols * row + col;
    }

    fn getPosFromIndex(self: *Grid, idx: usize) rl.Vector2 {
        const col = idx % self.nb_cols;
        const row = (idx - col) / self.nb_rows;

        return rl.Vector2{
            .x = @as(f32, @floatFromInt(col)),
            .y = @as(f32, @floatFromInt(row)),
        };
    }

    fn isPosInBounds(self: *Grid, row: i32, col: i32) bool {
        return !(col < 0 or row < 0 or col >= self.nb_cols or row >= self.nb_rows);
    }

    pub fn pressCell(self: *Grid, pos: rl.Vector2) void {
        self.closePressedCells();

        const idx = self.getIndexPixel(pos);
        const c = &self.grid[idx];

        if (c.state == .closed) {
            c.state = .pressed;
            last_pressed_cells[0] = idx;
        } else if (c.state == .open and c.type == .number) {
            const cords = self.getPosFromIndex(idx);
            const row = @as(i32, @intFromFloat(cords.y));
            const col = @as(i32, @intFromFloat(cords.x));

            for (dirs, 0..) |dir, i| {
                const offset_row = row + dir[0];
                const offset_col = col + dir[1];

                if (!self.isPosInBounds(offset_row, offset_col)) {
                    continue;
                }

                const offset_idx = self.getIndex(@as(u32, @intCast(offset_row)), @as(u32, @intCast(offset_col)));
                var offset_cell = &self.grid[offset_idx];

                if (offset_cell.state != .closed) continue;
                offset_cell.state = .pressed;
                last_pressed_cells[i] = offset_idx;
            }
        }
    }

    pub fn closePressedCells(self: *Grid) void {
        for (last_pressed_cells) |last_cell| {
            if (last_cell == null) continue;
            self.grid[last_cell.?].state = .closed;
        }
        last_pressed_cells = .{null} ** last_pressed_cells.len;
    }

    pub fn flagCell(self: *Grid, pos: rl.Vector2) void {
        const idx = self.getIndexPixel(pos);
        const c = &self.grid[idx];

        c.state = switch (c.state) {
            .flaged => .closed,
            .closed => .flaged,
            else => c.state,
        };
    }

    fn getNbAdjacentFlags(self: *Grid, row: i32, col: i32) u32 {
        var nb_flags: u32 = 0;

        for (dirs) |dir| {
            const offset_row = row + dir[0];
            const offset_col = col + dir[1];

            if (!self.isPosInBounds(offset_row, offset_col)) {
                continue;
            }

            const offset_idx = self.getIndex(@as(u32, @intCast(offset_row)), @as(u32, @intCast(offset_col)));
            const offset_cell = &self.grid[offset_idx];

            if (offset_cell.state == .flaged) {
                nb_flags += 1;
            }
        }

        return nb_flags;
    }

    pub fn openCell(self: *Grid, pos: rl.Vector2) void {
        const idx = self.getIndexPixel(pos);
        const c = &self.grid[idx];

        if (c.state == .closed) {
            c.state = .open;
        }
        if (c.type != .number) return;

        const cords = self.getPosFromIndex(idx);
        const row = @as(i32, @intFromFloat(cords.y));
        const col = @as(i32, @intFromFloat(cords.x));

        const nb_flaged = self.getNbAdjacentFlags(row, col);

        if (nb_flaged != c.number.?) return;

        for (dirs) |dir| {
            const offset_row = row + dir[0];
            const offset_col = col + dir[1];

            if (!self.isPosInBounds(offset_row, offset_col)) {
                continue;
            }

            const offset_idx = self.getIndex(@as(u32, @intCast(offset_row)), @as(u32, @intCast(offset_col)));
            var offset_cell = &self.grid[offset_idx];

            if (offset_cell.state == .closed) {
                offset_cell.state = .open;
            }
        }
    }

    pub fn render(self: *Grid, cells_texture: rl.Texture2D) void {
        for (self.grid) |c| {
            const x = @as(f32, @floatFromInt(c.col * CELL_SIZE));
            const y = @as(f32, @floatFromInt(c.row * CELL_SIZE));

            const offset = switch (c.state) {
                .closed => 0,
                .pressed => 1,
                .flaged => 2,
                .open => switch (c.type) {
                    .empty => 1,
                    .bomb => 3,
                    .clicked_bomb => 4,
                    .false_bomb => 4,
                    .number => c.number.? + 5,
                },
            };
            const texture_offset = @as(f32, @floatFromInt(offset * CELL_SIZE));

            const srcRect = rl.Rectangle.init(texture_offset, 0, CELL_SIZE, CELL_SIZE);
            const destRect = rl.Rectangle.init(x, y, CELL_SIZE, CELL_SIZE);

            rl.drawTexturePro(cells_texture, srcRect, destRect, rl.Vector2.init(0, 0), 0, rl.Color.white);
        }
    }
};
