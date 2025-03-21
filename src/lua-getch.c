#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <string.h>
#include <sys/select.h>
#include <termios.h>
#include <unistd.h>


#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>

#define LUA_T_PUSH_S_CF(S, CF) lua_pushstring(L, S); lua_pushcfunction(L, CF); lua_settable(L, -3);
#define LUA_T_PUSH_S_I(S, I) lua_pushstring(L, S); lua_pushinteger(L, I); lua_settable(L, -3);
#define LUA_T_PUSH_FLAG(F) lua_pushstring(L, #F); lua_pushinteger(L, F); lua_settable(L, -3);
#define US_IN_S 1000000





// get a FILE from Lua, or push a Lua error message
static FILE* get_file_from_lua_or_err(lua_State *L, int index) {
	FILE* file;
	if (lua_isnumber(L, index)) {
		int fd = lua_tonumber(L, index);
		file = fdopen(fd, "r+");
	} else {
		file = *(FILE**) luaL_checkudata(L, index, LUA_FILEHANDLE);
	}
	if (file==NULL) {
		luaL_error(L, "Expected a file as argument %d!", index);
	}
	return file;
}

// get the fd number for the FILE, or push a Lua error
static int file_to_fd_or_err(lua_State *L, FILE *file) {
	int fd = fileno(file);
	if (fd<0) {
		luaL_error(L, "Can't get fd from file!");
	}
	return fd;
}

// get the termios attributes for the file descriptor
static int l_get_termios_attributes(lua_State *L) {
	struct termios current;

	// get a fd from Lua
	FILE* file = get_file_from_lua_or_err(L, 1);
	int fd = file_to_fd_or_err(L, file);

	// try to get current terminal attributes
	if (tcgetattr(fd, &current)==-1) {
		lua_pushnil(L);
		lua_pushfstring(L, "Can't get attributes: %s", strerror(errno));
		return 2;
	}

	// push the termios attributes as Lua numbers

	// input modes
	lua_pushinteger(L, current.c_iflag);

	// output modes
	lua_pushinteger(L, current.c_oflag);

	// control modes
	lua_pushinteger(L, current.c_cflag);

	// local modes
	lua_pushinteger(L, current.c_lflag);

	return 4;
}

// set the termios attributes for the file descriptor
static int l_set_termios_attributes(lua_State *L) {
	struct termios current, new;

	FILE* file = get_file_from_lua_or_err(L, 1);
	int fd = file_to_fd_or_err(L, file);

	// try to get current terminal attributes
	if (tcgetattr(fd, &current)==-1) {
		lua_pushnil(L);
		lua_pushfstring(L, "Can't get attributes: %s", strerror(errno));
		return 2;
	}

	// start at old attributes
	new = current;

	// add attributes if Lua argument is present
	if (lua_isnumber(L, 2)) {
		new.c_iflag = lua_tointeger(L, 2);
	}
	if (lua_isnumber(L, 3)) {
		new.c_oflag = lua_tointeger(L, 3);
	}
	if (lua_isnumber(L, 4)) {
		new.c_cflag = lua_tointeger(L, 4);
	}
	if (lua_isnumber(L, 5)) {
		new.c_lflag = lua_tointeger(L, 5);
	}

	// optional termios actions to perform(default to 0)
	int optional_actions = TCSANOW;
	if (lua_isnumber(L, 6)) {
		optional_actions = lua_tointeger(L, 6);
	}

	// try to set the new attributes
	if (tcsetattr(fd, optional_actions, &new)==-1) {
		lua_pushnil(L);
		lua_pushfstring(L, "Can't set attributes: %s", strerror(errno));
		return 2;
	}

	// indicate success by returning true to Lua
	lua_pushboolean(L, 1);
	return 1;
}

