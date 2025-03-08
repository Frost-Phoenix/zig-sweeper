const Allocator = @import("std").mem.Allocator;

const rl = @import("raylib");

// ***** //

pub const CELL_SIZE = 16;

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

        gpa: Allocator,
        start: ?*Node,
        end: ?*Node,

        pub fn init(allocator: Allocator) This {
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

        pub fn enqueue(self: *This, val: T) void {
            const node = self.gpa.create(Node) catch @panic("Can't allocate memory");
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

pub fn loadTexture(comptime texture_name: []const u8) !rl.Texture2D {
    const texture_data = @embedFile(texture_name);
    const image = try rl.loadImageFromMemory(".png", texture_data);

    return try rl.loadTextureFromImage(image);
}
