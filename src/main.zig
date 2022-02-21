// Layout generator for river <https://github.com/ifreund/river>
//
// Copyright 2021 Hugo Machet
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

const build_options = @import("build_options");

const std = @import("std");
const assert = std.debug.assert;
const fmt = std.fmt;
const mem = std.mem;
const math = std.math;
const os = std.os;

const wayland = @import("wayland");
const wl = wayland.client.wl;
const river = wayland.client.river;

const flags = @import("flags.zig");

const log = std.log.scoped(.rivercarro);

const usage =
    \\Usage: rivercarro [options...]
    \\
    \\  -h              Print this help message and exit.
    \\  -version        Print the version number and exit.
    \\  -no-smart-gaps  Disable smart gaps
    \\
    \\  The following commands may also be sent to rivercarro at runtime:
    \\
    \\  -inner-gaps     Set the gaps around views in pixels. (Default 6)
    \\  -outer-gaps     Set the gaps around the edge of the layout area in
    \\                  pixels. (Default 6)
    \\  -main-location  Set the initial location of the main area in the
    \\                  layout. (Default left)
    \\  -main-count     Set the initial number of views in the main area of the
    \\                  layout. (Default 1)
    \\  -main-ratio     Set the initial ratio of main area to total layout
    \\                  area. (Default: 0.6)
    \\  -width-ratio    Set the ratio of the usable area width of the screen.
    \\                  (Default: 1.0)
    \\
    \\  See rivercarro(1) man page for more documentation.
    \\
;

const Command = enum {
    @"inner-gaps",
    @"outer-gaps",
    @"main-location",
    @"main-count",
    @"main-ratio",
    @"width-ratio",
};

const Location = enum {
    top,
    right,
    bottom,
    left,
    monocle,
};

// Configured through command line options.
var default_inner_gaps: u32 = 6;
var default_outer_gaps: u32 = 6;
var smart_gaps: bool = true;
var default_main_location: Location = .left;
var default_main_count: u32 = 1;
var default_main_ratio: f64 = 0.6;
var default_width_ratio: f64 = 1.0;

var only_one_view: bool = false;

/// We don't free resources on exit, only when output globals are removed.
const gpa = std.heap.c_allocator;

const Context = struct {
    layout_manager: ?*river.LayoutManagerV3 = null,
    outputs: std.TailQueue(Output) = .{},

    initialized: bool = false,

    fn addOutput(ctx: *Context, registry: *wl.Registry, name: u32) !void {
        const wl_output = try registry.bind(name, wl.Output, 3);
        errdefer wl_output.release();
        const node = try gpa.create(std.TailQueue(Output).Node);
        errdefer gpa.destroy(node);
        try node.data.init(ctx, wl_output, name);
        ctx.outputs.append(node);
    }
};

