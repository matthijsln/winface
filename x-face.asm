; compface output/input decoding/encoding
; Copyright (C) 2002 Matthijs Laan
; This file licensed as in license.txt
; http://www.xs4all.nl/~walterln/winface/

%define __XFACE_CODE

%include "x-face.inc"

extern _uncompface
extern _compface

; call uncompface() and decode its output to a bitmap
; int __stdcall decode_face(char *src, void *dest, int pad);
; src    pointer to source ASCIIZ X-Face. must have space for at least 1,057
;        bytes, as this buffer will be used for immediate data of that size.
; dest   pointer to where the bitmap should be decoded to. you can set this
;        to the same as src. it will be stored top to bottom.
; pad    number of bytes that should be added to the dest pointer after one
;	 row has been decoded.
;        one decoded row is 48/8=6 bytes, if you set this to 2 the next row
; 	 will be aligned to 8 bytes (provided src is, of course).
;	 you should use this value if you have created a DIB with
;	 CreateDIBSection() (with a _negative_ height to create a top to
;	 bottom DIB), which requires 4 byte alignment.
;        note that this skips bytes - it does not fill them with zeroes.
; returns:
;	   ERR_OK          0       ; successful completion
;	   ERR_EXCESS      1       ; completed OK but some input was ignored
;          ERR_INSUFF      -1      ; insufficient input.  bad face format?
;          ERR_INTERNAL    -2      ; arithmetic overflow or buffer overflow

segment _TEXT align=4 public use32 class=CODE

global decode_face
global _decode_face@12
_decode_face@12:
decode_face:
		mov	eax, [esp+4]
		push	eax
		call	_uncompface
		add	esp, 4
		test	eax, eax
		js	short .fail

		push	ebp
		mov	ebp, esp

		push	ebx
		push	edi
		push	esi
                push    eax

		mov	ebx, [ebp+8]		; source
		mov	edi, [ebp+12]		; dest

		; parse results of uncompface to create a 1 bit bitmap

		; ebx now points to something like this, (ASCII)

		; 0xDFFF,0xFFFF,0xFFFF,
		; 0x7ADD,0xFFFF,0xFFFF,
		; 0xD7AA,0xAAFF,0xFFFF,
		; ...and so on, for a total of 48 rows,
		; with a LF after each row,
		; terminated with 0

		; now convert that to this: (HEX)

		; DFFFFFFFFFFF7ADDFFFFFFFFD7AAAAFFFFFF...

		push	byte 48			; rows
.face_line:
		push	byte 3
		pop	esi			; words in a line
.face_word:
		push	byte 4
		inc	ebx			; skip "0x"
		pop	ecx
.next_char:
		or	edx, eax
		inc	ebx
		mov	al, byte [ebx]
		shl	edx, 4
		test	al, 64
		jnz	short .hex
		sub	al, 48
		loop	.next_char
		jmp	short .done
.hex:
		sub	al, 55
		loop	.next_char
.done:
		or	edx, eax
		xchg	dl, dh			; convert to big endian
		mov	[edi], dx
		add	edi, 2
		add	ebx, 2			; skip 'LF, ",0"'
		dec	esi
		jnz	short .face_word
		inc	ebx			; skip ","
		add	edi, dword [ebp+16]	; align for DIB, usually 2
		dec	dword [esp]
		jnz	short .face_line

		pop	eax			; remove rows var from stack

                pop     eax
		pop	esi
		pop	edi
		pop	ebx

		leave
.fail:
		ret	3 * 4

;------------------------------------------------------------------------------

; encode a 1 bit bitmap to hex and call compface()
; void __stdcall encode_face(void *src, char *dest, int pad);
; src    pointer to source X-Face top-to-bottom 48x48x1 bitmap.
; dest   pointer to where the X-Face should be stored to. you can *not* set this
;        to the same as src. must have space for at least xxx bytes
; pad    number of bytes that should be added to the src pointer after one
;	 row has been encoded.

%ifdef DELPHI_LINKER
; needed for buggy Delphi linker
segment _2_TEXT align=4 public use32 class=CODE
%endif

global encode_face
global _encode_face@12
_encode_face@12:
encode_face:
		push	edi

		mov	esi, [esp+8]		; src
		mov	edx, [esp+12]		; dest

		; convert this: (HEX)

		; DFFFFFFFFFFF [alignment padding] 7ADDFFFFFFFF [alignment padding] D7AAAAFFFFFF...

		; to: (ASCII)

		; DFFFFFFFFFFF7ADDFFFFFFFFD7AAAAFFFFFF...

		xor	eax, eax

		push	byte 48
.row:
		push	byte 6
		pop	ecx
.byte:
		mov	al, [esi]
		or	ah, al
		and	al, 0fh			; do high nibble
		add	al, 48
		cmp	al, 58
		jl	short .no_hex
		add	al, 7
.no_hex:
		mov	[edx+1], al
		shr	eax, 12			; do low nibble
		add	al, 48
		cmp	al, 58
		jl	short .no_hex2
		add	al, 7
.no_hex2:
		mov	[edx], al
		inc	esi
		inc	edx
		inc	edx
		loop	.byte

		add	esi, dword [esp+20]	; align
		dec	dword [esp]
		jnz	short .row

		mov	byte [edx], 0		; add null terminator

		pop	eax			; remove rows var from stack

		push	dword [esp+12]
		call	_compface
		add	esp, 4

		pop	edi

		ret	3 * 4
