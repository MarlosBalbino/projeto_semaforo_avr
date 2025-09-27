;
; led.asm

; ----- SETUP -----
.include "m328pdef.inc"

.cseg
.org 	0x00

jmp reset
.org OC1Aaddr
jmp OCI1A_Interrupt


OCI1A_Interrupt:
	push temp
	in temp, SREG
	push temp
	
	subi count, 1 ; contador - 1

	pop temp
	out SREG, temp
	pop temp
	reti

reset:

	; NOMEAR SEMaFOROS
	.def temp = r19 
	.def s2tempo = r20 ; TEMPO DO SEMAFORO 2
	.def sema12 = r21 ; semaforo 1 e 2
	.def sema34 = r22 ; semaforo 3 e 4
	.def count = r24
	.def state = r25
	;.def zero = r19


	; TEMPO DOS SEMÁFOROS 


	.equ T0 = 60
	.equ T1 = 4
	.equ T2 = 23
	.equ T3 = 4
	.equ T4 = 20
	.equ T5 = 3
	.equ T6 = 21
	.equ T7 = 1
	.equ T8 = 3
	.equ T9 = 1


	; SETANDO ESTADO INICIAL
	ldi count, T0
	ldi state, 0
	ldi sema12, 0x0C
	ldi sema34, 0x0C



	; ARMAZENAR ESTADOS 
	;semaforos 1 e 2
	;sema12: .db 0x0C,0x0C,0x0C,0x14, 0x24, 0x24, 0x21, 0x22,0x22,0x0C
	;semaforos 3 e 4
	;sema34: .db 0x0C,0x14,0x24,0x24, 0x24, 0x21, 0x21, 0x21, 0x22, 0x22

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


	.equ TAMANHO_ARRAY = 20; bytes ou 10 posições de elementos de 2 bytes cada
	.equ ENDERECO_FINAL = estado + TAMANHO_ARRAY

	; INICIALIZAR STACK

	ldi temp, low(RAMEND)
	out SPL, temp
	ldi temp, high(RAMEND)
	out SPH, temp

	; SETAR OS PINOS DOS SEMAFOROS COMO SAIDA
	ldi temp, 255 ; 0b1111111 - constante para setar os pinos como saida
	out  DDRB,temp		
	out  DDRC,temp	

	; LIGAR 
	out PORTB,sema12
	out PORTC,sema34

	; CONFIGURAR O DELAY

	#define CLOCK 16.0e6 ;clock speed
	#define DELAY 1 ;seconds
	;#define DELAY 1.0e-3
	.equ PRESCALE = 0b100 ;/256 prescale
	.equ PRESCALE_DIV = 256
	.equ WGM = 0b0100 ;Waveform generation mode: CTC - you must ensure this value is between 0 and 65535
	.equ TOP = int(0.5 + ((CLOCK/PRESCALE_DIV)*DELAY))
	.if TOP > 65535
	.error "TOP is out of range"
	.endif

	; AJUSTES FINAIS NO TIMER
	ldi temp, high(TOP) 
	sts OCR1AH, temp
	ldi temp, low(TOP)
	sts OCR1AL, temp
	ldi temp, ((WGM&0b11) << WGM10) 
	sts TCCR1A, temp
	ldi temp, ((WGM>> 2) << WGM12)|(PRESCALE << CS10)
	sts TCCR1B, temp 


	; ENDEREÇO DOS ESTADOS
	ldi ZL, low(estado*2)
	ldi ZH, high(estado*2)

	; habilitar interrupcoes do timer
	lds	 temp, TIMSK1
	sbr temp, 1 <<OCIE1A
	sts TIMSK1, temp

	sei ; habilitar interrupcoes globais


	; --- MAIN LOOP ---
	main_loop:

		cpi count,0 ;ou -1
		brne main_loop

		;ldi count, IGUAL

		cpi state, 0
		breq state_0

		cpi state, 1
		breq state_1

		cpi state, 2
		breq state_2

		cpi state, 3
		breq state_3

		cpi state, 4
		breq state_4

		cpi state, 5
		breq state_5

		cpi state, 6
		breq state_6

		cpi state, 7
		breq state_7

		cpi state, 8
		breq state_8

		cpi state, 9
		breq state_9
		



		state_0:
			ldi state,1
			ldi count, T1
			rjmp fiat

		state_1:
			ldi state,2
			ldi count, T2
			rjmp fiat

		state_2:
			ldi state,3
			ldi count, T3
			rjmp fiat

		state_3:
			ldi state, 4
			ldi count, T4
			rjmp fiat

		state_4:
			ldi state, 5
			ldi count, T5
			rjmp fiat

		state_5:
			ldi state, 6
			ldi count, T6
			rjmp fiat

		state_6:
			ldi state, 7
			ldi count, T7
			rjmp fiat

		state_7:
			ldi state, 8
			ldi count, T8
			rjmp fiat

		state_8:
			ldi state, 9
			ldi count, T9
			rjmp fiat

		state_9:
			ldi state, 0
			ldi count, T0
			rjmp fiat

		fiat:
		;  ------------------

		ldi temp, 0

		add ZL, state
		adc ZH,temp

		add ZL, state
		adc ZH,temp
		

		lpm sema12, Z+ 
		out PORTB,sema12

		lpm sema34, Z
		out PORTC,sema34

		ldi ZL, low(estado*2)
		ldi ZH, high(estado*2)
		
		;subi ZL, 1       ; Decrementa ZL em 1
		;sbci ZH, 0       ; Decrementa ZH em 0 com carry (se ZL "emprestou")

		rjmp main_loop


	;loop:	rjmp    loop