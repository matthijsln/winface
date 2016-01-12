;%include "x-face.inc"

; -----------------------------------------------------------------------------

%define MSG_SET_XFACE 	WM_USER+100
%define MSG_CLEAR_XFACE WM_USER+101

%define timer_freq	100
%define pos_save_waits	20

; -----------------------------------------------------------------------------

[section .bss]
; ptr to headers that identify the current post. used to determine if this
; routine is called with headers from a different posting (so that we can
; remove the X-Face from the display). this just works, although I've only
; checked it empirically.
current_post	resd 1

; thread id (not the handle) for the thread managing the window
thread_id	resd 1

temp		resb 14 + 100   ; let's hope our error text doesn't get any longer
				; than this

grav_hwnd	resd 1

hidden		resb 1

counter		resd 1

x		resd 1
y		resd 1

rect		resb RECT_size

menu		resd 1

__SECT__

; -----------------------------------------------------------------------------

[section .data]

disabled	db 0
initialized	db 0

error_text	db "Error %d: %s", 0

dib_error	db "CreateDIBSection failed", 0

__SECT__

; -----------------------------------------------------------------------------

%macro checkerror 2
; check for error
; %1 statement to set flags, i.e. "test eax, eax" or something
; %2 condition code - if this is true an error is reported with the line number
;    set to the line before the line containing "checkerror"
		%1
		j%-2	short %%ok
		mov	esi, __LINE__ - 1
		jmp	show_error
%%ok:
%endmacro

show_error:
		invoke	GetLastError
		invoke	FormatMessageA, dword FORMAT_MESSAGE_FROM_SYSTEM | FORMAT_MESSAGE_IGNORE_INSERTS | FORMAT_MESSAGE_ALLOCATE_BUFFER, 0, eax, 0, dword err_msg_ptr, 0, 0
		mov	ebx, temp
		invoke	wsprintfA, ebx, dword error_text, esi, dword [err_msg_ptr]
		add	esp, 4 * 4
		invoke	MessageBoxA, byte 0, ebx, dword title, byte 0

		; no need to LocalFree, we won't come back here again anyway

		mov	byte [disabled], 1

		xor	eax, eax
		ret	4


global patch
patch:
		; [esp+4]: ptr to article all headers, ASCIIZ
                ; Original multiline headers have been put on one line by Gravity!

		cmp	byte [disabled], 1
		je	.error_return

		cmp	byte [initialized], 1
		je	short .already_initialized

                ; create thread which will manage the window
		invoke	CreateThread, 0, dword 4096, dword thread_proc, 0, 0, dword thread_id
		checkerror {test eax, eax}, z

                ; give our dialog time to setup its message queue so that
                ; PostMessage won't fail (if the first post displayed
                ; has a X-Face, we do PostMessage real soon down here,
                ; and PM might fail because the dialog isn't created yet)
		invoke	Sleep, 0

		mov	byte [initialized], 1

.already_initialized:
		mov	esi, [esp+4]

		mov	ebx, esi		; save beginning of headers
.h:
		mov	edx, esi
.scan_eol:
		cmp	byte [esi], 0
		je	short .eol
                cmp     byte [esi], CR
		je	short .eol
                cmp     byte [esi], LF
		je	short .eol
		inc	esi
		jmp	short .scan_eol
