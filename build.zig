const std = @import("std");
const Builder = @import("std").build.Builder;
const Step = @import("std").build.Step;
const fs = std.fs;
const mem = std.mem;

const ScanProtocolsStep = @import("deps/zig-wayland/build.zig").ScanProtocolsStep;

/// While a rivercarror release is in development, this string should contain the version in development
/// with the "-dev" suffix.
/// When a release is tagged, the "-dev" suffix should be removed for the commit that gets tagged.
/// Directly after the tagged commit, the version should be bumped and the "-dev" suffix added.
const version = "0.1.1";

pub fn build(b: *Builder) !void {
    const target = b.standardTargetOptions(.{});
    const mode = b.standardReleaseOptions();

    const man_pages = b.option(
        bool,
        "man-pages",
        "Set to true to build man pages. Requires scdoc. Defaults to true if scdoc is found.",
    ) orelse scdoc_found: {
        _ = b.findProgram(&[_][]const u8{"scdoc"}, &[_][]const u8{}) catch |err| switch (err) {
            error.FileNotFound => break :scdoc_found false,
            else => return err,
        };
        break :scdoc_found true;
    };

    const full_version = blk: {
        if (mem.endsWith(u8, version, "-dev")) {
            var ret: u8 = undefined;
            const git_dir = try fs.path.join(b.allocator, &[_][]const u8{ b.build_root, ".git" });
            const git_commit_hash = b.execAllowFail(
                &[_][]const u8{ "git", "--git-dir", git_dir, "--work-tree", b.build_root, "rev-parse", "--short", "HEAD" },
                &ret,
                .Inherit,
            ) catch break :blk version;
            break :blk try std.fmt.allocPrintZ(b.allocator, "{s}-{s}", .{
                version,
                mem.trim(u8, git_commit_hash, &std.ascii.spaces),
            });
        } else {
            break :blk version;
        }
    };

    const scanner = ScanProtocolsStep.create(b);

    const protocol_path = mem.trim(u8, try b.exec(
        &[_][]const u8{ "pkg-config", "--variable=pkgdatadir", "river-protocols" },
    ), &std.ascii.spaces);
    const layout_protocol = try std.fs.path.join(b.allocator, &[_][]const u8{ protocol_path, "river-layout-v3.xml" });
    scanner.addProtocolPath(layout_protocol);

    const exe = b.addExecutable("rivercarro", "src/main.zig");
    exe.setTarget(target);
    exe.setBuildMode(mode);

    const options = b.addOptions();
    options.addOption([]const u8, "version", full_version);
    exe.addOptions("build_options", options);

    exe.step.dependOn(&scanner.step);
    exe.addPackage(.{
        .name = "wayland",
        .path = .{ .generated = &scanner.result },
    });
    exe.linkLibC();
    exe.linkSystemLibrary("wayland-client");

    scanner.addCSource(exe);

    exe.install();

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    if (man_pages) {
        const scdoc_step = ScdocStep.create(b);
        try scdoc_step.install();
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}

const ScdocStep = struct {
    const scd_paths = [_][]const u8{"doc/rivercarro.1.scd"};

    builder: *Builder,
    step: Step,

    fn create(builder: *Builder) *ScdocStep {
        const self = builder.allocator.create(ScdocStep) catch @panic("out of memory");
        self.* = init(builder);
        return self;
    }

    fn init(builder: *Builder) ScdocStep {
        return ScdocStep{
            .builder = builder,
            .step = Step.init(.custom, "Generate man pages", builder.allocator, make),
        };
    }

    fn make(step: *Step) !void {
        const self = @fieldParentPtr(ScdocStep, "step", step);
        for (scd_paths) |path| {
            const command = try std.fmt.allocPrint(
                self.builder.allocator,
                "scdoc < {s} > {s}",
                .{ path, path[0..(path.len - 4)] },
            );
            _ = try self.builder.exec(&[_][]const u8{ "sh", "-c", command });
        }
    }

    fn install(self: *ScdocStep) !void {
        self.builder.getInstallStep().dependOn(&self.step);

        for (scd_paths) |path| {
            const path_no_ext = path[0..(path.len - 4)];
            const basename_no_ext = fs.path.basename(path_no_ext);
            const section = path_no_ext[(path_no_ext.len - 1)..];

            const output = try std.fmt.allocPrint(
                self.builder.allocator,
                "share/man/man{s}/{s}",
                .{ section, basename_no_ext },
            );

            self.builder.installFile(path_no_ext, output);
        }
    }
};
