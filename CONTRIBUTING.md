# CONTRIBUTING

## Commit messages

Commit messages should start with a prefix indicating which part of the
project is affected by your change, followed by a one sentence summary,
first word is capitalized. First line is 50 columns long max.

Example:

    seat: Add pointer events

or

    backend: Fix typo in error message

You can add everything you feel need to be mentioned in the body of the
commit message, wrap lines at 72 columns.

A great guide to follow [here].

## Patches

For patches send a [plain text] mail to my [public inbox]
[~novakane/public-inbox@lists.sr.ht] with project prefix set to `rivercarro`:

You can configure your Git repo like so:

```bash
git config sendemail.to "~novakane/public-inbox@lists.sr.ht"
git config format.subjectPrefix "PATCH rivercarro"
```

Questions or discussions works the same way, precise the project name in
the subject, you just don't need to add `PATCH` before the project name.

Some useful resources if you're not used to send patches by email:

-   Using [git send-email].
-   [plain text email], if you need a better email client and learn
    how to format your email.
-   Learn [git rebase].

`git.sr.ht` also provides a [web UI] if you prefer.

## Coding style

Follow [zig style guide] no other option for _zig_ which is kinda great.

Some things are not enforced by `zig fmt`, I do have an opinion on some of
these things though:

-   Wrap lines at 100 columns unless it helps readability.
-   Wrap comments at 80 columns.
-   Filename: use `Foo.zig` if you only export one struct, if there is
    more than one struct to export use `foo.zig`:

    ```zig
    // Foo.zig
    const Foo = @This();

    field,
    field2,

    pub fn init() void {}

    fn function2() !void {}
    ```

    ```zig
    // foo.zig
    pub const Stuct1 = struct {
        field,
        field2,

        pub fn init() void {}
    };

    pub const Struct2 = struct {
        pub fn init() void {}

        fn function2() !void {}
    };
    ```

-   For import at the top of the file, I do it like this:

    -   std libs.
    -   Dependencies (_alphabetical order_).
    -   Other files from the project (_alphabetical order_). At the end
        of this section, add `const <Struct> = @This()` if needed.

    ```zig
    const std = @import("std");
    const fmt = std.fmt;
    const mem = std.mem;
    const os = std.os;

    const fcft = @import("fcft");
    const pixman = @import("pixman");
    const wayland = @import("wayland");
    const wl = wayland.client.wl;
    const zriver = wayland.client.zriver;

    const Buffer = @import("shm.zig").Buffer;
    const BufferStack = @import("shm.zig").BufferStack;
    const ctx = &@import("Client.zig").ctx;
    const Font = @import("Font.zig");
    const renderer = @import("renderer.zig");
    const Surface = @import("Surface.zig");
    const Output = @This();
    ```

-   For small `if` condition, use:

    ```zig
    if (false) return;

    // or

    if (false) {
        return;
    }

    // Do not use this:

    if (false)
        return;

    ```

-   Format using `zig fmt` before every commit, some tips to use it:

    ```zig
    pub exempleFunction(
        args1: type,
        args2: type,
        args3: type,
        args4: type, // <- Use a comma here so zig fmt respect it
    ) void {}
    ```

    ```zig
    if (cond1 == 1 and               // <- Line break after and/or
        cond2 == 2 and
        cond3 == 3 and cond4 == 4 or // <- Works like this too
        cond5 == 5) {}
    ```

[here]: https://gitlab.freedesktop.org/wayland/weston/-/blob/master/CONTRIBUTING.md#formatting-and-separating-commits
[gitpro book]: https://git-scm.com/book/en/v2/Distributed-Git-Contributing-to-a-Project
[public inbox]: https://lists.sr.ht/~novakane/public-inbox
[~novakane/public-inbox@lists.sr.ht]: mailto:~novakane/public-inbox@lists.sr.ht
[git send-email]: https://git-send-email.io
[plain text email]: https://useplaintext.email/
[git rebase]: https://git-rebase.io/
[web ui]: https://man.sr.ht/git.sr.ht/#sending-patches-upstream
[zig style guide]: https://ziglang.org/documentation/0.8.0/#Style-Guide
