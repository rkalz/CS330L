; Along32 Link Library Source Code ( Along32.asm )
; Copyright (C) 2009 Curtis Wong.
; All right reserved.
; Email: airekans@gmail.com
; Homepage: http://along32.sourceforge.net
;
; This file is part of Along32 library.
;
; Along32 library is free software: you can redistribute it and/or modify
; it under the terms of the GNU Lesser General Public License as 
; published by the Free Software Foundation, either version 3 of the
; License, or(at your option) any later version.
;
; Along32 library is distributed in the hope that it will be useful,
; but WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
; GNU Lesser General Public License for more details.
;
; You should have received a copy of the GNU Lesser General Public License
; along with Along32 library.  If not, see <http://www.gnu.org/licenses/>.
;
;
; Recent Updates:
; 2009/05/25: The main body of this file
; 2009/08/19: add comments
; 2010/04/15: fix the bug in ReadInt, and a bug in ReadHex. ReadHex will 
;             generate a segmentation fault.
; 2014/03/06: major revision to eliminate the int 80 stuff that is not 
;             compatible across all unix platforms.  I converted all of
;             the int 80h stuff to use standard C library calls such as
;             read() and write().  This is now usable on both Linux and
;             Mac OS/X, as well as any other Unix variant with a standard
;             C library.  Fixed a couple of bugs, and wrote a ReadFloat /
;             WriteFloat procedure which was completely missing.  Cleaned
;             up the source, aligning opcodes, operands, and operands, 
;             removed spurious spacing, etc.
; 2014/04/04  final cleanup, particularly paying attention to the glibc
;             calls which can be problematic.  They require specific
;             stack alignment, which students don't maintain very well,
;             so the code simply forces the correct 16 byte alignment
;             before the glibc calls are made to avoid spurious segmentation
;             faults.  A bug in WriteFloat was also fixed, a bug that would
;             cause negative numbers between 0 and -.999999 to be displayed
;             as positive.
;
; This library was created by Curtis Wong, and modified by Robert Hyatt,
; for use with the book, "Assembly Language for Intel-based Computers",
; 4th Edition & 5th Edition, modified from Irvine32.asm.
;
; Function Prototypes
; -------------- global functions ------------
; Clrscr : Clears the screen using an ANSI escape sequence
; Crlf : output a carriage return / new line
; Delay : Delay for n microseconds
; Gotoxy : Locate the cursor
; IsDigit : Determines whether the character in AL is a valid decimal digit.
; DumpMem : Writes a range of memory to standard output in hexadecimal.
; ParseDecimal32: convert the number string to a decimal number
; ParseInteger32 : Converts a string containing a signed integer to binary. 
; strlen : compute the length of null-teminated string
; Str_compare : Compare two strings.
; Str_trim : Remove all occurences of a character from the end of a string.
; Str_ucase : Convert a null-terminated string to upper case.
; Random32 : Generates an unsigned pseudo-random 32-bit integer
; Randomize : Re-seeds the random number generator with the current time
; RandomRange : Returns an unsigned pseudo-random 32-bit integer in EAX.
; ReadDec : read Decimal number from buffer
; ReadHex : Reads a 32-bit hexadecimal integer from the keyboard
; ReadInt : Reads a 32-bit signed decimal integer from standard input
; ReadString : read string from input buffer
; ReadChar : read a character from stdin
; WriteBin : write a 32-bit binary number to console( interface )
; WriteBinB : write a 32-bit binary number to console
; WriteChar : write a character to stdout
; WriteDec : write a decimal number to stdout
; WriteHex : Writes an unsigned 32-bit hexadecimal number to the console.
; WriteHexB : Writes an unsigned 32-bit hexadecimal number to the console.
; WriteInt : Writes a 32-bit signed binary integer to the console in ASCII.
; WriteString : output a null-terminated string
; -------------- private functions -----------
; AsciiDigit : convert the actual number to ascii represetation
; HexByte : Display the byte in AL in hexadecimal

%include "macros.inc"

%ifnmacro ShowFlag
;---------------------------------------------------------------------
%macro ShowFlag 2.nolist
;
; Helper macro.
; Display a single CPU flag value
; Directly accesses the eflags variable in Along32.asm
; (This macro cannot be placed in Macros.inc)
;---------------------------------------------------------------------

segment .data
%%flagStr: db "  ",%1, "="
%%flagVal: db 0,0

segment .text
         push      eax
         push      edx
         mov       eax, dword [eflags] ; retrieve the flags
         mov       byte [%%flagVal],'1'
         shr       eax, %2             ; shift into carry flag
         jc        %%L1
         mov       byte [%%flagVal],'0'
%%L1:    mov       edx, %%flagStr      ; display flag name and value
         call      WriteString
         pop       edx
         pop       eax
%endmacro
%endif

; import libc functions

extern atof, exit, read, time, usleep, write

%assign  MAX_DIGITS 80
%define  ESC       27                  ; escape code
InitFlag DB        0                   ; initialization flag
xtable   db        "0123456789ABCDEF"
segment  .bss                          ; uninitialized data
eflags:  resd      1
fpstate  resd      30                  ; floating point state save area
digitBuffer: resb  MAX_DIGITS + 1
buffer   resb      512
; --------------------------------------------------------
; make the functions global as the shared library functions
; --------------------------------------------------------

global Clrscr, Crlf, Delay, DumpMem, DumpRegs, Gotoxy, IsDigit, ParseDecimal32, ParseInteger32, Random32, Randomize, RandomRange, ReadChar, ReadDec,  ReadHex, ReadInt, ReadKey, ReadString,  Str_compare, Str_copy, strlen, Str_trim, Str_ucase, WriteBin, WriteBinB, WriteChar, WriteDec, WriteHex, WriteHexB, WriteInt, WriteString
global ReadFloat, WriteFloat, ExitProc
;----------------------------------------------------------

;-----------------------------------------------------
;
; First, write the control characters to stdout to clear the screen.
; Then move the cursor to 0,0 on the screen.
;-----------------------------------------------------
segment  .data
clrStr   db        ESC, "[2J", 0
segment  .text
Clrscr:
         pushad                        ; save registers
         mov       edx, clrStr         ; clear screen character string
         call      WriteString         ; clear screen by escape code sequence
         mov       edx, 0              ; row 0, col 0
         call      Gotoxy              ; position cursor
         popad                         ; restore registers
         ret
;--------------- End of Clrscr -----------------------

;-----------------------------------------------------
;
; Writes a carriage return / linefeed
; sequence (0Dh,0Ah) to standard output.
;-----------------------------------------------------
segment  .data
crlf     db        0dh, 0ah, 0
segment  .text
Crlf:
         pushad                        ; save registers
         mov       edx, crlf           ; address of cr/lf string
         call      WriteString         ; write it out
         popad                         ; restore registers
         ret
