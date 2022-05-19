const std = @import("std");
const Builder = @import("std").build.Builder;
const Step = @import("std").build.Step;
const assert = std.debug.assert;
const fs = std.fs;
const mem = std.mem;

const ScanProtocolsStep = @import("deps/zig-wayland/build.zig").ScanProtocolsStep;

/// While a rivercarro release is in development, this string should contain
/// the version in development with the "-dev" suffix.  When a release is
/// tagged, the "-dev" suffix should be removed for the commit that gets tagged.
/// Directly after the tagged commit, the version should be bumped and the "-dev"
/// suffix added.
const version = "0.1.5-dev";

pub fn build(b: *Builder) !void {
    const target = b.standardTargetOptions(.{});
    const mode = b.standardReleaseOptions();

    const full_version = blk: {
        if (mem.endsWith(u8, version, "-dev")) {
            var ret: u8 = undefined;

            const git_describe_long = b.execAllowFail(
                &[_][]const u8{ "git", "-C", b.build_root, "describe", "--long" },
                &ret,
                .Inherit,
            ) catch break :blk version;

            var it = mem.split(u8, mem.trim(u8, git_describe_long, &std.ascii.spaces), "-");
            _ = it.next().?; // previous tag
            const commit_count = it.next().?;
            const commit_hash = it.next().?;
            assert(it.next() == null);
            assert(commit_hash[0] == 'g');

            // Follow semantic versioning, e.g. 0.2.0-dev.42+d1cf95b
            break :blk try std.fmt.allocPrintZ(b.allocator, version ++ ".{s}+{s}", .{
                commit_count,
                commit_hash[1..],
            });
        } else {
            break :blk version;
        }
    };

    const scanner = ScanProtocolsStep.create(b);
    scanner.addProtocolPath("protocol/river-layout-v3.xml");

    const exe = b.addExecutable("rivercarro", "src/main.zig");
    exe.setTarget(target);
    exe.setBuildMode(mode);

    const options = b.addOptions();
    options.addOption([]const u8, "version", full_version);
    exe.addOptions("build_options", options);

    exe.step.dependOn(&scanner.step);

    exe.addPackagePath("flags", "common/flags.zig");

    exe.addPackage(.{
        .name = "wayland",
        .path = .{ .generated = &scanner.result },
    });
    exe.linkLibC();
    exe.linkSystemLibrary("wayland-client");

    scanner.addCSource(exe);

    exe.install();
    b.installFile("doc/rivercarro.1", "share/man/man1/rivercarro.1");

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
