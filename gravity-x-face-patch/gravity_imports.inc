%ifdef GRAV_2039

%define KERNEL32.FormatMessageA	005ad3c0h
%define KERNEL32.GetProcAddress	005ad438h
%define KERNEL32.GetLastError	005ad458h
%define KERNEL32.LoadLibraryA	005ad464h
%define USER32.MessageBoxA	005ad668h

%elifdef GRAV_2000

%define KERNEL32.FormatMessageA	0059c3b0h
%define KERNEL32.GetProcAddress	0059c404h
%define KERNEL32.GetLastError	0059c440h
%define KERNEL32.LoadLibraryA	0059c450h
%define USER32.MessageBoxA	0059c7fch

%elifdef GRAV_1800

%define KERNEL32.FormatMessageA	005a13ach
%define KERNEL32.GetProcAddress	005a1404h
%define KERNEL32.GetLastError	005a1440h
%define KERNEL32.LoadLibraryA	005a1450h
%define USER32.MessageBoxA	005a17fch

%elifdef GRAV_1020

%define KERNEL32.FormatMessageA	005803a0h
%define KERNEL32.GetProcAddress	005803e4h
%define KERNEL32.GetLastError	0058047ch
%define KERNEL32.LoadLibraryA	00580410h
%define USER32.MessageBoxA	005805dch

%endif