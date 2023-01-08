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
const io = std.io;
const mem = std.mem;
const math = std.math;
const os = std.os;

const flags = @import("flags");
const wayland = @import("wayland");
const wl = wayland.client.wl;
const river = wayland.client.river;

const log = std.log.scoped(.rivercarro);

const gpa = std.heap.c_allocator;

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
    @"gaps",
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

const Config = struct {
    smart_gaps: bool = true,
    inner_gaps: u31 = 6,
    outer_gaps: u31 = 6,
    main_location: Location = .left,
    main_count: u31 = 1,
    main_ratio: f64 = 0.6,
    width_ratio: f64 = 1.0,
};

const Context = struct {
    layout_manager: ?*river.LayoutManagerV3 = null,
    outputs: std.SinglyLinkedList(Output) = .{},
    initialized: bool = false,
};

var cfg: Config = .{};
var ctx: Context = .{};

const Output = struct {
    wl_output: *wl.Output,
    name: u32,

    cfg: Config,

    layout: *river.LayoutV3 = undefined,

    fn get_layout(output: *Output) !void {
        output.layout = try ctx.layout_manager.?.getLayout(output.wl_output, "rivercarro");
        output.layout.setListener(*Output, layout_listener, output);
    }

    fn layout_listener(layout: *river.LayoutV3, event: river.LayoutV3.Event, output: *Output) void {
        switch (event) {
            .namespace_in_use => fatal("namespace 'rivercarro' already in use.", .{}),

            .user_command => |ev| {
                var it = mem.tokenize(u8, mem.span(ev.command), " ");
                const raw_cmd = it.next() orelse {
                    log.err("not enough arguments", .{});
                    return;
                };
                const raw_arg = it.next() orelse {
                    log.err("not enough arguments", .{});
                    return;
                };
                if (it.next() != null) {
                    log.err("too many arguments", .{});
                    return;
                }
                const cmd = std.meta.stringToEnum(Command, raw_cmd) orelse {
                    log.err("unknown command: {s}", .{raw_cmd});
                    return;
                };
                switch (cmd) {
                    .@"inner-gaps" => {
                        const arg = fmt.parseInt(i32, raw_arg, 10) catch |err| {
                            log.err("failed to parse argument: {}", .{err});
                            return;
                        };
                        switch (raw_arg[0]) {
                            '+' => output.cfg.inner_gaps +|= @intCast(u31, arg),
                            '-' => {
                                const res = output.cfg.inner_gaps +| arg;
                                if (res >= 0) output.cfg.inner_gaps = @intCast(u31, res);
                            },
                            else => output.cfg.inner_gaps = @intCast(u31, arg),
                        }
                    },
                    .@"outer-gaps" => {
                        const arg = fmt.parseInt(i32, raw_arg, 10) catch |err| {
                            log.err("failed to parse argument: {}", .{err});
                            return;
                        };
                        switch (raw_arg[0]) {
                            '+' => output.cfg.outer_gaps +|= @intCast(u31, arg),
                            '-' => {
                                const res = output.cfg.outer_gaps +| arg;
                                if (res >= 0) output.cfg.outer_gaps = @intCast(u31, res);
                            },
                            else => output.cfg.outer_gaps = @intCast(u31, arg),
                        }
                    },
                    .@"gaps" => {
                        const arg = fmt.parseInt(i32, raw_arg, 10) catch |err| {
                            log.err("failed to parse argument: {}", .{err});
                            return;
                        };
                        switch (raw_arg[0]) {
                            '+' => {
                                output.cfg.inner_gaps +|= @intCast(u31, arg);
                                output.cfg.outer_gaps +|= @intCast(u31, arg);
                            },
                            '-' => {
                                const o = output.cfg.outer_gaps +| arg;
                                const i = output.cfg.inner_gaps +| arg;
                                if (i >= 0) output.cfg.inner_gaps = @intCast(u31, i);
                                if (o >= 0) output.cfg.outer_gaps = @intCast(u31, o);
                            },
                            else => {
                                output.cfg.inner_gaps = @intCast(u31, arg);
                                output.cfg.outer_gaps = @intCast(u31, arg);
                            },
                        }
                    },
                    .@"main-location" => {
                        output.cfg.main_location = std.meta.stringToEnum(Location, raw_arg) orelse {
                            log.err("unknown location: {s}", .{raw_arg});
                            return;
                        };
                    },
                    .@"main-count" => {
                        const arg = fmt.parseInt(i32, raw_arg, 10) catch |err| {
                            log.err("failed to parse argument: {}", .{err});
                            return;
                        };
                        switch (raw_arg[0]) {
                            '+' => output.cfg.main_count +|= @intCast(u31, arg),
                            '-' => {
                                const res = output.cfg.main_count +| arg;
                                if (res >= 1) output.cfg.main_count = @intCast(u31, res);
                            },
                            else => {
                                if (arg >= 1) output.cfg.main_count = @intCast(u31, arg);
                            },
                        }
                    },
                    .@"main-ratio" => {
                        const arg = fmt.parseFloat(f64, raw_arg) catch |err| {
                            log.err("failed to parse argument: {}", .{err});
                            return;
                        };
                        switch (raw_arg[0]) {
                            '+', '-' => {
                                output.cfg.main_ratio = math.clamp(output.cfg.main_ratio + arg, 0.1, 0.9);
                            },
                            else => output.cfg.main_ratio = math.clamp(arg, 0.1, 0.9),
                        }
                    },
                    .@"width-ratio" => {
                        const arg = fmt.parseFloat(f64, raw_arg) catch |err| {
                            log.err("failed to parse argument: {}", .{err});
                            return;
                        };
                        switch (raw_arg[0]) {
                            '+', '-' => {
                                output.cfg.width_ratio = math.clamp(output.cfg.width_ratio + arg, 0.1, 1.0);
                            },
                            else => output.cfg.width_ratio = math.clamp(arg, 0.1, 1.0),
                        }
                    },
                }
            },
            .user_command_tags => {},

            .layout_demand => |ev| {
                assert(ev.view_count > 0);

                const main_count = math.min(output.cfg.main_count, @truncate(u31, ev.view_count));
                const sec_count = @truncate(u31, ev.view_count) -| main_count;

                const only_one_view = blk: {
                    if (ev.view_count == 1 or output.cfg.main_location == .monocle) break :blk true;
                    break :blk false;
                };

                // Don't add gaps if there is only one view.
                if (only_one_view and cfg.smart_gaps) {
                    cfg.outer_gaps = 0;
                    cfg.inner_gaps = 0;
                } else {
                    cfg.outer_gaps = output.cfg.outer_gaps;
                    cfg.inner_gaps = output.cfg.inner_gaps;
                }

                const usable_w = switch (output.cfg.main_location) {
                    .left, .right, .monocle => @floatToInt(
                        u31,
                        @intToFloat(f64, ev.usable_width) * output.cfg.width_ratio,
                    ) -| (2 *| cfg.outer_gaps),
                    .top, .bottom => @truncate(u31, ev.usable_height) -| (2 *| cfg.outer_gaps),
                };
                const usable_h = switch (output.cfg.main_location) {
                    .left, .right, .monocle => @truncate(u31, ev.usable_height) -| (2 *| cfg.outer_gaps),
                    .top, .bottom => @floatToInt(
                        u31,
                        @intToFloat(f64, ev.usable_width) * output.cfg.width_ratio,
                    ) -| (2 *| cfg.outer_gaps),
                };

                // To make things pixel-perfect, we make the first main and first sec
                // view slightly larger if the height is not evenly divisible.
                var main_w: u31 = undefined;
                var main_h: u31 = undefined;
                var main_h_rem: u31 = undefined;

                var sec_w: u31 = undefined;
                var sec_h: u31 = undefined;
                var sec_h_rem: u31 = undefined;

                if (output.cfg.main_location == .monocle) {
                    main_w = usable_w;
                    main_h = usable_h;

                    sec_w = usable_w;
                    sec_h = usable_h;
                } else {
                    if (sec_count > 0) {
                        main_w = @floatToInt(u31, output.cfg.main_ratio * @intToFloat(f64, usable_w));
                        main_h = usable_h / main_count;
                        main_h_rem = usable_h % main_count;

                        sec_w = usable_w - main_w;
                        sec_h = usable_h / sec_count;
                        sec_h_rem = usable_h % sec_count;
                    } else {
                        main_w = usable_w;
                        main_h = usable_h / main_count;
                        main_h_rem = usable_h % main_count;
                    }
                }

                var i: u31 = 0;
                while (i < ev.view_count) : (i += 1) {
                    var x: i32 = undefined;
                    var y: i32 = undefined;
                    var width: u31 = undefined;
                    var height: u31 = undefined;

                    if (output.cfg.main_location == .monocle) {
                        x = 0;
                        y = 0;
                        width = main_w;
                        height = main_h;
                    } else {
                        if (i < main_count) {
                            x = 0;
                            y = (i * main_h) + if (i > 0) cfg.inner_gaps + main_h_rem else 0;
                            width = main_w - cfg.inner_gaps / 2;
                            height = (main_h + if (i == 0) main_h_rem else 0) -
                                if (i > 0) cfg.inner_gaps else 0;
                        } else {
                            x = (main_w - cfg.inner_gaps / 2) + cfg.inner_gaps;
                            y = (i - main_count) * sec_h +
                                if (i > main_count) cfg.inner_gaps + sec_h_rem else 0;
                            width = sec_w - cfg.inner_gaps / 2;
                            height = (sec_h + if (i == main_count) sec_h_rem else 0) -
                                if (i > main_count) cfg.inner_gaps else 0;
                        }
                    }

                    switch (output.cfg.main_location) {
                        .left => layout.pushViewDimensions(
                            x +| cfg.outer_gaps,
                            y +| cfg.outer_gaps,
                            width,
                            height,
                            ev.serial,
                        ),
                        .right => layout.pushViewDimensions(
                            usable_w - width -| x +| cfg.outer_gaps,
                            y +| cfg.outer_gaps,
                            width,
                            height,
                            ev.serial,
                        ),
                        .top => layout.pushViewDimensions(
                            y +| cfg.outer_gaps,
                            x +| cfg.outer_gaps,
                            height,
                            width,
                            ev.serial,
                        ),
                        .bottom => layout.pushViewDimensions(
                            y +| cfg.outer_gaps,
                            usable_w - width -| x +| cfg.outer_gaps,
                            height,
                            width,
                            ev.serial,
                        ),
                        .monocle => layout.pushViewDimensions(
                            x +| cfg.outer_gaps,
                            y +| cfg.outer_gaps,
                            width,
                            height,
                            ev.serial,
                        ),
                    }
                }

                switch (output.cfg.main_location) {
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
    const res = flags.parser([*:0]const u8, &.{
        .{ .name = "h", .kind = .boolean },
        .{ .name = "version", .kind = .boolean },
        .{ .name = "no-smart-gaps", .kind = .boolean },
        .{ .name = "inner-gaps", .kind = .arg },
        .{ .name = "outer-gaps", .kind = .arg },
        .{ .name = "main-location", .kind = .arg },
        .{ .name = "main-count", .kind = .arg },
        .{ .name = "main-ratio", .kind = .arg },
        .{ .name = "width-ratio", .kind = .arg },
    }).parse(os.argv[1..]) catch {
        try std.io.getStdErr().writeAll(usage);
        os.exit(1);
    };
    if (res.args.len != 0) fatal_usage("Unknown option '{s}'", .{res.args[0]});

    if (res.flags.h) {
        try io.getStdOut().writeAll(usage);
        os.exit(0);
    }
    if (res.flags.version) {
        try io.getStdOut().writeAll(build_options.version ++ "\n");
        os.exit(0);
    }
    if (res.flags.@"no-smart-gaps") {
        cfg.smart_gaps = false;
    }
    if (res.flags.@"inner-gaps") |raw| {
        cfg.inner_gaps = fmt.parseUnsigned(u31, raw, 10) catch
            fatal_usage("Invalid value '{s}' provided to -inner-gaps", .{raw});
    }
    if (res.flags.@"outer-gaps") |raw| {
        cfg.outer_gaps = fmt.parseUnsigned(u31, raw, 10) catch
            fatal_usage("Invalid value '{s}' provided to -outer-gaps", .{raw});
    }
    if (res.flags.@"main-location") |raw| {
        cfg.main_location = std.meta.stringToEnum(Location, raw) orelse
            fatal_usage("Invalid value '{s}' provided to -main-location", .{raw});
    }
    if (res.flags.@"main-count") |raw| {
        cfg.main_count = fmt.parseUnsigned(u31, raw, 10) catch
            fatal_usage("Invalid value '{s}' provided to -main-count", .{raw});
    }
    if (res.flags.@"main-ratio") |raw| {
        cfg.main_ratio = fmt.parseFloat(f64, raw) catch {
            fatal_usage("Invalid value '{s}' provided to -main-ratio", .{raw});
        };
        if (cfg.main_ratio < 0.1 or cfg.main_ratio > 0.9) {
            fatal_usage("Invalid value '{s}' provided to -main-ratio", .{raw});
        }
    }
    if (res.flags.@"width-ratio") |raw| {
        cfg.width_ratio = fmt.parseFloat(f64, raw) catch {
            fatal_usage("Invalid value '{s}' provided to -width-ratio", .{raw});
        };
        if (cfg.width_ratio < 0.1 or cfg.width_ratio > 1.0) {
            fatal_usage("Invalid value '{s}' provided to -width-ratio", .{raw});
        }
    }

    const display = wl.Display.connect(null) catch {
        fatal("unable to connect to wayland compositor", .{});
    };
    defer display.disconnect();

    const registry = try display.getRegistry();
    defer registry.destroy();
    registry.setListener(*Context, registry_listener, &ctx);

    const errno = display.roundtrip();
    if (errno != .SUCCESS) {
        fatal("initial roundtrip failed: E{s}", .{@tagName(errno)});
    }

    if (ctx.layout_manager == null) {
        fatal("Wayland compositor does not support river_layout_v3.\n", .{});
    }

    ctx.initialized = true;

    var it = ctx.outputs.first;
    while (it) |node| : (it = node.next) {
        try node.data.get_layout();
    }

    while (true) {
        const dispatch_errno = display.dispatch();
        if (dispatch_errno != .SUCCESS) {
            fatal("failed to dispatch wayland events, E:{s}", .{@tagName(dispatch_errno)});
        }
    }
}

fn registry_listener(registry: *wl.Registry, event: wl.Registry.Event, context: *Context) void {
    registry_event(context, registry, event) catch |err| switch (err) {
        error.OutOfMemory => {
            log.err("out of memory", .{});
            return;
        },
        else => return,
    };
}

fn registry_event(context: *Context, registry: *wl.Registry, event: wl.Registry.Event) !void {
    switch (event) {
        .global => |ev| {
            if (std.cstr.cmp(ev.interface, river.LayoutManagerV3.getInterface().name) == 0) {
                context.layout_manager = try registry.bind(ev.name, river.LayoutManagerV3, 2);
            } else if (std.cstr.cmp(ev.interface, wl.Output.getInterface().name) == 0) {
                const wl_output = try registry.bind(ev.name, wl.Output, 4);
                errdefer wl_output.release();

                const node = try gpa.create(std.SinglyLinkedList(Output).Node);
                errdefer gpa.destroy(node);

                node.data = .{
                    .wl_output = wl_output,
                    .name = ev.name,
                    .cfg = cfg,
                };

                if (ctx.initialized) try node.data.get_layout();
                context.outputs.prepend(node);
            }
        },
        .global_remove => |ev| {
            var it = context.outputs.first;
            while (it) |node| : (it = node.next) {
                if (node.data.name == ev.name) {
                    node.data.wl_output.release();
                    node.data.layout.destroy();
                    context.outputs.remove(node);
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

fn fatal_usage(comptime format: []const u8, args: anytype) noreturn {
    log.err(format, args);
    std.io.getStdErr().writeAll(usage) catch {};
    os.exit(1);
}
