const std = @import("std");
const Iterator = @import("iterator").Iterator;

test "peekable" {
    const Iter = struct {
        const Self = @This();

        index: usize = 0,
        iterator: Iterator(usize) = .{ .nextFn = next, .methods = .{ .resetFn = reset } },
        items: *const [4]usize = &.{ 2, 5, 8, 1000 },

        fn next(iter: *Iterator(usize)) ?usize {
            const self = iter.cast(Self);
            defer self.index += 1;
            if (self.items.len <= self.index) {
                return null;
            } else {
                return self.items[self.index];
            }
        }

        fn reset(iter: *Iterator(usize)) void {
            const self = iter.cast(Self);
            self.index = 0;
        }
    };

    var iter = Iter{};
    var peekable = iter.iterator.peekable();

    try std.testing.expectEqual(2, peekable.peek());
    try std.testing.expectEqual(2, peekable.peek());
    try std.testing.expectEqual(2, peekable.next());
}
