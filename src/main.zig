const std = @import("std");
const limine = @import("limine");

// The Limine requests can be placed anywhere, but it is important that
// the compiler does not optimise them away, so, usually, they should
// be made volatile or equivalent.

const terminal_request: limine.Terminal.Request = .{ .revision = 0 };

fn halt() void {
    while (true) {
        asm volatile ("hlt");
    }
}

// The following will be our kernel's entry point.
pub fn _start() void {
    // Ensure we got a terminal
    if (terminal_request.response == null) {
        halt();
    }

    // We should now be able to call the Limine terminal to print out
    // a simple "Hello World" to screen.
    terminal_request.response.write("Hello World", 11);

    // We're done, just hang...
    halt();
}
