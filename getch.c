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
#define US_IN_S 1000000


static struct termios oldt, newt;
static char buffer[BUFSIZ];


// enable non-canonical mode for stdin, and disable automaitc input character echo(save original termios)
static inline void termios_enable_non_canonical() {
	tcgetattr(STDIN_FILENO, &oldt); // save old terminal attributes
	newt = oldt; // new terminal attributes are based on old ones
	newt.c_lflag &= ~(ICANON | ECHO); // remove ICANON and ECHO from flags
	tcsetattr(STDIN_FILENO, TCSANOW, &newt); // set new terminal attributes
}

// restore previous terminal attributes(enter canonical mode if previously enabled)
static inline void termios_restore() {
	tcsetattr(STDIN_FILENO, TCSANOW, &oldt); // restore old(original) terminal attributes
}


// disable buffering on stdin
static inline void disable_buffering() {
	// This ensures that the presence of extra characters is properly detected by select etc.
	setbuf(stdin, NULL);
}

// enable buffering on stdin
static inline void enable_buffering() {
	setbuf(stdin, buffer);
}


// get character as soon as possible(no buffering, no line termination)
static int l_getch_blocking(lua_State *L) {
	termios_enable_non_canonical(); // enter terminal into non-canonical mode, disable character echo
	disable_buffering(); // disable libc buffering

	int ch = getc(stdin);

	enable_buffering(); // re-enable libc buffering
	termios_restore(); // restore terminal

	// return nil if EOF, character number otherwise
	if (ch==EOF) {
		lua_pushnil(L);
	} else {
		lua_pushinteger(L, ch);
	}
	return 1;
}


// wait up to timeout seconds to get a character, then always return(even if no character was read)
// if timeout is 0(or not specified) behaves "non-blocking".
static int l_getch_non_blocking(lua_State *L) {
	unsigned char ch;
	struct timeval timeout;

	double dur = 0;

	// Optional first argument is timeout in seconds
	if (lua_isnumber(L,1)) {
		dur = lua_tonumber(L, 1);
		int secs = (int)dur; // get integer seconds
		int usecs = (dur-(double)secs)*US_IN_S;  // get integer micro-seconds
		timeout.tv_sec = secs; // populate timeval struct
		timeout.tv_usec = usecs;
	}

	int flags = fcntl(STDIN_FILENO, F_GETFL, 0); // get file descriptor flags for stdin
	fcntl(0, F_SETFL, flags | O_NONBLOCK ); // set O_NONBLOCK in file descriptor flags
	termios_enable_non_canonical(); // enter terminal into non-canonical mode, disable character echo

	if (dur>0) { // a timeout is specified, use select to honor the timeout
		fd_set read_ready_fds; // prepare fd set for select
		FD_ZERO(&read_ready_fds);
		FD_SET(STDIN_FILENO, &read_ready_fds);
	    select(STDIN_FILENO+1, &read_ready_fds, NULL, NULL, &timeout); // Wait for a change in the fds's(When a new character was written to stdin, or timeout, or error)
	}

	// just try to read a character.
	int r = read( STDIN_FILENO, &ch, sizeof(ch));

	if (r < 0) { // read failed(not ready, timeout, or error)
		lua_pushnil(L);
		lua_pushinteger(L, r); // return error as second return value
	} else {
		lua_pushinteger(L, ch); // return read character as integer to lua
		lua_pushinteger(L, r); // return bytes read as second return value
	}

	termios_restore(); // restore terminal
	fcntl(0, F_SETFL, flags);

	return 2;
}





int luaopen_getch(lua_State *L) {
	lua_newtable(L);
	LUA_T_PUSH_S_CF("blocking", l_getch_blocking)
	LUA_T_PUSH_S_CF("non_blocking", l_getch_non_blocking)
	return 1;
}
