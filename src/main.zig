const std = @import("std");
const builtin = @import("builtin");
const limine = @import("limine");

// The Limine requests can be placed anywhere, but it is important that
// the compiler does not optimise them away, so, usually, they should
// be made volatile or equivalent.

pub export var terminal_request: limine.Terminal.Request = .{};

// Halt and catch fire function
fn hcf() void {
    switch (builtin.target.cpu.arch) {
        .x86_64 => {
            asm volatile ("cli");
            while (true) {
                asm volatile ("hlt");
            }
        },
        .aarch64, .riscv64 => {
            while (true) {
                asm volatile ("wfi");
            }
        },
        else => @compileError("unsupported architecture"),
    }
}

// The following will be our kernel's entry point.
pub export fn _start() callconv(.C) void {
    // Ensure we got a terminal
    var terminal: limine.Terminal.Response = undefined;
    if (terminal_request.response) |_terminal| {
        terminal = _terminal.*;

        if (terminal.terminal_count < 1) {
            hcf();
        }
    }

    // We should now be able to call the Limine terminal to print out
    // a simple "Hello World" to screen.
    const terminals = terminal.getTerminals();
    terminal.write(terminals[0], "Hello World");

    // We're done, just hang...
    hcf();
}
