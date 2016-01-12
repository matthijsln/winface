%include "win32.inc"
%include "macros.inc"

%include "kernel32.inc"

section .data

; --- screen messages ---

string greeting, "Microplanet Gravity X-Face patch v1.2", CRLF, "Gravity versions supported: 2.12, 2.3, 2.5, 2.6 build 2039", CRLF, CRLF, "This program will: ", CRLF, " - Check if the Gravity.exe file matches a known version", CRLF, " - Make a backup of Gravity.exe to Gravity.exe.bak", CRLF, " - Patch Gravity.exe to add the X-Face display feature", CRLF, CRLF, "The patched Gravity.exe will require WinFace.dll.", CRLF, CRLF
string question, "Do you want to proceed with this? (type y if you do) "
string notice1, CRLF, CRLF, "Verifying Gravity.exe...", CRLF
string notice2, "  File opened", CRLF
notice3	db "  File size OK, Gravity version 2."
 notice3versionminor	db "xx build "
 notice3build		db "xxxx", CRLF
notice3_end:
%define notice3_size notice3_end-notice3
string notice4, "  Integrity check passed", CRLF, "Copying Gravity.exe to Gravity.exe.bak...", CRLF
string notice5, "  Backup created", CRLF, "Patching Gravity.exe...", CRLF
string notice6, "  Patch successfully applied", CRLF
string error, "Error: "
string wrong_filesize, "File size does not match any known version"
string integrity_fail, "File integrity failure; patch already applied?"
string error_gravity_damaged, "File writing error, Gravity.exe may be damaged - restore backup", CRLF
string done, CRLF, "Press any key to exit..."

; --- filenames ---

string filename, "Gravity.exe", 0
string backup_filename, "Gravity.exe.bak", 0

; --- some buffers ---

dummy		dd 0

string charbuf, " "
err_msg_ptr	dd 0

buf		db 0

; --- patch data ---

; Gravity.exe file sizes
%define GRAV_2039_FS	2584576
%define GRAV_2000_FS	2506752
%define GRAV_2000_IT_FS 2985984
%define GRAV_1800_FS	2523136
%define GRAV_1020_FS	2318336

; part 1 of the patch; the code which will jump to part 2. Gravity reaches this
; code when it has header lines to process. At [ecx+17] there will be a pointer
; to the headers.

; build 1020

; original code
; 00406F7D  8A45 0B        mov     al, byte ptr [ebp+B]
; 00406F80  84C0           test    al, al
; 00406F82  0F85 3C030000  jnz     Gravity.004072C4

; patched code
; 00406F7D  E9 6693FFFF    jmp     Gravity.004002E8
; 00406F82  0F85 3C030000  jnz     Gravity.004072C4

; build 1800

; original code
; 0040790C  8A45 0B        mov     al, byte ptr [ebp+B]
; 0040790F  84C0           test    al, al
; 00407911  0F85 E0020000  jnz     Gravity.00407BF7

; patched code
; 0040790C  E9 D789FFFF    jmp     Gravity.004002E8
; 00407911  0F85 E0020000  jnz     Gravity.00407BF7

; build 2000

; original code
; 0040763C  8A45 0B        mov     al, byte ptr [ebp+B]
; 0040763F  84C0           test    al, al
; 00407641  0F85 E0020000  jnz     Gravity.00407927

; patched code
; 0040763C  E9 A78CFFFF    jmp     Gravity.004002E8
; 00407641  0F85 E0020000  jnz     Gravity.00407927

; build 2039

; 0040930C  8A43 0B        mov     al, byte ptr [ebx+B]
; 0040930F  84C0           test    al, al
; 00409311  74 0C          je      short Gravity.0040931F

; patched code:

; 0040930C  E9 D76FFFFF    jmp     Gravity.004002E8
; 00409311  74 0C          je      short Gravity.0040931F


jmppatch db 0e9h
 jmppatch_word db 0, 0, 0ffh, 0ffh

; part 2 of the patch; the code which part 1 will jump to. this will be placed
; at offset 02e8h in the file, which corresponds to 04002e8h at runtime. this
; is originally filled with 3,352 bytes of zeroes for aligning sections.

%define PATCH_OFFSET 02e8h

patch_2039:
incbin "patch-2039.bin"
patch_2039_end:
%define PATCH_SIZE patch_2039_end - patch_2039	; patch size is for all builds equal

patch_2000:
incbin "patch-2000.bin"

patch_1800:
incbin "patch-1800.bin"

patch_1020:
incbin "patch-1020.bin"

struc vd
	.jmppatch_offset	resd 1
	.jmppatch_word		resw 1
	.patch			resd 1
endstruc

grav_1020_data istruc vd
		at vd.jmppatch_offset,	dd 06f7dh
		at vd.jmppatch_word,	db 066h, 093h
		at vd.patch,		dd patch_1020
iend

grav_1800_data istruc vd
		at vd.jmppatch_offset,	dd 0790ch
		at vd.jmppatch_word,	db 0d7h, 089h
		at vd.patch,		dd patch_1800
iend

grav_2000_data istruc vd
		at vd.jmppatch_offset,	dd 0763ch
		at vd.jmppatch_word,	db 0a7h, 08ch
		at vd.patch,		dd patch_2000
iend

grav_2039_data istruc vd
		at vd.jmppatch_offset,	dd 0930ch
		at vd.jmppatch_word,	db 0d7h, 06fh
		at vd.patch,		dd patch_2039
iend

; --- patch applier code ---

section .code

; print string %1 defined with "string" macro (or if %1_size is defined manually)
; edi: stdout handle
%macro print 1
		invoke	WriteConsoleA, edi, %1, dword %1_size, dword dummy, 0
%endmacro

