# Rivercarro

A slightly modified version of _rivertile_ layout generator for
**[river][]**

Compared to _rivertile_, _rivercarro_ add:

-   monocle layout
-   smart gaps

Features I may add, or not, still debating with myself,
[contribution][] welcome:

-   smart borders - using `river-control-unstable-v1` protocol to send
    `border-width` and `0` to remove borders, could be buggy but it's the
    better solution for now, waiting for `river-control-v2`
-   "true" gaps _( see [stacktile][] )_
-   per tags layout

[river]: https://github.com/ifreund/river
[contribution]: #Contributing
[stacktile]: https://sr.ht/~leon_plickat/stacktile/

## Building

Same requirements as **[river][]**, use [zig 0.8.0][] too, if **[river][]** and
_rivertile_ works on your machine you shouldn't have any problems

Init submodules:

    git submodule update --init

Build, `e.g.`

    zig build --prefix ~/.local

[river]: https://github.com/ifreund/river#building
[zig 0.8.0]: https://ziglang.org/download/

## Usage

Works exactly as _rivertile_, you can just replace _rivertile_ name by
_rivercarro_ in your config, and read `rivertile(1)` man page

`e.g.` In your **river** init (usually `$XDG_CONFIG_HOME/river/init`)

```bash

# Mod+H and Mod+L to decrease/increase the main_factor value of rivercarro by 0.05
riverctl map normal $mod H mod-layout-value rivercarro fixed main_factor -0.05
riverctl map normal $mod L mod-layout-value rivercarro fixed main_factor +0.05

# Mod+Shift+H and Mod+Shift+L to increment/decrement the main_count value of rivercarro.
riverctl map normal $mod+Shift H mod-layout-value rivercarro int main_count +1
riverctl map normal $mod+Shift L mod-layout-value rivercarro int main_count -1

# Mod+{Up,Right,Down,Left} to change layout orientation
riverctl map normal $mod Up    set-layout-value rivercarro string main_location top
riverctl map normal $mod Right set-layout-value rivercarro string main_location right
riverctl map normal $mod Down  set-layout-value rivercarro string main_location bottom
riverctl map normal $mod Left  set-layout-value rivercarro string main_location left
# And for monocle
riverctl map normal $mod M     set-layout-value rivercarro string main_location monocle

# Set and exec into the default layout generator, rivercarro.
# River will send the process group of the init executable SIGTERM on exit.
riverctl default-layout rivercarro
exec rivercarro

```

### Command line options

```bash
$ rivercarro --help
Usage: rivercarro [options]

  -h, --help      Print this help message and exit.
  -view-padding   Set the padding around views in pixels. (Default 6)
  -outer-padding  Set the padding around the edge of the layout area in
                  pixels. (Default 6)
  -main-location  Set the initial location of the main area in the
                  layout. (Default left)
  -main-count     Set the initial number of views in the main area of the
                  layout. (Default 1)
  -main-factor    Set the initial ratio of main area to total layout
                  area. (Default: 0.6)
  -no-smart-gaps  Disable smart gaps
```

## Contributing

Send patches or question using [git send-email][] to my [public inbox][]
[~novakane/public-inbox@lists.sr.ht][] with project prefix set to
`rivercarro`:

```
git config sendemail.to "~novakane/public-inbox@lists.sr.ht"
git config format.subjectPrefix "PATCH rivercarro"
```

Run `zig fmt` and wrap line at 100 columns unless it makes sense

[git send-email]: https://git-send-email.io
[public inbox]: https://lists.sr.ht/~novakane/public-inbox
[~novakane/public-inbox@lists.sr.ht]: mailto:~novakane/public-inbox@lists.sr.ht

## Credits

Almost all credits go to [Isaac Freund][] and [Leon Henrik Plickat][]

**Thanks to them!**

[Isaac Freund]: https://github.com/ifreund
[Leon Henrik Plickat]: https://sr.ht/~leon_plickat/

## License

[GNU General Public License v3.0][]

[GNU General Public License v3.0]: LICENSE
