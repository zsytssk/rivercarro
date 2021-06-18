# rivercarro

A slightly modified version of `rivertile` layout generator for [river](https://github.com/ifreund/river)

Compared to `rivertile`, `rivercarro` add:

-   monocle layout
-   smart gaps

Features I may add, or not, still not decided on what I want,
[contribution](#Contributing) welcome:

-   smart borders - using river-control-unstable-v1 protocol to send "border-width" and
    0 to remove borders, could be buggy but it's the better solution for now, waiting for
    river-control v2
-   "true" gaps _( see [stacktile](https://sr.ht/~leon_plickat/stacktile/) )_
-   per tags layout
-   command to turn on/off smart gaps/borders

## Building

Same requirements as [river](https://github.com/ifreund/river#building),
use [zig 0.8.0](https://ziglang.org/download/) too

Init submodules:

    git submodule update --init

Build, e.g.

    zig build --prefix ~/.local

## Usage

Works exactly as `rivertile`, you can just replace `rivertile` name by
`rivercarro` in your config

e.g.
In your river init (usually `$XDG_CONFIG_HOME/river/init`)

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

## Contributing

Send patches or question using [git send-email](https://git-send-email.io) to my [public inbox](https://lists.sr.ht/~novakane/public-inbox)  
`~novakane/public-inbox@lists.sr.ht` with project prefix set to `rivercarro`:

```
git config sendemail.to "~novakane/public-inbox@lists.sr.ht"
git config format.subjectPrefix "PATCH rivercarro"
```

Run `zig fmt` and wrap line at 100 columns unless it makes sense

## Credits

Almost all credits go to [Isaac Freund](https://github.com/ifreund) and
[Leon Henrik Plickat](https://sr.ht/~leon_plickat/)

Thanks to them!

## License

[GNU General Public License v3.0](LICENSE)
