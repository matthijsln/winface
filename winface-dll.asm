%include "win32.inc"

%include "kernel32.inc"
%include "user32.inc"
%include "gdi32.inc"
%include "comdlg32.inc"
%include "shell32.inc"

%include "resource.inc"
%include "macros.inc"

%include "x-face.inc"

%define align_dword(s) ((s+3) & ~11b)

%define TEMP_BUF_SIZE 4096

%define FACE_BITMAP_SIZE (align_dword(48/8)*48)

default_face:
incbin "default_face.txt"
db 0
default_face_end:
%define default_face_size default_face_end - default_face

; used for writing to a .bmp file: BITMAPFILEHEADER structure
start_of_bmp_headers:
bitmap_file_header	dw	"BM"
			dd	end_of_bmp_headers - start_of_bmp_headers + FACE_BITMAP_SIZE
			dw	0
			dw	0
			dd	end_of_bmp_headers - start_of_bmp_headers

; also used for creating DIB section
bitmap_info_header	dd 10 * 4		; biSize
			dd 48			; biWidth
			dd -48			; biHeight		; pixels begin at top-left, not lower-left
									; apparently .bmp's are always bottom-up so
									; this is temporarily changed to +48 when
									; writing .bmps
			dw 1			; biPlanes
			dw 1			; biBitCount
			dd 0 ; BI_RGB		; biCompression
			dd 0			; biSizeImage
			dd 0			; biXPelsPerMeter
			dd 0			; biYPelsPerMeter
			dd 2			; biClrUsed
			dd 2			; biClrImportant

			; now comes the RGBQUAD array
white			dd 000ffffffh			; white
black			dd 000000000h			; black
end_of_bmp_headers:

title db "WinFace/1.51", 0

bmp db "bmp", 0

loadimg_error_text	db "Error loading image", 0

file_filter db "Images (*.bmp)", 0, "*.bmp", 0, "All files (*.*)", 0, "*.*", 0, 0

edited		db 0

;------------------------------------------------------------------------------

section .bss

;------------------------------------------------------------------------------

dib_handle	resd 1				; handle to the 48x48x1 DIB
dib_pixels	resd 1				; ptr to DIB bits

hwnd		resd 1				; dialog box hwnd

face_buffer	resb 1057

temp_buf	resb TEMP_BUF_SIZE
temp_bmp_buf	resb FACE_BITMAP_SIZE
err_msg_ptr	resd 1

dummy		resd 1

instance	resd 1

invert		resb 1
single_line	resd 1
c_escape	resd 1

;------------------------------------------------------------------------------

section .code

;-------------------------PATCH SUPPORT CODE-----------------------------------

%include "patchsupport.asm"

;-------------------------DLL ENTRY POINT--------------------------------------

global _dll_main
_dll_main:
		mov	eax, [esp+4]
		mov	dword [instance], eax
		xor	eax, eax
		inc	eax
		ret	0ch

;-------------------------WINFACE GUI CODE-------------------------------------

global gui_main
gui_main:
		invoke	DialogBoxParamA, dword [instance], IDD_MAINDIALOG, 0, dword dialog_proc, eax
		xor	eax, eax
		invoke	ExitProcess, eax

;------------------------------------------------------------------------------
%if 0

; push	dword error_text
; call	show_lasterror

show_lasterror:
		mov	eax, [esp+4]

		push	ebx
		push	esi
		push	edi

		mov	esi, eax
		invoke	lstrlenA, esi
		mov	ebx, TEMP_BUF_SIZE-1-2	; include null terminator and ": "
		sub	ebx, eax
		cmp	ebx, 0
		jl	short .show

		push	eax
		mov	edi, temp_buf
		invoke	lstrcpyA, edi, esi
		pop	eax
		add	edi, eax
		mov	word [edi], ": "
		inc	edi
		inc	edi
		inc	ebx			; include null terminator for lstrcpyn

		invoke	GetLastError
		invoke	FormatMessageA, dword FORMAT_MESSAGE_FROM_SYSTEM | FORMAT_MESSAGE_IGNORE_INSERTS | FORMAT_MESSAGE_ALLOCATE_BUFFER, 0, eax, 0, dword err_msg_ptr, 0, 0
		invoke	lstrcpynA, edi, dword [err_msg_ptr], ebx
		invoke	LocalFree, dword [err_msg_ptr]

		mov	esi, temp_buf

