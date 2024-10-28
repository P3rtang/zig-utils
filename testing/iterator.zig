const std = @import("std");
const Iterator = @import("iterator").Iterator;

test "map" {
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
    try std.testing.expectEqual(2, iter.iterator.next());
    try std.testing.expectEqual(5, iter.iterator.next());
    try std.testing.expectEqual(8, iter.iterator.next());
    try std.testing.expectEqual(1000, iter.iterator.next());
    iter.iterator.reset();

    var map_iter = iter.iterator.map(usize, struct {
        fn call(in: usize) usize {
            return in * 2;
        }
    }.call);
    try std.testing.expectEqual(4, map_iter.iterator.next());
    try std.testing.expectEqual(10, map_iter.iterator.next());
    try std.testing.expectEqual(16, map_iter.iterator.next());
    try std.testing.expectEqual(2000, map_iter.iterator.next());
}

test "collect" {
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
    const list = try iter.iterator.collect(std.testing.allocator);
    defer list.deinit();

    var expected: [4]usize = .{ 2, 5, 8, 1000 };
    try std.testing.expectEqualDeep(&expected, list.items[0..4]);

    iter.iterator.reset();
    try std.testing.expectEqual(2, iter.iterator.next());
    try std.testing.expectEqual(5, iter.iterator.next());
    try std.testing.expectEqual(8, iter.iterator.next());
    try std.testing.expectEqual(1000, iter.iterator.next());
}

test "filter" {
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
    var filtered = iter.iterator.filter(struct {
        fn call(item: *const usize) bool {
            return item.* % 2 == 0;
        }
    }.call);

    try std.testing.expectEqual(2, filtered.iterator.next());
    try std.testing.expectEqual(8, filtered.iterator.next());
    try std.testing.expectEqual(1000, filtered.iterator.next());
}

test "flatten" {
    {
        const Iter = struct {
            const Self = @This();

            index: usize = 0,
            iterator: Iterator(?usize) = .{ .nextFn = next, .methods = .{ .resetFn = reset } },
            items: *const [7]?usize = &.{ 2, null, 5, 8, null, null, 1000 },

            fn next(iter: *Iterator(?usize)) ??usize {
                const self = iter.cast(Self);
                defer self.index += 1;
                if (self.items.len <= self.index) {
                    return null;
                } else {
                    return self.items[self.index];
                }
            }

            fn reset(iter: *Iterator(?usize)) void {
                const self = iter.cast(Self);
                self.index = 0;
            }
        };

        var iter = Iter{};
        var flattened = iter.iterator.flatten();

        try std.testing.expectEqual(2, flattened.iterator.next());
        try std.testing.expectEqual(5, flattened.iterator.next());
        try std.testing.expectEqual(8, flattened.iterator.next());
        try std.testing.expectEqual(1000, flattened.iterator.next());
    }
    {
        const CustomError = error{Err};

        const Iter = struct {
            const Self = @This();

            index: usize = 0,
            iterator: Iterator(CustomError!usize) = .{ .nextFn = next, .methods = .{ .resetFn = reset } },
            items: *const [7]CustomError!usize = &.{ 2, CustomError.Err, 5, 8, CustomError.Err, CustomError.Err, 1000 },

            fn next(iter: *Iterator(CustomError!usize)) ?CustomError!usize {
                const self = iter.cast(Self);
                defer self.index += 1;
                if (self.items.len <= self.index) {
                    return null;
                } else {
                    return self.items[self.index];
                }
            }

            fn reset(iter: *Iterator(CustomError!usize)) void {
                const self = iter.cast(Self);
                self.index = 0;
            }
        };

        var iter = Iter{};
        var flattened = iter.iterator.flatten();

        try std.testing.expectEqual(2, flattened.iterator.next());
        try std.testing.expectEqual(5, flattened.iterator.next());
        try std.testing.expectEqual(8, flattened.iterator.next());
        try std.testing.expectEqual(1000, flattened.iterator.next());
    }
    {
        const CustomError = error{Err};

        const Iter = struct {
            const Self = @This();

            index: usize = 0,
            iterator: Iterator(CustomError!usize) = .{ .nextFn = next, .methods = .{ .resetFn = reset } },
            items: *const [7]CustomError!usize = &.{ 2, CustomError.Err, 5, 8, CustomError.Err, CustomError.Err, 1000 },

            fn next(iter: *Iterator(CustomError!usize)) ?CustomError!usize {
                const self = iter.cast(Self);
                defer self.index += 1;
                if (self.items.len <= self.index) {
                    return null;
                } else {
                    return self.items[self.index];
                }
            }

            fn reset(iter: *Iterator(CustomError!usize)) void {
                const self = iter.cast(Self);
                self.index = 0;
            }
        };

        var iter = Iter{};
        const flattened = iter.iterator.flat_err();

        try std.testing.expectError(CustomError.Err, flattened);
    }
}

