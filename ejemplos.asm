; -------------------------------------------------------------------------------------------------------------------------------

; operaciones simples

JE jump if zero
JNGE jump if negative


;dividir r13 por 3

mov ecx, 3
mov rax, r13
xor rdx, rdx ;hay que limpiar esto
div ecx ; div por 3
mov r13, rax

; igual para mul


; -------------------------------------------------------------------------------------------------------------------------------


; syscall - SYS_WRITE (print)

%define SYS_WRITE 1

section .data
msg db 'Maximiliano Fisz 586/19',0xa, 'Gaspar Onesto De Luca 711/22', 0xa, 'Victoria Rauch 1181/21', 0xa, 'hola mundo!!!!!!!!!!'
len equ $ - msg

.section text
mov rdx, len
mov rsi, msg
mov rdi, 1
mov rax, SYS_WRITE
syscall

; -------------------------------------------------------------------------------------------------------------------------------

; ejemplo de prologo y epilogo, tambien de registros y memoria

; uint32_t alternate_sum_8(uint32_t x1, uint32_t x2, uint32_t x3, uint32_t x4, uint32_t x5, uint32_t x6, uint32_t x7, uint32_t x8);
; registros y pila: x1[rdi], x2[rsi], x3[rdx], x4[rcx], x5[r8], x6[r9], x7[rbp+0x10], x8[rbp+0x18]
alternate_sum_8:
	;prologo
	push rbp ; alineado a 16
	mov rbp,rsp
	; COMPLETAR

	sub rdi, rsi
	add rdi, rdx
	sub rdi, rcx
	add rdi, r8
	sub rdi, r9
	add rdi, [rbp+0x10]
	sub rdi, [rbp+0x18]

	mov rax, rdi
	;epilogo
	pop rbp
	ret

; -------------------------------------------------------------------------------------------------------------------------------

; ejemplo usar una funcion de C que toma dos parametros, a y breakpoint

mov rdi, rax
mov rsi, rdx
call sumar_c


; -------------------------------------------------------------------------------------------------------------------------------

; ejemplo convertir de entero a float y viceversa, y convertir de float a double

; int to float to int
cvtsi2ss xmm1, rsi
; do smt with xmm1 and save in xmm0
cvttss2si rax, xmm0

; float into double
cvtss2sd xmm0, xmm0


; -------------------------------------------------------------------------------------------------------------------------------

; structs y offsets
; dado los siguientes structs en C
;typedef struct nodo_s {
;    struct nodo_s* next;   // Siguiente elemento de la lista o NULL si es el final
;    uint8_t categoria;     // Categoría del nodo
;    uint32_t* arreglo;     // Arreglo de enteros
;    uint32_t longitud;     // Longitud del arreglo
;} nodo_t;

;typedef struct __attribute__((__packed__)) packed_nodo_s {
;    struct packed_nodo_s* next;   // Siguiente elemento de la lista o NULL si es el final
;    uint8_t categoria;     // Categoría del nodo
;    uint32_t* arreglo;     // Arreglo de enteros
;    uint32_t longitud;     // Longitud del arreglo
;} packed_nodo_t;

; tenemos estos offsets y mem allocs

;NODO_LENGTH	EQU	28
;LONGITUD_OFFSET	EQU	24

;PACKED_NODO_LENGTH	EQU	21
;PACKED_LONGITUD_OFFSET	EQU	17


; -------------------------------------------------------------------------------------------------------------------------------

; STRINGS

; uint32_t strLen(char* a)
strLen:
	push rbp ; alineado a 16
	mov rbp,rsp

	mov rsi, 0 ; contador Y offset ja!
	
	restart:
	cmp byte [rdi + rsi], 0 ; comparar si en una direccion esta el terminador
	je salida

	add rsi, 1 
	jmp restart

	salida:
	mov rax, rsi
	pop rbp
	ret

