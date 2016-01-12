@echo off
rc /r winface-dll.rc
nasmw -f win32 -w+orphan-labels -O2 winface-dll.asm
nasmw -f win32 -w+orphan-labels -O2 x-face.asm
link /dll /export:patch /export:compface /export:uncompface /export:gui_main /subsystem:windows /base:0x2a40000 /fixed:no /out:WinFace.dll /entry:dll_main /merge:.data=.code /merge:.text=.code /align:4096 /section:.code,erw winface-dll.obj x-face.obj winface-dll.res arith.obj gen.obj compface.obj uncompface.obj file.obj compress.obj kernel32.lib user32.lib gdi32.lib comctl32.lib ddraw.lib shell32.lib comdlg32.lib
upx --best WinFace.dll

