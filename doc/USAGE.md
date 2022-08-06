# Usage

The lua-getch module is split into two parts:
A set of C functions for manipulating the terminal, and a set of Lua
modules that make using the C functions a lot easier.

Load the complete module by calling `require("lua-getch")`,
which in `init.lua` loads the C library via `require("getch")`,
and extends the table returned by the C module with some Lua functions.





# getch.get_termios_attributes(fd)

`iflags,oflags,cflags,lflags = getch.get_termios_attributes(fd)`

Get the termios attributes from the specified file descriptor.
This is a binding for the `tcgetattr`(see `man 3 termios`) function.

`fd` is either a Lua file descriptor usedata object(such as io.stdin),
or a file descriptor number.

Return values are termios flags, nil otherwise. See `man 3 termios`





# getch.set_termios_attributes(fd, iflags,oflags,cflags,lflags, optional_actions)

`ok = getch.set_termios_attributes(fd, iflags,oflags,cflags,lflags)`

Set the termios attributes for the specified file descriptor.

`fd` is either a Lua file descriptor usedata object(such as io.stdin),
or a file descriptor number.
This is a binding for the `tcsetattr`(see `man 3 termios`) function.
`iflags`, `oflags`, `cflags`, `lflags` are input/output/control/local flags. See `man 3 termios`
`optional_actions` defaults to `TCSANOW` if not specified.
If a flag is not specified(nil) it stays unchanged.

Return value `ok` is true if successful, false otherwise





# Constants

These constants are provided by the C module as well.
Please see the termios documentation for details on what they do.
Lua flag names are lower-cased. (See `man 3 termios`)



## getch.iflags

Input flag constants from termios. See `man 3 termios`.

Valid indices are:

ignbrk, brkint, ignpar, parmrk, inpck, istrip, inlcr, igncr, icrnl, iuclc, ixon, ixany, ixoff, imaxbel, iutf8



## getch.oflags

Output flag constants from termios. See `man 3 termios`.

Valid indices are:

opost, olcuc, onlcr, ocrnl, onocr, onlret, ofill, ofdel, nldly, crdly, tabdly, bsdly, vtdly, ffdly



## getch.cflags

Control flag constants from termios. See `man 3 termios`.

Valid indices are:

cbaud, cbaudex, csize, cstopb, cread, parenb, parodd, hupcl, clocal, cibaud, cmspar, crtscts



## getch.lflags

Local flag constants from termios. See `man 3 termios`.

Valid indices are:

isig, icanon, xcase, echo, echoe, echok, echonl, echoctl, echoprt, echoke, flusho, noflsh, tostop, pendin, iexten



## getch.optional_actions

Optional actions constants to perform on set_termios_attributes.

Valid indices are:

tcsanow, tcsadrain, tcsaflush





# getch.set_nonblocking(fd, non_blocking)

`ok = getch.set_nonblocking(fd, non_blocking)`

Enable or disable non-blocking mode for the specified file descriptor.
This is a partial binding for the `fcntl`(`man 2 fcntl`) function.

`fd` is a Lua file descriptor, or file descriptor number.
`non_blocking` if true, enable non-blocking mode, otherwise disable

Return value `ok` is true if successful, nil otherwise.





# getch.select(timeout, read_fd1, read_fd2, ..., nil, write_fd1, write_fd2, ...)

`ok, read_fd1, read_fd2, ..., nil, write_fd1, write_fd2 = getch.select(timeout, read_fd1, read_fd2, ..., nil, write_fd1, write_fd2, ...)`

Wait until the specified file descriptors become available for
reading/writing, or the timeout(if any) has elapsed.
This is a partial binding for the `select`(`man 2 select`) function.

`timeout` is the timeout in seconds, or nil to wait indefinitly.
All other arguments are expected to be file descriptors(numbers or file userdata).
All file descriptors are added to the read file descriptor list, until
the first nil in the argument, then they are treated as write file descriptors.


The following Lua functions are added to the table returned by the C module
(the table returned by `require("getch")`) when the module is loaded as
`require("lua-getch")`.

Return value `ok` is true if successful, nil otherwise.
If a file descriptor is ready then it is returned, nil otherwise.
The file descriptors are always returned in the same argument position.





# getch:set_raw_mode(fd, non_blocking)

`ok = getch:set_raw_mode(fd)`

This enables the non-canonical bit to enable character-based input, and
disables local echo. Optionally enables non-blocking mode.
This provieds a basic "raw terminal" mode for interactive applications.
Stores the current terminal attributes in an upvalue.

`fd` is a Lua file descriptor, or file descriptor number.

Return value `ok` is true if successful, nil otherwise.




# getch:restore_mode()

Restores the "regular" terminal mode after using `getch:set_raw_mode()`.
`getch.set_raw_mode()` needs to be called before this function.





# getch:get_char(fd)

`char = getch:get_char(fd)`

Get a single character from the specified file descriptor as an integer.
This basically does `io.read(1):byte()`, but catches the error that
would occur when `io.read(1)` returns nil.

`fd` is a Lua file descriptor, or file descriptor number.

Return value `char` is a number when reading succeeds, nil otherwise.





# getch:get_char_stdin()

`char = getch:get_char_stdin()`

This just does `getch.get_char(io.stdin)`.

This is only here because it is used very often, and makes the usage
of `getch:get_key_mbs()` easier.





# getch:get_char_cooked(timeout)

`char = getch:get_char_stdin()`

This disables the LibC line buffering for stdin(`io.stdin:setvbuf("no")`),
enables raw mode(using `getch:set_raw_mode(io.stdin)`),
tries to read a character with an optional timeout, then restores the
terminal(enable line buffering, leave raw mode).

`timeout` is the timeout in seconds to wait for a character.

Return value `char` is a number when reading succeeds, nil otherwise(e.g. timeout).





# getch:get_key_mbs

`resolved, seq = getch:get_key_mbs(get_key, key_table, max_depth, seq)`

Try to resolve a multibyte sequence by calling the
`get_key` callback function repeatedly,
and resolving results using the `key_table` recursively.

This enables easy parsing of terminal escape sequences like.

`get_key` is a callback that is called when a new key in the multibyte
sequence is requested.
No arguments are passed to the callback.

Return values from this callback are looked up in `key_table`:
When indexing the `key_table` using the returned value yields
another table, this function recurses,
using the found table as the new `key_table`.

Return value `resolved` is the resolved value from key_table if any,
nil otherwise.
Return value `seq` is a table containing all values returned by the
`get_key` function(a list of all characters that have been read so far).



## getch.key_table

An example `key_table` that can resolve some terminal input sequences
to more useful strings.

Currently it resolves the following keys on ANSI-like terminals:

tab, enter, backspace, delete, escape, up/down/left/right, pos1, insert, pageup/pagedown
