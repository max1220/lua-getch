#!/bin/bash
gcc -shared -fpic -o getkey.so getkey.c -I"/usr/include/lua5.1"
strip getkey.so