// enable/disable non-blocking mode for the specified file descriptor
static int l_set_nonblocking(lua_State *L) {
	FILE* file = get_file_from_lua_or_err(L, 1);
	int fd = file_to_fd_or_err(L, file);

	// get new file descriptor flags for stdin
	int flags = fcntl(fd, F_GETFL, 0);
	if (lua_toboolean(L, 2)) {
		flags |= O_NONBLOCK;
	} else {
		flags &= ~O_NONBLOCK;
	}

	// check return value for fcntl
	if (fcntl(fd, F_SETFL, flags)==-1) {
		lua_pushnil(L);
		lua_pushfstring(L, "fcntl() error: %s", strerror(errno));
	}

	// indicate success by returning true to Lua
	lua_pushboolean(L, 1);
	return 1;
}

static int l_select(lua_State *L) {
	// create two fd sets for select
	fd_set read_fds, write_fds;
	FD_ZERO(&read_fds);
	FD_ZERO(&write_fds);

	// check argument count
	int arg_count = lua_gettop(L);
	if (arg_count < 3) {
		lua_pushnil(L);
		lua_pushfstring(L, "Requires argument count >=3");
		return 2;
	}

	// first argument is always timeout, but can be nil
	int has_tval = 0;
	struct timeval tval;
	if (lua_isnumber(L, 1)) {
		double timeout = lua_tonumber(L, 1);
		long secs = timeout;
		if (timeout > 0) {
			has_tval = 1;
			tval.tv_sec = secs;
			tval.tv_usec = (timeout-(double)secs)*US_IN_S;
		}
	}
	
	
	// populate read_fds & write_fds from remaining arguments
	int max_fd = 0;
	for (int i=2; i<=arg_count; i=i+2) {
		// get arguments from Lua
		int is_write = lua_toboolean(L, i);
		FILE* file = get_file_from_lua_or_err(L, i+1);
		int fd = file_to_fd_or_err(L, file);

		// replace with argument with numeric file descriptor
		lua_pushinteger(L, fd);
		lua_replace(L, i+1);

		// update max_fd
		if (fd>max_fd) { max_fd = fd; }

		// update read_fds/write_fds
		if (is_write) {
			FD_SET(fd, &write_fds);
		} else {
			FD_SET(fd, &read_fds);
		}
	}

	// perform configured select() operation
	int select_ret;
	if (has_tval) {
		select_ret = select(max_fd+1, &read_fds, &write_fds, NULL, &tval);
	} else {
		select_ret = select(max_fd+1, &read_fds, &write_fds, NULL, NULL);
	}

	// first return argument is the select return code
	lua_pushinteger(L, select_ret);
	int return_args = 1;

	// write updated values from read_fds/write_fds to Lua return arguments
	for (int i=2; i<=arg_count; i=i+2) {
		int is_write = lua_toboolean(L, i);
		int fd = lua_tointeger(L, i+1);
		if (is_write) {
			lua_pushboolean(L, FD_ISSET(fd, &write_fds));
		} else {
			lua_pushboolean(L, FD_ISSET(fd, &read_fds));
		}
		return_args++;
	}

	// returns same number of arguments it received
	return return_args;
}





