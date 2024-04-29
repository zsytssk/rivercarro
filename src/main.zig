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
    \\  -h                    Print this help message and exit.
    \\  -version              Print the version number and exit.
    \\  -no-smart-gaps        Disable smart gaps
    \\  -per-tag              Remember configuration per tag
    \\  -width-ratio-centered Center views when used with width-ratio
    \\
    \\  The following commands may also be sent to rivercarro at runtime
    \\  via riverctl(1):
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
    gaps,
    @"main-location",
    @"main-location-cycle",
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
    width_ratio_centered: bool = false,
    per_tag: bool = false,
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

    cfgs: std.AutoHashMapUnmanaged(u32, Config) = .{},
    user_command_tags: u32 = 0,

    layout: *river.LayoutV3 = undefined,

    fn get_cfg(output: *Output, tags: u32) *Config {
        const default_cfg = output.cfgs.getPtr(0) orelse unreachable;
        if (!cfg.per_tag) return default_cfg;

        // default to global config
        const entry = output.cfgs.getOrPutValue(gpa, tags, default_cfg.*) catch {
            // 0 always has a value
            log.err("out of memory, reverting to default cfg", .{});
            return default_cfg;
        };
        return entry.value_ptr;
    }

    fn get_layout(output: *Output) !void {
        output.layout = try ctx.layout_manager.?.getLayout(output.wl_output, "rivercarro");
        output.layout.setListener(*Output, layout_listener, output);
    }

    fn layout_listener(layout: *river.LayoutV3, event: river.LayoutV3.Event, output: *Output) void {
        switch (event) {
            .namespace_in_use => fatal("namespace 'rivercarro' already in use.", .{}),

            .user_command => |ev| {
                var it = mem.tokenize(u8, mem.span(ev.command), " ");
                const active_cfg = output.get_cfg(output.user_command_tags);
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
                            '+' => active_cfg.inner_gaps +|= @intCast(arg),
                            '-' => {
                                const res = active_cfg.inner_gaps +| arg;
                                if (res >= 0) active_cfg.inner_gaps = @intCast(res);
                            },
                            else => active_cfg.inner_gaps = @intCast(arg),
                        }
                    },
                    .@"outer-gaps" => {
                        const arg = fmt.parseInt(i32, raw_arg, 10) catch |err| {
                            log.err("failed to parse argument: {}", .{err});
                            return;
                        };
                        switch (raw_arg[0]) {
                            '+' => active_cfg.outer_gaps +|= @intCast(arg),
                            '-' => {
                                const res = active_cfg.outer_gaps +| arg;
                                if (res >= 0) active_cfg.outer_gaps = @intCast(res);
                            },
                            else => active_cfg.outer_gaps = @intCast(arg),
                        }
                    },
                    .gaps => {
                        const arg = fmt.parseInt(i32, raw_arg, 10) catch |err| {
                            log.err("failed to parse argument: {}", .{err});
                            return;
                        };
                        switch (raw_arg[0]) {
                            '+' => {
                                active_cfg.inner_gaps +|= @intCast(arg);
                                active_cfg.outer_gaps +|= @intCast(arg);
                            },
                            '-' => {
                                const o = active_cfg.outer_gaps +| arg;
                                const i = active_cfg.inner_gaps +| arg;
                                if (i >= 0) active_cfg.inner_gaps = @intCast(i);
                                if (o >= 0) active_cfg.outer_gaps = @intCast(o);
                            },
                            else => {
                                active_cfg.inner_gaps = @intCast(arg);
                                active_cfg.outer_gaps = @intCast(arg);
                            },
                        }
                    },
                    .@"main-location" => {
                        active_cfg.main_location = std.meta.stringToEnum(Location, raw_arg) orelse {
                            log.err("unknown location: {s}", .{raw_arg});
                            return;
                        };
                    },
                    .@"main-location-cycle" => {
                        var loc_it = mem.splitSequence(u8, raw_arg, ",");
                        // select the first one, then the one after the current
                        var picked: ?Location = null;
                        var pick_next: bool = false;
                        while (loc_it.next()) |loc| {
                            const current = std.meta.stringToEnum(Location, loc) orelse {
                                log.err("unknown location: {s}", .{loc});
                                return;
                            };
                            if (picked == null or pick_next) {
                                picked = current;
                                if (pick_next) break;
                            }
                            if (current == active_cfg.main_location) {
                                pick_next = true;
                            }
                        }
                        active_cfg.main_location = picked.?;
                    },
                    .@"main-count" => {
                        const arg = fmt.parseInt(i32, raw_arg, 10) catch |err| {
                            log.err("failed to parse argument: {}", .{err});
                            return;
                        };
                        switch (raw_arg[0]) {
                            '+' => active_cfg.main_count +|= @intCast(arg),
                            '-' => {
                                const res = active_cfg.main_count +| arg;
                                if (res >= 1) active_cfg.main_count = @intCast(res);
                            },
                            else => {
                                if (arg >= 1) active_cfg.main_count = @intCast(arg);
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
                                active_cfg.main_ratio = math.clamp(active_cfg.main_ratio + arg, 0.1, 0.9);
                            },
                            else => active_cfg.main_ratio = math.clamp(arg, 0.1, 0.9),
                        }
                    },
                    .@"width-ratio" => {
                        const arg = fmt.parseFloat(f64, raw_arg) catch |err| {
                            log.err("failed to parse argument: {}", .{err});
                            return;
                        };
                        switch (raw_arg[0]) {
                            '+', '-' => {
                                active_cfg.width_ratio = math.clamp(active_cfg.width_ratio + arg, 0.1, 1.0);
                            },
                            else => active_cfg.width_ratio = math.clamp(arg, 0.1, 1.0),
                        }
                    },
                }
            },
            .user_command_tags => |ev| {
                output.user_command_tags = ev.tags;
            },

            .layout_demand => |ev| {
                assert(ev.view_count > 0);

                const active_cfg = output.get_cfg(ev.tags);
                const main_count = @min(active_cfg.main_count, @as(u31, @truncate(ev.view_count)));
                const sec_count = @as(u31, @truncate(ev.view_count)) -| main_count;

                const only_one_view = ev.view_count == 1 or active_cfg.main_location == .monocle;

                // Don't add gaps if there is only one view.
                if (only_one_view and cfg.smart_gaps) {
                    cfg.outer_gaps = 0;
                    cfg.inner_gaps = 0;
                } else {
                    cfg.outer_gaps = active_cfg.outer_gaps;
                    cfg.inner_gaps = active_cfg.inner_gaps;
                }

                const usable_w = switch (active_cfg.main_location) {
                    .left, .right, .monocle => @as(
                        u31,
                        @intFromFloat(@as(f64, @floatFromInt(ev.usable_width)) * active_cfg.width_ratio),
                    ) -| (2 *| cfg.outer_gaps),
                    .top, .bottom => @as(u31, @truncate(ev.usable_height)) -| (2 *| cfg.outer_gaps),
                };
                const usable_h = switch (active_cfg.main_location) {
                    .left, .right, .monocle => @as(u31, @truncate(ev.usable_height)) -| (2 *| cfg.outer_gaps),
                    .top, .bottom => @as(
                        u31,
                        @intFromFloat(@as(f64, @floatFromInt(ev.usable_width)) * active_cfg.width_ratio),
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

                if (active_cfg.main_location == .monocle) {
                    main_w = usable_w;
                    main_h = usable_h;

                    sec_w = usable_w;
                    sec_h = usable_h;
                } else {
                    if (sec_count > 0) {
                        main_w = @as(u31, @intFromFloat(active_cfg.main_ratio * @as(f64, @floatFromInt(usable_w))));
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

                    if (active_cfg.main_location == .monocle) {
                        x = 0;
                        y = 0;
                        width = main_w;
                        height = main_h;
                    } else {
                        if (i < main_count) {
                            x = 0;
                            y = (i * main_h) + if (i > 0) cfg.inner_gaps + main_h_rem else 0;
                            width = if (sec_count > 0) main_w - cfg.inner_gaps / 2 else main_w;
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

                    if (active_cfg.width_ratio != 1.0 and active_cfg.width_ratio_centered) {
                        x += @intCast((ev.usable_width - usable_w) / 2);
                    }

                    switch (active_cfg.main_location) {
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

                switch (active_cfg.main_location) {
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
        .{ .name = "width-ratio-centered", .kind = .boolean },
        .{ .name = "per-tag", .kind = .boolean },
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
    if (res.flags.@"width-ratio-centered") cfg.width_ratio_centered = true;
    if (res.flags.@"per-tag") cfg.per_tag = true;

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
            if (mem.orderZ(u8, ev.interface, river.LayoutManagerV3.getInterface().name) == .eq) {
                context.layout_manager = try registry.bind(ev.name, river.LayoutManagerV3, 2);
            } else if (mem.orderZ(u8, ev.interface, wl.Output.getInterface().name) == .eq) {
                const wl_output = try registry.bind(ev.name, wl.Output, 4);
                errdefer wl_output.release();

                const node = try gpa.create(std.SinglyLinkedList(Output).Node);
                errdefer gpa.destroy(node);

                node.data = .{
                    .wl_output = wl_output,
                    .name = ev.name,
                };
                try node.data.cfgs.put(gpa, 0, cfg);

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
                    node.data.cfgs.deinit(gpa);
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
