@echo off
rc /r winface.rc
nasmw -f win32 -w+orphan-labels -O2 winface.asm
link /subsystem:windows /out:WinFace.exe /entry:main /align:4096 winface.obj winface.lib winface.res
