@echo off
nasmw -f win32 -i../asminclude/ -O99 -w+orphan-labels patcher.asm
link /subsystem:console /out:gravity-x-face-patch-1_2.exe /entry:main /merge:.data=.code /merge:.rdata=.code /merge:.text=.code /align:4096 /section:.code,erw patcher.obj user32.lib ddraw.lib msvcrt.lib kernel32.lib 
editbin /section:.code,ceiruw gravity-x-face-patch-1_2.exe
