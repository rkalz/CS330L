; Rofael Aleezada
; 22 September 2017
; v1
;
; Assignment 2
; Find the average of an arbitrary amount of numbers
;

%include "along32.inc"

global _start
section .data
	promptInput db "Enter a number: ", 0
	solOutput db "The average is: ", 0
	exitOutput db "Exiting...", 0

	sum dq 0
	ct dq 0
section .text

_start:
	jmp readIn
	
	jmp ext	
readIn:
	mov edx, promptInput
	call WriteString
	call ReadInt
	call Crlf

	cmp eax, 0
	je getAvg
	jne addAvg

addAvg:
	mov ebx, [sum]
	add ebx, eax
	mov [sum], ebx
	
	xor eax,eax
	
	mov eax, [ct]
	add eax, 1
	mov [ct], eax
	
	jmp readIn
	
getAvg:
	mov eax, [sum]
	mov ebx, [ct]
	cmp ebx, 0
	je noInput
	
	xor edx,edx
	cdq
	idiv ebx
	
	mov edx, solOutput
	call WriteString
	mov edx, eax
	call WriteInt
	call Crlf
	jmp ext

noInput:
	mov edx, solOutput
	call WriteString
	mov edx, 0
	call WriteInt
	call Crlf
	jmp ext

ext:
	mov edx, exitOutput
	call WriteString
	call Crlf
	mov eax, 01h 	; exitC)
	mov ebx, 0h 	; errno

	int 80h


