; compface output/input decoding/encoding
; Copyright (C) 2002 Matthijs Laan
; This file licensed as in license.txt
; http://www.xs4all.nl/~walterln/winface/

%ifndef __XFACE_INC
%define __XFACE_INC

extern _compface
extern _uncompface

%ifndef __XFACE_CODE
extern decode_face
extern encode_face
%endif; __XFACE_CODE

%define ERR_OK          0       ; successful completion
%define ERR_EXCESS      1       ; completed OK but some input was ignored
%define ERR_INSUFF      -1      ; insufficient input.  Bad face format?
%define ERR_INTERNAL    -2      ; Arithmetic overflow or buffer overflow

%endif; __XFACE_INC