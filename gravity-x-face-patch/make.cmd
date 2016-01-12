@echo off
echo Making patch...
call make_patch.cmd
echo Making patcher...
call make_patcher.cmd

del d:\apps\gravity212\gravity.exe
del d:\apps\gravity212\gravity.exe.bak
copy "d:\apps\gravity212\copy of gravity.exe" d:\apps\gravity212\gravity.exe
copy gravity-x-face-patch-1_2.exe d:\apps\gravity212\