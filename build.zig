const std = @import("std");
const assert = std.debug.assert;
const fs = std.fs;
const mem = std.mem;

const Scanner = @import("zig-wayland").Scanner;

/// While a rivercarro release is in development, this string should contain
/// the version in development with the "-dev" suffix.  When a release is
/// tagged, the "-dev" suffix should be removed for the commit that gets tagged.
/// Directly after the tagged commit, the version should be bumped and the "-dev"
/// suffix added.
const version = "0.5.0-dev";

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const pie = b.option(bool, "pie", "Build a Position Independent Executable") orelse false;

    const full_version = blk: {
        if (mem.endsWith(u8, version, "-dev")) {
            var ret: u8 = undefined;

            const git_describe_long = b.runAllowFail(
                &[_][]const u8{ "git", "-C", b.build_root.path orelse ".", "describe", "--long" },
                &ret,
                .Inherit,
            ) catch break :blk version;

            var it = mem.split(u8, mem.trim(u8, git_describe_long, &std.ascii.whitespace), "-");
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

    const options = b.addOptions();
    options.addOption([]const u8, "version", full_version);

    const scanner = Scanner.create(b, .{});

    scanner.addCustomProtocol("protocol/river-layout-v3.xml");

    scanner.generate("wl_output", 4);
    scanner.generate("river_layout_manager_v3", 2);

    const wayland = b.createModule(.{ .root_source_file = scanner.result });
    const flags = b.createModule(.{ .root_source_file = .{ .path = "common/flags.zig" } });

    const rivercarro = b.addExecutable(.{
        .name = "rivercarro",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    rivercarro.root_module.addOptions("build_options", options);

    rivercarro.linkLibC();

    rivercarro.root_module.addImport("wayland", wayland);
    rivercarro.linkSystemLibrary("wayland-client");

    rivercarro.root_module.addImport("flags", flags);

    scanner.addCSource(rivercarro);

    rivercarro.pie = pie;

    b.installArtifact(rivercarro);
    b.installFile("doc/rivercarro.1", "share/man/man1/rivercarro.1");
}
