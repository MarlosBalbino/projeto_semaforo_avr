.include "m328pdef.inc"
.list
.def tmp = r19
.def units = r16
.def tens = r18

.cseg 
.org 0 

.equ ClockMHz = 16
.equ DelayMs = 5 ; delay em milisegundos para rotina de delay

#define CLOCK 16.0e6 ;clock speed
#define DELAY 1 ; delay em secondos para a interrupção de timer

.equ PRESCALE = 0b100 ;/256 prescale8
.equ PRESCALE_DIV = 256
.equ TOP = int((CLOCK/PRESCALE_DIV)*DELAY - 1)
.if TOP > 65535
.error "TOP is out of range"
.endif

rjmp RESET 

.org OC1Aaddr
rjmp TIM1_COMPA

RESET:
	cli

	; ============== CONFIGURA AS PORTAS DE SAÍDA E OS VALORES INICIAIS ===================
	; Ativa as portas B e D
    ldi r16, 0b11111111 
    out DDRB, r16
	out DDRD, r16

	; Inicia o valores que serão mostrados no display
	ldi tens, 0
    ldi units, 0
	ldi r17, 0b00000001 ; valor inicial da porta D (ativar pino D0)

	; ============== CONFIGURA O TIMER ====================================================
	; Timer1: CTC, prescaler = 256
	ldi tmp, 0x00
	sts TCCR1A, tmp
	ldi tmp, (1<<WGM12)
	sts TCCR1B, tmp

	; OCR1A = 62499 (0xF423) para 1s
	ldi tmp, high(TOP)
	sts OCR1AH, tmp
	ldi tmp, low(TOP)
	sts OCR1AL, tmp

	; habilita interrupção Compare A
	lds r20, TIMSK1
	ori r20, 1 << OCIE1A
	sts TIMSK1, r20

	;ldi tmp, 0
	;sts TCNT1H, tmp
	;sts TCNT1L, tmp
	;ldi tmp, (1<<OCF1A)
	;sts TIFR1, tmp


	sei

	lds r20, TCCR1B
	ori r20, (1<<CS12)    ; CS12 = 1 -> prescaler 256
	sts TCCR1B, r20
	/*; Timer1: CTC (WGM12=1), prescaler = 256 (CS12=1)
	; Vamos configurar com o timer parado e só depois iniciar

	; TCCR1A = 0
	ldi tmp, 0x00
	sts TCCR1A, tmp

	; Configure WGM12 sem prescaler (timer parado)
	ldi tmp, (1<<WGM12)    ; apenas WGM12 = CTC, sem bits CSx ainda
	sts TCCR1B, tmp

	; OCR1A = TOP (high / low)
	ldi tmp, high(TOP)
	sts OCR1AH, tmp
	ldi tmp, low(TOP)
	sts OCR1AL, tmp

	; Zera o contador TCNT1 (evita que TCNT1 >= OCR1A)
	ldi tmp, 0x00
	sts TCNT1H, tmp
	sts TCNT1L, tmp

	; Limpa qualquer flag de comparação pendente (escreve 1 no bit)
	ldi tmp, (1<<OCF1A)
	sts TIFR1, tmp

	; habilita interrupção Compare A (OCIE1A)
	lds r20, TIMSK1
	ori r20, (1<<OCIE1A)
	sts TIMSK1, r20

	; Agora habilita interrupções globais (sei)
	sei

	; Finalmente, inicie o timer escrevendo o prescaler (adiciona CS12)
	; Leitura/escrita de TCCR1B para preservar WGM12
	lds r20, TCCR1B
	ori r20, (1<<CS12)    ; CS12 = 1 -> prescaler 256
	sts TCCR1B, r20*/

send_units:	
	out PORTD, r17 ; Ativa o pino D0

	; Verifica o valor de r17 para controlar a saída
	cpi r17, 0b00000001
	brne send_tens
		
	; Coloca o valor de r16 na porta B se r17 = 0b00000001, ou seja, se o pino D0 estiver ativo
	out PORTB, units       
	rjmp alternate
    
	send_tens:
		; Coloca o valor de r18 na porta B se r17 = 0b00000010	
		out PORTB, tens

	alternate:
		; Alterna ou valores de r17 entre 0b00000001 e 0b00000010. Ou seja, alterna entre os pinos D0 e D1
		ldi r20, 0b00000011
		eor r17, r20  ; 01 XOR 03 = 02, 02 XOR 03 = 01
		
		rcall delay1000ms
		rjmp send_units

TIM1_COMPA:
    ; salvar SREG (em r20) — necessário para preservar flags
    in   r20, SREG
    push r20

    ; Incrementa unidades
    inc  units
    cpi  units, 10
    brlo done        ; se units < 10, finaliza (dezenas não muda)

    ; units == 10 -> rollover
    ldi  units, 0     ; zerar unidades
    inc  tens         ; incrementar dezenas
    cpi  tens, 10
    brlo done        ; se tens < 10, finaliza

    ; tens == 10 -> rollover
    ldi  tens, 0

done:
    ; restaurar SREG e retornar da interrupção
    pop  r20
    out  SREG, r20
    reti

; --- Sub-rotina de delay ---
delay1000ms:
    ldi r22, byte3(ClockMHz * 1000 * DelayMs / 5)
    ldi r21, high(ClockMHz * 1000 * DelayMs / 5)
    ldi r20, low(ClockMHz * 1000 * DelayMs / 5)

delay_loop:
    subi r20, 1
    sbci r21, 0
    sbci r22, 0
    brcc delay_loop
    ret