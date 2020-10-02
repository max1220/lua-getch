#!/bin/bash

# Allow for overriding of lua location from the make command-line.
LUA_INC=/usr/include/lua5.1
LUA_LIB=lua5.1

# Adjust to your needs. lua5.1 is ABI-Compatible with luajit.
CFLAGS= -O3 -Wall -Wextra -I${LUA_INC}
LIBS= -l${LUA_LIB}
STRIP_FLAGS=

# Target directories for 'make install':
INSTALL_PATH= /usr/local/share/lua/5.1/getch/ # lua -e "print((package.path:gsub(';', '\n')))"
INSTALL_CPATH= /usr/local/lib/lua/5.1/ # lua -e "print((package.cpath:gsub(';', '\n')))"



# Platform specific flags
UNAME_S := $(shell uname -s)
ifeq ($(UNAME_S),Linux)
	CFLAGS += -fPIC -shared
endif
ifeq ($(UNAME_S),Darwin)
	CFLAGS += -bundle -undefined dynamic_lookup -all_load
	STRIP_FLAGS += -x
endif

getch.so: getch.c
	$(CC) -o $@ $(CFLAGS) $(LIBS) $<
	strip ${STRIP_FLAGS} $@

.PHONY: install
install:
	mkdir -p $(INSTALL_PATH)
	mkdir -p $(INSTALL_CPATH)
	# copy C library part to lua cpath
	cp -v getch.so $(INSTALL_CPATH)
	# copy Lua library part to lua path
	cp -v lua/* $(INSTALL_PATH)

.PHONY: clean
clean:
	rm getch.so
