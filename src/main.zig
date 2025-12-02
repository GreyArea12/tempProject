const std = @import("std");
const context = @import("context.zig");
const foo = @import("foo.zig");
pub fn main() !void {
    // Prints to stderr, ignoring potential errors.
    std.debug.print("Context for asp\n", .{});
    foo.run();
}