// called on require("getch"), return the table with the lua-getch functions
int luaopen_getch(lua_State *L) {
	lua_newtable(L);
	LUA_T_PUSH_S_CF("get_termios_attributes", l_get_termios_attributes)
	LUA_T_PUSH_S_CF("set_termios_attributes", l_set_termios_attributes)
	LUA_T_PUSH_S_CF("set_nonblocking", l_set_nonblocking)
	LUA_T_PUSH_S_CF("select", l_select)

	// add iflags table
	lua_pushstring(L, "iflags");
	lua_newtable(L);
	LUA_T_PUSH_FLAG(IGNBRK)
	LUA_T_PUSH_FLAG(BRKINT)
	LUA_T_PUSH_FLAG(IGNPAR)
	LUA_T_PUSH_FLAG(PARMRK)
	LUA_T_PUSH_FLAG(INPCK)
	LUA_T_PUSH_FLAG(ISTRIP)
	LUA_T_PUSH_FLAG(INLCR)
	LUA_T_PUSH_FLAG(IGNCR)
	LUA_T_PUSH_FLAG(ICRNL)
	LUA_T_PUSH_FLAG(IUCLC)
	LUA_T_PUSH_FLAG(IXON)
	LUA_T_PUSH_FLAG(IXANY)
	LUA_T_PUSH_FLAG(IXOFF)
	LUA_T_PUSH_FLAG(IMAXBEL)
	LUA_T_PUSH_FLAG(IUTF8)
	lua_settable(L, -3);


	// add oflags table
	lua_pushstring(L, "oflags");
	lua_newtable(L);
	LUA_T_PUSH_FLAG(OPOST)
	LUA_T_PUSH_FLAG(OLCUC)
	LUA_T_PUSH_FLAG(ONLCR)
	LUA_T_PUSH_FLAG(OCRNL)
	LUA_T_PUSH_FLAG(ONOCR)
	LUA_T_PUSH_FLAG(ONLRET)
	LUA_T_PUSH_FLAG(OFILL)
	LUA_T_PUSH_FLAG(OFDEL)
	LUA_T_PUSH_FLAG(NLDLY)
	LUA_T_PUSH_FLAG(CRDLY)
	LUA_T_PUSH_FLAG(TABDLY)
	LUA_T_PUSH_FLAG(BSDLY)
	LUA_T_PUSH_FLAG(VTDLY)
	LUA_T_PUSH_FLAG(FFDLY)
	lua_settable(L, -3);

	// add cflags table
	lua_pushstring(L, "cflags");
	lua_newtable(L);
	LUA_T_PUSH_FLAG(CBAUD)
	LUA_T_PUSH_FLAG(CBAUDEX)
	LUA_T_PUSH_FLAG(CSIZE)
	LUA_T_PUSH_FLAG(CSTOPB)
	LUA_T_PUSH_FLAG(CREAD)
	LUA_T_PUSH_FLAG(PARENB)
	LUA_T_PUSH_FLAG(PARODD)
	LUA_T_PUSH_FLAG(HUPCL)
	LUA_T_PUSH_FLAG(CLOCAL)
	LUA_T_PUSH_FLAG(CIBAUD)
	LUA_T_PUSH_FLAG(CMSPAR)
	LUA_T_PUSH_FLAG(CRTSCTS)
	lua_settable(L, -3);

	// add lflags table
	lua_pushstring(L, "lflags");
	lua_newtable(L);
	LUA_T_PUSH_FLAG(ISIG)
	LUA_T_PUSH_FLAG(ICANON)
	LUA_T_PUSH_FLAG(XCASE)
	LUA_T_PUSH_FLAG(ECHO)
	LUA_T_PUSH_FLAG(ECHOE)
	LUA_T_PUSH_FLAG(ECHOK)
	LUA_T_PUSH_FLAG(ECHONL)
	LUA_T_PUSH_FLAG(ECHOCTL)
	LUA_T_PUSH_FLAG(ECHOPRT)
	LUA_T_PUSH_FLAG(ECHOKE)
	LUA_T_PUSH_FLAG(FLUSHO)
	LUA_T_PUSH_FLAG(NOFLSH)
	LUA_T_PUSH_FLAG(TOSTOP)
	LUA_T_PUSH_FLAG(PENDIN)
	LUA_T_PUSH_FLAG(IEXTEN)
	lua_settable(L, -3);

	// add lflags table
	lua_pushstring(L, "optional_actions");
	lua_newtable(L);
	LUA_T_PUSH_FLAG(TCSANOW)
	LUA_T_PUSH_FLAG(TCSADRAIN)
	LUA_T_PUSH_FLAG(TCSAFLUSH)
	lua_settable(L, -3);


	return 1;
}
