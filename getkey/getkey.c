#include <stdio.h>
#include <termios.h>
#include <unistd.h>
#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>

int mygetch ( void ) {
	// Gets a char without line buffering by setting a diffrent Term mode, reading a key & setting it back.
	int ch;
	struct termios oldt, newt;
	tcgetattr ( STDIN_FILENO, &oldt );
	newt = oldt;
	newt.c_lflag &= ~( ICANON | ECHO );
	tcsetattr ( STDIN_FILENO, TCSANOW, &newt );
	ch = getchar();
	tcsetattr ( STDIN_FILENO, TCSANOW, &oldt );
	return ch;
}

int getkey_wrapper(lua_State *L) {
	lua_pushnumber(L, mygetch());
	return 1;
}

int luaopen_getkey(lua_State *L) {
	luaL_Reg functions[] = {
		{"getkey", getkey_wrapper},
		{NULL, NULL}};


	luaL_openlib(L, "getkey", functions, 0);
	return 0;
}