const Output = struct {
    wl_output: *wl.Output,
    name: u32,

    inner_gaps: u32,
    outer_gaps: u32,
    main_location: Location,
    main_count: u32,
    main_ratio: f64,
    width_ratio: f64,

    layout: *river.LayoutV3 = undefined,

    fn init(output: *Output, ctx: *Context, wl_output: *wl.Output, name: u32) !void {
        output.* = .{
            .wl_output = wl_output,
            .name = name,
            .inner_gaps = default_inner_gaps,
            .outer_gaps = default_outer_gaps,
            .main_location = default_main_location,
            .main_count = default_main_count,
            .main_ratio = default_main_ratio,
            .width_ratio = default_width_ratio,
        };
        if (ctx.initialized) try output.getLayout(ctx);
    }

    fn deinit(output: *Output) void {
        output.wl_output.release();
        output.layout.destroy();
    }

    fn getLayout(output: *Output, ctx: *Context) !void {
        assert(ctx.initialized);
        output.layout = try ctx.layout_manager.?.getLayout(output.wl_output, "rivercarro");
        output.layout.setListener(*Output, layoutListener, output);
    }

    fn layoutListener(layout: *river.LayoutV3, event: river.LayoutV3.Event, output: *Output) void {
        switch (event) {
            .namespace_in_use => fatal("namespace 'rivercarro' already in use.", .{}),

            .user_command => |ev| {
                var it = mem.tokenize(u8, mem.span(ev.command), " ");
                const raw_cmd = it.next() orelse {
                    log.err("Not enough arguments", .{});
                    return;
                };
                const raw_arg = it.next() orelse {
                    log.err("Not enough arguments", .{});
                    return;
                };
                if (it.next() != null) {
                    log.err("Too many arguments", .{});
                    return;
                }
                const cmd = std.meta.stringToEnum(Command, raw_cmd) orelse {
                    log.err("Unknown command: {s}", .{raw_cmd});
                    return;
                };
                switch (cmd) {
                    .@"inner-gaps" => {
                        const arg = fmt.parseInt(i32, raw_arg, 10) catch |err| {
                            log.err("Failed to parse argument: {}", .{err});
                            return;
                        };
                        switch (raw_arg[0]) {
                            '+' => output.inner_gaps +|= @intCast(u32, arg),
                            '-' => {
                                const result = @as(i33, output.inner_gaps) + arg;
                                if (result >= 0) output.inner_gaps = @intCast(u32, result);
                            },
                            else => output.inner_gaps = @intCast(u32, arg),
                        }
                    },
                    .@"outer-gaps" => {
                        const arg = fmt.parseInt(i32, raw_arg, 10) catch |err| {
                            log.err("Failed to parse argument: {}", .{err});
                            return;
                        };
                        switch (raw_arg[0]) {
                            '+' => output.outer_gaps +|= @intCast(u32, arg),
                            '-' => {
                                const result = @as(i33, output.outer_gaps) + arg;
                                if (result >= 0) output.outer_gaps = @intCast(u32, result);
                            },
                            else => output.outer_gaps = @intCast(u32, arg),
                        }
                    },
                    .@"main-location" => {
                        output.main_location = std.meta.stringToEnum(Location, raw_arg) orelse {
                            log.err("Unknown location: {s}", .{raw_arg});
                            return;
                        };
                    },
                    .@"main-count" => {
                        const arg = fmt.parseInt(i32, raw_arg, 10) catch |err| {
                            log.err("Failed to parse argument: {}", .{err});
                            return;
                        };
                        switch (raw_arg[0]) {
                            '+' => output.main_count +|= @intCast(u32, arg),
                            '-' => {
                                const result = @as(i33, output.main_count) + arg;
                                if (result >= 0) output.main_count = @intCast(u32, result);
                            },
                            else => output.main_count = @intCast(u32, arg),
                        }
                    },
                    .@"main-ratio" => {
                        const arg = fmt.parseFloat(f64, raw_arg) catch |err| {
                            log.err("Failed to parse argument: {}", .{err});
                            return;
                        };
                        switch (raw_arg[0]) {
                            '+', '-' => {
                                output.main_ratio = math.clamp(output.main_ratio + arg, 0.1, 0.9);
                            },
                            else => output.main_ratio = math.clamp(arg, 0.1, 0.9),
                        }
                    },
                    .@"width-ratio" => {
                        const arg = fmt.parseFloat(f64, raw_arg) catch |err| {
                            log.err("Failed to parse argument: {}", .{err});
                            return;
                        };
                        switch (raw_arg[0]) {
                            '+', '-' => {
                                output.width_ratio = math.clamp(output.width_ratio + arg, 0.1, 1.0);
                            },
                            else => output.width_ratio = math.clamp(arg, 0.1, 1.0),
                        }
                    },
                }
            },

            .layout_demand => |ev| {
                const main_count = math.clamp(output.main_count, 1, ev.view_count);
                const secondary_count = blk: {
                    if (ev.view_count > main_count) break :blk ev.view_count - main_count;
                    break :blk 0;
                };

                only_one_view = blk: {
                    if (ev.view_count == 1 or output.main_location == .monocle) break :blk true;
                    break :blk false;
                };

                // Don't add gaps if there is only one view.
                if (only_one_view and smart_gaps) {
                    default_outer_gaps = 0;
                    default_inner_gaps = 0;
                } else {
                    default_outer_gaps = output.outer_gaps;
                    default_inner_gaps = output.inner_gaps;
                }

                const usable_width = switch (output.main_location) {
                    .left, .right, .monocle => @floatToInt(
                        u32,
                        @intToFloat(f64, ev.usable_width) * output.width_ratio,
                    ) - 2 * default_outer_gaps,
                    .top, .bottom => ev.usable_height - 2 * default_outer_gaps,
                };
                const usable_height = switch (output.main_location) {
                    .left, .right, .monocle => ev.usable_height - 2 * default_outer_gaps,
                    .top, .bottom => @floatToInt(
                        u32,
                        @intToFloat(f64, ev.usable_width) * output.width_ratio,
                    ) - 2 * default_outer_gaps,
                };

                // To make things pixel-perfect, we make the first main and first secondary
                // view slightly larger if the height is not evenly divisible.
                var main_width: u32 = undefined;
                var main_height: u32 = undefined;
                var main_height_rem: u32 = undefined;

                var secondary_width: u32 = undefined;
                var secondary_height: u32 = undefined;
                var secondary_height_rem: u32 = undefined;

                if (output.main_location == .monocle) {
                    main_width = usable_width;
                    main_height = usable_height;

                    secondary_width = usable_width;
                    secondary_height = usable_height;
                } else {
                    if (main_count > 0 and secondary_count > 0) {
                        main_width = @floatToInt(u32, output.main_ratio * @intToFloat(f64, usable_width));
                        main_height = usable_height / main_count;
                        main_height_rem = usable_height % main_count;

                        secondary_width = usable_width - main_width;
                        secondary_height = usable_height / secondary_count;
                        secondary_height_rem = usable_height % secondary_count;
                    } else if (main_count > 0) {
                        main_width = usable_width;
                        main_height = usable_height / main_count;
                        main_height_rem = usable_height % main_count;
                    } else if (secondary_width > 0) {
                        main_width = 0;
                        secondary_width = usable_width;
                        secondary_height = usable_height / secondary_count;
                        secondary_height_rem = usable_height % secondary_count;
                    }
                }

                var i: u32 = 0;
                while (i < ev.view_count) : (i += 1) {
                    var x: i32 = undefined;
                    var y: i32 = undefined;
                    var width: u32 = undefined;
                    var height: u32 = undefined;

                    if (output.main_location == .monocle) {
                        x = 0;
                        y = 0;
                        width = main_width;
                        height = main_height;
                    } else {
                        if (i < main_count) {
                            x = 0;
                            y = @intCast(i32, (i * main_height) +
                                if (i > 0) default_inner_gaps else 0 +
                                if (i > 0) main_height_rem else 0);
                            width = main_width - default_inner_gaps / 2;
                            height = main_height -
                                if (i > 0) default_inner_gaps else 0 +
                                if (i == 0) main_height_rem else 0;
                        } else {
                            x = @intCast(i32, (main_width - default_inner_gaps / 2) + default_inner_gaps);
                            y = @intCast(i32, ((i - main_count) * secondary_height) +
                                if (i > main_count) default_inner_gaps else 0 +
                                if (i > main_count) secondary_height_rem else 0);
                            width = secondary_width - default_inner_gaps / 2;
                            height = secondary_height -
                                if (i > main_count) default_inner_gaps else 0 +
                                if (i == main_count) secondary_height_rem else 0;
                        }
                    }

                    switch (output.main_location) {
                        .left => layout.pushViewDimensions(
                            x + @intCast(i32, default_outer_gaps),
                            y + @intCast(i32, default_outer_gaps),
                            width,
                            height,
                            ev.serial,
                        ),
                        .right => layout.pushViewDimensions(
                            @intCast(i32, usable_width - width) - x + @intCast(i32, default_outer_gaps),
                            y + @intCast(i32, default_outer_gaps),
                            width,
                            height,
                            ev.serial,
                        ),
                        .top => layout.pushViewDimensions(
                            y + @intCast(i32, default_outer_gaps),
                            x + @intCast(i32, default_outer_gaps),
                            height,
                            width,
                            ev.serial,
                        ),
                        .bottom => layout.pushViewDimensions(
                            y + @intCast(i32, default_outer_gaps),
                            @intCast(i32, usable_width - width) - x + @intCast(i32, default_outer_gaps),
                            height,
                            width,
                            ev.serial,
                        ),
                        .monocle => layout.pushViewDimensions(
                            x + @intCast(i32, default_outer_gaps),
                            y + @intCast(i32, default_outer_gaps),
                            width,
                            height,
                            ev.serial,
                        ),
                    }
                }

                switch (output.main_location) {
                    .left => layout.commit("left", ev.serial),
                    .right => layout.commit("right", ev.serial),
                    .top => layout.commit("top", ev.serial),
                    .bottom => layout.commit("bottom", ev.serial),
                    .monocle => layout.commit("monocle", ev.serial),
                }
            },
        }
    }
};

