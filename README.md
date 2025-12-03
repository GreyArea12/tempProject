# Fiber Scheduler Implementation (Zig)

Assignment N2 - Advanced Systems Programming

## Overview

This project implements a cooperative fiber scheduler in Zig, enabling multiple lightweight tasks (fibers) to run concurrently on a single thread. The implementation demonstrates context switching, stack management, and cooperative multitasking without using POSIX threads.

## Project Structure

```
.
├── src/
│   ├── main.zig          # Entry point
│   ├── task1.zig         # Task 1: Context switching examples
│   ├── task2.zig         # Task 2: Scheduler test cases
│   ├── fiber.zig         # Fiber class implementation
│   ├── scheduler.zig     # Scheduler class and global API
│   ├── context.zig       # Context library wrapper
│   └── root.zig          # Module root
├── clib/
│   ├── libcontext.a      # Precompiled context switching library
│   ├── context.h         # C header for context API
│   └── context.s         # Assembly implementation
└── build.zig             # Build configuration
```

## Building and Running

### Build
```bash
zig build
```

### Run
```bash
zig build run
```

### Clean
```bash
rm -rf .zig-cache zig-out
```

## Task 1: Context Switching

Task 1 demonstrates basic context switching mechanics using the provided context library.

### Implementation

**Files:** `task1.zig`

**Key concepts:**
- Context structure (RIP, RSP, and preserved registers)
- Stack allocation and alignment (16-byte, Sys V ABI)
- Red Zone (128 bytes below stack pointer)
- Context switching with `set_context()`

### Example: foo and goo

Two functions (`foo` and `goo`) execute with independent stacks. Control transfers from `foo` to `goo` using `set_context()`.

**Output:**
```
you called foo
you called goo
```

## Task 2: Fiber Scheduler

Task 2 implements a Fiber class and a round-robin scheduler that manages multiple fibers in a FIFO queue.

### Implementation

**Files:** `fiber.zig`, `scheduler.zig`, `task2.zig`

**Components:**

1. **Fiber Class** - Encapsulates context and stack management
   - Automatic stack allocation with proper alignment
   - Memory management with allocator
   - Optional data pointer for sharing data between fibers
2. **Scheduler Class** - Manages fiber queue and execution
3. **Global API Functions** - `spawn()`, `do_it()`, `fiber_exit()`, `get_data()`

### API

```zig
// Initialize scheduler
scheduler.initGlobalScheduler(allocator);
defer scheduler.deinitGlobalScheduler();

// Create and spawn fibers
var fiber = try Fiber.init(allocator, &function, data_ptr);
scheduler.spawn(&fiber);

// Run all fibers
scheduler.do_it();

// Inside a fiber: get data
const data = scheduler.get_data();

// Inside a fiber: exit
scheduler.fiber_exit();
```

### Test Cases

#### Test 1: Basic Scheduler
Two fibers execute in FIFO order without data sharing.

**Output:**
```
fiber 1
fiber 2
```

#### Test 2: Data Passing
Two fibers share and modify a common integer via `get_data()`.

**Output:**
```
=== Test with Data Passing ===
fiber 1
fiber 1: 10
fiber 2: 11
```

**Demonstrates:** Fiber 1 reads (10), increments to 11, Fiber 2 reads (11).

#### Test 3: Multiple Fibers
Three fibers execute in order, demonstrating FIFO scheduling.

**Output:**
```
=== Test with Multiple Fibers (3) ===
fiber 1 executing
fiber 2 executing
fiber 3 executing
```

#### Test 4: Multiple Fibers with Shared Data
Three fibers collaboratively modify a shared counter.

**Output:**
```
=== Test Multiple Fibers with Shared Data ===
Fiber 1: counter = 1
Fiber 2: counter = 11
Fiber 3: counter = 111
```

**Demonstrates:** Counter progresses 0 → 1 → 11 → 111 as each fiber adds its value.

## How It Works

### Context Switching

The scheduler uses the context library (implemented in assembly) to save and restore execution state:

1. **`get_context(ctx)`** - Saves current execution state (RIP, RSP, registers)
2. **`set_context(ctx)`** - Restores a saved context and resumes execution
3. **`swap_context(out, in)`** - Atomically saves current and loads new context

### Scheduler Loop

```zig
pub fn do_it(self: *Scheduler) void {
    // Save scheduler's context (return point)
    _ = context.get(&self.context_);
    
    if (self.fibers_.items.len > 0) {
        // Get next fiber from queue
        const f = self.fibers_.orderedRemove(0);
        
        // Set as current and jump to it
        current_fiber = f;
        context.set(f.getContext());
    }
    // When fiber calls fiber_exit(), control returns here
}
```

### Fiber Execution Flow

```
main()
  ↓
spawn(fiber1)    → adds to queue
spawn(fiber2)    → adds to queue
  ↓
do_it()          → saves scheduler context
  ↓
[fiber1 runs]
  ↓
fiber_exit()     → restores scheduler context
  ↓
do_it()          → continues (loop)
  ↓
[fiber2 runs]
  ↓
fiber_exit()     → restores scheduler context
  ↓
do_it()          → no more fibers, returns
  ↓
main() returns
```

## Key Implementation Details

### Stack Setup (Sys V ABI)

```zig
// Allocate stack
const stack = try allocator.alloc(u8, 4096);

// Point to end (stacks grow downwards)
var sp = @ptrFromInt(@intFromPtr(stack.ptr) + stack.len);

// Align to 16 bytes
sp = @ptrFromInt(@intFromPtr(sp) & ~@as(usize, 15));

// Account for Red Zone (128 bytes)
sp = @ptrFromInt(@intFromPtr(sp) - 128);
```

### Data Sharing

Fibers can share data via pointers:

```zig
var shared_data: i32 = 10;
var fiber = try Fiber.init(allocator, &func, &shared_data);

// Inside func:
fn func() callconv(.c) void {
    const ptr = scheduler.get_data();
    if (ptr) |p| {
        const data: *i32 = @ptrCast(@alignCast(p));
        // Use data.*
    }
}
```

## Design Decisions

1. **Global Scheduler** - Single global instance simplifies API and matches assignment requirements
2. **ArrayListUnmanaged** - Used for Zig 0.16 compatibility
3. **FIFO Ordering** - Round-robin scheduling ensures fairness
4. **No Preemption** - Cooperative scheduling requires explicit `fiber_exit()` calls
5. **Opaque Pointers** - `?*anyopaque` allows any data type to be shared

## Limitations

- **Single-threaded** - All fibers run on one thread (by design)
- **No preemption** - Fibers must explicitly yield control
- **Manual exit** - Fibers cannot return normally, must call `fiber_exit()`
- **Fixed stack size** - Each fiber gets 4KB stack

## Testing

Run all tests:
```bash
zig build run
```

Tests verify:
- ✅ Basic context switching
- ✅ Fiber creation and execution
- ✅ Scheduler FIFO ordering
- ✅ Data sharing between fibers
- ✅ Multiple concurrent fibers

## References

- [Sys V x86-64 ABI](https://gitlab.com/x86-psABIs/x86-64-ABI)
- [Fibers Implementation Guide](https://graphitemaster.github.io/fibers/)
- Zig Documentation

## Author

Nathan Hodges (22031026)