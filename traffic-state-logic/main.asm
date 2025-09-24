;
; led.asm

; ----- SETUP -----
.include "m328pdef.inc"

.cseg
.org 	0x00

; NOMEAR SEMaFOROS
.def temp = r20 
.def sema12 = r21 ; semaforo 1 e 2
.def sema34 = r23 ; semaforo 3 e 4




; ARMAZENAR ESTADOS
; semaforos 1 e 2
;estados12: .db 0x0C,0x0C,0x0C,0x14, 0x24, 0x24, 0x21, 0x22,0x22,0x0C
;estados34: .db 0x0C,0x14,0x24,0x24, 0x24, 0x21, 0x21, 0x21, 0x22, 0x22

estado:
  .dw 0x0C0C
  .dw 0x140C
  .dw 0x240C
  .dw 0x2414
  .dw 0x2424
  .dw 0x2124
  .dw 0x2121
  .dw 0x2122
  .dw 0x2222
  .dw 0x220C

.equ TAMANHO_ARRAY = 20; bytes ou 10 posi��es de elementos de 2 bytes cada
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

; CONFIGURAR O DELAY

#define CLOCK 16.0e6 ;clock speed
#define DELAY 1 ;seconds
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


; ENDERE�O DOS ESTADOS
ldi ZL, low(estado*2)
ldi ZH, high(estado*2)


; --- MAIN LOOP ---
main_loop:

in temp, TIFR1
andi temp, 1<<OCF1A 
; andi --> 1 (OCF1A � um)	--> overflow - J� PASSOU delay SEGUNDOS!
; andi --> 0 (OCF1A � zero)	--> contando - ainda t� contando
breq facaNada ; veja se os 2 s�o zero. se sim, ainda est� contando.

; chegou aqui? o tempo j� deu! reset a bandeira 
ldi temp, 1<<OCF1A ;write a 1 to clear the flag
out TIFR1, temp ; com est� no modo CTC, o registrador do temporizador, TCNT1, � zerado



; overflow

adiw Z, 2


ldi temp, high(ENDERECO_FINAL)
cpse ZH, temp
rjmp resetEstados

ldi temp, low(ENDERECO_FINAL)
cp ZL, temp
brsh resetEstados



facaNada:
	; ------ MAIN ----
	lpm sema12, Z+ ;JA VAI PARA O PROXIMO
	out PORTB,sema12

	lpm sema34, Z
	out PORTC,sema34

	; Para fazer Z voltar ao LSB do elemento que ele acabou de ler:
	subi ZL, 1       ; Decrementa ZL em 1
	sbci ZH, 0       ; Decrementa ZH em 0 com carry (se ZL "emprestou")

	rjmp main_loop

resetEstados:
	ldi ZL, low(estado*2)
	ldi ZH, high(estado*2)

	rjmp facaNada


;loop:	rjmp    loop