; Rofael Aleezada
; 10 November 2017
; v1 - Implemented program
;
; Assignment 5
; Quadratic formula solver
;

%include "along32.inc"

global _start
section .data
  prompt_intro db "Quadratic Formula Solver!", 0
  prompt_a db "Enter a: ", 0
  prompt_b db "Enter b: ", 0
  prompt_c db "Enter c: ", 0
  prompt_one_sol db "The solution is ", 0
  prompt_mul_sols db "The solutions are ", 0
  prompt_and db " and ", 0
  prompt_img_sols db "There are imaginary solutions. Cannot solve.", 0
  prompt_period db ".", 0
  prompt_exit db "Exiting...", 0

  FOUR dq 4.0
  TWO dq 2.0

  a dq 0
  b dq 0
  c dq 0

  pos dq 0
  ngs dq 0

  void dq 0

section .text

_start:
  ; Load a, b, c into memory
  mov edx, prompt_intro
  call WriteString
  call Crlf

  mov edx, prompt_a
  call WriteString
  call ReadFloat
  fstp qword [a]

  mov edx, prompt_b
  call WriteString
  call ReadFloat
  fstp qword [b]

  mov edx, prompt_c
  call WriteString
  call ReadFloat
  fstp qword [c]

  jmp solve

solve:
  ; load 4, a, c
  fld qword [c]
  fld qword [a]
  fld qword [FOUR]

  ; multiply 4 by a and c
  fmul st1
  fmul st2
  ; swap and pop a
  fxch st1
  fstp qword [void]
  ; swap and pop c
  fxch st1
  fstp qword [void]

  ; load b, multiply by self
  fld qword [b]
  fmul st0
  ; subtract 4ac from b^2, pop 4ac
  fsub st1
  fxch st1
  fstp qword [void]

  ; check if b^2 - 4ac is less than zero
  ; load determinant, take absolute value, check if same
  ; if not, is imaginary
  ; if same, take square root
  fld st0
  fabs
  fcomip st1
  jne imag
  fsqrt

  ; push b and negate
  fld qword [b]
  fchs

  ; push a and 2, multiply, pop 2
  fld qword [a]
  fld qword [TWO]
  fmul st1
  fxch st1
  fstp qword [void]

  ; push -b, add det, divide by 2a, pop to positive
  fld st1
  fadd st3
  fdiv st1
  fstp qword [pos]

  ; repeat for negative
  fld st1
  fsub st3
  fdiv st1
  fstp qword [ngs]

  ; check if positive and negative are the same
  fld qword [ngs]
  fld qword [pos]
  fcomi st1
  je one_sol

  ; print positive and negative solutions
  mov edx, prompt_mul_sols
  call WriteString
  call WriteFloat
  fstp qword [void]

  mov edx, prompt_and
  call WriteString
  call WriteFloat

  mov edx, prompt_period
  call WriteString
  call Crlf

  jmp exit

imag:
  mov edx, prompt_img_sols
  call WriteString
  call Crlf
  jmp exit

one_sol:
  mov edx, prompt_one_sol
  call WriteString
  call WriteFloat

  mov edx, prompt_period
  call WriteString
  call Crlf
  jmp exit

exit:
  finit
  mov edx, prompt_exit
  call WriteString
  call Crlf

	mov eax, 01h
	mov ebx, 0h

	int 80h
