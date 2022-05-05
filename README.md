# Rivercarro

A slightly modified version of _rivertile_ layout generator for
**[river]**

Compared to _rivertile_, _rivercarro_ adds:

-   Monocle layout, views will takes all the usable area on the screen.
-   Gaps instead of padding around views or layout area.
-   Modify gaps size at runtime.
-   Smart gaps, if there is only one view, gaps will be disable.
-   Limit the width of the usable area of the screen.

If you want a layout generator with more features and configuration, have
a look at some others great community contributions like [stacktile] or [kile].

## Building

Same requirements as **[river]**, use [zig] 0.9, if **[river]** and
_rivertile_ works on your machine you shouldn't have any problems.

Init submodules:

    git submodule update --init

Build, `e.g.`

    zig build --prefix ~/.local

## Usage

Works exactly as _rivertile_, you can just replace _rivertile_ name by
_rivercarro_ in your config, and read `rivercarro(1)` man page for commands
specific to rivercarro.

`e.g.` In your **river** init (usually `$XDG_CONFIG_HOME/river/init`)

```bash
# Mod+H and Mod+L to decrease/increase the main ratio of rivercarro
riverctl map normal $mod H send-layout-cmd rivercarro "main-ratio -0.05"
riverctl map normal $mod L send-layout-cmd rivercarro "main-ratio +0.05"

# Mod+Shift+H and Mod+Shift+L to increment/decrement the main count of rivercarro
riverctl map normal $mod+Shift H send-layout-cmd rivercarro "main-count +1"
riverctl map normal $mod+Shift L send-layout-cmd rivercarro "main-count -1"

# Mod+{Up,Right,Down,Left} to change layout orientation
riverctl map normal $mod Up    send-layout-cmd rivercarro "main-location top"
riverctl map normal $mod Right send-layout-cmd rivercarro "main-location right"
riverctl map normal $mod Down  send-layout-cmd rivercarro "main-location bottom"
riverctl map normal $mod Left  send-layout-cmd rivercarro "main-location left"
# And for monocle
riverctl map normal $mod M     send-layout-cmd rivercarro "main-location monocle"

# Add others rivercarrro's commands the same way with the keybinds you'd like.
# e.g.
# riverctl map normal $mod <keys> send-layout-cmd rivercarro "inner-gaps -1"
# riverctl map normal $mod <keys> send-layout-cmd rivercarro "inner-gaps +1"
# riverctl map normal $mod <keys> send-layout-cmd rivercarro "outer-gaps -1"
# riverctl map normal $mod <keys> send-layout-cmd rivercarro "outer-gaps +1"
# riverctl map normal $mod <keys> send-layout-cmd rivercarro "width-ratio -0.1"
# riverctl map normal $mod <keys> send-layout-cmd rivercarro "width-ratio +0.1"

# Set and exec into the default layout generator, rivercarro.
# River will send the process group of the init executable SIGTERM on exit.
riverctl default-layout rivercarro
exec rivercarro
```

### Command line options

```
$ rivercarro -h
Usage: rivercarro [options...]

  -h              Print this help message and exit.
  -version        Print the version number and exit.
  -no-smart-gaps  Disable smart gaps

  The following commands may also be sent to rivercarro at runtime:

  -inner-gaps     Set the gaps around views in pixels. (Default 6)
  -outer-gaps     Set the gaps around the edge of the layout area in
                  pixels. (Default 6)
  -main-location  Set the initial location of the main area in the
                  layout. (Default left)
  -main-count     Set the initial number of views in the main area of the
                  layout. (Default 1)
  -main-ratio     Set the initial ratio of main area to total layout
                  area. (Default: 0.6)
  -width-ratio    Set the ratio of the usable area width of the screen.
                  (Default: 1.0)

  See rivercarro(1) man page for more documentation.
```

## Contributing

See [CONTRIBUTING.md]

You can also found me on IRC `irc.libera.chat` as `novakane`, mostly on
`#river`.

## Thanks

Thanks to [Isaac Freund] and [Leon Henrik Plickat] for river obviously, for
rivertile, most of rivercarro code comes from them, and for always answering
my many questions!

## License

rivercarro is licensed under the [GNU General Public License v3.0 or later]

Files in `common/` and `protocol/` directories are released under various
licenses by various parties. You should refer to the copyright block of each
files for the licensing information.

[river]: https://github.com/ifreund/river
[stacktile]: https://sr.ht/~leon_plickat/stacktile/
[kile]: https://gitlab.com/snakedye/kile
[zig]: https://ziglang.org/download/
[contributing.md]: CONTRIBUTING.md
[isaac freund]: https://github.com/ifreund
[leon henrik plickat]: https://sr.ht/~leon_plickat/
[gnu general public license v3.0 or later]: COPYING
