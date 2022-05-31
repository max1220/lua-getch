# Usage

This document explains how to use the lua-getch library.
Some knowledge of how terminals work may be required.



## `ch = getch.blocking()`

Gets a single character, blocking(waits for a character). `ch` is a character code as defined by the terminal,
and is returned as a number.
Note that a character code might be part of an escape sequence send by the terminal.
Returns nil on EOF.



## `ch,err = getch.non_blocking(timeout)`

Gets a single character, non-blocking(check for a character).
Returns nil if no character is available, the character code otherwise(see above).
If optional argument timeout is specified, wait up to timeout seconds for input.
If ch is nil, err is the error code(EOF etc.)




## `ch, resolved = getch.get_mbs(callback, key_table)`

Utility function to help decode multibyte terminal sequences, by looking up
successive character codes provided by `callback` in the nested `key_table`.
This function calls the `key = callback()` function to get an index into the `key_table`.
If the returned key is a function, that function is called with the callback and the last key as arguments,
and the return value is used as the new value for key(e.g. `key = key(callback, last_key)`).
If that key is present in the key_table and it's corresponding table entry is not a table value,
it is returned as-is(`return key_table[key]`). If it is a table value this function calls itself in a
recursive manner to resolve the multibyte sequence(e.g. `return get_mbs(callback, key_table[key])`).

e.g. when you press the up arrow key on most terminals, a sequence such as `\e[A` (decimal 27, 91, 65)
is generated, so you can use this function to look up this sequence in a table that could like this:

```
local key_table = { [27] = { [91] = { [65] = "Up" } } }
local ch, resolved = getch.get_mbs(getch.blocking, key_table)`
```

In this example, the function would return `65, "Up"`.

There would be 3 calls to getch.get_mbs:
```
local ch, resolved = getch.get_mbs(getch.blocking, { [27] = { [91] = { [65] = "Up" } } }) -- calls in return...
getch.get_mbs(getch.blocking, { [91] = { [65] = "Up" } }) -- calls in return...
getch.get_mbs(getch.blocking, { [65] = "Up" }) -- returns 65, "Up"
```

*Note*: `ch` is always the *last* return value from callback.

