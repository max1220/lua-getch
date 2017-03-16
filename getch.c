#include <stdio.h>
#include <termios.h>
#include <unistd.h>
#include <fcntl.h>
#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>

static int l_getch_blocking(lua_State *L) {
	unsigned char ch;
	struct termios oldt, newt;
	tcgetattr ( STDIN_FILENO, &oldt );
	newt = oldt;
	newt.c_lflag &= ~( ICANON | ECHO );
	tcsetattr ( STDIN_FILENO, TCSANOW, &newt );
	ch = getchar();
	tcsetattr ( STDIN_FILENO, TCSANOW, &oldt );

	lua_pushnumber(L, (int)ch);
	return 1;
}

static int l_getch_non_blocking(lua_State *L) {
	unsigned char ch;
	int r;
	struct termios oldt, newt;
	int flags = fcntl(0, F_GETFL, 0);
	
	fcntl(0, F_SETFL, flags | O_NONBLOCK );
	
	tcgetattr ( STDIN_FILENO, &oldt );
	newt = oldt;
	newt.c_lflag &= ~( ICANON | ECHO );
	tcsetattr ( STDIN_FILENO, TCSANOW, &newt );

	if ( (r = read(0, &ch, sizeof(ch))) < 0) {
		// can't read!
		lua_pushnil(L);
	} else {
		lua_pushnumber(L, (int)ch);
	}

	tcsetattr ( STDIN_FILENO, TCSANOW, &oldt );
	fcntl(0, F_SETFL, flags);

	lua_pushnumber(L, (int)ch);
	return 1;
}

int luaopen_getch(lua_State *L) {
	luaL_Reg functions[] = {
		{"blocking", l_getch_blocking},
		{"non_blocking", l_getch_non_blocking},
		{NULL, NULL}
	};

	luaL_openlib(L, "getch", functions, 0);
	return 0;
}
