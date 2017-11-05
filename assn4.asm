; Rofael ALeezada
; 27 October 2017
; v1 - Implemented program
;
; Assignment 4
; Read in N (<= 100) integers and print then sorted
;

%include "along32.inc"

global _start
section .data
  prompt_input db "Enter a number: ", 0
  prompt_exit db "Exiting...", 0
  space db " ", 0

  array times 100 dq 0                     ; array
  count dq 0                               ; Length of array
  i dq 0
  j dq 0

section .text

_start:
  jmp read

read:
  mov eax, [count]        ; If we've added 100 things, we're done
  cmp eax, 100
  je sort

  mov edx, prompt_input
  call WriteString
  call ReadInt
  cmp eax, 0
  je sort
  jne append

append:
  ; eax: The number to be inserted
  ; ebx: The count of numbers inserted
  ; ecx: The pointer to where the number will be inserted
  mov ebx, [count]
  mov ecx, ebx
  imul ecx, 8              ; Get pointer to the start of position count
  mov [array + ecx], eax
  inc ebx                  ; increment count
  mov [count], ebx
  jmp read

sort:
  ; eax: Stores i
  ; ebx: Stores number of things in array
  mov eax, [i]             ; Check if i < count - 1
  mov ebx, [count]         ; True: move to sort
  dec ebx                  ; False: end sort
  cmp eax, ebx
  jl sub_sort
  jge end_sort

sub_sort:
  ; eax: First stores i, then the memory position of array[j]
  ; ebx: First stores count, then the memory position of array[j+1]
  ; ecx: First stores k, then the number at position array[j]
  ; edx: Stores the number at posittion array[j+1]
  mov eax, [i]             ; Check if j < count - i - 1
  mov ebx, [count]         ; True: continue
  mov ecx, [j]             ; False: increment i and reset j
  sub ebx, eax
  dec ebx
  cmp ecx, ebx
  jge inc_i

  mov eax, [j]             ; Get memory locations of j and j + 1
  mov ebx, eax
  inc ebx
  imul eax, 8
  imul ebx, 8

  mov ecx, [array + eax]   ; Get values at j and j + 1
  mov edx, [array + ebx]

  cmp ecx, edx
  jle inc_j                ; if a[j] <= a[j + 1], no need to swap

  mov [array + eax], edx   ; swap values
  mov [array + ebx], ecx
  jmp inc_j

inc_j:
  ; edx: Stores j
  mov edx, [j]
  inc edx
  mov [j], edx
  jmp sub_sort

inc_i:
  ; edx: Stores j then i
  mov edx, 0                ; Reset j
  mov [j], edx

  mov edx, [i]
  inc edx
  mov [i], edx
  jmp sort

end_sort:
  ; ebx: Reset to use as counter for last printed index
  mov ebx, 0
  jmp print

print:
  ; eax: The number to be printed
  ; ebx: The last printed index
  ; ecx: The pointer to the number to be printed
  mov edx, [count]         ; If ebx is equal to count, we've printed all numbers
  cmp edx, ebx
  je exit

  mov ecx, ebx             ; Get pointer to index, move value to eax
  imul ecx, 8
  mov eax, [array + ecx]
  mov edx, space
  call WriteInt            ; print number and a space
  call WriteString

  inc ebx
  jmp print

exit:
  call Crlf
  mov edx, prompt_exit
  call WriteString
  call Crlf

	mov eax, 01h
	mov ebx, 0h

	int 80h
