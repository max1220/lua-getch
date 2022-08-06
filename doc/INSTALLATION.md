# LuaRocks installation

This library is packaged and build using Luarocks, which makes building
and installing easy.

Currently this library is not published on a luarocks server,
so you need to clone this repository and build it yourself:

```
git clone https://github.com/max1220/lua-getch
cd lua-getch
# install locally, usually to ~/.luarocks
luarocks make --local
```

This will install the module locally, typically in ~/.luarocks.



## Adding additional CFLAGS etc.

You can also add additional CFLAGS when building with LuaRocks, e.g.:

```
luarocks make --local CFLAGS="-O2 -fPIC -Wall -Wextra -Wpedantic"
```



## Adding to LuaRocks modules to package.path

When installing locally you need to tell Lua where to look for modules
installed using Luarocks, e.g.:

```
luarocks path >> ~/.bashrc
```

This will allow you to `require()` and locally installed LuaRocks package.