; print string %1 with length %2
; edi: stdout handle
%macro print 2
		invoke	WriteConsoleA, edi, %1, %2, dword dummy, 0
%endmacro

; read a single char from stdin into charbuf
; esi: stdin handle
%define readchar invoke	ReadConsoleA, esi, dword charbuf, 1, dword dummy, 0

global          _main
_main:
		invoke	GetStdHandle, STD_OUTPUT_HANDLE
		mov	edi, eax
		invoke	GetStdHandle, STD_INPUT_HANDLE
		mov	esi, eax

		invoke	SetConsoleMode, esi, 0
		print	dword greeting
		invoke	SetConsoleTextAttribute, edi, FOREGROUND_RED | FOREGROUND_GREEN | FOREGROUND_BLUE | FOREGROUND_INTENSITY
		print	dword question
		invoke	SetConsoleTextAttribute, edi, FOREGROUND_RED | FOREGROUND_GREEN | FOREGROUND_BLUE

		readchar
		mov	bl, [charbuf]

		print	dword charbuf

		cmp	bl, "y"
		je	.continue
		cmp	bl, "Y"
		je	.continue
		jmp	.abort
.continue:
		print	dword notice1

		; open the file
		invoke	CreateFileA, dword filename, dword GENERIC_READ | GENERIC_WRITE, FILE_SHARE_READ, 0, OPEN_EXISTING, 0, 0
		cmp	eax, INVALID_HANDLE_VALUE
		je	.show_last_error
		mov	ebx, eax

		print	dword notice2

		; determine file size
		invoke	GetFileSize, ebx, 0
		cmp	eax, -1
		je	.show_last_error

		cmp	eax, GRAV_2039_FS
		je	.ok2039
		cmp	eax, GRAV_2000_FS
		je	.ok2000
		cmp	eax, GRAV_2000_IT_FS
		je	.ok2000
		cmp	eax, GRAV_1800_FS
		je	.ok1800
		cmp	eax, GRAV_1020_FS
		je	.ok1020

		invoke	SetConsoleTextAttribute, edi, FOREGROUND_RED | FOREGROUND_INTENSITY
		print	dword error
		print	dword wrong_filesize
		jmp	.quit

.ok2039:
		mov	ebp, grav_2039_data
		mov	word [notice3versionminor], '60'
		mov	dword [notice3build], '2039'
		jmp	.ok

.ok2000:
		mov	ebp, grav_2000_data
		mov	word [notice3versionminor], '50'
		mov	dword [notice3build], '2000'
		jmp	.ok
.ok1800:
		mov	ebp, grav_1800_data
		mov	word [notice3versionminor], '30'
		mov	dword [notice3build], '1800'
		jmp	.ok

.ok1020:
		mov	ebp, grav_1020_data
		mov	word [notice3versionminor], '12'
		mov	dword [notice3build], '1020'

.ok:
		print	dword notice3

		; minimalist integrity check: check for 8A
		; machine code at the jump patch offset

		invoke	SetFilePointer, ebx, dword [ebp+vd.jmppatch_offset], 0, FILE_BEGIN
		invoke	ReadFile, ebx, dword buf, 1, dword dummy, 0
		cmp	byte [buf], 08ah
		jne	.integrity_fail

		print	dword notice4

		; backup

                invoke	CopyFileA, dword filename, dword backup_filename, 1
		test	eax, eax
		jz	.backup_fail

		print	dword notice5

		; patch part 1

		mov	ax, [ebp+vd.jmppatch_word]
		mov	[jmppatch_word], ax

		invoke	SetFilePointer, ebx, -1, 0, FILE_CURRENT
		invoke	WriteFile, ebx, dword jmppatch, 5, dword dummy, 0
		test	eax, eax
		jz	.write_fail

		; patch part 2

		invoke	SetFilePointer, ebx, dword PATCH_OFFSET, 0, FILE_BEGIN
		invoke	WriteFile, ebx, dword [ebp+vd.patch], dword PATCH_SIZE, dword dummy, 0
		test	eax, eax
		jz	.write_fail

		invoke	SetConsoleTextAttribute, edi, FOREGROUND_GREEN | FOREGROUND_INTENSITY
		print	dword notice6

		invoke	CloseHandle, ebx

		jmp	.no_error

.integrity_fail:
		invoke	SetConsoleTextAttribute, edi, FOREGROUND_RED | FOREGROUND_INTENSITY
		print	dword error
		print	dword integrity_fail
		invoke	CloseHandle, ebx
		jmp	.quit

.write_fail:
		invoke	SetConsoleTextAttribute, edi, FOREGROUND_RED | FOREGROUND_INTENSITY
		print	dword error_gravity_damaged
		
		;??? bad lasterror due to print ???

.backup_fail:
		invoke	GetLastError
		push	eax
		invoke	CloseHandle, ebx
		pop	eax
		invoke	SetLastError, eax

.show_last_error:
		invoke	SetConsoleTextAttribute, edi, FOREGROUND_RED | FOREGROUND_INTENSITY

		invoke	GetLastError
		invoke	FormatMessageA, dword FORMAT_MESSAGE_FROM_SYSTEM | FORMAT_MESSAGE_IGNORE_INSERTS | FORMAT_MESSAGE_ALLOCATE_BUFFER, 0, eax, 0, dword err_msg_ptr, 0, 0
		mov	ebx, eax
		print	dword error
		mov	eax, [err_msg_ptr]
		print	eax, ebx

.quit:
.no_error:
		invoke	SetConsoleTextAttribute, edi, FOREGROUND_RED | FOREGROUND_GREEN | FOREGROUND_BLUE
		print	dword done
		readchar

.abort:
		xor	eax, eax
		ret