const std = @import("std");
const context = @import("context.zig");
const task1 = @import("task1.zig");
const task2 = @import("task2.zig");
const task3 = @import("task3.zig");
pub fn main() !void {
    //std.debug.print("Context for asp\n", .{});
    //task1.run();
    try task2.run();
}