; char* strClone(char* a)
strClone:
	push rbp ; alineado a 16
	mov rbp,rsp

	mov r12, rdi ; guardamos el input
	mov rsi, 0 ; contador y offset
	
	clone_loop_length:
	cmp byte [r12 + rsi], 0x00 ; comparar si en una direccion esta el terminador
	je clone_malloc_call

	add rsi, 1 
	jmp clone_loop_length

	clone_malloc_call:
	inc rsi ; lugar para el terminador
	mov rdi, rsi ; preparamos la longitud para malloc
	mov r15, rsi ; guardamos la longitud en algo no volatil
	call malloc

	mov r14, r15 ; guardamos la longitud
	mov r13, rax ; guardamos el dest de malloc
	mov rsi, 0 ; reiniciamos el contador

	clone_assign:
	cmp r14, rsi ; si el iterador y longitud son iguales nos vamos
	je clone_salida

	mov r15b, [r12 + rsi] ; guardamos la primer letra en algun lado
	mov [r13 + rsi], r15b ; la ponemos en el espacio donde nos dejo malloc

	inc rsi
	jmp clone_assign


	clone_salida:
	mov rax, r13
	pop rbp
	ret


; -------------------------------------------------------------------------------------------------------------------------------


; SIMD

; MASCARAS!!!!

mascaraIguales: db 0x00, 0x00, 0x00, 0x00, 0x04, 0x04, 0x04, 0x04, 0x08, 0x08, 0x08, 0x08, 0x0C, 0x0C, 0x0C, 0x0C ; dado paquetes de bytes, pone el primero de cada 4 en los 3 siguientes: AAAABBBBCCCCDDDD

mascaraPrimerBit: times 4 dd 1; pone en 0 todos los bits de una dword excepto el primero, transformas quiza 1111111111 en 000000001 , util para sumar resultados de cmp en simd y evitar overflow, usando un pand

mascaraValor: times 16 db 00001111b ; para convertir sets de 4 bits impares en 0000. Dado paquetes de bytes, les pone su segunda parte en ceros con un pand

; dado un struct de un pixel que se ve asi:
;typedef struct pixe_s {
;    uint8_t blue;
;    uint8_t green;  
;    uint8_t red;  
;    uint8_t alpha;
;} pixel_t;
; Unas mascaras para modificar sus valores correcteramente son (notar la inversion del struct y la definicion de la mascara):
pxnegros: times 4 dd 11111111_00000000_00000000_00000000b ; el primer octeto mantiene el alpha en 255 y el resto en 0
pxblancos: times 4 dd 11111111_11111111_11111111_11111111b ; todo en 255

; si quisieramos poner en 00000s el alpa y mantener el valor del resto de propiedades:

mascaraMataAlpha: times 2 dd 00000000_11111111_11111111_11111111b ; deja pasar los valores de rgb de un pixel y pone en 0 el alpha. 2 pixeles a la vez

; Ejemplos de operaciones

; sumar 4 numeros de 32 bits entre si en un registro de 128:
PHADDD xmm0, xmm0; 
PHADDD xmm0, xmm0; 


; quiero crear la mascara AAAABBBBCCCCDDDD, con datos AxxxBxxxCxxxDxxx en xmm0
movdqu xmm1, xmm0 ; hago una copia para el shuffle y crear la mascara
movdqu xmm8, [mascaraIguales] ; cargo la mascara de valores iguales, debug
pshufb xmm1, xmm8 ; creo la mascara completa, con el patron de xmm8 y los valores de xmm1 (los originales de xmm0)

; cmps
pcmpeqd xmm0, xmm1 ; comparo dos registros dword a dword. achtung, si son iguales, me deja lleno de 111111111s el dword resultado

; Quiero cambiar un miserable byte que tengo en r15 y ponerlo en la 4ta posicion de xmm2
pinsrb xmm2, r15b, 00000011b ; le pongo la variable donde va


; -------------------------------------------------------------------------------------------------------------------------------
; -------------------------------------------------------------------------------------------------------------------------------
; -------------------------------------------------------------------------------------------------------------------------------
; -------------------------------------------------------------------------------------------------------------------------------
; -------------------------------------------------------------------------------------------------------------------------------
; -------------------------------------------------------------------------------------------------------------------------------