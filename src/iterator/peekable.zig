const super = @import("lib.zig");

pub fn Peekable(comptime T: type) type {
    return struct {
        const Self = @This();

        iterator: *super.Iterator(T),
        next_val: ?T = null,

        pub fn next(self: *Self) ?T {
            if (self.next_val) |val| {
                self.next_val = null;
                return val;
            } else {
                return self.iterator.next();
            }
        }

        pub fn peek(self: *Self) ?T {
            if (self.next_val == null) {
                self.next_val = self.iterator.next();
            }

            return self.next_val;
        }
    };
}

pub fn PeekableBox(comptime T: type) type {
    return struct {
        const Self = @This();

        iterator: *super.IteratorBox(T),
        next_val: ?T = null,

        pub fn next(self: *Self) ?T {
            if (self.next_val) |val| {
                self.next_val = null;
                return val;
            } else {
                return self.iterator.next();
            }
        }

        pub fn peek(self: *Self) ?T {
            if (self.next_val == null) {
                self.next_val = self.iterator.next();
            }

            return self.next_val;
        }
    };
}
