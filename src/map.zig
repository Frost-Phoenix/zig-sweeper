const rl = @import("raylib");

const Allocator = @import("std").mem.Allocator;

const CELL_SIZE = @import("common.zig").CELL_SIZE;

const Cell = packed struct(u8) {
    is_closed: bool,
    is_flagged: bool,
    is_pressed: bool,
    is_bomb: bool,
    number: u4,
};

pub const Grid = struct {
    grid: []Cell,
    nb_rows: usize,
    nb_cols: usize,

    pub fn init(allocator: Allocator, nb_rows: usize, nb_cols: usize) @This() {
        const grid = Grid{
            .grid = allocator.alloc(Cell, @intCast(nb_rows * nb_cols)) catch unreachable,
            .nb_rows = nb_rows,
            .nb_cols = nb_cols,
        };

        for (grid.grid) |*cell| {
            cell.* = Cell{
                .is_closed = true,
                .is_flagged = true,
                .is_pressed = false,
                .is_bomb = false,
                .number = 0,
            };
        }

        return grid;
    }

    pub fn deinit(self: *Grid, allocator: Allocator) void {
        allocator.free(self.grid);
    }

    fn getIndex(self: *Grid, row: usize, col: usize) usize {
        return row * self.nb_cols + col;
    }

    pub fn getCell(self: *Grid, row: usize, col: usize) *Cell {
        const idx = self.getIndex(row, col);

        return &self.grid[idx];
    }
};

var cells_texture: rl.Texture2D = undefined;
pub fn loadCellsTexture() void {
    cells_texture = rl.loadTexture("res/cells.png") catch unreachable;
}

pub fn deinit() void {
    rl.unloadTexture(cells_texture);
}

pub fn flagCell(grid: *Grid, row: i32, col: i32) void {
    _ = grid; // autofix
    _ = row; // autofix
    _ = col; // autofix
}

pub fn pressCell(grid: *Grid, row: i32, col: i32) void {
    _ = grid; // autofix
    _ = row; // autofix
    _ = col; // autofix

}
pub fn openCell(grid: *Grid, row: i32, col: i32) void {
    _ = grid; // autofix
    _ = row; // autofix
    _ = col; // autofix

}

fn getTextureOffset(cell: *Cell) i32 {
    if (cell.is_flagged) {
        return 2;
    } else if (cell.is_closed) {
        return 0;
    } else {
        return 5;
    }
}

pub fn render(grid: *Grid) void {
    for (0..grid.nb_rows) |row| {
        for (0..grid.nb_cols) |col| {
            const x = @as(f32, @floatFromInt(col * CELL_SIZE));
            const y = @as(f32, @floatFromInt(row * CELL_SIZE));

            const cell = grid.getCell(row, col);

            const offset = getTextureOffset(cell);
            const texture_offset = @as(f32, @floatFromInt(offset * CELL_SIZE));

            const srcRect = rl.Rectangle.init(texture_offset, 0, CELL_SIZE, CELL_SIZE);
            const destRect = rl.Vector2.init(x, y);

            rl.drawTextureRec(cells_texture, srcRect, destRect, rl.Color.white);
        }
    }
}
