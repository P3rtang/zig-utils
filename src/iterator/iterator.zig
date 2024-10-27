const std = @import("std");
const debug = @import("debug");
const super = @import("lib.zig");

/// *Interface*
///
/// Iterator is a stateless iterface apart from the index field.
/// This means generic functions should never allocate memory apart from return values.
pub fn Iterator(comptime T: type) type {
    return struct {
        const Self = @This();

        nextFn: *const fn (self: *Self) ?T,

        /// This field is used to overload the default methods of iterator
        /// It can be useful to just overload the reset method with your own
        ///
        /// methods able to be overloaded are:
        ///   - len
        ///   - reset
        ///   - collect
        methods: IteratorMethods = .{},

        pub const IteratorMethods = struct {
            lenFn: *const fn (*Self) usize = _len,
            resetFn: *const fn (*Self) void = _reset,
            collectFn: *const fn (*Self, std.mem.Allocator) std.mem.Allocator.Error!std.ArrayList(T) = _collect,
            peekFn: ?*const fn (*Self) ?T = null,
        };

        const FilteredIterator = struct {
            parent_ptr: *Self,
            iterator: Self = .{ .nextFn = call },
            filterFn: *const fn (*const T) bool,

            fn call(iter: *Self) ?T {
                const self = iter.cast(@This());

                while (self.parent_ptr.next()) |t| {
                    var _t = t;
                    if (self.filterFn(&_t)) {
                        return t;
                    }
                }

                return null;
            }
        };

        const FlattenedIterator = struct {
            const U = (blk: {
                switch (@typeInfo(T)) {
                    .ErrorUnion => |err| break :blk err.payload,
                    .Optional => |opt| break :blk opt.child,
                    else => break :blk T,
                }
            });

            parent_ptr: *Self,
            iterator: Iterator(U) = .{ .nextFn = call },

            fn call(iter: *Iterator(U)) ?U {
                const self = iter.cast(@This());

                while (self.parent_ptr.next()) |item| {
                    if (@typeInfo(T) == .ErrorUnion) {
                        if (item) |u| {
                            return u;
                        } else |_| {}
                    } else if (@typeInfo(T) == .Optional) {
                        if (item) |u| {
                            return u;
                        }
                    }
                }

                return null;
            }
        };

        fn MappedIterator(comptime U: type) type {
            return struct {
                parent_ptr: *Self,
                iterator: Iterator(U) = .{ .nextFn = call, .methods = .{ .resetFn = @This().reset } },
                mapFn: *const fn (T) U,

                fn call(iter: *Iterator(U)) ?U {
                    const self = iter.cast(@This());

                    if (self.parent_ptr.next()) |i| {
                        return self.mapFn(i);
                    } else {
                        return null;
                    }
                }

                fn reset(iter: *Iterator(U)) void {
                    const self = iter.cast(@This());
                    self.parent_ptr.reset();
                }
            };
        }

        // TODO: make a switch statement that changes return type for different `from()` functions
        // This way it will be possible to use 1 `from()` function
        const ArrayIterator = struct {
            array: *const std.ArrayList(T),
            iterator: Iterator(*const T) = .{ .nextFn = call },

            fn call(iter: *Iterator(*const T)) ?*const T {
                const self = iter.cast(@This());

                if (self.array.items.len > iter.index) {
                    return &self.array[iter.index];
                } else {
                    return null;
                }
            }
        };

        fn ZippedIterator(comptime U: type) type {
            return struct {
                const Zip = struct { T, U };
                iterator: Iterator(Zip) = .{ .nextFn = call },
                iterT: *Iterator(T),
                iterU: *Iterator(U),

                fn call(iter: *Iterator(Zip)) ?Zip {
                    const self = iter.cast(@This());

                    var res: Zip = undefined;
                    if (self.iterT.next()) |t| {
                        res.@"0" = t;
                    } else {
                        return null;
                    }

                    if (self.iterU.next()) |u| {
                        res.@"1" = u;
                    } else {
                        return null;
                    }

                    return res;
                }
            };
        }

        pub fn cast(self: *Self, comptime U: type) *U {
            const parent: *U = @fieldParentPtr("iterator", self);
            return parent;
        }

        pub fn box(self: *Self, arena: *std.heap.ArenaAllocator) *IteratorBox(T) {
            const iterator = arena.allocator().create(IteratorBox(T)) catch std.debug.panic("Out of Memory, buy more RAM", .{});
            iterator.* = .{ .arena = arena, .iterator = self };
            return iterator;
        }

        fn _box_debug(self: *Self, name: []const u8, arena: *std.heap.ArenaAllocator) *IteratorBox(T) {
            const iterator = arena.allocator().create(IteratorBox(T)) catch std.debug.panic("Out of Memory, buy more RAM", .{});
            iterator.* = .{ .arena = arena, .name = name, .iterator = self };
            return iterator;
        }

        pub fn next(self: *Self) ?T {
            return self.nextFn(self);
        }

        pub fn peekable(self: *Self) super.Peekable(T) {
            return .{ .iterator = self };
        }

        fn _len(self: *Self) usize {
            var count: usize = 0;
            while (self.next()) |_| {
                count += 1;
            }

            self.reset();
            return count;
        }

        pub fn len(self: *Self) usize {
            return self.methods.lenFn(self);
        }

        pub fn map(self: *Self, comptime U: type, callback: *const fn (T) U) MappedIterator(U) {
            return MappedIterator(U){ .parent_ptr = self, .mapFn = callback };
        }

        pub fn collect(self: *Self, alloc: std.mem.Allocator) !std.ArrayList(T) {
            return self.methods.collectFn(self, alloc);
        }

        fn _collect(self: *Self, alloc: std.mem.Allocator) !std.ArrayList(T) {
            var list = std.ArrayList(T).init(alloc);
            while (self.next()) |item| {
                try list.append(item);
            }

            return list;
        }

        fn _reset(_: *Self) void {}

        pub fn reset(self: *Self) void {
            self.methods.resetFn(self);
        }

        pub fn filter(self: *Self, callback: *const fn (*const T) bool) FilteredIterator {
            return FilteredIterator{
                .parent_ptr = self,
                .filterFn = callback,
            };
        }

        /// Flatten will remove any elements from an iterator that are null or errors
        /// If you want to the error returned use flat_err instead
        ///
        /// @param self: *Iterator(?T | error!T)
        ///
        /// @return FlattenedIterator
        pub fn flatten(self: *Self) FlattenedIterator {
            return FlattenedIterator{ .parent_ptr = self };
        }

        /// Flat_err will convert an iterator of type error!type to !Iterator(type)
        /// for this to work the iterator has to consume and collect every element
        /// this means for this to be useful the iterator has to be resettable
        pub fn flat_err(self: *Self) @typeInfo(T).ErrorUnion.error_set!FlattenedIterator {
            if (@typeInfo(T) != .ErrorUnion) {
                @compileError("Iterator Type has to be ErrorUnion");
            }

            while (self.next()) |item| {
                _ = try item;
            }
            self.reset();

            return FlattenedIterator{ .parent_ptr = self };
        }

        pub fn fold(
            self: *Self,
            accumulator: anytype,
            callback: *const fn (@TypeOf(accumulator), *const T) @TypeOf(accumulator),
        ) @TypeOf(accumulator) {
            var acc = accumulator;
            while (self.next()) |item| {
                acc = callback(acc, &item);
            }
            return acc;
        }

        pub fn any(self: *Self, callback: *const fn (*const T) bool) bool {
            while (self.next()) |item| {
                if (callback(&item)) {
                    return true;
                }
            }

            return false;
        }

        pub fn all(self: *Self, callback: *const fn (*const T) bool) bool {
            while (self.next()) |item| {
                if (!callback(&item)) {
                    return false;
                }
            }

            return true;
        }

        pub fn find(self: *Self, callback: *const fn (*const T) bool) ?T {
            while (self.next()) |item| {
                if (callback(&item)) {
                    return item;
                }
            }

            return null;
        }

        /// ForEach loop through the iterator and calls callback on every item
        ///
        /// **Warning**
        /// It might just be more convenient to use a simple while loop,
        /// because of the way zig handles closures but the functional approach works as well.
        pub fn forEach(self: *Self, callback: *const fn (*const T) void) void {
            while (self.next()) |item| {
                callback(&item);
            }
        }

        pub fn zip(self: *Self, comptime U: type, other: *Iterator(U)) ZippedIterator(U) {
            return ZippedIterator(U){
                .iterT = self,
                .iterU = other,
            };
        }
    };
}

