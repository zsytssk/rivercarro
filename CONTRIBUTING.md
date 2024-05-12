# CONTRIBUTING

## Commit messages

Commit messages should start with a prefix indicating which part of the
project is affected by your change, if this a general code patch you may not
add it, followed by a one sentence summary, first word is capitalized. First
line is 50 columns long max.

Example:

    seat: Add pointer events

    Update to zig 1.0.0

You can add everything you feel need to be mentioned in the body of the
commit message, wrap lines at 72 columns.

A great guide to follow [here](https://gitlab.freedesktop.org/wayland/weston/-/blob/master/CONTRIBUTING.md#formatting-and-separating-commits).

## Patches

For patches send a **plain text** mail to the [public inbox](https://lists.sr.ht/~novakane/public-inbox)
[~novakane/public-inbox@lists.sr.ht](mailto:~novakane/public-inbox@lists.sr.ht)
with project prefix set to `rivercarro`:

The prefix will looks like this `[PATCH rivercarro] <commit-message>`

You can configure your Git repo like so:

```bash
git config sendemail.to "~novakane/public-inbox@lists.sr.ht"
git config format.subjectPrefix "PATCH rivercarro"
```

Some useful resources if you're not used to send patches by email:

-   Using [git send-email](https://git-send-email.io).
-   [plain text email](https://useplaintext.email/), if you need a better email
      client and learn how to format your email.
-   Learn [git rebase](https://git-rebase.io/).
-   [pyonji](https://git.sr.ht/~emersion/pyonji) an easy-to-use cli tool to send e-mail patches.

`git.sr.ht` also provides a [web UI](https://man.sr.ht/git.sr.ht/#sending-patches-upstream) if you prefer.

## Issues

Questions or discussions works the same way than patches, precise the project
name in the subject, you just don't need to add `PATCH` before the project name,
e.g.  `[rivercarro] how do I do this?`

## Coding style

Follow [zig style guide](https://ziglang.org/documentation/0.8.0/#Style-Guide)
no other option for _zig_ which is kinda great.

Some things are not enforced by `zig fmt`, I do have an opinion on some of
these things though:

-   Use snake_case for function name, I know this is a pretty big difference
      from the official style guide but it makes code so much more readable.
-   Wrap lines at 100 columns unless it helps readability.
-   Use the struct name instead of Self.

    ```zig
    // Foo.zig
    const Foo = @This();

    // Do this
    pub fn init(foo: *Foo) void {}
    // instead of this
    pub fn init(self: *Foo) void {}
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
    pub example_function(
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