.show:
		invoke	MessageBoxA, dword [hwnd], esi, dword title, MB_OK | MB_ICONERROR

		pop	edi
		pop	esi
		pop	ebx
		ret	1 * 4
%endif

;------------------------------------------------------------------------------

[section .data]
error_msg db "Error in X-Face, not decoded", 0

__SECT__


face_to_image:
		invoke	GetDlgItem, dword [hwnd], dword IDC_XFACEEDIT
		invoke	SendMessageA, eax, WM_GETTEXT, dword 1057, dword temp_buf

		push	2
		push	dword [dib_pixels]
		push	dword temp_buf
		call	decode_face
		test	eax, eax
		js	short .error

		invoke	GetDlgItem, dword [hwnd], dword IDC_IMAGE
		invoke	RedrawWindow, eax, 0, 0, RDW_INVALIDATE

		ret

.error:
		invoke	MessageBoxA, dword [_hwnd], dword error_msg, dword title, MB_OK
		ret

;------------------------------------------------------------------------------

%macro WM_INITDIALOG_handler 0
		mov	eax, [_hwnd]
		mov	[hwnd], eax

%if 0		; doesn't seem to work
		invoke	LoadIconA, dword 400000, 101
		invoke	SetClassLongA, dword [_hwnd], GCL_HICON, eax
%endif

		invoke	CreateDIBSection, 0, dword bitmap_info_header, 0, dword dib_pixels, 0, 0
		mov	dword [dib_handle], eax

		invoke	GetDlgItem, dword [hwnd], dword IDC_IMAGE
		invoke	SendMessageA, eax, dword STM_SETIMAGE, IMAGE_BITMAP, dword [dib_handle]

		; set edit control font

		; push LOGFONT structure

		push	dword "New"
		push	dword "ier "
		push	dword "Cour"

		push	7
		pop	ecx
.push_loop:
		push	0
		loop	.push_loop

		invoke	GetDC			; ,  0 (already pushed)
		invoke	GetDeviceCaps, eax, LOGPIXELSY

		push	9
		pop	edx
		mul	edx
		push	72
		pop	ecx
		div	ecx
		neg	eax

		push	eax					; lfHeight

		invoke	CreateFontIndirectA, esp
		add	esp, 8 * 4

		push	ebx			; save

		push	1		; fRedraw
		push	eax		; hfont

		invoke	GetDlgItem, dword [hwnd], dword IDC_XFACEEDIT
		mov	ebx, eax
		invoke	SendMessageA, ebx, WM_SETFONT

		; set max chars
		invoke	SendMessageA, ebx, dword EM_SETLIMITTEXT, dword 1057-1, 0

		; set text
		invoke	SendMessageA, ebx,  WM_SETTEXT, 0, dword default_face
		pop	ebx

		call	face_to_image

		; copy default face to face_buffer

		push	edi
		push	esi

		mov	edi, face_buffer
		mov	esi, default_face
		mov	ecx, default_face_size
		rep	movsb

		pop	esi
		pop	edi

		xor	eax, eax
		inc	eax
		jmp	.exit
%endmacro

;------------------------------------------------------------------------------

%macro WM_DESTROY_handler 0
		invoke	EndDialog, dword [hwnd],  0
		jmp	.exit
%endmacro

;------------------------------------------------------------------------------

ofn_hook:
		cmp	dword [esp+8], WM_NOTIFY
		jne	short .exit

                invoke	IsDlgButtonChecked, dword [esp+8], dword IDC_INVERTCHECK
		mov	[invert], al
.exit:
		xor	eax, eax
		ret	4 * 4

;------------------------------------------------------------------------------
; eax: wParam
; ecx: wNotifyCode

