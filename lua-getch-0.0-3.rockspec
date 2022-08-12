package = "lua-getch"
version = "0.0-3"
source = {
	url = "git://github.com/max1220/lua-getch",
	tag = "0.0-3"
}
description = {
	summary = "Simple implementation of an (optionally non-blocking) getch implementation",
	detailed = [[
		This libraray implements a getch() function for getting input codes
		from a connected terminal one character at a time, and some basic
		utillities for parsing terminal input codes.
	]],
	homepage = "http://github.com/max1220/lua-getch",
	license = "MIT"
}
dependencies = {
	"lua >= 5.1"
}
build = {
	type = "builtin",
	modules = {
		getch = {
			sources = {"src/lua-getch.c"},
			defines = {
				"LUAROCK_PACKAGE_VERSION=\""..version.."\"",
				"LUAROCK_PACKAGE_NAME=\""..package.."\""
			}
		}
	}
}
