const std = @import("std");
const builtin = @import("builtin");

const Build = std.Build;
const Arch = std.Target.Cpu.Arch;
const CrossTarget = std.zig.CrossTarget;

pub fn build(b: *Build) !void {
    const arch = b.option(Arch, "arch", "The CPU architecture to build for") orelse .x86_64;
    const target = try genTarget(arch);

    const kernel = try buildKernel(b, target);
    const iso = try buildLimineIso(b, kernel);
    b.default_step.dependOn(&iso.step);
    _ = try runIsoQemu(b, iso, arch);
}

fn genTarget(arch: Arch) !CrossTarget {
    var target = CrossTarget{
        .cpu_arch = arch,
        .os_tag = .freestanding,
        .abi = .none,
    };

    switch (arch) {
        .x86_64 => {
            const features = std.Target.x86.Feature;
            target.cpu_features_sub.addFeature(@enumToInt(features.x87));
            target.cpu_features_sub.addFeature(@enumToInt(features.mmx));
            target.cpu_features_sub.addFeature(@enumToInt(features.sse));
            target.cpu_features_sub.addFeature(@enumToInt(features.sse2));
            target.cpu_features_sub.addFeature(@enumToInt(features.avx));
            target.cpu_features_sub.addFeature(@enumToInt(features.avx2));

            target.cpu_features_add.addFeature(@enumToInt(features.soft_float));
        },
        .aarch64 => {},
        else => return error.UnsupportedArchitecture,
    }

    return target;
}

fn buildKernel(b: *Build, target: CrossTarget) !*Build.InstallArtifactStep {
    const optimize = b.standardOptimizeOption(.{});

    const kernel = b.addExecutable(.{
        .name = "kernel",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    kernel.code_model = switch (target.cpu_arch.?) {
        .x86_64 => .kernel,
        .aarch64 => .small,
        else => return error.UnsupportedArchitecture,
    };
    kernel.linker_script = .{ .path = "src/linker.ld" };

    const limine = b.dependency("limine", .{
        .target = target,
        .optimize = optimize,
    });
    kernel.addModule("limine", limine.module("limine"));

    return b.addInstallArtifact(kernel);
}

fn buildLimineIso(b: *Build, kernel: *Build.InstallArtifactStep) !*Build.RunStep {
    const limine_deploy = switch (builtin.os.tag) {
        .linux => "limine-deploy",
        .windows => "limine-deploy.exe",
        else => return error.UnsupportedOS,
    };

    // TODO: use submodules with a hardcoded path until Zig supports
    //       static assets
    const limine_path = "external/limine";

    const cmd = &[_][]const u8{
        // zig fmt: off
        "/bin/sh", "-c",
        try std.mem.concat(b.allocator, u8, &[_][]const u8{
            "mkdir -p zig-out/iso/root && ",
            "make -C " ++ limine_path ++ " && ",
            "cp zig-out/bin/", kernel.artifact.out_filename, " zig-out/iso/root && ",
            "cp src/limine.cfg zig-out/iso/root && ",
            "cp ", limine_path ++ "/limine.sys ",
                   limine_path ++ "/limine-cd.bin ",
                   limine_path ++ "/limine-cd-efi.bin ",
                   "zig-out/iso/root && ",
            "xorriso -as mkisofs -quiet -b limine-cd.bin ",
                "-no-emul-boot -boot-load-size 4 -boot-info-table ",
                "--efi-boot limine-cd-efi.bin ",
                "-efi-boot-part --efi-boot-image --protective-msdos-label ",
                "zig-out/iso/root -o zig-out/iso/limine-barebones.iso && ",
            limine_path ++ "/" ++ limine_deploy ++ " zig-out/iso/limine-barebones.iso",
        // zig fmt: on
        }),
    };

    const iso_cmd = b.addSystemCommand(cmd);
    iso_cmd.step.dependOn(&kernel.step);

    const iso_step = b.step("iso", "Generate bootable ISO file");
    iso_step.dependOn(&iso_cmd.step);

    return iso_cmd;
}

fn runIsoQemu(b: *Build, iso: *Build.RunStep, arch: Arch) !*Build.RunStep {
    const qemu_executable = switch (arch) {
        .x86_64 => "qemu-system-x86_64",
        .aarch64 => "qemu-system-aarch64",
        else => return error.UnsupportedArchitecture,
    };
    const qemu_iso_args = &[_][]const u8{
        qemu_executable,
        "-M",
        "q35,accel=kvm:whpx:tcg",
        "-m",
        "2G",
        "-cdrom",
        "zig-out/iso/limine-barebones.iso",
        "-boot",
        "d",
    };
    const qemu_iso_cmd = b.addSystemCommand(qemu_iso_args);
    qemu_iso_cmd.step.dependOn(&iso.step);

    const qemu_iso_step = b.step("run", "Boot ISO in qemu");
    qemu_iso_step.dependOn(&qemu_iso_cmd.step);

    return qemu_iso_cmd;
}