.eol:
		mov	eax, esi
		sub	eax, edx		; eax is length of header line
		lea	ecx, [eax-7]		; ecx: length of X-Face, without "X-Face: " (-8) and with Z (+1)
		mov	edi, eax
		cmp	eax, 9			; is the header line shorter than 9 bytes?
		jl	.next_header

		; edx: beginning of header line
		; esi: 1 past end of header line
		; eax: length of header line	; not used any further down
		; ecx: length of X-Face (if any)

		; scan header line for "X-Face: "

		push	edx
		push	ecx

		; convert the first 8 chars to lowercase and store those in
                ; temp (so that we catch all combinations such as "X-Face: ",
                ; "x-face: ", "X-face: ", etc.
		push	byte 8
		pop	ecx
		mov	edi, temp
.to_lower:
		mov	al, byte [edx]
		inc	edx
		cmp	al, "A"
		jl	short .next_char
		cmp	al, "Z"
		ja	short .next_char
		add	al, 32
.next_char:
		mov	[edi], al
		inc	edi
		loop	.to_lower

		pop	ecx
		pop	edx

		cmp	dword [temp], "x-fa"
		jne	.next_header
		cmp	dword [temp+4], "ce: "
		jne	short .next_header

                ; we got a X-Face!

		mov	dword [current_post], ebx

                cmp     ecx, 4096               ; X-Face max one page in size
		ja	.quit

                ; pass X-Face to window manager thread

		; alloc one page (4096 bytes)
		push	ecx
		push	edx

%error FIXME ??? eax 0 ???
 		invoke	VirtualAlloc, byte 0, eax, dword MEM_COMMIT, byte PAGE_READWRITE
		mov	edi, eax
		pop	edx
		pop	ecx
		checkerror {test eax, eax}, z

		mov	bh, byte [esi]		; save byte from Gravity buffer
		mov	byte [esi], 0		; make header line zero terminated

		add	edx, 8			; skip "X-Face: "

.copy_face:
		mov	bl, byte [edx]
		mov	byte [eax], bl
		inc	edx
		inc	eax
		loop	.copy_face

		invoke	PostMessageA, dword [hwnd], dword MSG_SET_XFACE, edi, eax
		test	eax, eax
		jnz	short .post_ok

		; free buffer - dialog won't receive message
		invoke	VirtualFree, edi, byte 0, dword MEM_RELEASE

.post_ok:
		mov	byte [esi], bh		; repair Gravity buffer

		jmp	short .got_face		; don't scan the headers any further

.next_header:
		cmp	byte [esi], 0
		je	short .no_face

		xor	eax, eax

		cmp	byte [esi], CR
		sete	al
		add	esi, eax

		cmp	byte [esi], LF
		sete	al
		add	esi, eax

		cmp	byte [esi], CR
		sete	al
		add	esi, eax

		cmp	byte [esi], 0
		je	short .no_face

		; esi: ptr to beginning of next header
		mov	edx, esi
		jmp	.scan_eol

.no_face:
		;cmp	ebx, dword [current_post]
		;je	.same_posting

		; notify dialog to remove current X-Face from screen
                ; as the posting has changed and does not have a X-Face

		invoke	PostMessageA, dword [hwnd], dword MSG_CLEAR_XFACE, eax, eax

.got_face:
.same_posting:
.quit:

                xor     eax, eax
                inc     eax
                ret	4

.error_return:
		xor	eax, eax
		ret	4


; -----------------------------------------------------------------------------

[section .data]

grav_classname	db	"MicroPlanetNewsfra"
me		db	"me", 0

ini_name	db	"x-face-patch.ini", 0

key_name_sx	db "s"
key_name_x	db "x", 0
key_name_sy	db "s"
key_name_y	db "y", 0
key_name_hide	db "hide", 0
key_name_double	db "double", 0
key_name_white	db "white", 0
key_name_black	db "black", 0

fmt_str		db "%d", 0

window_title	db "X-Face", 0

double_pixels	dd 0

double_size	db 0
hide_noface	db 0
disable		db 0
black_color	dd 0
white_color	dd 0ffffffffh

have_face	db 0

white_rgb	dd 0ffffffh
black_rgb	dd 0000000h

current_palette dd 0

choose_col istruc CHOOSECOLOR
	at CHOOSECOLOR.lStructSize,	dd CHOOSECOLOR_size
	at CHOOSECOLOR.hwndOwner,	dd 0
	at CHOOSECOLOR.hInstance,	dd 0
	at CHOOSECOLOR.rgbResult,	dd 0
	at CHOOSECOLOR.lpCustColors,	dd custom_colors
	at CHOOSECOLOR.Flags,		dd CC_ANYCOLOR | CC_FULLOPEN | CC_RGBINIT
	at CHOOSECOLOR.lCustData,	dd 0
	at CHOOSECOLOR.lpfnHook,	dd 0
	at CHOOSECOLOR.lpTemplateName,	dd 0
iend

custom_colors times 16 dd 0ffffffh

__SECT__

[section .bss]

double_size_bmp	resd 1

border_w	resd 1
border_h	resd 1

__SECT__

thread_proc:
		invoke	DialogBoxParamA, dword [instance], IDD_FACEDIALOG, 0, dword face_dialog_proc, eax
		ret	4

%define _hwnd	ebp+8
%define msg	ebp+12
%define wParam	ebp+16
%define lParam	ebp+20


; -----------------------------------------------------------------------------

; can only be called from within the dialog proc!

show_face:
		cmp	byte [double_size], 0
		je	short .no_double_size

		; stretch bitmap

		invoke	CreateCompatibleDC, 0
		mov	esi, eax
		invoke	SelectObject, eax, dword [dib_handle]

		invoke	CreateCompatibleDC, 0
		mov	edi, eax
		invoke	SelectObject, eax, dword [double_size_bmp]

		invoke	StretchBlt, edi, 0, 0, 96, 96, esi, 0, 0, 48, 48, dword SRCCOPY

		invoke	DeleteDC, esi
		invoke	DeleteDC, edi

		mov	edi, dword [double_size_bmp]
		push	48

		jmp	short .set_bitmap

.no_double_size:
		mov	edi, dword [dib_handle]
		push	0

.set_bitmap:
		; set size; 48x48 or 96x96 client area

		pop	esi

		mov	ebx, esi
		add	esi, [border_w]
		add	ebx, [border_h]

; doesn't seem to work on win95/98
;		invoke	SetWindowPos, dword [_hwnd], eax, eax, eax, eax, ecx, SWP_NOMOVE | SWP_NOZORDER

		push	1

		push	eax
		push	eax
		push	eax
		push	eax

		invoke	GetWindowRect, dword [_hwnd], esp

		mov	dword [esp+8], esi
		mov	dword [esp+12], ebx

		invoke	MoveWindow, dword [_hwnd]

		invoke	GetDlgItem, dword [_hwnd], dword IDC_FACEIMAGE
		invoke	SendMessageA, eax, dword STM_SETIMAGE, IMAGE_BITMAP, edi

		invoke	RedrawWindow, dword [_hwnd], 0, 0, byte RDW_INVALIDATE

		ret

; -----------------------------------------------------------------------------

face_dialog_proc:

		push	ebp
		mov	ebp, esp

		push	ebx
		push	esi
		push	edi

		mov	eax, [msg]

		cmp	eax, WM_INITDIALOG
		jne	.l0

		mov	eax, [_hwnd]
		mov	[hwnd], eax
		mov	ebx, eax

		; start building args for SetWindowPos()

		push	SWP_NOZORDER		; uFlags

		invoke	GetSystemMetrics, byte SM_CYFIXEDFRAME
		lea	esi, [eax * 2 + 48]
		mov	[border_h], esi
		push	esi			; cy

		invoke	GetSystemMetrics, byte SM_CXFIXEDFRAME
		lea	eax, [eax * 2 + 48]
		mov	[border_w], eax
		push	eax			; cx

		xor	esi, esi
		xor	edi, edi

		invoke	GetPrivateProfileIntA, dword me, dword key_name_sy, 0, dword ini_name
		push	eax
		invoke	GetSystemMetrics, byte SM_CYSCREEN
		pop	ecx
		cmp	eax, ecx
		jne	short .topleft

		invoke	GetPrivateProfileIntA, dword me, dword key_name_sx, 0, dword ini_name
		push	eax
		invoke	GetSystemMetrics, byte SM_CXSCREEN
		pop	ecx
		cmp	eax, ecx
		jne	short .topleft

		invoke	GetPrivateProfileIntA, dword me, dword key_name_y, 0, dword ini_name
		mov	esi, eax
		invoke	GetPrivateProfileIntA, dword me, dword key_name_x, 0, dword ini_name
		mov	edi, eax

.topleft:
		push	esi			; y
		push	edi			; x

		push	0			; hwndInsertAfter (ignored)
		push	ebx			; hwnd
		invoke	SetWindowPos

		; setup timer

		mov	dword [counter], pos_save_waits

		invoke	SetTimer, ebx, 0, dword timer_freq, 0	; save window pos every timer_freq milliseconds

		; load colors

		invoke	GetPrivateProfileIntA, dword me, dword key_name_white, dword 0ffffffh, dword ini_name
		mov	dword [white], eax

		invoke	GetPrivateProfileIntA, dword me, dword key_name_black, 0, dword ini_name
		mov	dword [black], eax


		; create DIB

		invoke	CreateDIBSection, 0, dword bitmap_info_header, 0, dword dib_pixels, 0, 0
		test	eax, eax
		jnz	short .ok

		xor	eax, eax
		mov	edi, dword [dib_pixels]
		mov	ecx, 8 * 48 / 4		; 8, not 6, because of DIB alignment
		rep	stosd

		invoke	MessageBoxA, byte 0, dword dib_error, dword title, byte 0
		invoke	EndDialog, dword [hwnd], eax

		jmp	.exit

.ok:
		mov	dword [dib_handle], eax

		; create 96x96x1 bitmap
		mov	dword [bitmap_info_header+4], 96
		mov	dword [bitmap_info_header+8], 96
		invoke	CreateDIBSection, 0, dword bitmap_info_header, 0, dword double_pixels, 0, 0
		mov	[double_size_bmp], eax

		; load context menu
		invoke	LoadMenuA, dword [instance], IDR_POPUPMENU
		invoke	GetSubMenu, eax, 0
		mov	dword [menu], eax

		invoke	GetDlgItem, ebx, dword IDC_FACEIMAGE
		invoke	SendMessageA, eax, dword STM_SETIMAGE, IMAGE_BITMAP, dword [dib_handle]

		invoke	FindWindowA, dword grav_classname, 0
		mov	dword [grav_hwnd], eax
		invoke	SetForegroundWindow, eax

		; load hide setting
		invoke	GetPrivateProfileIntA, dword me, dword key_name_hide, 0, dword ini_name

		shr	eax, 1
		salc

                mov	[hide_noface], al

		and	al, 08h

		invoke	CheckMenuItem, dword [menu], dword ID_HIDEWHENNOXFACEAVAILABLE, eax

		; load double setting
		invoke	GetPrivateProfileIntA, dword me, dword key_name_double, 0, dword ini_name

		shr	eax, 1
		salc

                mov	[double_size], al

		and	al, 08h

		invoke	CheckMenuItem, dword [menu], dword ID_DOUBLESIZE, eax

		jmp	.exit

.l0:
		cmp	eax, MSG_SET_XFACE
		jne	.l1

		mov	byte [have_face], 1

		; display the X-Face wParam points to

		; copy face to face_buffer
		mov	esi, [wParam]
		invoke	lstrlenA, esi
		inc	eax
		mov	ecx, eax
		mov	edi, face_buffer
		rep	movsb

		push	2
		push	dword [dib_pixels]
		push	dword [wParam]
		call	decode_face
		mov	ebx, eax

		invoke	VirtualFree, dword [wParam], 0, dword MEM_RELEASE

		test	ebx, ebx
		js	.clear

		call	show_face

		;invoke	SetWindowPos, dword [_hwnd], eax, eax, eax, eax, eax, SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_SHOWWINDOW
		;invoke	SetForegroundWindow, dword [grav_hwnd]
		invoke	ShowWindow, dword [_hwnd], SW_SHOWNA

		invoke	EnableMenuItem, dword [menu], dword ID_COPYXFACETEXT, MF_ENABLED
		invoke	EnableMenuItem, dword [menu], dword ID_COPYIMAGE, MF_ENABLED

		jmp	.exit

.l1:
		cmp	eax, MSG_CLEAR_XFACE
		jne	short .l2
.clear:
		; remove X-Face

		mov	byte [face_buffer], 0

		invoke	EnableMenuItem, dword [menu], dword ID_COPYXFACETEXT, MF_GRAYED
		invoke	EnableMenuItem, dword [menu], dword ID_COPYIMAGE, MF_GRAYED

		xor	eax, eax
		mov	edi, dword [dib_pixels]
		mov	ecx, 8 * 48 / 4		; 8, not 6, because of DIB alignment
		rep	stosd

		call	show_face

		mov	byte [have_face], 0

		cmp	byte [hide_noface], 0
		je	short .keep_showing

		invoke	ShowWindow, dword [_hwnd], SW_HIDE

.keep_showing:

		jmp	.exit

.l2:
		cmp	eax, WM_TIMER
		jne	.l3

		dec	byte [counter]
		jnz	.dont_save

		mov	dword [counter], pos_save_waits

		; look if we need to save the window position

		invoke	GetWindowRect, dword [_hwnd], dword rect

		mov	eax, dword [rect+RECT.left]
		mov	ebx, dword [rect+RECT.top]

		cmp	eax, dword [x]
		je	.dont_save
		jmp	.save

		cmp	ebx, dword [y]
		je	.dont_save
.save:
		; save the window coords

		mov	dword [x], eax
		mov	dword [y], ebx

		mov	edi, temp
		mov	esi, ini_name

		invoke	wsprintfA, edi, dword fmt_str, eax
		add	esp, 3*4

		mov	ecx, key_name_x
		invoke	WritePrivateProfileStringA, dword me, ecx, edi, esi

		mov	eax, dword [y]

		invoke	wsprintfA, edi, dword fmt_str, eax
		add	esp, 3*4

		mov	ecx, key_name_y
		invoke	WritePrivateProfileStringA, dword me, ecx, edi, esi

		invoke	GetSystemMetrics, SM_CXSCREEN

		invoke	wsprintfA, edi, dword fmt_str, eax
		add	esp, 3*4

		mov	ecx, key_name_sx
		invoke	WritePrivateProfileStringA, dword me, ecx, edi, esi

		invoke	GetSystemMetrics, SM_CYSCREEN

		invoke	wsprintfA, edi, dword fmt_str, eax
		add	esp, 3*4

		mov	ecx, key_name_sy
		invoke	WritePrivateProfileStringA, dword me, ecx, edi, esi

.dont_save:
		invoke	FindWindowA, dword grav_classname, 0
		test	eax, eax
		jz	short .inactive

		mov	ebx, eax

		invoke	GetForegroundWindow
		cmp	eax, dword [_hwnd]
		je	short .active
		cmp	eax, ebx
		je	short .active

.inactive:
		invoke	ShowWindow, dword [_hwnd], SW_HIDE
		mov	byte [hidden], 1

		jmp	short .end
.active:

		cmp	byte [hidden], 1
		jne	short .end

		cmp	byte [hide_noface], 0
		je	short .show

		cmp	byte [have_face], 0
		je	.exit

.show:
		invoke	ShowWindow, dword [_hwnd], SW_SHOW
		mov	byte [hidden], 0

.end:

		jmp	.exit
.l3:
		cmp	eax, WM_LBUTTONDOWN
		jne	short .l4

		; drag window
		invoke	SendMessageA, dword [_hwnd], dword WM_SYSCOMMAND, dword 0f012h, 0

		jmp	.exit
.l4:
		cmp	eax, WM_CONTEXTMENU
		jne	.l5

		xor	ecx, ecx
		mov	eax, [lParam]
		mov	cx, ax
		shr	eax, 16

		invoke	TrackPopupMenu, dword [menu], dword TPM_RETURNCMD | TPM_NONOTIFY, ecx, eax, 0, dword [_hwnd], 0
		test	eax, eax
		jz	.exit

		cmp	eax, ID_DOUBLESIZE
		jne	short .p0

		xor	eax, eax
                xor	byte [double_size], 0ffh		; cmp'ing only with 0, not with 1!
		mov	al, [double_size]
		push	eax

		; save to .ini

		and	eax, 1

		mov	edi, temp
		mov	esi, ini_name

		invoke	wsprintfA, edi, dword fmt_str, eax
		add	esp, 3*4

		mov	ecx, key_name_double
		invoke	WritePrivateProfileStringA, dword me, ecx, edi, esi

		pop	eax
		and	al, 08h

		invoke	CheckMenuItem, dword [menu], dword ID_DOUBLESIZE, eax

		call	show_face
		jmp	.exit

.p0:
		cmp	eax, ID_HIDEWHENNOXFACEAVAILABLE
		jne	short .p1

		xor	eax, eax
		xor	byte [hide_noface], 0ffh
		mov	al, [hide_noface]
		push	eax

		; save to .ini

		and	eax, 1

		mov	edi, temp
		mov	esi, ini_name

		invoke	wsprintfA, edi, dword fmt_str, eax
		add	esp, 3*4

		mov	ecx, key_name_hide
		invoke	WritePrivateProfileStringA, dword me, ecx, edi, esi

		pop	eax
		and	al, 08h

		invoke	CheckMenuItem, dword [menu], dword ID_HIDEWHENNOXFACEAVAILABLE, eax

		cmp	byte [have_face], 0
		je	.clear

		invoke	ShowWindow, dword [_hwnd], SW_SHOWNA

.p1:
		cmp	eax, ID_DISABLE
		jne	short .p2

		invoke	EndDialog, dword [_hwnd], 0
		jmp	.exit

.p2:
		cmp	eax, ID_BLACKCOLOR
		jne	short .p3

		mov	eax, [black]
		mov	[choose_col+CHOOSECOLOR.rgbResult], eax
		mov	eax, [_hwnd]
		mov	[choose_col+CHOOSECOLOR.hwndOwner], eax
		invoke	ChooseColorA, dword choose_col
		test	eax, eax
		jz	.exit

		mov	eax, [choose_col+CHOOSECOLOR.rgbResult]
		bswap	eax
		shr	eax, 8
		mov	dword [black], eax

		; save to .ini

		mov	edi, temp
		mov	esi, ini_name

		invoke	wsprintfA, edi, dword fmt_str, eax
		add	esp, 3*4

		mov	ecx, key_name_black
		invoke	WritePrivateProfileStringA, dword me, ecx, edi, esi

		jmp	short .recreate_bitmaps

.p3:
		cmp	eax, ID_WHITECOLOR
		jne	.p4

		mov	eax, [white]
		mov	[choose_col+CHOOSECOLOR.rgbResult], eax
		mov	eax, [_hwnd]
		mov	[choose_col+CHOOSECOLOR.hwndOwner], eax
		invoke	ChooseColorA, dword choose_col
		test	eax, eax
		jz	.exit

		mov	eax, [choose_col+CHOOSECOLOR.rgbResult]
		bswap	eax
		shr	eax, 8
		mov	dword [white], eax

		; save to .ini

		mov	edi, temp
		mov	esi, ini_name

		invoke	wsprintfA, edi, dword fmt_str, eax
		add	esp, 3*4

		mov	ecx, key_name_white
		invoke	WritePrivateProfileStringA, dword me, ecx, edi, esi


.recreate_bitmaps:

		; first create a new 48x48x1 bitmap with the new colors
		mov	dword [bitmap_info_header+4], 48
		mov	dword [bitmap_info_header+8], -48
		invoke	CreateDIBSection, 0, dword bitmap_info_header, 0, dword temp, 0, 0
		mov	ebx, eax

		; copy bits from old 48x48x1 bitmap

		mov	esi, dword [dib_pixels]
		mov	edi, dword [temp]
		mov	ecx, 8 * 48 / 4
		rep	movsd

                ; destroy old bitmaps

		invoke	DeleteObject, dword [dib_handle]
		invoke	DeleteObject, dword [double_size_bmp]

		; replace dib_handle with new bmp
		mov	dword [dib_handle], ebx
		mov	eax, dword [temp]
		mov	dword [dib_pixels], eax

		; create new 96x96x1 bitmap with the new colors
		mov	dword [bitmap_info_header+4], 96
		mov	dword [bitmap_info_header+8], 96
		invoke	CreateDIBSection, 0, dword bitmap_info_header, 0, dword dummy, 0, 0
		mov	dword [double_size_bmp], eax

		call	show_face

		jmp	.exit

.p4:
		cmp	eax, ID_COPYIMAGE
		jne	short .p5

		invoke	CreateCompatibleDC, 0
		mov	esi, eax
		invoke	CreateCompatibleBitmap, eax, 48, 48
		mov	edi, eax
		invoke	SelectObject, esi, edi
		invoke	CreateCompatibleDC, 0
		mov	ebx, eax
		invoke	SelectObject, eax, dword [dib_handle]

		invoke	BitBlt, esi, 0, 0, 48, 48, ebx, 0, 0, dword SRCCOPY

		invoke	OpenClipboard, 0
		invoke	EmptyClipboard
		invoke	SetClipboardData, CF_BITMAP, edi
		invoke	CloseClipboard

		invoke	DeleteDC, esi
		invoke	DeleteDC, ebx

.p5:
		cmp	eax, ID_COPYXFACETEXT
		jne	short .p6

		invoke	lstrlenA, dword face_buffer
		inc	eax
		mov	ebx, eax

		invoke	GlobalAlloc, dword GMEM_DDESHARE, ebx
		push	eax

		invoke	GlobalLock, eax

		mov	edi, eax
		mov	esi, face_buffer
		mov	ecx, ebx
		rep	movsb

		pop	ebx

		invoke	GlobalUnlock, ebx

		invoke	OpenClipboard, 0
		invoke	EmptyClipboard
		invoke	SetClipboardData, CF_TEXT, ebx
		invoke	CloseClipboard

		jmp	short .exit
.p6:

		jmp	short .exit
.l5:

		xor	eax, eax
.exit:
		pop	edi
		pop	esi
		pop	ebx

		leave
		ret	4 * 4