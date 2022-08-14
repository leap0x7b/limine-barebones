const std = @import("std");
const limine = @import("limine");

// The Limine requests can be placed anywhere, but it is important that
// the compiler does not optimise them away, so, usually, they should
// be made volatile or equivalent.

pub export var terminal_request: limine.Terminal.Request = .{};

fn done() void {
    while (true) {
        asm volatile ("hlt");
    }
}

// The following will be our kernel's entry point.
pub export fn _start() callconv(.C) void {
    // Ensure we got a terminal
    var terminal: limine.Terminal.Response = undefined;
    if (terminal_request.response) |_terminal| {
        terminal = _terminal.*;

        if (terminal.terminal_count < 1) {
            done();
        }
    }

    // We should now be able to call the Limine terminal to print out
    // a simple "Hello World" to screen.
    const terminals = terminal.getTerminals();
    terminal.write(terminals[0], "Hello World");

    // We're done, just hang...
    done();
}
