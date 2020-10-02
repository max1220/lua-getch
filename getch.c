#include <assert.h>
#include <stdio.h>
#include <termios.h>
#include <unistd.h>
#include <fcntl.h>
#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>
#include <sys/select.h>





#define LUA_T_PUSH_S_N(S, N) lua_pushstring(L, S); lua_pushnumber(L, N); lua_settable(L, -3);
#define LUA_T_PUSH_S_S(S, S2) lua_pushstring(L, S); lua_pushstring(L, S2); lua_settable(L, -3);
#define LUA_T_PUSH_S_CF(S, CF) lua_pushstring(L, S); lua_pushcfunction(L, CF); lua_settable(L, -3);



static int l_getch_blocking(lua_State *L) {
	int ch;
	struct termios oldt, newt;
	tcgetattr ( STDIN_FILENO, &oldt );
	newt = oldt;
	newt.c_lflag &= ~( ICANON | ECHO );
	tcsetattr ( STDIN_FILENO, TCSANOW, &newt );

    // Disable buffering on stdin. This ensures that the presence of extra
    // characters is properly detected by select.
    setbuf(stdin, NULL);

	ch = getchar();

    // Restore the stdin buffer
    static char buffer[BUFSIZ];
    setbuf(stdin, buffer);

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

	return 1;
}


int luaopen_getch(lua_State *L) {
	lua_newtable(L);
	LUA_T_PUSH_S_CF("blocking", l_getch_blocking)
	LUA_T_PUSH_S_CF("non_blocking", l_getch_non_blocking)
	return 1;
}
