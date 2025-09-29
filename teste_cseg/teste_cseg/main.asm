
.org 0x00

.def idx   = r20
.def zero = r1
.def tmp = r19

rjmp RESET 

; SETAR OS PINOS DOS SEMAFOROS COMO SAIDA
	


RESET:
	ldi tmp, 255 ; 0b1111111 - constante para setar os pinos como saida
	out  DDRB,tmp		
	out  DDRC,tmp	
	out  DDRD,tmp

	ldi idx, 0

loop:
	mov tmp, idx
    lsl tmp  

	ldi ZL, low(estado*2)     
    ldi ZH, high(estado*2)   

    add ZL, tmp
    adc ZH, zero   

	lpm r16, Z+ 
	out PORTB,r16

	lpm r18, Z
	out PORTC,r18



	ldi ZL, low(counter*2)      ; Z low
    ldi ZH, high(counter*2) 

	add ZL, tmp
    adc ZH, zero   

	lpm r16, Z+ 
	out PORTD,r16

	lpm r16, Z 
	out PORTD,r16

	inc idx
	rjmp loop


counter: ; unidades dezenas
    .db 1, 0 
    .db 0, 4  
    .db 2, 3  
    .db 0, 4  
	.db 2, 0 
	.db 0, 3
	.db 2, 1
	.db 0, 1
	.db 0, 3
	.db 0, 1


estado:
	  .dw 0x0C0C
	  .dw 0x140C ; 0x140C (este eh o verdadeiro)
	  .dw 0x240C
	  .dw 0x2414
	  .dw 0x2424
	  .dw 0x2124
	  .dw 0x2121
	  .dw 0x2122
	  .dw 0x2222
	  .dw 0x220C


