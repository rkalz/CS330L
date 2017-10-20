; Rofael Aleezada
; 13 October 2017
; v1 - Implemented
;
; Bit Counter
; Given a hex number, returns the number of one bits,
; The position of the least significant bit
; and the most significant bit.

%include "along32.inc"

global _start
section .data
  prompt_input db "Enter a hex number: ", 0
  prompt_one db "The total number of one bits is: ", 0
  prompt_lsb db "The least significant bit is at position ", 0
  prompt_msb db "The most significant bit is at position ", 0

  bit_count dq 0
  one_bits dq 0
  lsb dq 0
  msb dq 0

section .text

_start:
  mov edx, prompt_input
  call WriteString
  call ReadHex

  mov ebx, eax
  jmp count_bits

count_bits:
  ; eax - WriteInt writes int in here
  ; ebx - number
  ; ecx - scratch
  ; edx - WriteString writes String in here

  cmp ebx, 0           ; If num is zero, all done
  je exit

  mov ecx, [bit_count] ; Increase the bit count by 1
  inc ecx
  mov [bit_count], ecx

  mov ecx, ebx
  and ecx, 1           ; Get lowest bit
  shr ebx, 1           ; Remove lowest bit from num

  cmp ecx, 0           ; If bit was zero, move on to next one
  je count_bits

  mov ecx, [one_bits]  ; Bit was one, so we increment count of one bits
  inc ecx
  mov [one_bits], ecx

  mov ecx, [lsb]       ; If LSB has yet to be assigned, do it
  cmp ecx, 0           ; If not, bit is automatically MSB
  je assign_lsb
  jne assign_msb

assign_lsb:
  mov ecx, [bit_count] ; Set LSB to current bit count
  mov [lsb], ecx

  jmp assign_msb

assign_msb:
  mov ecx, [bit_count] ; set MSB to current bit count
  mov [msb], ecx

  jmp count_bits

exit:
  mov edx, prompt_one
  call WriteString
  mov eax, [one_bits]
  call WriteInt
  call Crlf

  mov edx, prompt_lsb
  call WriteString
  mov eax, [lsb]
  dec eax              ; Need to decrement by one since
  call WriteInt        ; position = count - 1
  call Crlf

  mov edx, prompt_msb
  call WriteString
  mov eax, [msb]
  dec eax
  call WriteInt
  call Crlf

	mov eax, 01h 	; exitC)
	mov ebx, 0h 	; errno

	int 80h
