const std = @import("std");
const context = @import("context.zig");
const Fiber = @import("fiber.zig").Fiber;

//---------------------------------------------------------------
// Global scheduler instance
//---------------------------------------------------------------

var s: Scheduler = undefined;
var s_initialized: bool = false;
var current_fiber: ?*Fiber = null; // Track the currently running fiber

// Initialize the global scheduler (must be called before use)
pub fn initGlobalScheduler(allocator: std.mem.Allocator) !void {
    s = try Scheduler.init(allocator);
    s_initialized = true;
}

// Cleanup the global scheduler
pub fn deinitGlobalScheduler() void {
    if (s_initialized) {
        s.deinit();
        s_initialized = false;
    }
}

//---------------------------------------------------------------
// Scheduler class - manages fiber execution in round-robin
//---------------------------------------------------------------

pub const Scheduler = struct {
    fibers_: std.ArrayListUnmanaged(*Fiber),
    context_: context.Context,
    allocator_: std.mem.Allocator,

    // Create a new scheduler
    pub fn init(allocator: std.mem.Allocator) !Scheduler {
        return Scheduler{
            .fibers_ = std.ArrayListUnmanaged(*Fiber){},
            .context_ = undefined,
            .allocator_ = allocator,
        };
    }

    // Free the scheduler resources
    pub fn deinit(self: *Scheduler) void {
        self.fibers_.deinit(self.allocator_);
    }

    // method spawn with a fiber f:
    //   push f to back of fibers_
    pub fn spawn(self: *Scheduler, f: *Fiber) !void {
        try self.fibers_.append(self.allocator_, f);
    }

    // method do_it:
    //   return here to re-enter scheduler
    //   call get_context with context_
    //
    //   if fibers_ is not empty:
    //     set f by poping from of fibers_
    //
    //     jump to task
    //     set c calling method function get_context from f
    //     call set_context with c
    pub fn do_it(self: *Scheduler) void {
        // return here to re-enter scheduler
        _ = context.get(&self.context_);

        if (self.fibers_.items.len > 0) {
            // set f by popping from front of fibers_
            const f = self.fibers_.orderedRemove(0);

            // Set current fiber before jumping to it
            current_fiber = f;

            // jump to task
            const c = f.getContext();
            context.set(c);
        }
    }

    // method fiber_exit:
    //   jump back to the scheduler 'loop'
    //   call set_context with context_
    pub fn fiber_exit(self: *Scheduler) void {
        // jump back to the scheduler 'loop'
        context.set(&self.context_);
    }

    // method yield:
    //   save current fiber context
    //   re-queue the fiber
    //   jump back to scheduler
    pub fn yield(self: *Scheduler) void {
        if (current_fiber) |fiber| {
            // Save current state
            _ = context.get(fiber.getContext());

            // Re-queue this fiber to run again later
            self.fibers_.append(self.allocator_, fiber) catch {
                // If append fails, just continue without re-queuing
                return;
            };

            // Return to scheduler
            context.set(&self.context_);
        }
    }
};

//---------------------------------------------------------------
// Global API functions (call into global scheduler s)
//---------------------------------------------------------------

// @brief create a new task for execution
// @param function fiber execution body
pub fn spawn(f: *Fiber) void {
    s.spawn(f) catch |err| {
        std.debug.print("Error spawning fiber: {}\n", .{err});
    };
}

// @brief run with the current set of fibers queued.
// returns only when all fiber have completed.
pub fn do_it() void {
    s.do_it();
}

// @brief terminates a fiber
// note call control flow within a fiber must terminate
// with a call to fiber_exit.
pub fn fiber_exit() void {
    s.fiber_exit();
}

// @brief get pointer to data passed as part of fiber creation
// @return pointer to data passed in at fiber creation
pub fn get_data() ?*anyopaque {
    if (current_fiber) |fiber| {
        return fiber.getData();
    }
    return null;
}

// @brief yield control back to scheduler
// once rescheduled fiber will restart directly following call to yield
pub fn yield() void {
    s.yield();
}
