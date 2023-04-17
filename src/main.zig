const std = @import("std");
const builtin = @import("builtin");
const limine = @import("limine");

// The Limine requests can be placed anywhere, but it is important that
// the compiler does not optimise them away, so, usually, they should
// be made volatile or equivalent.

pub export var framebuffer_request: limine.Framebuffer.Request = .{};

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
// If renaming _start() to something else, make sure to change the
// linker script accordingly.
pub export fn _start() callconv(.C) void {
    // Ensure we got a framebuffer
    if (framebuffer_request.response) |framebuffer_response| {
        if (framebuffer_response.framebuffer_count < 1) {
            hcf();
        }

        // Fetch the first framebuffer
        const framebuffer = framebuffer_response.getFramebuffers()[0];

        // Note: we assume the framebuffer model is RGB with 32-bit pixels.
        for (0..100) |i| {
            framebuffer.getSlice(u32)[i * (framebuffer.pitch / 4) + i] = 0xffffff;
        }
    }

    // We're done, just hang...
    hcf();
}
