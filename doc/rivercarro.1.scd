RIVERCARRO(1)

# NAME

rivercarro - tiled layout generator for river

# SYNOPSIS

*rivercarro* [options...]

# DESCRIPTION

rivercarro is a fork of *rivertile*(1) layout generator for *river*(1).
It provides a simple tiled layout with split main/secondary stacks. The
initial state may be configured with various options passed on startup. Some
values may additionally be modified while rivercarro is running with the
help of *riverctl*(1).

In addition to *rivertile*(1), *rivercarro* provides:

- Monocle layout, views will takes all the usable area on the screen.
- Smart gaps, if there is only one view, gaps will be disable.
- Inner gaps instead of padding around views.
- Limit the width of the usable area of the screen.

# OPTIONS

*-h*
	Print a help message and exit.

*-version*
	Print the version number and exit.

*-view-padding* <pixels>
	Set the padding around views in pixels.

	Default: 6

*-outer-padding* <pixels>
	Set the padding around the edge of the layout area in pixels.

	Default: 6

*-main-location* <top|bottom|left|right|monocle>
	Set the initial location of the main area in the layout.

	Default: left

*-main-count* <count>
	Set the initial number of views in the main area of the
	layout.

	Default: 1

*-main-ratio* <ratio>
	Set the initial ratio of the main area to total layout area. The
	_ratio_ must be between 0.1 and 0.9, inclusive.

	Default: 0.6

*-width-ratio* <ratio>
	Set the initial ratio of the width of the usable area of the
	screen. The _ratio_ must be between 0.1 and 1.0, inclusive.

	Default: 1.0

*-no-smart-gaps*
	Disable smart gaps.

# COMMANDS

These commands may be sent to rivercarro at runtime with the help of
*riverctl*(1).

*main-location* <top|bottom|left|right|monocle>
	Set the location of the main area in the layout.

*main-count* <value>
	Set or modify the number of views in the main area of the layout. If
	_value_ is prefixed by a +/- sign, _value_ is added/subtracted from the
	current count. If there is no sign, the main count is set to _value_.

*main-ratio* <value>
	Set or modify the ratio of the main area to total layout area. If
	_value_ is prefixed by a +/- sign, _value_ is added/subtracted from
	the current ratio. If there is no sign, the main ratio is set to
	_value_. Note that the ratio will always be clamped to the range
	0.1 to 0.9.

*width-ratio* <value>
	Set or modify the ratio of the the width of the usable area of
	the screen. If _value_ is prefixed by a +/- sign, _value_ is
	added/subtracted from the current ratio. If there is no sign, the
	width ratio is set to _value_. Note that the ratio will always be
	clamped to the range 0.1 to 1.0.

# EXAMPLES

Start *rivercarro* with 4 pixels outer padding and the *top* main location:

	rivercarro -outer-padding 4 -main-location top

Increase the main ratio by 0.1 at runtime:

	riverctl send-layout-cmd rivercarro "main-ratio +0.1"

Set the main count to 3 at runtime:

	riverctl send-layout-cmd rivercarro "main-count 3"

Set the width ratio at 70% at runtime:

	riverctl send-layout-cmd rivercarro "width-ratio 0.7"

# SEE ALSO

*river*(1), *riverctl*(1), *rivertile*(1)
