const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "bskysim",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    
    // Install it as the module
    run_cmd.step.dependOn(b.getInstallStep());
    const eazy_args_dep = b.dependency("eazy_args", .{
        .target = target,
        .optimize = optimize,
    });
    const eazy_args_mod = eazy_args_dep.module("eazy_args");
    
    const heap_dep = b.dependency("heap", .{
        .target = target,
        .optimize = optimize,
    });
    const heap_mod = heap_dep.module("heap");

    exe.root_module.addImport("eazy_args", eazy_args_mod);
    exe.root_module.addImport("heap", heap_mod);

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const release_step = b.step("release", "Build for Windows (x64), Linux (x64) and Mac (ARM64)");

    const targets: []const std.Target.Query = &.{
        //.{ .cpu_arch = .x86_64, .os_tag = .windows },
        .{ .cpu_arch = .x86_64, .os_tag = .linux, .abi = .gnu },
        .{ .cpu_arch = .aarch64, .os_tag = .macos },
    };

    for (targets) |t| {
        const release_exe = b.addExecutable(.{
            .name = "bskysim",
            .root_module = b.createModule(.{
                .root_source_file = b.path("src/main.zig"),
                .target = b.resolveTargetQuery(t),
                .optimize = .ReleaseSafe, // Force optimized builds for release
            }),
        });

        release_exe.root_module.addImport("eazy_args", eazy_args_mod);
        release_exe.root_module.addImport("heap", heap_mod);
        
        // This installs the artifact into a subfolder named after the target
        // e.g., zig-out/x86_64-windows/busstop_simulation.exe
        const target_output = b.addInstallArtifact(release_exe, .{
            .dest_dir = .{
                .override = .{
                    .custom = try t.zigTriple(b.allocator),
                },
            },
        });

        release_step.dependOn(&target_output.step);

    }
}
