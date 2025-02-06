pub const CellState = enum {
    open,
    closed,
    flaged,
    pressed,
};
pub const CellType = enum {
    bomb,
    clicked_bomb,
    false_bomb,
    empty,
    number,
};
pub const Cell = struct {
    type: CellType,
    state: CellState,
    number: ?u8,

    row: u32,
    col: u32,

    pub fn init(_type: CellType, _number: ?u8) Cell {
        return Cell{
            .type = _type,
            .state = CellState.closed,
            .number = _number,
        };
    }
};
