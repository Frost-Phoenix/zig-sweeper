const std = @import("std");
const print = std.debug.print;

const rl = @import("raylib");
const Color = rl.Color;

pub fn Queue(comptime T: type) type {
    return struct {
        const This = @This();

        const QueueError = error{
            QueueEmpty,
        };

        const Node = struct {
            data: T,
            next: ?*Node,
        };

        gpa: std.mem.Allocator,
        start: ?*Node,
        end: ?*Node,

        pub fn init(allocator: std.mem.Allocator) This {
            return This{
                .gpa = allocator,
                .start = null,
                .end = null,
            };
        }

        pub fn deinit(self: *This) void {
            var node = self.start;

            while (node != null) {
                const tmp = node.?;
                node = node.?.next;
                self.gpa.destroy(tmp);
            }
        }

        pub fn enqueue(self: *This, val: T) !void {
            const node = try self.gpa.create(Node);
            node.* = .{
                .data = val,
                .next = null,
            };

            if (self.end) |end| {
                end.next = node;
            } else {
                self.start = node;
            }

            self.end = node;
        }

        pub fn dequeue(self: *This) QueueError!T {
            if (self.isEmpty()) {
                return QueueError.QueueEmpty;
            }

            const head = self.start.?;
            defer self.gpa.destroy(head);

            if (head.next) |next| {
                self.start = next;
            } else {
                self.start = null;
                self.end = null;
            }

            return head.data;
        }

        pub fn isEmpty(self: *This) bool {
            return self.start == null;
        }
    };
}

const FPS = 60;
const CELL_SIZE = 16;

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

var screen_width: i32 = undefined;
var screen_height: i32 = undefined;

var game_state: GameState = undefined;

const GameState = enum {
    playing,
    win,
    lost,
};

const Pos = struct {
    row: usize,
    col: usize,
};

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
    nb_open_cells: i32,

    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, nb_rows: usize, nb_cols: usize, nb_bombs: i32) @This() {
        var grid: Grid = Grid{
            .cells = allocator.alloc(Cell, nb_rows * nb_cols) catch unreachable,
            .nb_rows = nb_rows,
            .nb_cols = nb_cols,
            .nb_bombs = nb_bombs,
            .nb_open_cells = 0,

            .allocator = allocator,
        };

        for (0..nb_rows * nb_cols) |idx| {
            grid.cells[idx] = Cell{
                .is_closed = true,
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
        // assert: test if pos in bound
        return self.nb_cols * pos.row + pos.col;
    }

    pub fn getCell(self: *Grid, pos: Pos) *Cell {
        const idx = self.getIdx(pos);

        return &self.cells[idx];
    }

    fn openConnectedEmptyCell(self: *Grid, start_pos: Pos) !void {
        var queue = Queue(Pos).init(self.allocator);
        defer queue.deinit();

        try queue.enqueue(start_pos);

        while (!queue.isEmpty()) {
            const pos = try queue.dequeue();

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
                self.nb_open_cells += 1;

                if (cell.number != 0) continue;

                try queue.enqueue(offset_pos);
            }
        }
    }

    pub fn openCell(self: *Grid, pos: Pos) !void {
        const cell = self.getCell(pos);

        if (cell.is_flagged or !cell.is_closed) {
            return;
        }

        cell.is_closed = false;
        self.nb_open_cells += 1;

        if (cell.is_bomb) {
            game_state = .lost;
            return;
        } else if (cell.number == 0) {
            try self.openConnectedEmptyCell(pos);
        }

        if (self.nb_open_cells == self.nb_cols * self.nb_rows - @as(usize, @intCast(self.nb_bombs))) {
            game_state = .win;
        }
    }

    pub fn flaggCell(self: *Grid, pos: Pos) void {
        const cell = self.getCell(pos);

        if (!cell.is_closed) {
            return;
        }

        cell.is_flagged = !cell.is_flagged;
    }

    pub fn pressCell(self: *Grid, pos: Pos) void {
        _ = self; // autofix
        _ = pos; // autofix
    }

    pub fn reset(self: *Grid) void {
        self.nb_open_cells = 0;

        for (0..self.nb_rows * self.nb_cols) |idx| {
            const cell = &self.cells[idx];

            cell.is_closed = true;
            cell.is_flagged = false;
            cell.is_pressed = false;
            cell.is_bomb = false;
            cell.number = 0;
        }

        self.plantBombs();
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    const nb_rows: usize = 16;
    const nb_cols: usize = 30;
    const nb_bombs = 25;

    game_state = .playing;

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
        // Update
        try update(&grid);

        // Render
        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(Color.gray);

        renderGrid(&grid, cell_texture);

        if (game_state == .playing) continue;

        const rect = rl.Rectangle.init(
            @as(f32, @floatFromInt(@divFloor(screen_width, 2) - 100)),
            @as(f32, @floatFromInt(@divFloor(screen_height, 2) - 30)),
            200,
            60,
        );
        rl.drawRectangleRec(rect, Color.black);

        const txt = switch (game_state) {
            .lost => "You lose",
            .win => "You win !",
            else => unreachable,
        };

        rl.drawText(
            txt,
            @divFloor(screen_width, 2) - 43,
            @divFloor(screen_height, 2) - 15,
            20,
            Color.white,
        );

        rl.drawText(
            "<R> to replay",
            @divFloor(screen_width, 2) - 33,
            @divFloor(screen_height, 2) + 10,
            10,
            Color.white,
        );
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

            const cell = grid.getCell(.{ .row = row, .col = col });

            const offset_idx = getCellTextureOffset(cell);
            const offset_px = @as(f32, @floatFromInt(offset_idx * CELL_SIZE));

            const src = rl.Rectangle.init(offset_px, 0, CELL_SIZE, CELL_SIZE);
            const dest = rl.Vector2.init(x, y);

            rl.drawTextureRec(cell_texture, src, dest, Color.white);
        }
    }
}

fn update(grid: *Grid) !void {
    if (game_state == .playing) {
        try updateMouse(grid);
    }

    updateKeyboard(grid);
}

fn getPosFromMousePos(mouse_pos: rl.Vector2) Pos {
    return Pos{
        .row = @divFloor(@as(usize, @intFromFloat(mouse_pos.y)), CELL_SIZE),
        .col = @divFloor(@as(usize, @intFromFloat(mouse_pos.x)), CELL_SIZE),
    };
}

fn updateMouse(grid: *Grid) !void {
    const mouse_pos = rl.getMousePosition();
    const pos = getPosFromMousePos(mouse_pos);

    if (rl.isMouseButtonReleased(.left)) {
        try grid.openCell(pos);
    } else if (rl.isMouseButtonReleased(.right)) {
        grid.flaggCell(pos);
    }
}

fn updateKeyboard(grid: *Grid) void {
    if (rl.isKeyPressed(.r)) {
        game_state = .playing;
        grid.reset();
    }
}
