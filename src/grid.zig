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

pub const Grid = struct {
    grid: []cell.Cell,

    nb_rows: u32,
    nb_cols: u32,

    last_pressed_cell: ?u32 = null,

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
                    // .state = .open,
                    .type = .empty,
                    .number = 3,
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

                if (offset_col < 0 or offset_row < 0 or offset_col >= self.nb_cols or offset_row >= self.nb_rows) {
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

    pub fn getIndex(self: *Grid, row: u32, col: u32) u32 {
        return self.nb_cols * row + col;
    }

    pub fn getIndexPixel(self: *Grid, pos: rl.Vector2) u32 {
        const row = @as(u32, @intFromFloat(pos.y / CELL_SIZE));
        const col = @as(u32, @intFromFloat(pos.x / CELL_SIZE));
        return self.nb_cols * row + col;
    }

    pub fn pressCell(self: *Grid, pos: rl.Vector2) void {
        const idx = self.getIndexPixel(pos);

        if (self.last_pressed_cell != null and idx != self.last_pressed_cell.?) {
            self.grid[self.last_pressed_cell.?].state = .closed;
        }

        if (self.grid[idx].state == .closed) {
            self.grid[idx].state = .pressed;
            self.last_pressed_cell = idx;
        }
    }

    pub fn closePressedCells(self: *Grid) void {
        if (self.last_pressed_cell) |c| {
            self.grid[c].state = .closed;
        }
        self.last_pressed_cell = null;
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

    pub fn openCell(self: *Grid, pos: rl.Vector2) void {
        const idx = self.getIndexPixel(pos);
        const c = &self.grid[idx];

        if (c.state == .flaged) {
            return;
        }

        self.grid[idx].state = .open;
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
