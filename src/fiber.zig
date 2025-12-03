const std = @import("std");
const context = @import("context.zig");

// Fiber class - encapsulates context and stack for a fiber
pub const Fiber = struct {
    context_: context.Context,
    stack_: []u8,
    allocator_: std.mem.Allocator,
    data_: ?*anyopaque, // Optional data pointer

    // Create a new fiber with the given function and optional data
    pub fn init(allocator: std.mem.Allocator, function: *const fn () callconv(.c) void, data: ?*anyopaque) !Fiber {
        // Allocate stack (4KB)
        const stack = try allocator.alloc(u8, 4096);

        // Set up stack pointer (stacks grow downwards)
        var sp: [*]u8 = @ptrFromInt(@intFromPtr(stack.ptr) + stack.len);

        // Align to 16 bytes
        sp = @ptrFromInt(@intFromPtr(sp) & ~@as(usize, 15));

        // Account for Red Zone
        sp = @ptrFromInt(@intFromPtr(sp) - 128);

        // Create context
        var ctx: context.Context = undefined;
        ctx.rip = @ptrCast(@constCast(function));
        ctx.rsp = @ptrCast(sp);

        return Fiber{
            .context_ = ctx,
            .stack_ = stack,
            .allocator_ = allocator,
            .data_ = data,
        };
    }

    // Free the fiber's stack
    pub fn deinit(self: *Fiber) void {
        self.allocator_.free(self.stack_);
    }

    // Get the context of this fiber
    pub fn getContext(self: *Fiber) *context.Context {
        return &self.context_;
    }

    // Get the data pointer passed to this fiber
    pub fn getData(self: *Fiber) ?*anyopaque {
        return self.data_;
    }
};
