#!/bin/bash

# Allow for overriding of lua location from the make command-line.
LUA_INC=/usr/include/lua5.1
LUA_LIB=lua5.1

# Adjust to your needs. lua5.1 is ABI-Compatible with luajit.
CFLAGS=-O3 -Wall -Wextra -I${LUA_INC}
LIBS=-l${LUA_LIB}
STRIP_FLAGS=

# Target directories for 'make install':

# name for the lua module(used in require() to load Lua module that loads the C module)
INSTALL_LUALIBNAME=lua-getch

# filename for the compiled getch.so in the cpath. Changing this also requires changing the require("getch") accordingly.
INSTALL_CLIBNAME=getch

# Installation path for the Lua modules. Will be installed to a subdirectory $INSTALL_LIBNAME in this directory.
# To list the default package.path for your Lua installation, you could use: lua -e "print((package.path:gsub(';', '\n')))"
INSTALL_PATH=/usr/local/share/lua/5.1

# Installation path for the C module. A single .so file named getch.so will be installed here
# To list the default package.cpath for your Lua installation, you could use: lua -e "print((package.cpath:gsub(';', '\n')))"
INSTALL_CPATH=/usr/local/lib/lua/5.1



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

.PHONY: all
all: getch.so

.PHONY: install
install: getch.so
	mkdir -vp $(INSTALL_PATH)/$(INSTALL_LUALIBNAME)
	mkdir -vp $(INSTALL_CPATH)/
	# copy C library part to lua cpath
	cp -v getch.so $(INSTALL_CPATH)/$(INSTALL_CLIBNAME).so
	# copy Lua library part to lua path
	cp -v lua/* $(INSTALL_PATH)/$(INSTALL_LUALIBNAME)/

.PHONY: install_symlinks
install_symlinks: getch.so
	mkdir -vp $(INSTALL_PATH)/
	mkdir -vp $(INSTALL_CPATH)/
	# install symlink for C library part to lua cpath
	ln -vs $(CURDIR)/getch.so $(INSTALL_CPATH)/$(INSTALL_CLIBNAME).so
	# install symlink for Lua library part to lua path
	ln -vs $(CURDIR)/lua $(INSTALL_PATH)/$(INSTALL_LUALIBNAME)

.PHONY: clean
clean:
	rm -f getch.so