%macro IDC_OPENBUTTON_handler 0

		cmp	ecx, BN_CLICKED
		jne	.exit

		; open button clicked

		; show open file dialog

		mov	eax, temp_buf
		mov	byte [eax], 0

		push	IDD_OFNDIALOG					; lpTemplateName
		push	dword ofn_hook					; lpfnHook
		push	0						; lCustData
		push	0						; lpstrDefExt
		push	0						; nFileExtension and nFileOffset
		push	dword OFN_FILEMUSTEXIST | OFN_HIDEREADONLY | OFN_EXPLORER | OFN_ENABLEHOOK | OFN_ENABLETEMPLATE	| OFN_ENABLESIZING ; Flags
		push	0						; lpstrTitle
		push	0						; lpstrInitialDir
		push	0						; nMaxFileTitle
		push	0						; lpstrFileTitle
		push	dword TEMP_BUF_SIZE-1 				; nMaxFile
		push	eax		 				; lpstrFile
		push	1						; nFilterIndex
		push	0						; nMaxCustFilter
		push	0						; lpstrCustomFilter
		push	dword file_filter 				; lpstrFilter
		push	dword [instance]				; hInstance
		push	dword [hwnd]					; hwndOwner
		push	OPENFILENAME_size 				; lStructSize

		invoke	GetOpenFileNameA, esp
		add	esp, OPENFILENAME_size
		test	eax, eax
		jz	.exit

.load_file_in_temp_buf:
		invoke	LoadCursorA, 0, dword IDC_WAIT
		invoke	SetCursor, eax

		push	ebx
		push	edi
		push	esi

		xor	edx, edx		; IMAGE_BITMAP
%if 0 ; .ico "support" (non-functional)
		; scan for .ico

		mov	edi, temp_buf
		xor	eax, eax
		lea	ecx, [eax-1]

		repnz	scasb

		mov	eax, [edi-4]
		or	eax, 000202020h
		cmp	eax, "ico"
		jne	short .no_ico

		inc	edx			; IMAGE_ICON
.no_ico:
		push	edx			; save is .ico?
%endif ; .ico "support"
		invoke	LoadImageA, 0, dword temp_buf, edx, 0, 0, dword LR_LOADFROMFILE | LR_CREATEDIBSECTION
		pop	edx			; restore is .ico?
		test	eax, eax
		jz	.loadimg_error

		mov	ebx, eax		; ebx: source image handle
%if 0 ; .ico "support"
		test	edx, edx
		jz	.no_ico2

		invoke	MessageBeep, 0

		invoke	CreateCompatibleDC,  0
		mov	edi, eax

		invoke	SelectObject, eax, dword [dib_handle]

		invoke	GetStockObject, WHITE_BRUSH

		;push	48
		;push	48
		;push	0
		;push	0

		;invoke	FillRect, edi, esp, eax
		;add	esp, 4 * 4

                invoke	DrawIconEx, edi, 0, 0, ebx, 48, 48, 0, eax, DI_NORMAL

		invoke	DestroyIcon, ebx
		invoke	DeleteDC, edi

		jmp	.loaded
.no_ico2:

%endif ; .ico "support"

		; start building args for StretchBlt()

		cmp	byte [invert], BST_UNCHECKED
		je	short .no_invert
		push	dword NOTSRCCOPY	; dwRop
		jmp	short .inverted
.no_invert:
		push	dword SRCCOPY		; dwRop
.inverted:

		; calc width and height; look them up in the .bmp file

		invoke	CreateFileA, dword temp_buf, dword GENERIC_READ, FILE_SHARE_READ, 0, OPEN_EXISTING, 0, 0
		mov	esi, eax
		invoke	SetFilePointer, esi, dword 12h, 0, FILE_BEGIN
		invoke	ReadFile, esi, dword temp_buf, 8, dword dummy, 0
		invoke	CloseHandle, esi

		mov	eax, dword temp_buf

		push	dword [eax+4]		; nHeightSrc
		push	dword [eax]		; nWidthSrc

		push	0			; nYOriginSrc
		push	0			; nXOriginSrc

		invoke	CreateCompatibleDC, 0
		mov	esi, eax

		invoke	SelectObject, eax, ebx

		push	esi			; hdcSrc
		push	48
		push	48
		push	0
		push	0

		invoke	CreateCompatibleDC, 0
		mov	edi, eax

		invoke	SelectObject, eax, dword [dib_handle]

;		invoke	FillRect, edi, esp, dword 0ffffffh

		push	edi

		call	[StretchBlt]

		invoke	DeleteDC, edi
		invoke	DeleteDC, esi
		invoke	DeleteObject, ebx

