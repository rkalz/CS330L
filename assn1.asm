; Rofael Aleezada
; 1 September 2017
; v1
;
; Number mainpulation
; CS330L Assignment 1
;

%include "along32.inc"

global _start
section .data
	prompt1 db "Enter the first number: ", 0
	prompt2 db "Enter the second number: ", 0
	prompterr db "Error: The numbers are the same. Exiting.", 0
	promptsol db "The solution is ", 0
	promptex db "Exiting... ", 0 

	a dq 0
	b dq 0
	c dq 0 ; a+b
	d dq 0 ; a-b
	e dq 0 ; a*b
	f dq 0 ; c/d
	g dq 0 ; e-f

section .text

_start:
	; your code goes here

	; Get value for a
	mov edx, prompt1
	call WriteString
	call ReadInt
	mov [a], eax
	call Crlf
	
	; Get value for b
	mov edx, prompt2
	call WriteString
	call ReadInt
	mov [b], eax
	call Crlf
	
	; Terminate if a and b are the same
	mov eax, [a]
	mov ebx, [b]
	cmp eax, ebx
	je is_same

	; Add a to b to get c
	mov eax, [a]
	mov ebx, [b]
	add eax, ebx
	mov [c], eax

	; Subtract b from a to get d
	mov eax, [a]
	mov ebx, [b]
	sub eax, ebx
	mov [d], eax

	; Multiply a by b to get e
	mov eax, [a]
	mov ebx, [b]
	imul eax, ebx
	mov [e], eax

	; Divide c by d to get f
	mov eax, [c]
	mov ebx, [d]
	xor edx, edx
	cdq
	idiv ebx
	mov [f], eax

	; Subtract f from e to get g
	mov eax, [e]
	mov ebx, [f]
	sub eax, ebx
	mov [g], eax

	; Display value of g as solution
	mov edx, promptsol
	call WriteString
	mov edx, [g]
	call WriteInt
	call Crlf
	jmp exit

is_same:
	mov edx, prompterr
	call WriteString
	call Crlf
	jmp exit

exit:
	mov edx, promptex
	call WriteString
	call Crlf
	mov eax, 01h 	; exitC)
	mov ebx, 0h 	; errno

	int 80h