test "fold" {
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

    const zero: usize = 0;
    const sum = iter.iterator.fold(zero, struct {
        fn call(acc: usize, item: *const usize) usize {
            return acc + item.*;
        }
    }.call);

    try std.testing.expectEqual(1015, sum);
}

test "any_all" {
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

    const Callback = struct {
        fn any_correct(item: *const usize) bool {
            return item.* > 100;
        }
        fn any_wrong(item: *const usize) bool {
            return item.* % 7 == 0;
        }
        fn all_correct(item: *const usize) bool {
            return item.* > 0;
        }
        fn all_wrong(item: *const usize) bool {
            return item.* % 2 == 0;
        }
    };

    var iter = Iter{};

    const any_correct = iter.iterator.any(Callback.any_correct);
    iter.iterator.reset();

    const any_wrong = iter.iterator.any(Callback.any_wrong);
    iter.iterator.reset();

    const all_correct = iter.iterator.all(Callback.all_correct);
    iter.iterator.reset();

    const all_wrong = iter.iterator.all(Callback.all_wrong);

    try std.testing.expect(any_correct);
    try std.testing.expect(!any_wrong);
    try std.testing.expect(all_correct);
    try std.testing.expect(!all_wrong);
}

test "find" {
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

    const Callback = struct {
        fn find(item: *const usize) bool {
            return item.* > 5;
        }
    };

    var iter = Iter{};
    try std.testing.expectEqual(8, iter.iterator.find(Callback.find));
}

test "for_each" {
    const Iter = struct {
        const Self = @This();
        var sum: usize = 0;

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

        fn forEach(item: *const usize) void {
            sum += item.*;
        }
    };

    var iter = Iter{};
    iter.iterator.forEach(Iter.forEach);
    try std.testing.expectEqual(1015, Iter.sum);
}

test "zip" {
    const IterT = struct {
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

    const IterU = struct {
        const Self = @This();

        index: usize = 0,
        iterator: Iterator([]const u8) = .{ .nextFn = next, .methods = .{ .resetFn = reset } },
        items: *const [5][]const u8 = &.{ "two", "five", "eight", "thousand", "N/A" },

        fn next(iter: *Iterator([]const u8)) ?[]const u8 {
            const self = iter.cast(Self);
            defer self.index += 1;
            if (self.items.len <= self.index) {
                return null;
            } else {
                return self.items[self.index];
            }
        }

        fn reset(iter: *Iterator([]const u8)) void {
            const self = iter.cast(Self);
            self.index = 0;
        }
    };

    var iter_t = IterT{};
    var iter_u = IterU{};

    var zip = iter_t.iterator.zip([]const u8, &iter_u.iterator);

    try std.testing.expectEqual(.{ 2, "two" }, zip.iterator.next());
    try std.testing.expectEqual(.{ 5, "five" }, zip.iterator.next());
    try std.testing.expectEqual(.{ 8, "eight" }, zip.iterator.next());
    try std.testing.expectEqual(.{ 1000, "thousand" }, zip.iterator.next());
    try std.testing.expectEqual(null, zip.iterator.next());
}

test "overload" {
    const Iter = struct {
        const Self = @This();

        index: usize = 0,
        iterator: Iterator(usize) = .{ .nextFn = next, .methods = .{ .lenFn = len, .collectFn = collect, .resetFn = reset } },
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

        fn len(_: *Iterator(usize)) usize {
            return 8;
        }

        fn collect(_: *Iterator(usize), alloc: std.mem.Allocator) !std.ArrayList(usize) {
            var list = std.ArrayList(usize).init(alloc);
            try list.appendSlice(&.{ 10, 20, 42 });
            return list;
        }

        fn reset(iter: *Iterator(usize)) void {
            const self = iter.cast(Self);
            self.index = 0;
        }
    };

    var iter = Iter{};

    try std.testing.expectEqual(8, iter.iterator.len());
    {
        const expected: [3]usize = .{ 10, 20, 42 };
        const list = try iter.iterator.collect(std.testing.allocator);
        defer list.deinit();
        try std.testing.expectEqualDeep(&expected, list.items[0..3]);
    }
}
