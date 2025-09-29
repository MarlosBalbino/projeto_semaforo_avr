.include "m328pdef.inc"
.list

.def zero  = r1 
.def units = r16
.def tens  = r18
.def tmp   = r19
.def idx   = r20

.equ NUM_STATES = 10

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

	clr zero          ; zera r1 (r1 deve ficar zero)
    ldi idx, 0
	rcall LoadState

	; ============== CONFIGURA AS PORTAS DE SAÍDA E OS VALORES INICIAIS ===================
	; Ativa as portas B e D
    ldi tmp, 0b11111111 
    out DDRB, tmp
	out DDRD, tmp

	; Inicia o valores que serão mostrados no display
	; ldi tens, high(states*2)
    ; ldi units, low(states*2)
	ldi r17, 0b00000001 ; valor inicial da porta D (ativar pino D0)

	; ============== CONFIGURA O TIMER ====================================================
	
	; OCR1A = 62499 (0xF423) para 1s
	ldi tmp, high(TOP)
	sts OCR1AH, tmp
	ldi tmp, low(TOP)
	sts OCR1AL, tmp

	; habilita interrupção Compare A
	lds tmp, TIMSK1
	ori tmp, 1<<OCIE1A
	sts TIMSK1, tmp

	; Timer1: CTC, prescaler = 256
	ldi tmp, 0x00
	sts TCCR1A, tmp
	ldi tmp, (1<<WGM12) | (1<<CS12)
	sts TCCR1B, tmp

	sei

	
send_units:	
	out PORTD, r17 ; Ativa o pino D0

	; Verifica o valor de r17 para controlar a saída
	; cpi r17, 0b00000001
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
		ldi tmp, 0b00000011
		eor r17,tmp  ; 01 XOR 03 = 02, 02 XOR 03 = 01
		
		rcall delay1000ms
		rjmp send_units

TIM1_COMPA:
    ; --- salvar SREG (em r17) ---
    in   tmp, SREG
    push tmp

    ; --- Checa se contador já está em 00: se sim, avança o estado ---
    cpi  units, 0
    brne do_units_decrement      ; units != 0 -> faz decremento normal
    cpi  tens, 0
    breq call_next_state   ; units==0 && tens==0 -> carregar próxima entrada

    ; --- units == 0 e tens > 0: pega "borrow" e decrementa tens ---
    ldi  units, 9
    dec  tens
    rjmp done_isr

do_units_decrement:
    dec  units
    rjmp done_isr

call_next_state:
    ; --- Preservar regs que NextState / LoadState usarão (r30:r31 e tmp=r19) ---
    ;push r30
    ;push r31
    ;push tmp        ; tmp = r19

    ; chama NextState (incrementa idx, faz LoadState -> coloca tens/units em r18/r16)
    rcall NextState

    ; --- restaurar r19, r31, r30 ---
    ;pop  tmp
    ;pop  r31
    ;pop  r30

done_isr:
    ; --- restaurar SREG e sair da ISR ---
    pop  tmp
    out  SREG, tmp
    reti


; --- Sub-rotina de delay ---
delay1000ms:
    ldi r22, byte3(ClockMHz * 1000 * DelayMs / 5)
    ldi r21, high(ClockMHz * 1000 * DelayMs / 5)
    ldi r25, low(ClockMHz * 1000 * DelayMs / 5)

delay_loop:
    subi r25, 1
    sbci r21, 0
    sbci r22, 0
    brcc delay_loop
    ret




states: ; unidades dezenas
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
    


LoadState:
    ; calcula endereço base states + idx*2 e posiciona Z
    ldi ZL, low(states*2)      ; Z low
    ldi ZH, high(states*2)     ; Z high

    mov tmp, idx
    lsl tmp                   ; tmp = idx * 2 (multiplica por 2)
    ; tmp é 8-bit; se NUM_STATES*2 <= 255, isso basta. Para tabelas maiores, usar 16-bit mult.
    add ZL, tmp
    adc ZH, zero             ; zero deve ser r1=0

    ; lê tens e units da flash
    lpm tens, Z+              ; lê primeira byte (tens), Z <- Z + 1
    lpm units, Z              ; lê segunda byte (units)

    ret


NextState:
    inc idx
    cpi idx, NUM_STATES
    brlo skip_idx_reset
    ldi idx, 0
skip_idx_reset:
    rcall LoadState
    ret