pub fn IteratorBox(comptime T: type) type {
    return struct {
        const Self = @This();

        arena: *std.heap.ArenaAllocator,
        name: ?[]const u8 = null,
        iterator: *Iterator(T),

        pub fn deinit(self: *Self) void {
            self.arena.deinit();
        }

        pub fn next(self: *Self) ?T {
            return self.iterator.next();
        }

        pub fn peekable(self: *Self) *super.PeekableBox(T) {
            const p = self.arena.allocator().create(super.PeekableBox(T)) catch std.debug.panic("Out of Memory, buy more RAM", .{});
            p.* = .{ .iterator = self };
            return p;
        }

        pub fn reset(self: *Self) void {
            self.iterator.reset();
        }

        pub fn len(self: *Self) usize {
            var count: usize = 0;
            while (self.next()) |_| : (count += 1) {}
            return count;
        }

        pub fn map(self: *Self, comptime U: type, callback: *const fn (T) U) *IteratorBox(U) {
            const box = self.arena.allocator().create(IteratorBox(U)) catch std.debug.panic("Out of Memory, buy more RAM", .{});
            var map_iter = self.arena.allocator().create(Iterator(T).MappedIterator(U)) catch std.debug.panic("Out of Memory, buy more RAM", .{});

            map_iter.* = self.iterator.map(U, callback);
            box.* = .{ .arena = self.arena, .iterator = &map_iter.iterator };

            return box;
        }

        pub fn collect(self: *Self) std.ArrayList(T) {
            var list = std.ArrayList(T).init(self.arena.allocator());
            while (self.next()) |item| {
                list.append(item) catch std.debug.panic("Out of Memory, buy more RAM", .{});
            }
            return list;
        }

        pub fn flatten(self: *Self) *IteratorBox(T) {
            const box = self.alloc.create(IteratorBox(T)) catch std.debug.panic("Out of Memory, buy more RAM", .{});

            const map_iter = self.alloc.create(Iterator(T).FlattenedIterator);
            map_iter.* = self.iterator.flatten();
            box.* = .{ .alloc = self.alloc, .iterator = map_iter.iterator, .parent_ptr = map_iter };

            return box;
        }

        /// Flat_err will convert an iterator of type error!type to !Iterator(type)
        /// for this to work the iterator has to consume and collect every element
        /// this means for this to be useful the iterator has to be resettable
        pub fn flat_err(self: *Self) @typeInfo(T).ErrorUnion.error_set!*IteratorBox(@typeInfo(T).ErrorUnion.payload) {
            const U = @typeInfo(T).ErrorUnion.payload;

            if (@typeInfo(T) != .ErrorUnion) {
                @compileError("Iterator Type should be an ErrorUnion");
            }

            const FlatIter = struct {
                iterator: Iterator(U) = .{ .nextFn = @This().next, .methods = .{ .resetFn = @This().reset } },
                parent_ptr: *Iterator(T),

                fn next(iter: *Iterator(U)) ?U {
                    const this = iter.cast(@This());

                    if (this.parent_ptr.next()) |item| {
                        if (item) |i| {
                            return i;
                        } else |_| {}
                    }
                    return null;
                }

                fn reset(iter: *Iterator(U)) void {
                    const this = iter.cast(@This());
                    this.parent_ptr.reset();
                }
            };

            while (self.next()) |item| {
                _ = try item;
            }
            self.reset();

            const flat = try self.arena.allocator().create(FlatIter);
            flat.* = FlatIter{ .parent_ptr = self.iterator };

            const iterator = flat.iterator.box(self.arena);
            return iterator;
        }
    };
}