;--------------- End of Crlf -------------------------

;------------------------------------------------------
;
; Delay (pause) the current process for a given number
; of microseconds.
; Receives: EAX = number of useconds
; Returns: nothing
;------------------------------------------------------
Delay:
         pushad                        ; save registers
         mov       ebp, esp            ; save esp
         sub       esp, 16             ; round stack size up to x16
         and       esp, 0fffffff0h     ; 16 byte boundary
         sub       esp, 12             ; library alignment
         push      eax                 ; push arg on stack
         call      usleep              ; call usleep(usecs)
         mov       esp, ebp            ; restore stack
         popad                         ; restore registers
         ret
;--------------- End of Delay -------------------------

;------------------------------------------------------
;
; Exit ends the current process with a normal exit status
; Receives: nothing
; Returns: nothing
;------------------------------------------------------
ExitProc:
         mov       ebp, esp            ; save esp
         sub       esp, 16             ; round stack size up to x16
         and       esp, 0fffffff0h     ; 16 byte boundary
         sub       esp, 12             ; library alignment
         xor       eax, eax            ; exit status = 0
         push      eax                 ; push arg on stack
         call      exit                ; call exit system call
;--------------- End of Exit --------------------------

;--------------------------------------------------------
;
; Locate the cursor
; Receives: DH = screen row, DL = screen column
; Last update: 7/11/01
;--------------------------------------------------------
segment .data
lStr1    db        ESC, "[", 0
lStr2    db        ";", 0
lStr3    db        "H", 0

segment .text
Gotoxy:
         pushad                        ; save registers
         mov       ebx, edx            ; save row/col
         mov       edx, lStr1          ; first part of escape sequence
         call      WriteString         ; dump it to console
         movzx     eax,bl              ; get screen col
         call      WriteDec            ; display col
         mov       edx, lStr2          ; second part of escape sequence
         call      WriteString         ; dump it to console
         movzx     eax,bh              ; get screen row
         call      WriteDec            ; display col
         mov       edx, lStr3          ; third part of escape sequence
         call      WriteString         ; dump it to console
         popad                         ; restore registers
         ret
;--------------- End of Gotoxy -------------------------

;-----------------------------------------------
;
; Determines whether the character in AL is a
; valid decimal digit.
; Receives: AL = character
; Returns: ZF=1 if AL contains a valid decimal
;   digit; otherwise, ZF=0.
;-----------------------------------------------
IsDigit:
         cmp       al,'0'              ; digit < 0?
         jb        id                  ; yes, no good
         cmp       al,'9'              ; digit > 9?
         ja        id                  ; yes, no good
         test      ax,0                ; digit is ok, set ZF = 1
id:      ret
;--------------- End of IsDigit ----------------------

;---------------------------------------------------
;
; Writes a range of memory to standard output
; in hexadecimal.
; Receives: ESI = starting offset, ECX = number of units,
;           EBX = unit size (1=byte, 2=word, or 4=doubleword)
; Returns:  nothing
;---------------------------------------------------
segment  .data
oneSpace: db ' ',0
dumpPrompt: db 13,10,"Dump of offset ",0
dashLine: db "-------------------------------",13,10,0
segment  .text
DumpMem:
         enter     8, 0                ; [ebp - 4]: unit size
                                       ; [ebp - 8]: number of units written
         pushad                        ; save registers
         mov       edx, dumpPrompt     ; address of heading
         call      WriteString         ; display it
         mov       eax, esi            ; get memory offset to dump
         call      WriteHex            ; display starting address in hex
         call      Crlf                ; new line
         mov       edx, dashLine       ; dashed line separator
         call      WriteString         ; write it
         mov       dword [ebp - 8], 0  ; zero bytes written
         mov       dword [ebp - 4], ebx; display fmt (1, 2 or 4 bytes)
         cmp       ebx, 4              ; set to display dword chunk?
         je        dm1                 ; yes
         cmp       ebx,2               ; no, what about word chunk:
         je        dm2                 ; yes
         jmp       dm3                 ; one byte at a time
; 32-bit doubleword output
dm1:     mov       eax, dword [esi]    ; get next dword
         call      WriteHex            ; display in hex
         mWriteSpace 2                 ; spaces
         add       esi, ebx            ; next cnunk
         Loop      dm1                 ; loop until done
         jmp       dm5                 ; done
; 16-bit word output
dm2:     mov       ax, word [esi]      ; get next word
         ror       ax, 8               ; swap bytes (al = high order now)
         call      HexByte             ; display high order byte
         ror       ax, 8               ; swap bytes (la = low order now)
         call      HexByte             ; display low order byte
         mWriteSpace 1                 ; display 1 space
         add       esi, ebx            ; point to next word
         Loop      dm2                 ; loop until done
         jmp       dm5                 ; done
; 8-bit byte output, 16 bytes per line
dm3:     mov       al, byte [esi]      ; get next byte
         call      HexByte             ; display byte
         inc       dword [ebp - 8]     ; count bytes, break line at 16
         mWriteSpace 1                 ; write byte
         inc       esi                 ; next byte
         mov       dx, 0               ; clear for div
         mov       ax, word [ebp - 8]  ; get bytes written
         mov       bx, 16              ; modulo 16
         div       bx                  ; divide byte count by 16
         cmp       dx,0                ; remainder == 0?
         jne       dm4                 ; no, keep going
         call      Crlf                ; yes, new line
dm4:     Loop      dm3                 ; loop until done
dm5:     call      Crlf                ; new line
         popad                         ; restore registers
         leave
         ret
;--------------- End of DumpMem -------------------------