pub fn main() !void {
    // https://github.com/ziglang/zig/issues/7807
    const argv: [][*:0]const u8 = os.argv;
    const result = flags.parse(argv[1..], &[_]flags.Flag{
        .{ .name = "-h", .kind = .boolean },
        .{ .name = "-version", .kind = .boolean },
        .{ .name = "-no-smart-gaps", .kind = .boolean },
        .{ .name = "-inner-gaps", .kind = .arg },
        .{ .name = "-outer-gaps", .kind = .arg },
        .{ .name = "-main-location", .kind = .arg },
        .{ .name = "-main-count", .kind = .arg },
        .{ .name = "-main-ratio", .kind = .arg },
        .{ .name = "-width-ratio", .kind = .arg },
    }) catch {
        try std.io.getStdErr().writeAll(usage);
        os.exit(1);
    };
    if (result.args.len != 0) fatalPrintUsage("Unknown option '{s}'", .{result.args[0]});

    if (result.boolFlag("-h")) {
        try std.io.getStdOut().writeAll(usage);
        os.exit(0);
    }
    if (result.boolFlag("-version")) {
        try std.io.getStdOut().writeAll(build_options.version ++ "\n");
        os.exit(0);
    }
    if (result.boolFlag("-no-smart-gaps")) {
        smart_gaps = false;
    }
    if (result.argFlag("-inner-gaps")) |raw| {
        default_inner_gaps = fmt.parseUnsigned(u32, raw, 10) catch
            fatalPrintUsage("Invalid value '{s}' provided to -inner-gaps", .{raw});
    }
    if (result.argFlag("-outer-gaps")) |raw| {
        default_outer_gaps = fmt.parseUnsigned(u32, raw, 10) catch
            fatalPrintUsage("Invalid value '{s}' provided to -outer-gaps", .{raw});
    }
    if (result.argFlag("-main-location")) |raw| {
        default_main_location = std.meta.stringToEnum(Location, raw) orelse
            fatalPrintUsage("Invalid value '{s}' provided to -main-location", .{raw});
    }
    if (result.argFlag("-main-count")) |raw| {
        default_main_count = fmt.parseUnsigned(u32, raw, 10) catch
            fatalPrintUsage("Invalid value '{s}' provided to -main-count", .{raw});
    }
    if (result.argFlag("-main-ratio")) |raw| {
        default_main_ratio = fmt.parseFloat(f64, raw) catch {
            fatalPrintUsage("Invalid value '{s}' provided to -main-ratio", .{raw});
        };
        if (default_main_ratio < 0.1 or default_main_ratio > 0.9) {
            fatalPrintUsage("Invalid value '{s}' provided to -main-ratio", .{raw});
        }
    }
    if (result.argFlag("-width-ratio")) |raw| {
        default_width_ratio = fmt.parseFloat(f64, raw) catch {
            fatalPrintUsage("Invalid value '{s}' provided to -width-ratio", .{raw});
        };
        if (default_width_ratio < 0.1 or default_width_ratio > 1.0) {
            fatalPrintUsage("Invalid value '{s}' provided to -width-ratio", .{raw});
        }
    }

    const display = wl.Display.connect(null) catch {
        std.debug.print("Unable to connect to Wayland server.\n", .{});
        os.exit(1);
    };
    defer display.disconnect();

    var ctx: Context = .{};

    const registry = try display.getRegistry();
    registry.setListener(*Context, registryListener, &ctx);
    _ = try display.roundtrip();

    if (ctx.layout_manager == null) {
        fatal("Wayland compositor does not support river_layout_v3.\n", .{});
    }

    ctx.initialized = true;

    var it = ctx.outputs.first;
    while (it) |node| : (it = node.next) {
        const output = &node.data;
        try output.getLayout(&ctx);
    }

    while (true) _ = try display.dispatch();
}

fn registryListener(registry: *wl.Registry, event: wl.Registry.Event, ctx: *Context) void {
    switch (event) {
        .global => |global| {
            if (std.cstr.cmp(global.interface, river.LayoutManagerV3.getInterface().name) == 0) {
                ctx.layout_manager = registry.bind(global.name, river.LayoutManagerV3, 1) catch return;
            } else if (std.cstr.cmp(global.interface, wl.Output.getInterface().name) == 0) {
                ctx.addOutput(registry, global.name) catch |err|
                    fatal("Failed to bind output: {}", .{err});
            }
        },
        .global_remove => |ev| {
            var it = ctx.outputs.first;
            while (it) |node| : (it = node.next) {
                const output = &node.data;
                if (output.name == ev.name) {
                    ctx.outputs.remove(node);
                    output.deinit();
                    gpa.destroy(node);
                    break;
                }
            }
        },
    }
}

fn fatal(comptime format: []const u8, args: anytype) noreturn {
    log.err(format, args);
    os.exit(1);
}

fn fatalPrintUsage(comptime format: []const u8, args: anytype) noreturn {
    log.err(format, args);
    std.io.getStdErr().writeAll(usage) catch {};
    os.exit(1);
}
