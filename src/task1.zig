const std = @import("std");
const context = @import("context.zig");
const Fiber = @import("fiber.zig").Fiber;

// We need goo's context to be accessible from foo
var goo_context: context.Context = undefined;

fn foo() callconv(.c) void {
    std.debug.print("you called foo\n", .{});
    // Instead of exiting, jump to goo!
    context.set(&goo_context);
}

fn goo() callconv(.c) void {
    std.debug.print("you called goo\n", .{});
    std.posix.exit(0);
}

pub fn run() void {
    // Set up stack for foo
    var data_foo: [4096]u8 align(16) = undefined;
    var sp_foo: [*]u8 = @ptrFromInt(@intFromPtr(&data_foo) + 4096);
    sp_foo = @ptrFromInt(@intFromPtr(sp_foo) & ~@as(usize, 15));
    sp_foo = @ptrFromInt(@intFromPtr(sp_foo) - 128);

    var c_foo: context.Context = undefined;
    c_foo.rip = @ptrCast(@constCast(&foo));
    c_foo.rsp = @ptrCast(sp_foo);

    // Set up stack for goo
    var data_goo: [4096]u8 align(16) = undefined;
    var sp_goo: [*]u8 = @ptrFromInt(@intFromPtr(&data_goo) + 4096);
    sp_goo = @ptrFromInt(@intFromPtr(sp_goo) & ~@as(usize, 15));
    sp_goo = @ptrFromInt(@intFromPtr(sp_goo) - 128);

    goo_context.rip = @ptrCast(@constCast(&goo));
    goo_context.rsp = @ptrCast(sp_goo);

    // Start by calling foo
    context.set(&c_foo);
}

// ============================================
// Part 2: Using Fiber class (as per assignment pseudo code)
// ============================================
// func foo:
//   ...
//
// func main:
//   set f by creating fiber with foo
//
//   set c calling method function get_context from f
//   call set_context with c

fn fooWithFiber() callconv(.c) void {
    std.debug.print("foo called via Fiber class\n", .{});
    std.posix.exit(0);
}

pub fn runWithFiberClass() !void {
    std.debug.print("\n=== Using Fiber Class ===\n", .{});

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // set f by creating fiber with foo
    var f = try Fiber.init(allocator, &fooWithFiber);
    defer f.deinit();

    // set c calling method function get_context from f
    const c = f.getContext();

    // call set_context with c
    context.set(c);
}
