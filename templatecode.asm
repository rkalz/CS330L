; name goes here
; date of initial writing
; revision history
;
; name of program
; purpose
;

global _start
section .data

section .text

_start:
	; your code goes here
	
	
	; last line of code
	jmp exit
	
exit:
	mov eax, 01h 	; exitC)
	mov ebx, 0h 	; errno

	int 80h

