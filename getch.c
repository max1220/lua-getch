#include <assert.h>
#include <stdio.h>
#include <termios.h>
#include <unistd.h>
#include <fcntl.h>
#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>

// Defines a few character constants. The first three are standard ascii values
// provided here for ease of use. The last four are custom values that are 
// returned by this value of getch() but don't correspond to any ascii value
// themselves.
#define KEY_TUPLE \
    KEY_ENTRY(KEY_ENTER, 10) \
    KEY_ENTRY(KEY_ESCAPE, 27) \
    KEY_ENTRY(KEY_SPACE, 32) \
    KEY_ENTRY(KEY_UP, 256) \
    KEY_ENTRY(KEY_DOWN, 257) \
    KEY_ENTRY(KEY_LEFT, 258) \
    KEY_ENTRY(KEY_RIGHT, 259) \

#define KEY_ENTRY(k, v) \
    const int k = v;
    KEY_TUPLE
#undef KEY_ENTRY
    
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

    if (ch == KEY_ESCAPE) {
        // Determine if there is more input waiting on the STDIN file
        // descriptor. If not this escape represents the escape key directly.
        // If there is, this actually an escape code and we need to read more
        // characters to determine specifically what it represents.
        fd_set readfds;
        FD_ZERO(&readfds);
        FD_SET(STDIN_FILENO, &readfds);

        // Don't wait on the select()
        struct timeval timeout;
        timeout.tv_sec = 0;
        timeout.tv_usec = 0;

        int sel = select(STDIN_FILENO + 1, &readfds, NULL, NULL, &timeout);
        if (sel > 0) {
            // Additional data is present on stdin
            ch = getchar();
            assert(ch == 91);
            ch = getchar();
            switch (ch) {
                case 'A':
                    ch = KEY_UP;
                    break;
                case 'B':
                    ch = KEY_DOWN;
                    break;
                case 'C':
                    ch = KEY_RIGHT;
                    break;
                case 'D':
                    ch = KEY_LEFT;
                    break;
                default:
                    assert(0 && "Unhandled escape sequence");
                    break;
            }
        }
    }

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

    // Add our constants.
#define KEY_ENTRY(k, v) \
    lua_pushstring(L, #k); \
    lua_pushnumber(L, v); \
    lua_settable(L, -3);
    KEY_TUPLE
#undef KEY_ENTRY

	return 0;
}
