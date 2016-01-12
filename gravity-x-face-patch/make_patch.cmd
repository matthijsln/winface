@echo off
nasmw -f bin -i../asminclude/ -w+orphan-labels -dGRAV_1020 -O999 -o patch-1020.bin patch.asm
nasmw -f bin -i../asminclude/ -w+orphan-labels -dGRAV_1800 -O999 -o patch-1800.bin patch.asm
nasmw -f bin -i../asminclude/ -w+orphan-labels -dGRAV_2000 -O999 -o patch-2000.bin patch.asm
nasmw -f bin -i../asminclude/ -w+orphan-labels -dGRAV_2039 -O999 -o patch-2039.bin patch.asm