.loaded:

		invoke	GetDlgItem, dword [hwnd], dword IDC_IMAGE
		invoke	RedrawWindow, eax, 0, 0, RDW_INVALIDATE

		; update edit control text

		push	2
		push	dword face_buffer
		push	dword [dib_pixels]
		call	encode_face

		call	check_if_edited

		; make sure "Single Line" and "C-Escape" are pushlike checkboxes

		invoke	GetDlgItem, dword [hwnd], dword IDC_SINGLELINEBUTTON
		mov	ebx, eax
		invoke	SetWindowLongA, ebx, GWL_STYLE, dword WS_CHILDWINDOW | WS_VISIBLE | WS_TABSTOP | BS_AUTOCHECKBOX | BS_PUSHLIKE
		invoke	CheckDlgButton, dword [hwnd], dword IDC_SINGLELINEBUTTON, dword [single_line]
		invoke	RedrawWindow, ebx, 0, 0, RDW_INVALIDATE

		; idem for "C-Escape"

		invoke	GetDlgItem, dword [hwnd], dword IDC_CESCAPEBUTTON
		mov	ebx, eax
		invoke	SetWindowLongA, ebx, GWL_STYLE, dword WS_CHILDWINDOW | WS_VISIBLE | WS_TABSTOP | BS_AUTOCHECKBOX | BS_PUSHLIKE
		invoke	CheckDlgButton, dword [hwnd], dword IDC_CESCAPEBUTTON, dword [c_escape]
		invoke	RedrawWindow, ebx, 0, 0, RDW_INVALIDATE

		mov	byte [edited], 0

		call	reformat_face

		; restore cursor

		invoke	SendMessageA, dword [hwnd], WM_SETCURSOR, dword [hwnd], 0

		pop	esi
		pop	edi
		pop	ebx

		jmp	.exit
.loadimg_error:
		invoke	MessageBoxA, dword [hwnd], dword loadimg_error_text, dword title, MB_OK | MB_ICONERROR
		jmp	.exit
%endmacro

;------------------------------------------------------------------------------

; eax: wParam
; ecx: wNotifyCode

%macro IDC_TOIMAGEBUTTON_handler 0

		cmp	ecx, BN_CLICKED
		jne	.exit

		call	face_to_image

		jmp	.exit
%endmacro

;------------------------------------------------------------------------------

; eax: wParam
; ecx: wNotifyCode

%macro IDC_SAVEBUTTON_handler 0

		cmp	ecx, BN_CLICKED
		jne	.exit

		mov	eax, temp_buf
		mov	byte [eax], 0

		push	0						; lpTemplateName
		push	0						; lpfnHook
		push	0						; lCustData
		push	dword bmp					; lpstrDefExt
		push	0						; nFileExtension and nFileOffset
		push	dword OFN_FILEMUSTEXIST | OFN_HIDEREADONLY  	; Flags
		push	0						; lpstrTitle
		push	0						; lpstrInitialDir
		push	0						; nMaxFileTitle
		push	0						; lpstrFileTitle
		push	dword TEMP_BUF_SIZE-1 				; nMaxFile
		push	eax		 				; lpstrFile
		push	1						; nFilterIndex
		push	0						; nMaxCustFilter
		push	0						; lpstrCustomFilter
		push	dword file_filter 				; lpstrFilter
		push	0						; hInstance
		push	dword [hwnd]					; hwndOwner
		push	OPENFILENAME_size 				; lStructSize

		invoke	GetSaveFileNameA, esp
		add	esp, OPENFILENAME_size
		test	eax, eax
		jz	.exit

		push	esi
		push	edi

		; turn bitmap upside down

		mov	esi, [dib_pixels]
		add	esi, 47 * 8
		mov	edi, temp_bmp_buf


		push	48
		pop	ecx
.loop:
		mov	eax, dword [esi]
		mov	dword [edi], eax
		mov	eax, dword [esi+4]
		mov	dword [edi+4], eax
		add	edi, 8
		sub	esi, 8
		loop	.loop

		mov	dword [bitmap_info_header+8], 48

		invoke	CreateFileA, dword temp_buf, dword GENERIC_WRITE, FILE_SHARE_READ, 0, CREATE_ALWAYS, 0, 0
		mov	esi, eax
		invoke	WriteFile, esi, dword start_of_bmp_headers, end_of_bmp_headers - start_of_bmp_headers, dword dummy, 0
		invoke	WriteFile, esi, dword temp_bmp_buf, dword FACE_BITMAP_SIZE, dword dummy, 0
		invoke	CloseHandle, esi

		mov	dword [bitmap_info_header+8], -48

		pop	edi
		pop	esi

		jmp	.exit
