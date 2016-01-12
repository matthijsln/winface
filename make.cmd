@echo off
call make_dll.cmd
call make_exe.cmd
copy WinFace.dll d:\apps\gravity
copy WinFace.dll d:\apps\gravity23