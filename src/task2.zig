const std = @import("std");
const scheduler = @import("scheduler.zig");
const Fiber = @import("fiber.zig").Fiber;

//---------------------------------------------------------------
// Basic test (no data passing)
//---------------------------------------------------------------

// func func1:
//   output "fiber 1"
//   call fiber_exit
fn func1() callconv(.c) void {
    std.debug.print("fiber 1\n", .{});
    scheduler.fiber_exit();
}

// func func2:
//   output "fiber 2"
//   call fiber_exit
fn func2() callconv(.c) void {
    std.debug.print("fiber 2\n", .{});
    scheduler.fiber_exit();
}

// func main:
pub fn basicTest() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // set s to be scheduler
    try scheduler.initGlobalScheduler(allocator);
    defer scheduler.deinitGlobalScheduler();

    // set f2 to be fiber with func2
    var f2 = try Fiber.init(allocator, &func2, null);
    defer f2.deinit();

    // set f1 to be fiber with func1
    var f1 = try Fiber.init(allocator, &func1, null);
    defer f1.deinit();

    // call s method spawn with address of f1
    scheduler.spawn(&f1);

    // call s method spawn with address of f2
    scheduler.spawn(&f2);

    // call s method do_it
    scheduler.do_it();
}

//---------------------------------------------------------------
// Test with data passing
//---------------------------------------------------------------

// func func1_with_data:
//   output "fiber 1"
//   set dp to get_data
//   output "fiber 1: " *dp
//   set *dp to *dp PLUS 1
//   call fiber_exit
fn func1_with_data() callconv(.c) void {
    std.debug.print("fiber 1\n", .{});
    const dp = scheduler.get_data();
    if (dp) |ptr| {
        const int_ptr: *i32 = @ptrCast(@alignCast(ptr));
        std.debug.print("fiber 1: {}\n", .{int_ptr.*});
        int_ptr.* += 1;
    }
    scheduler.fiber_exit();
}

// func func2_with_data:
//   set dp to get_data
//   output "fiber 2: " *dp
//   call fiber_exit
fn func2_with_data() callconv(.c) void {
    const dp = scheduler.get_data();
    if (dp) |ptr| {
        const int_ptr: *i32 = @ptrCast(@alignCast(ptr));
        std.debug.print("fiber 2: {}\n", .{int_ptr.*});
    }
    scheduler.fiber_exit();
}

// Test function with data passing
pub fn testWithData() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\n=== Test with Data Passing ===\n", .{});

    // set s to be scheduler
    try scheduler.initGlobalScheduler(allocator);
    defer scheduler.deinitGlobalScheduler();

    // set d to 10
    var d: i32 = 10;
    const dp = &d;

    // set f2 to be fiber with func2, dp
    var f2 = try Fiber.init(allocator, &func2_with_data, dp);
    defer f2.deinit();

    // set f1 to be fiber with func1, dp
    var f1 = try Fiber.init(allocator, &func1_with_data, dp);
    defer f1.deinit();

    // call s method spawn with address of f1
    scheduler.spawn(&f1);

    // call s method spawn with address of f2
    scheduler.spawn(&f2);

    // call s method do_it
    scheduler.do_it();
}

//---------------------------------------------------------------
// Test with multiple fibers (3 fibers)
//---------------------------------------------------------------

fn fiber1() callconv(.c) void {
    std.debug.print("fiber 1 executing\n", .{});
    scheduler.fiber_exit();
}

fn fiber2() callconv(.c) void {
    std.debug.print("fiber 2 executing\n", .{});
    scheduler.fiber_exit();
}

fn fiber3() callconv(.c) void {
    std.debug.print("fiber 3 executing\n", .{});
    scheduler.fiber_exit();
}

pub fn testMultipleFibers() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\n=== Test with Multiple Fibers (3) ===\n", .{});

    try scheduler.initGlobalScheduler(allocator);
    defer scheduler.deinitGlobalScheduler();

    var f1 = try Fiber.init(allocator, &fiber1, null);
    defer f1.deinit();

    var f2 = try Fiber.init(allocator, &fiber2, null);
    defer f2.deinit();

    var f3 = try Fiber.init(allocator, &fiber3, null);
    defer f3.deinit();

    // Spawn in order: 1, 2, 3
    scheduler.spawn(&f1);
    scheduler.spawn(&f2);
    scheduler.spawn(&f3);

    // Should execute in FIFO order
    scheduler.do_it();
}

//---------------------------------------------------------------
// Test with multiple fibers sharing data
//---------------------------------------------------------------

fn counter_fiber_1() callconv(.c) void {
    const dp = scheduler.get_data();
    if (dp) |ptr| {
        const counter: *i32 = @ptrCast(@alignCast(ptr));
        counter.* += 1;
        std.debug.print("Fiber 1: counter = {}\n", .{counter.*});
    }
    scheduler.fiber_exit();
}

fn counter_fiber_2() callconv(.c) void {
    const dp = scheduler.get_data();
    if (dp) |ptr| {
        const counter: *i32 = @ptrCast(@alignCast(ptr));
        counter.* += 10;
        std.debug.print("Fiber 2: counter = {}\n", .{counter.*});
    }
    scheduler.fiber_exit();
}

fn counter_fiber_3() callconv(.c) void {
    const dp = scheduler.get_data();
    if (dp) |ptr| {
        const counter: *i32 = @ptrCast(@alignCast(ptr));
        counter.* += 100;
        std.debug.print("Fiber 3: counter = {}\n", .{counter.*});
    }
    scheduler.fiber_exit();
}

pub fn testMultipleFibersWithData() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\n=== Test Multiple Fibers with Shared Data ===\n", .{});

    try scheduler.initGlobalScheduler(allocator);
    defer scheduler.deinitGlobalScheduler();

    // Shared counter starting at 0
    var counter: i32 = 0;
    const counter_ptr = &counter;

    var f1 = try Fiber.init(allocator, &counter_fiber_1, counter_ptr);
    defer f1.deinit();

    var f2 = try Fiber.init(allocator, &counter_fiber_2, counter_ptr);
    defer f2.deinit();

    var f3 = try Fiber.init(allocator, &counter_fiber_3, counter_ptr);
    defer f3.deinit();

    // Spawn all three fibers
    scheduler.spawn(&f1);
    scheduler.spawn(&f2);
    scheduler.spawn(&f3);

    // Execute all fibers
    scheduler.do_it();
}

pub fn run() !void {
    // Basic test
    try basicTest();

    // Test with data passing
    try testWithData();

    // Test with multiple fibers
    try testMultipleFibers();

    // Test with multiple fibers sharing data
    try testMultipleFibersWithData();
}