%endmacro

;------------------------------------------------------------------------------

; eax: wParam
; ecx: wNotifyCode

%macro IDC_COPYBUTTON_handler 0

		cmp	ecx, BN_CLICKED
		jne	.exit

		push	esi
		push	edi
		push	ebx

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

		pop	ebx
		pop	edi
		pop	esi

		jmp	.exit
%endmacro

;------------------------------------------------------------------------------

%macro WM_DROPFILES_handler 0

		mov	byte [invert], 0

		invoke	DragQueryFile, dword [wParam], 0, dword temp_buf, dword TEMP_BUF_SIZE-1
		jmp	.load_file_in_temp_buf
%endmacro

;------------------------------------------------------------------------------

check_if_edited:
; garbles: ebx

		cmp	byte [edited], 1
		jne	short .not_edited
		ret
.not_edited:
		mov	byte [edited], 1

		; change checkbox buttons to normal buttons

		; first save if it was checked or not, so that we can apply
		; that when we encode a bitmap when we make the buttons
		; checkboxes again

		invoke	IsDlgButtonChecked, dword [hwnd], dword IDC_SINGLELINEBUTTON
		mov	[single_line], eax

		invoke	GetDlgItem, dword [hwnd], dword IDC_SINGLELINEBUTTON
		mov	ebx, eax
		invoke	CheckDlgButton, dword [hwnd], dword IDC_SINGLELINEBUTTON, BST_UNCHECKED
		invoke	SetWindowLongA, ebx, GWL_STYLE, dword WS_CHILDWINDOW | WS_VISIBLE | WS_TABSTOP
		invoke	RedrawWindow, ebx, 0, 0, RDW_INVALIDATE

		; idem for "C-Escape"

		invoke	IsDlgButtonChecked, dword [hwnd], dword IDC_CESCAPEBUTTON
		mov	[c_escape], eax

		invoke	GetDlgItem, dword [hwnd], dword IDC_CESCAPEBUTTON
		mov	ebx, eax
		invoke	CheckDlgButton, dword [hwnd], dword IDC_CESCAPEBUTTON, BST_UNCHECKED
		invoke	SetWindowLongA, ebx, GWL_STYLE, dword WS_CHILDWINDOW | WS_VISIBLE | WS_TABSTOP
		invoke	RedrawWindow, ebx, 0, 0, RDW_INVALIDATE

		ret
;------------------------------------------------------------------------------

reformat_face:
		push	esi
		push	edi

		mov	edi, temp_buf
		mov	esi, face_buffer

		cmp	byte [edited], 1
		jne	short .not_edited

		; edited, first get edit control text in face_buffer

		invoke	GetDlgItem, dword [hwnd], dword IDC_XFACEEDIT
		invoke	SendMessageA, eax, WM_GETTEXT, dword 1057, esi

.not_edited:
.loop:
		cmp	dword [single_line], 1
		jne	short .no_sl

		cmp	byte [esi], ' '
		jne	short .no_space
		inc	esi
		jmp	short .next_char

.no_space:
		cmp	byte [esi], CR
		jne	short .no_sl

		cmp	byte [esi+1], LF
		jne	short .no_sl

		inc	esi
		inc	esi
		jmp	short .next_char
.no_sl:
		cmp	dword [c_escape], 1
		jne	short .no_ce

		cmp	byte [esi], '\'
		jne	short .no_slash

		mov	byte [edi], '\'
		inc	edi
		jmp	short .copy_next

.no_slash:
		cmp	byte [esi], '"'
		jne	short .no_quote

		mov	byte [edi], '\'
		inc	edi
		jmp	short .copy_next

.no_quote:
		cmp	byte [esi], '%'
		jne	short .no_percent

		mov	byte [edi], '%'
		inc	edi
		jmp	short .copy_next

