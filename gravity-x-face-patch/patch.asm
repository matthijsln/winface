; Microplanet Gravity X-Face patch

; Gravity version		Macro
; Gravity 2.60 build 2039	GRAV_2039
; Gravity 2.50 build 2000	GRAV_2000
; Gravity 2.30 build 1800	GRAV_1800
; Gravity 2.12 build 1020	GRAV_1020

%ifndef GRAV_1020
%ifndef GRAV_1800
%ifndef GRAV_2000
%ifndef GRAV_2039
%error No Gravity version defined; use -D switch
%endif
%endif
%endif
%endif

bits 32
org 04002e8h					; start code in filler zeroes in Gravity.exe

%include "macros.inc"
%include "win32.inc"

; imported WinAPI functions:

; KERNEL32.LoadLibraryA,
; KERNEL32.GetProcAddress,
; KERNEL32.GetLastError,
; KERNEL32.FormatMessageA,
; USER32.MessageBoxA

%include "gravity_imports.inc"

; -----------------------------------------------------------------------------
; variables

; these point far into the .data section - hopefully alignment filler zeroes,
; it's probably safe to use for read/write vars

%ifndef GRAV_2039
absolute 00605ef0h
%elifdef GRAV_1020
absolute 005e0f70h
%else
absolute 00617ff0h
%endif

initialized	resb 1
disabled	resb 1

; address of patch() function in WinFace.exe
patch		resd 1

err_msg_ptr	resd 1

; -----------------------------------------------------------------------------

[section .text]

		; [ecx+17]: ptr to article all headers, ASCIIZ
                ; Original multiline headers have been put on one line by Gravity!

		cmp	byte [disabled], 1
		je	.disabled

		pushad

		mov	ebx, [ecx+17]

		cmp	byte [initialized], 1
		je	.already_initialized

                mov 	byte [disabled], 1

		; load WinFace.dll

		invoke	KERNEL32.LoadLibraryA, dword library_name
		test	eax, eax
		jnz	.ok1
		mov	ebx, error_text
		jmp	.show_lasterror

.ok1:

		invoke	KERNEL32.GetProcAddress, eax, dword func_name
		test	eax, eax
		jnz	.ok2
		mov	ebx, error_text2
		jmp	.show_lasterror
.ok2:

		mov	dword [patch], eax

.already_initialized:

		push	ebx
		call	dword [patch]
		test	eax, eax
		jnz	.ok3
		mov	eax, error_text3
		mov	ebx, patch_name
		jmp	.show_error

.ok3:
                mov 	byte [disabled], 0
		mov	byte [initialized], 1

		jmp	.return
.show_lasterror:

		invoke	KERNEL32.GetLastError
		invoke	KERNEL32.FormatMessageA, dword FORMAT_MESSAGE_FROM_SYSTEM | FORMAT_MESSAGE_IGNORE_INSERTS | FORMAT_MESSAGE_ALLOCATE_BUFFER, 0, eax, 0, dword err_msg_ptr, 0, 0
		mov	eax, [err_msg_ptr]

.show_error:
		invoke	USER32.MessageBoxA, 0, eax, ebx, 0
.error:
		mov	byte [disabled], 1

.return:
		popad
.disabled:
		; repair patched instruction
%ifndef GRAV_2039
		mov	al, byte [ebp+0bh]
%else
		mov	al, byte [ebx+0bh]
%endif
		test	al, al

%ifdef GRAV_2039
		jmp	0409311h
%elifdef GRAV_2000
		jmp	0407641h
%elifdef GRAV_1800
		jmp	0407911h
%elifdef GRAV_1020
		jmp	0406f82h
%endif

; -----------------------------------------------------------------------------

; read-only constants (really can't write to these)

error_text	db	"Can't load "
library_name	db	"WinFace.dll", 0

error_text2	db	"GetProcAddress failed", 0
error_text3	db	"patch failed", 0

patch_name	db	"X-Face "
func_name	db	"patch", 0