;---------------------------------------------------
;
; Displays EAX, EBX, ECX, EDX, ESI, EDI, EBP, ESP in
; hexadecimal. Also displays the Zero, Sign, Carry, and
; Overflow flags.
; Receives: nothing.
; Returns: nothing.
;
; Warning: do not create any local variables or stack
; parameters, because they will alter the EBP register.
;---------------------------------------------------
segment .data
fptemp   dd        0.0
saveIP   dd        0
saveESP  dd        0
fp       dd        0,0,0,0,0,0,0,0
fpbuf    db        "std:  ", 0
fpmsg    db        "Floating Point Registers:", 13, 10, 13, 10, 0
segment  .text
DumpRegs:
         pushad
         pop       dword [saveIP]      ; get current EIP
         mov       dword [saveESP],esp ; save ESP's value at entry
         push      dword [saveIP]      ; replace it on stack
         push      eax                 ; save EAX (restore on exit)
         pushfd                        ; push extended flags
         pushfd                        ; push flags again, and
         pop       dword [eflags]      ; save them in a variable
         call      Crlf                ; blank line
         mShowRegister "EAX",EAX       ; display EAX
         mShowRegister "EBX",EBX       ; display EBX
         mShowRegister "ECX",ECX       ; display ECX
         mShowRegister "EDX",EDX       ; display EDX
         call      Crlf                ; new line
         mShowRegister "ESI",ESI       ; display ESI
         mShowRegister "EDI",EDI       ; display EdI
         mShowRegister "EBP",EBP       ; display EBP
         mov eax, dword [saveESP]      ; fetch SP (it has been altered by this
                                       ; routine so we show a saved copy
         mShowRegister "ESP",EAX       ; display ESP
         call      Crlf                ; new line
         mov eax, dword [saveIP]       ; fetch saved EIP
         mShowRegister "EIP",EAX       ; show EIP (set by call to here)
         mov eax, dword [eflags]       ; fetch saved eflags
         mShowRegister "EFL",EAX       ; show EFL

; Show the flags (using the eflags variable). The integer parameter indicates
; how many times EFLAGS must be shifted right to shift the selected flag 
; into the Carry flag.

         ShowFlag  "CF",1              ; show carry flag
         ShowFlag  "SF",8              ; show sign flag
         ShowFlag  "ZF",7              ; show zero flag
         ShowFlag  "OF",12             ; show overflow flag
         ShowFlag  "AF",5              ; show adjust flag (BCD math)
         ShowFlag  "PF",3              ; show parity flag
         call      Crlf                ; new line
         call      Crlf                ; blank line

; now we display the floating point stack

         mov       edx, fpmsg          ; heading
         call      WriteString         ; display heading
         mov       ecx, 0              ; number of floating point regs
ststack: fstp      dword [fp + 4*ecx]  ; save fp stack in order
         inc       ecx                 ; next entry
         cmp       ecx, 8              ; done 'em all?
         jl        ststack             ; nope continue
         mov       ecx, 0              ; start at stack entry 0
fpl:     fld       dword [fp + 4*ecx]  ; grep nth stack entry
         mov       eax, ecx            ; stack element #
         or        eax, 30h            ; convert to ascii
         mov       byte [fpbuf + 2], al; build label
         mov       edx, fpbuf          ; address of buffer
         call      WriteString         ; write label
         call      ftoa                ; convert float to ascii
         mov       edx, fpbuff         ; address of full-form fp value
         call      WriteString         ; write out fp value
         call      Crlf                ; next line
         fstp      dword [fptemp]      ; remove value
         inc       ecx                 ; next entry
         cmp       ecx, 8              ; done 'em all?
         jl        fpl                 ; nope continue
ldstack: fld       dword [fp - 4 + 4*ecx] ; save fp stack in order
         loop      ldstack             ; do all 8 regs
         popfd                         ; pop fd
         pop eax                       ; pop eax to clear up stack
         popad
         ret
;--------------- End of DumpRegs ---------------------

;--------------------------------------------------------
;
; Converts (parses) a string containing an unsigned decimal
; integer, and converts it to binary. All valid digits occurring 
; before a non-numeric character are converted. 
; Leading spaces are ignored.

; Receives: EDX = offset of string, ECX = length 
; Returns:
;  If the integer is blank, EAX=0 and CF=1
;  If the integer contains only spaces, EAX=0 and CF=1
;  If the integer is larger than 2^32-1, EAX=0 and CF=1
;  Otherwise, EAX=converted integer, and CF=0
;--------------------------------------------------------
ParseDecimal32:
         enter     4, 0
         pushad                        ; save registers
         mov       esi,edx             ; save offset in ESI
         cmp       ecx,0               ; length greater than zero?
         jne       pd1                 ; yes: continue
         mov       eax,0               ; no: set return value
         jmp       pd5                 ; and exit with CF=1
; Skip over leading spaces, tabs
pd1:     mov       al, byte [esi]      ; get a character from buffer
         cmp       al,' '              ; space character found?
         je        pd1a                ; yes: skip it
         cmp       al, TAB             ; TAB found?
         je        pd1a                ; yes: skip it
         jmp       pd2                 ; no: goto next step
pd1a:    inc       esi                 ; yes: point to next char
         loop      pd1                 ; continue searching until end of string
         jmp       pd5                 ; exit with CF=1 if all spaces
; Start to convert the number.
pd2:     mov       eax, 0              ; clear accumulator
         mov       ebx, 10             ; EBX is the divisor
; Repeat loop for each digit.
pd3:     mov       dl, byte [esi]      ; get character from buffer
         cmp       dl, '0'             ; character < '0'?
         jb        pd4                 ; yes
         cmp       dl, '9'             ; character > '9'?
         ja        pd4                 ; yes
         and       edx, 0Fh            ; no: convert to binary
         mov       dword [ebp - 4], edx; save edx, mul destroys contents
         mul       ebx                 ; EDX:EAX = EAX * EBX
         jc        pd5                 ; quit if Carry (EDX > 0)
         mov       edx, dword [ebp - 4]; restore edx
         add       eax, edx            ; add new digit to sum
         jc        pd5                 ; quit if Carry generated
         inc       esi                 ; point to next digit
         jmp       pd3                 ; get next digit
pd4:     clc                           ; succesful completion (CF=0)
         jmp       pd6                 ; done
pd5:     mov       eax, 0              ; clear result to zero
         stc                           ; signal an error (CF=1)
pd6:     popad                         ; restore registers
         leave
         ret
;--------------- End of ParseDecimal32 ---------------------

;--------------------------------------------------------
;
; Converts a string containing a signed decimal integer to
; binary. 
;
; All valid digits occurring before a non-numeric character
; are converted. Leading spaces are ignored, and an optional 
; leading + or - sign is permitted. If the string is blank, 
; a value of zero is returned.
;
; Receives: EDX = string offset, ECX = string length
; Returns:  If CF=0, the integer is valid, and EAX = binary value.
;   If CF=1, the integer is invalid and EAX = 0.
;
; Created 7/15/05, using Gerald Cahill's 10/10/03 corrections.
; Updated 7/19/05, to skip over tabs
;--------------------------------------------------------
segment .data
overflow_msgL db  " <32-bit integer overflow>",0
invalid_msgL  db  " <invalid integer>",0
segment .text
ParseInteger32:
         enter     8, 0                ; [ebp - 4]: Lsign
                                       ; [ebp - 8]: saveDigit
         push      ebx                 ; save ebx
         push      ecx                 ; save ecx
         push      edx                 ; save edx
         push      esi                 ; save esi
         mov       dword [ebp - 4], 1  ; assume number is positive
         mov       esi, edx            ; save offset in SI
         cmp       ecx, 0              ; length greater than zero?
         jne       pi1                 ; yes: continue
         mov       eax, 0              ; no: set return value
         jmp       pi10                ; and exit
; Skip over leading spaces and tabs.
pi1:     mov       al, byte [esi]      ; get a character from buffer
         cmp       al, ' '             ; space character found?
         je        pi1a                ; yes: skip it
         cmp       al, TAB             ; TAB found?
         je        pi1a                ; yes: skip it
         jmp       pi2                 ; no: goto next step
pi1a:    inc       esi                 ; yes: point to next char
         loop      pi1                 ; continue searching until end of string
         mov       eax, 0              ; all spaces?
         jmp       pi10                ; return 0 as a valid value
; Check for a leading sign.
pi2:     cmp       al, '-'             ; minus sign found?
         jne       pi3                 ; no: look for plus sign
         mov       dword [ebp - 4], -1 ; yes: sign is negative
         dec       ecx                 ; subtract from counter
         inc       esi                 ; point to next char
         jmp       pi3a                ; continue
pi3:     cmp       al, '+'             ; plus sign found?
         jne       pi3a                ; no: skip
         inc       esi                 ; yes: move past the sign
         dec       ecx                 ; subtract from digit counter
; Test the first digit, and exit if nonnumeric.
pi3a:    mov       al, byte [esi]      ; get first character
         call      IsDigit             ; is it a digit?
         jnz       pi7a                ; no: show error message
; Start to convert the number.
pi4:     mov       eax, 0              ; clear accumulator
         mov       ebx, 10             ; EBX is the divisor
; Repeat loop for each digit.
pi5:     mov       dl, byte [esi]      ; get character from buffer
         cmp       dl, '0'             ; character < '0'?
         jb        pi9                 ; yes
         cmp       dl, '9'             ; character > '9'?
         ja        pi9                 ; yes
         and       edx, 0Fh            ; no: convert to binary
         mov       dword [ebp - 8], edx ; save string address
         imul      ebx                 ; EDX:EAX = EAX * EBX
         mov       edx, dword [ebp - 8]; restore string address imul wiped out
         jo        pi6                 ; quit if overflow
         add       eax, edx            ; add new digit to AX
         jo        pi6                 ; quit if overflow
         inc       esi                 ; point to next digit
         jmp       pi5                 ; get next digit
; Overflow has occured, unlesss EAX = 80000000h
; and the sign is negative:
pi6:     cmp       eax, 80000000h      ; compare to max -int
         jne       pi7                 ; got overflow
         cmp       dword [ebp - 4], -1 ; did number wrap to negative?
         jne       pi7                 ; overflow occurred
         jmp       pi9                 ; the integer is valid
; Choose "integer overflow" messsage.
pi7:     mov       edx, overflow_msgL  ; select message
         jmp       pi8                 ; and jump to print it
; Choose "invalid integer" message.
pi7a:    mov       edx, invalid_msgL   ; select message
; Display the error message pointed to by EDX, and set the Overflow flag.
pi8:     call      WriteString         ; write out chosen error message
         call      Crlf                ; new line
         mov       al, 127             ; max positive int (1 byte)
         add       al, 1               ; set Overflow flag
         mov       eax, 0              ; set return value to zero
         jmp       pi10                ; and exit
; IMUL leaves the Sign flag in an undeterminate state, so the OR instruction
; determines the sign of the iteger in EAX.
pi9:     imul      dword [ebp - 4]     ; EAX = EAX * sign
         or        eax, eax            ; determine the number's Sign
pi10:    pop       esi                 ; restore esi
         pop       edx                 ; restore edx
         pop       ecx                 ; restore ecx
         pop       ebx                 ; restore ebx
         leave
         ret
;--------------- End of ParseInteger32 ---------------------

;---------------------------------------------------------
;
; Return the length of a null-terminated string.
; Receives: pointer to a string
; Returns: EAX = string length
;---------------------------------------------------------
strlen:
         mov       edi, edx            ; address of string
         mov       eax, 0              ; character count
sl1:     cmp       byte [edi], 0       ; end of string?
         je        sl2                 ; yes: quit
         inc       edi                 ; no: point to next
         inc       eax                 ; add 1 to count
         jmp       sl1                 ; continue searching for NULL
sl2:     ret
;--------------- End of strlen -----------------------

;----------------------------------------------------------
;
; Compare two strings.
; Receive: the pointers to the first and the second strings
; in ESI and EDI.
; Returns nothing, but the Zero and Carry flags are affected
; exactly as they would be by the CMP instruction.
;-----------------------------------------------------
Str_compare:
         pushad                        ; save registers
sc1:     mov       al, byte [esi]      ; get byte of string 1
         mov       dl, byte [edi]      ; get byte of string 2
         cmp       al, 0               ; end of string1?
         jne       sc2                 ; no
         cmp       dl, 0               ; yes: end of string2?
         jne       sc2                 ; no
         jmp       sc3                 ; yes, exit with ZF = 1
sc2:     inc       esi                 ; point to next
         inc       edi                 ; ditto
         cmp       al, dl              ; chars equal?
         je        sc1                 ; yes: continue loop
sc3:     popad                         ; no: exit with flags set
         ret
;--------------- End of Str_compare -----------------------

;---------------------------------------------------------
;
; Copy a string from source to target.
; Requires: the target string must contain enough
;           space to hold a copy of the source string.
;----------------------------------------------------------
Str_copy:
         pushad                        ; save registers
         push      edx                 ; save source address
         push      ecx                 ; save destination address
         call      strlen              ; EAX = length source
         mov       ecx, eax            ; REP count
         inc       ecx                 ; add 1 for null byte
         pop       edi                 ; destination to edi
         pop       esi                 ; source to edi
         cld                           ; direction = up
         rep       movsb               ; copy the string
         popad                         ; restore registers
         ret
;--------------- End of Str_copy -----------------------

;-----------------------------------------------------------
;
; Remove all occurences of a given character from
; the end of a string.
; Returns: nothing
;-----------------------------------------------------------
Str_trim:
         pushad                        ; save registers
         mov       edi, edx            ; buffer address
         call      strlen              ; returns length in EAX
         cmp       eax, 0              ; zero-length string?
         je        tl2                 ; yes: exit
         mov       ecx, eax            ; no: counter = string length
         dec       eax                 ; strlen - 1 = last char
         add       edi, eax            ; EDI points to last char
         mov       al, cl              ; char to trim
         std                           ; direction = reverse
         repe      scasb               ; skip past trim character
         jne       tl1                 ; removed first character?
         dec       edi                 ; adjust EDI: ZF=1 && ECX=0
tl1:     mov       byte [edi+2], 0     ; insert null byte
tl2:     popad                         ; restore registers
         ret
;--------------- End of Str_trim -----------------------

;---------------------------------------------------
;
; Convert a null-terminated string to upper case.
; Receives: a pointer to the string
; Returns: nothing
; Last update: 1/18/02
;---------------------------------------------------
Str_ucase:
         push      esi                 ; save esi
         mov       esi, edx            ; address of string
l1:      mov       al, byte [esi]      ; get char
         cmp       al, 0               ; end of string?
         je        l3                  ; yes: quit
         cmp       al, 'a'             ; below "a"?
         jb        l2                  ; yes, skip
         cmp       al, 'z'             ; above "z"?
         ja        l2                  ; yes, skip
         and       byte [esi], 0dfh    ; remove lower case bit to make upper
l2:      inc       esi                 ; next char
         jmp       l1                  ; back to top of loop
l3:      pop       esi                 ; restore esi
         ret
;--------------- End of Str_ucase -----------------------

;--------------------------------------------------------------
;
; Generates an unsigned pseudo-random 32-bit integer
;   in the range 0 - FFFFFFFFh.
; Receives: nothing
; Returns: EAX = random integer
;--------------------------------------------------------------
segment  .data
seed     dd        1
segment  .text
Random32:
         push      edx                 ; save edx
         mov       eax, 343FDh         ; prime multiplier
         imul      dword [seed]        ; * seed
         add       eax, 269EC3h        ; add in another prime
         mov       dword [seed], eax   ; save the seed for the next call
         ror       eax, 8              ; rotate out the lowest digit (10/22/00)
         pop       edx                 ; restore edx
         ret
;------------------ End of Random32 --------------------

;--------------------------------------------------------
;
; Re-seeds the random number generator with the current time
; in seconds.
; Receives: nothing
; Returns: nothing
;--------------------------------------------------------
Randomize:
         pushad                        ; save registers
         mov       ebp, esp            ; save esp
         sub       esp, 16             ; round stack size up to x16
         and       esp, 0fffffff0h     ; 16 byte boundary
         sub       esp, 12             ; library alignment
         xor       eax, eax            ; zero (NULL) value
         push      eax                 ; push on stack - arg to time()
         call      time                ; get seconds since epoch
         mov       dword [seed],eax    ; store in seed
         mov       esp, ebp            ; restore stack
         popad                         ; restore regs
         mov       eax, dword [seed]   ; return value
         ret
;------------------ End of Randomize --------------------

;--------------------------------------------------------------
;
; Returns an unsigned pseudo-random 32-bit integer
; in EAX, between 0 and n-1. 
; Input parameter: EAX = n.
;--------------------------------------------------------------
RandomRange:
          push     ebx                 ; save ebx
          push     edx                 ; save edx
          mov      ebx, eax            ; maximum value
          call     Random32            ; eax = random number
          mov      edx, 0              ; fix edx for unsigned div
          div      ebx                 ; divide by max value
          mov      eax, edx            ; return the remainder
          pop      edx                 ; restore edx
          pop      ebx                 ; restore ebx
          ret
;------------------ End of RandomRange --------------------

;------------------------------------------------------------
;
; Reads one character from the keyboard.
; Waits for the character if none is
; currently in the input buffer.
; Returns:  AL = ASCII code
;----------------------------------------------------------
ReadChar:
         push      ecx                 ; save ecx
         push      edx                 ; save edx
         mov       ecx, 1              ; byte count
         mov       edx, buffer         ; buffer address
         call      ReadString          ; read one byte
         mov       al, byte [buffer]   ; copy to al
         pop       edx                 ; restore edx
         pop       ecx                 ; restore ecx
         ret
;--------------- End of ReadChar -------------------------

;--------------------------------------------------------
;
; Reads a 32-bit unsigned decimal integer from the keyboard,
; stopping when the Enter key is pressed.All valid digits occurring 
; before a non-numeric character are converted to the integer value. 
; Leading spaces are ignored.
; Receives: nothing
; Returns:
;  If the integer is blank, EAX=0 and CF=1
;  If the integer contains only spaces, EAX=0 and CF=1
;  If the integer is larger than 2^32-1, EAX=0 and CF=1
;  Otherwise, EAX=converted integer, and CF=0
;--------------------------------------------------------
ReadDec:
         push      edx                 ; save edx
         push      ecx                 ; save ecx
         mov       edx, digitBuffer    ; address of buffer
         mov       ecx, MAX_DIGITS     ; read up to 80 bytes
         call      ReadString          ; read 'em in
         mov       ecx, eax            ; save length
         call      ParseDecimal32      ; returns EAX
         pop       ecx                 ; restore ecx
         pop       edx                 ; restore edx
         ret
;--------------- End of ReadDec ------------------------

;--------------------------------------------------------
;
; Reads a 64-bit IEEE floating point value in, and places it on the
; top of the floating point stack.  This is pulled off by using the 
; C library atof() function to make life simple.                      
; Receives: nothing
; Returns:
;  If the value is blank, ZF=1
;  Otherwise, ST(0)=converted value, ZF=0
;--------------------------------------------------------
ReadFloat:
         pushad                        ; save registers
         mov       ecx, MAX_DIGITS     ; read up to 80 bytes
         mov       edx, digitBuffer    ; address of buffer
         call      ReadString          ; read in string
         mov       ebp, esp            ; save esp
         sub       esp, 16             ; round stack size up to x16
         and       esp, 0fffffff0h     ; 16 byte boundary
         sub       esp, 12             ; library alignment
         push      dword digitBuffer   ; address of ascii number
         call      atof                ; call atof() to convert to binary
         mov       esp, ebp            ; restore stack
         popad                         ; restore regs
         ret
;--------------- End of ReadDec ------------------------

;--------------------------------------------------------
;
; Reads a 32-bit hexadecimal integer from the keyboard,
; stopping when the Enter key is pressed.
; Receives: nothing
; Returns: EAX = binary integer value
; Returns:
;  If the integer is blank, EAX=0 and CF=1
;  If the integer contains only spaces, EAX=0 and CF=1
;  Otherwise, EAX=converted integer, and CF=0

; Remarks: No error checking performed for bad digits
; or excess digits.
;--------------------------------------------------------
segment  .data
; in following table, -1=illegal, -2=skip, otherwise value of digit
xlat_in  db        99,-1,-1,-1,-1,-1,-1,-1, -1,-1,-1,-1,-1,-1,-1,-1 ;00-0f
         db        -1,-1,-1,-1,-1,-1,-1,-1, -1,-1,-1,-1,-1,-1,-1,-1 ;10-1f
         db        -2,-1,-1,-1,-1,-1,-1,-1, -1,-1,-1,-1,-1,-1,-1,-1 ;20-2f
         db         0, 1, 2, 3, 4, 5, 6, 7,  8, 9,-1,-1,-1,-1,-1,-1 ;30-3f
         db        -1,10,11,12,13,14,15,-1, -1,-1,-1,-1,-1,-1,-1,-1 ;40-4f
         db        -1,-1,-1,-1,-1,-1,-1,-1, -1,-1,-1,-1,-1,-1,-1,-1 ;50-5f
         db        -1,10,11,12,13,14,15,-1, -1,-1,-1,-1,-1,-1,-1,-1 ;60-6f
         db        -1,-1,-1,-1,-1,-1,-1,-1, -1,-1,-1,-1,-1,-1,-1,-1 ;70-7f
segment .text
ReadHex:
         push      ebx                 ; save ebx
         push      ecx                 ; save ecx
         push      edx                 ; save edx
         push      esi                 ; save esi
         mov       edx, digitBuffer    ; address of buffer
         mov       ecx, MAX_DIGITS     ; bytes to read (max)
         call      ReadString          ; input the string
         mov       esi, edx            ; save in ESI also
         mov       ecx, eax            ; save length in ECX
         cmp       ecx, 0              ; greater than zero?
         jne       hexcvt              ; yes: continue
         jmp       b8                  ; no: exit with CF=1
hexcvt:  xor       edx, edx            ; converted value = 0
         mov       ebx, xlat_in        ; translate table
b5:      xor       eax, eax            ; eax = 0
         mov       al, byte [esi]      ; get character from buffer
         and       al, 7fh             ; 7 bits
         xlat                          ; translate to binary
         cmp       al, -1              ; bad digit?
         je        b8                  ; yes
         cmp       al, -2              ; space (skip)?
         jne       b5a                 ; no
         cmp       edx, 0              ; anything converted yet?
         je        b5a                 ; no, spaces still ok
         jmp       zero                ; after a digit, space terminates number
b5a:     shl       edx, 4              ; shift so we can add next digit
         add       edx, eax            ; add in converted digit
b6       inc       esi                 ; point to next digit
         loop      b5                  ; repeat, decrement counter
zero:    mov       eax, edx            ; return valid value
         clc                           ; CF=0
         jmp       b9                  ; done, clean up and exit
b8:      mov       eax, 0              ; error: return 0
         stc                           ; CF=1
b9:      pop       esi                 ; restore esi
         pop       edx                 ; restore edx
         pop       ecx                 ; restore ecx
         pop       ebx                 ; restore ebx
         ret
;--------------- End of ReadHex ------------------------

;--------------------------------------------------------
;
; Reads a 32-bit signed decimal integer from standard
; input, stopping when the Enter key is pressed.
; All valid digits occurring before a non-numeric character
; are converted to the integer value. Leading spaces are
; ignored, and an optional leading + or - sign is permitted.
; All spaces return a valid integer, value zero.

; Receives: nothing
; Returns:  If CF=0, the integer is valid, and EAX = binary value.
;           If CF=1, the integer is invalid and EAX = 0.
;--------------------------------------------------------
ReadInt:
         push      ecx                 ; save ecx
         push      edx                 ; save edx
         mov       edx, digitBuffer    ; buffer address
         mov       ecx, MAX_DIGITS     ; byte count
         call      ReadString          ; read string of characters
         mov       ecx, eax            ; save length in ECX
         call      ParseInteger32      ; returns EAX, CF
         pop       edx                 ; restore edx
         pop       ecx                 ; restore ecx
         ret
;--------------- End of ReadInt ------------------------

;--------------------------------------------------------
;
; Reads a string from the keyboard and places the characters
; in a buffer.
;
; We do make sure to add a NULL on the end of the input we read, and we strip
; off the CR/LF pair if either is present.
;
; Receives: EDX offset of the input buffer
;           ECX = maximum characters to input (including terminal null)
; Returns:  EAX = size of the input string.
;----------------------------------------------------------
ReadString:
         push      ebx                 ; save ebx
         push      ecx                 ; save ecx
         push      edx                 ; save edx
         push      esi                 ; save esi
         push      edx                 ; save buffer address
         mov       ebp, esp            ; save esp
         sub       esp, 16             ; round stack size up to x16
         and       esp, 0fffffff0h     ; 16 byte boundary
         sub       esp, 4              ; library alignment
         push      ecx                 ; push byte count for _read()
         push      edx                 ; push buffer address for _read()
         mov       eax, 1              ; push stdin fd (1)
         push      eax                 ; for _read()
         call      read                ; reads n bytes (ecx) into buffer (edx)
         mov       esp, ebp            ; restore stack
         pop       edx                 ; recover buffer address for following
         mov       byte [edx + eax], 0 ; add trailing zero
         mov       ecx, eax            ; characters read
         mov       esi, edx            ; address of buffer
rcloop:  cmp       byte [esi], 0ah     ; linefeed?
         jne       rcskip              ; no
         mov       byte [esi], 0       ; yes, replace with NULL
         dec       eax                 ; ignore the zero that replaced LF
rcskip:  inc       esi                 ; next character
         loop      rcloop              ; check entire buffer
         pop       esi                 ; restore esi
         pop       edx                 ; restore edx
         pop       ecx                 ; restore ecx
         pop       ebx                 ; restore ebx
         ret
;--------------- End of ReadString ----------------------

;------------------------------------------------------
;
; Writes a 32-bit integer to the console window in
; binary format. Converted to a shell that calls the
; WriteBinB procedure, to be compatible with the
; library documentation in Chapter 5.
; Receives: EAX = the integer to write
; Returns: nothing
;------------------------------------------------------
WriteBin:
         push      ebx                 ; save register
         mov       ebx, 4              ; select doubleword format
         call      WriteBinB           ; then call WriteBinB
         pop       ebx                 ; restore register
         ret
;--------------- End of WriteBin --------------------

;------------------------------------------------------
;
; Writes a 32-bit integer to the console window in
; binary format.
; Receives: EAX = the integer to write
;           EBX = display size (1,2,4)
; Returns: nothing
;------------------------------------------------------
WriteBinB:
         pushad                        ; save registers
         cmp       ebx, 1              ; is ebx 1?
         jz        wb0                 ; yes
         cmp       ebx, 2              ; is ebx 2?
         jz        wb0                 ; yes
         mov       ebx, 4              ; then force it to 4
wb0:     mov       ecx, ebx            ; save count
         shl       ecx, 1              ; number of 4-bit groups in EAX
         cmp       ebx, 4              ; 4 byte reg?
         je        wb0a                ; yes
         ror       eax, 8              ; assume 1 byte regand ROR byte
         cmp       ebx, 1              ; test assumption
         je        wb0a                ; correct
         ror       eax, 8              ; TYPE==2 so ROR another byte
wb0a:    mov       esi, buffer         ; address of buffer
wb1:     push      ecx                 ; save loop count
         mov       ecx, 4              ; 4 bits in each group
wb1a:    shl       eax, 1              ; shift EAX left into Carry flag
         mov       byte [esi], '0'     ; choose '0' as default digit
         jnc       wb2                 ; if carry = 0, then jump to L2
         mov       byte [esi], '1'     ; else move '1' to DL
wb2:     inc       esi                 ; next byte in buffer
         loop      wb1a                ; go to next bit within group
         mov       byte [esi], ' '     ; insert a blank space
         inc       esi                 ; between groups
         pop       ecx                 ; restore outer loop count
         loop      wb1                 ; begin next 4-bit group
         dec       esi                 ; eliminate the trailing space
         mov       byte [esi], 0       ; insert null byte at end
         mov       edx, buffer         ; address of buffer
         call      WriteString         ; call WriteString to display
         popad                         ; restore registers
         ret
;--------------- End of WriteBinB --------------------
         
;------------------------------------------------------
;
; Write a character to the console window
; Recevies: AL = character
;------------------------------------------------------
WriteChar:
         pushad                        ; save registers
         mov       [buffer], al        ; move character to buffer
         mov       edx, buffer         ; address of buffer
         mov       ecx, 1              ; byte count
         call      WriteString         ; write the character
         popad                         ; restore registers
         ret
;--------------- End of WriteChar --------------------
         
;-----------------------------------------------------
;
; Writes an unsigned 32-bit decimal number to
; the console window. 
; Input parameters: EAX = the number to write.
;------------------------------------------------------
segment  .data
; There will be as many as 10 digits.
bufferL: db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
segment  .text
WriteDec: 
         pushad                        ; save registers
         mov       ecx, 0              ; digit counter
         mov       edi, bufferL        ; address of buffer
         add       edi, 11             ; buffer len - 1
         mov       ebx, 10             ; decimal number base
wd1:     mov       edx, 0              ; clear dividend to zero
         div       ebx                 ; divide EAX by the radix
         xchg      eax, edx            ; swap quotient, remainder
         or        al, 30h             ; convert AL to ASCII
         mov       byte [edi], al      ; save the digit
         dec       edi                 ; back up in buffer
         xchg      eax, edx            ; swap quotient, remainder
         inc       ecx                 ; increment digit count
         or        eax, eax            ; quotient = 0?
         jnz       wd1                 ; no, divide again
                                       ; Display the digits (CX = count)
         inc       edi                 ; edi off by one, correct
         mov       edx, edi            ; buffer address
         call      WriteString         ; call WriteString
         popad                         ; restore registers
         ret
;--------------- End of WriteDec ---------------------

;--------------------------------------------------------
;
; Writes a 64-bit IEEE floating point value using the value on the top
; of the floating point stack.  This is pulled off by using a simple
; trick.  We convert the whole part of the number to a simple character
; format...                            
; Returns: nothing
;--------------------------------------------------------
WriteFloat:
         pushad                        ; save registers
         call      ftoa                ; convert top of fp stack to ascii
         mov       ecx, 11             ; chars to check
         mov       edx, fpbuff         ; address of buffer
wf1:     cmp       byte [edx], ' '     ; this a blank?
         jne       wf2                 ; nope, done
         inc       edx                 ; next char
         loop      wf1                 ; loop until first non-blank
wf2:     call      WriteString         ; display whole part
         popad                         ; restore regs
         ret
;--------------- End of WriteFloat ------------------------

;------------------------------------------------------
;
; Writes an unsigned 32-bit hexadecimal number to
; the console window.
; Receives: EAX = the number to write. 
; Returns: nothing
;------------------------------------------------------
segment .data
hb       db        0, 0, 0, 0, 0, 0, 0, 0, 0
segment .text
WriteHex:
WriteHexB:
         pushad                        ; save registers
         mov       ecx, 8              ; number of characters to print
         mov       ebx, 16             ; hexadecimal base (divisor)
wh1:     mov       edx, 0              ; clear upper dividend
         div       ebx                 ; divide EAX by the base
         xchg      eax, edx            ; swap quotient, remainder
         call      AsciiDigit          ; convert AL to ASCII
         mov       byte [hb - 1 + ecx], al ; save the digit
         xchg      eax, edx            ; swap quotient, remainder
         loop      wh1                 ; output 8 digits
         mov       edx, hb             ; buffer address
         call      WriteString         ; write the string
         popad                         ; restore registers
         ret
;--------------- End of WriteHex ---------------------

;-----------------------------------------------------
;
; Writes a 32-bit signed binary integer to the console window
; in ASCII decimal.
; Receives: EAX = the integer
; Returns:  nothing
; Comments: Displays a leading sign, no leading zeros.
;-----------------------------------------------------
segment  .data
buffer_B db        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 
minus    db        0

segment .text
WriteInt:
         pushad                        ; save registers
         mov       byte [minus], 0     ; assume minus is false
         or        eax, eax            ; is AX positive?
         jns       wi1                 ; yes: jump to B1
         neg       eax                 ; no: make it positive
         mov       byte [minus], 1     ; set minus to true
wi1:     mov       ecx, 0              ; digit count = 0
         mov       edi, buffer_B       ; buffer address
         add       edi, 11             ; max size - 1
         mov       ebx, 10             ; will divide by 10
wi2:     mov       edx, 0              ; set dividend to 0
         div       ebx                 ; divide AX by 10
         or        dl, 30h             ; convert remainder to ASCII
         dec       edi                 ; reverse through the buffer
         mov       byte [edi], dl      ; store ASCII digit
         inc       ecx                 ; increment digit count
         or        eax, eax            ; quotient > 0?
         jnz       wi2                 ; yes: divide again
         dec       edi                 ; back up in the buffer
         inc       ecx                 ; increment counter
         mov       byte [edi], '+'     ; insert plus sign
         cmp       byte [minus], 0     ; was the number positive?
         jz        wis3                ; yes
         mov       byte [edi], '-'     ; no: insert negative sign
wis3:    mov       edx, edi            ; buffer address
         call      WriteString         ; call WriteString
         popad                         ; restore registers
         ret                           ; return
;--------------- End of WriteInt ---------------------

;--------------------------------------------------------
;
; Writes a null-terminated string to standard
; output. 
; Input parameter: EDX points to the string.
; uses standard unix write() proc, rather than the ugly int 80
; stuff the original Along32 file relied on, since int 80 is not
; compatible across different flavors of Unix (Linux / OS/X for two
; incompatible examples.)  We need to place three parameters on
; the stack to match the read call format:
;
;     write(fd, buffer, len)
;
; We can safely assume stdout (fd=1).  Buffer is passed to us
; via EDX, and we use the strlen procedure to count the number
; of characters.
; 
; WARNING:  write() uses some stuff that requires a specific stack
; alignment.  If you add code here, using push/pop, make certain you
; push/pop multiples of 16 bytes or write() will promptly crash.
; The code below carefully aligns the stack exactly as required by
; write().
;
;--------------------------------------------------------
WriteString:
         pushad                        ; save registers
         call      strlen              ; return length of string in EAX
         mov       ebp, esp            ; save esp
         sub       esp, 16             ; round stack size up to x16
         and       esp, 0fffffff0h     ; 16 byte boundary
         sub       esp, 4              ; library alignment
         push      eax                 ; byte count as returned by strlen
         push      edx                 ; buffer address from edx
         mov       eax, 1              ; stdout = 1
         push      eax                 ; add to argument list
         call      write               ; call standard library write() code
         mov       esp, ebp            ; restore stack pointer
         popad                         ; restore registers
         ret                           
;--------------- End of WriteString ---------------------

;*************************************************************
;*                    PRIVATE PROCEDURES                     *
;*************************************************************

segment  .data
xlat_out db        30h,31h,32h,33h,34h,35h,36h,37h
         db        38h,39h,41h,42h,43h,44h,45h,46h ;00-0f
segment  .text
;--------------------------------------------------------
;
; Convert AL to an ASCII digit. Used by WriteHex & WriteDec
;--------------------------------------------------------
AsciiDigit:
         push      ebx                 ; save register
         mov       ebx, xlat_out       ; address of xlat table
         xlat                          ; convert to ascii
         pop       ebx                 ; restore register
         ret
;---------------- End of AsciiDigit ---------------------

;--------------------------------------------------------
;
; Display the byte in AL in hexadecimal
;--------------------------------------------------------
HexByte:
         pushad                        ; save registers
         mov       dl, al              ; save value
         rol       dl, 4               ; get high order 4 bits to low-order
         mov       al, dl              ; back to al for xlat
         and       al, 0Fh             ; scrub all but 4 LSB's
         mov       ebx, xlat_out       ; address of xlat table
         xlat                          ; convert to ascii
         mov       byte [buffer], al   ; save first char
         rol       dl, 4               ; now get low order 4 bits back
         mov       al, dl              ; back to al for xlat
         and       al, 0Fh             ; scrub all but 4 LSB's
         xlat                          ; convert to ascii
         mov       byte [buffer+1], al ; save second char
         mov       byte [buffer+2], 0  ; null byte
         mov       edx, buffer         ; display the buffer
         call      WriteString         ; write the buffer
         popad                         ; restore registers
         ret
;------------------ End of HexByte ---------------------

;--------------------------------------------------------
;
; converts a 32 bit IEEE floating point value, using the value on the 
; top of the floating point stack.  This is pulled off by using a simple
; trick.  We convert the whole part of the number to a simple character
; format.  We leave the result in fpbuff, where the caller can print it
; out in the short form or the aligned form.
; Returns: nothing
;--------------------------------------------------------
segment  .data
fpwhole  dd        0
fpbuff   db        "         ."
fpfrac   db        "   ", 0
ten      dd        10
cw       dw        0
limit    dd        10000000.0
segment  .text
ftoa:
         pushad                        ; save registers
         fsave     [fpstate]           ; save fp state
         frstor    [fpstate]           ; restore fp state (save destroyed it)
         mov       ebp, esp            ; save esp
         fld       dword [limit]       ; upper bound on simple output
         fcomi     st0, st1            ; compare to see if number too large
         fstp      dword [fpwhole]     ; remove bound
         ja        ftoa0               ; jump if standard format will work
         jmp       eformat             ; else jump to e-format code
ftoa0:   mov       edi, fpbuff         ; address of buffer
         mov       ecx, 9              ; 9 spaces
ftoa1:   mov       byte[edi], ' '      ; blank first part of number
         inc       edi                 ; next character
         loop      ftoa1               ; blank them all
         mov       edi, fpfrac         ; address of buffer
         mov       ecx, 3              ; 3 spaces
ftoa2:   mov       byte[edi], ' '      ; blank fraction part of number
         inc       edi                 ; next character
         loop      ftoa2               ; blank them all
         fstcw     word [cw]           ; save current fp control word
         or        word [cw], 0c00h    ; truncate on fist
         fldcw     word [cw]           ; back to fp hardware
         mov       byte [minus], 0     ; assume minus is false
         fst       dword [fptemp]      ; save fp value
         mov       ecx, [fptemp]       ; get IEEE number (binary)
         test      ecx, 80000000h      ; test sign bit
         jz        ftoa3               ; number is positive
         mov       byte [minus], 1     ; set minus to true
         fabs                          ; make number positive
ftoa3:   fist      dword [fpwhole]     ; store whole part, no rounding
         mov       eax, dword [fpwhole]; get whole part into eax
         mov       ecx, 0              ; digit count = 0
         mov       edi, fpbuff + 9     ; buffer address
         mov       ebx, 10             ; will divide by 10
ftoa4:   mov       edx, 0              ; set dividend to 0
         div       ebx                 ; divide EAX by 10
         or        dl, 30h             ; convert remainder to ASCII
         dec       edi                 ; reverse through the buffer
         mov       byte [edi], dl      ; store ASCII digit
         inc       ecx                 ; increment digit count
         or        eax, eax            ; quotient > 0?
         jnz       ftoa4               ; yes: divide again
         dec       edi                 ; back up in the buffer
         inc       ecx                 ; increment counter
         mov       byte [edi], '+'     ; insert plus sign
         cmp       byte [minus], 0     ; was the number positive?
         jz        ftoa5               ; yes
         mov       byte [edi], '-'     ; no: insert negative sign
ftoa5:   mov       edi, fpfrac         ; address of fraction buffer
         mov       ecx, 3              ; only print 3 digits to right of .
         fisub     dword [fpwhole]     ; leave just fractional digits
         fabs                          ; make entire value positive
ftoa6:   fimul     dword [ten]         ; extract leftmost fractional digit
         fist      dword [fpwhole]     ; store it
         fisub     dword [fpwhole]     ; remove it for next pass
         mov       eax, dword [fpwhole]; into eax
         or        al, 30h             ; convert to ascii
         mov       byte [edi], al      ; store into buffer
         inc       edi                 ; next character in buffer
         loop      ftoa6               ; and repeat again
         frstor    [fpstate]           ; restore fp stack
         popad                         ; restore regs
         ret
eformat:
         fst       dword [fptemp]      ; save the 32 bit hex value
         mov       esp, ebp            ; restore stack
         frstor    [fpstate]           ; restore fp stack
         popad
         ret
          
;--------------- End of ftoa ------------------------------