.no_percent:
		cmp	byte [esi], CR
		jne	short .no_cr

		cmp	byte [esi+1], LF
		jne	short .no_cr

		mov	word [edi], '\n'
		inc	edi
		inc	edi
		inc	esi
		inc	esi
		jmp	short .next_char

.no_cr:
.no_ce:
.copy_next:
		movsb

.next_char:
		cmp	byte [esi], 0
		jnz	short .loop

		mov	byte [edi], 0

		; set text

		invoke	GetDlgItem, dword [hwnd], dword IDC_XFACEEDIT
		invoke	SendMessageA, eax, WM_SETTEXT, 0, dword temp_buf
.exit:

		pop	edi
		pop	esi

		ret

;------------------------------------------------------------------------------

; eax: wParam
; ecx: wNotifyCode

%macro IDC_XFACEEDIT_handler 0

		cmp	ecx, EN_CHANGE
		jne	.exit

		push	ebx

		call	check_if_edited

		pop	ebx

		jmp	.exit

%endmacro

;------------------------------------------------------------------------------

; eax: wParam
; ecx: wNotifyCode

%macro IDC_SINGLELINEBUTTON_handler 0

		cmp	byte [edited], 1
		je	short .edited0

		invoke	IsDlgButtonChecked, dword [hwnd], dword IDC_SINGLELINEBUTTON
		mov	[single_line], eax

		call	reformat_face

		jmp	.exit

.edited0:
		push	dword [single_line]
		push	dword [c_escape]
		mov	dword [single_line], 1
		mov	dword [c_escape], 0
		call	reformat_face
		pop	eax
		mov	dword [c_escape], eax
		pop	eax
		mov	dword [single_line], eax


		jmp	.exit
%endmacro

;------------------------------------------------------------------------------

; eax: wParam
; ecx: wNotifyCode

%macro IDC_CESCAPEBUTTON_handler 0

		cmp	byte [edited], 1
		je	short .edited1

		invoke	IsDlgButtonChecked, dword [hwnd], dword IDC_CESCAPEBUTTON
		mov	[c_escape], eax

		call	reformat_face

		jmp	short .exit

.edited1:
		push	dword [single_line]
		push	dword [c_escape]
		mov	dword [single_line], 0
		mov	dword [c_escape], 1
		call	reformat_face
		pop	eax
		mov	dword [c_escape], eax
		pop	eax
		mov	dword [single_line], eax

		jmp	short .exit

%endmacro

;------------------------------------------------------------------------------

dialog_proc:

%define _hwnd	ebp+8
%define msg	ebp+12
%define wParam	ebp+16
%define lParam	ebp+20

		push	ebp
		mov	ebp, esp

		mov	eax, [msg]
		cmp	eax, WM_INITDIALOG
		jne	.l0

		WM_INITDIALOG_handler
.l0:
		cmp	eax, WM_COMMAND
		jne	.no_WM_COMMAND

		mov	eax, dword [wParam]	; ax: wID

		cmp	ax, WM_DESTROY
		jne	short .l1

		WM_DESTROY_handler
.l1:
		mov	ecx, eax
		shr	ecx, 16			; ecx: wNotifyCode

		cmp	ax, IDC_OPENBUTTON
		jne	.l2

		IDC_OPENBUTTON_handler
.l2:
		cmp	ax, IDC_TOIMAGEBUTTON
		jne	short .l3

		IDC_TOIMAGEBUTTON_handler
.l3:
		cmp	ax, IDC_SAVEBUTTON
		jne	.l4

		IDC_SAVEBUTTON_handler
.l4:
		cmp	ax, IDC_COPYBUTTON
		jne	.l5

		IDC_COPYBUTTON_handler

.l5:
		cmp	ax, IDC_XFACEEDIT
		jne	.l6

		IDC_XFACEEDIT_handler
.l6:
		cmp	ax, IDC_SINGLELINEBUTTON
		jne	short .l7

		IDC_SINGLELINEBUTTON_handler
.l7:
		cmp	ax, IDC_CESCAPEBUTTON
		jne	short .l8

		IDC_CESCAPEBUTTON_handler
.l8:
		xor	eax, eax
		jmp	short .exit

.no_WM_COMMAND:
		cmp	eax, WM_DROPFILES
		jne	short .l9

		WM_DROPFILES_handler
.l9:


		xor	eax, eax
.exit:
		leave
		ret	4 * 4