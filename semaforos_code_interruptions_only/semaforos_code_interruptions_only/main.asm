.include "m328pdef.inc"

.cseg
.org 0x00

; =============== Definição de nomes para registradores =============== 
.def zero  = r1 
.def units = r16
.def tens  = r18

.def temp   = r19 
.def s2idx  = r20 ; Índice para tabela do semaforo 2
.def sema12 = r21 ; semaforo 1 e 2
.def sema34 = r22 ; semaforo 3 e 4
.def count  = r24 ; contador dos estados
.def state  = r25 ; estado atual

; =============== Declaração de variáveis  ============================
; Tempo de cada estado
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

; Tabela de estados
state_table:
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

; Tabela de tempos para o semáforo 2
s2timer: 
    .db 8, 8 ; dezena, unidade
    .db 0, 4  
    .db 4, 8

.equ NUM_S2TIMER = 3 ; número de posições na s2timer

.equ ClockMHz = 16
.equ DelayMs  = 5 ; delay em milisegundos para rotina de delay

#define CLOCK 16.0e6 ; clock speed
#define DELAY 0.15 ; temporizador em segundos
.equ PRESCALE = 0b100 ;/256 prescale
.equ PRESCALE_DIV = 256
.equ WGM = 0b0100 ; Waveform generation mode: CTC - you must ensure this value is between 0 and 65535
.equ TOP = int(0.5 + ((CLOCK/PRESCALE_DIV)*DELAY))
.if TOP > 65535
.error "TOP is out of range"
.endif

jmp RESET
.org OC1Aaddr
jmp OCI1A_Interrupt
.org OC0Aaddr
jmp OCI0A_Interrupt

; =============== Configuração inicial/Inicializações  ===============
RESET:	
	cli

	clr zero
	ldi s2idx, 0 ; inicializa indice da tabela s2timer
	rcall LoadS2State ; carrega os valores inciais de s2timer em units e tens
	dec units ; o primeiro tempo de s2 é 87s

	; Seta estado inical
	ldi count, T0
	ldi state, 0
	ldi sema12, 0x0C
	ldi sema34, 0x0C
	
	; Inicializa stack
	ldi temp, low(RAMEND)
	out SPL, temp
	ldi temp, high(RAMEND)
	out SPH, temp

	; Habilita as portas B, C e D
	ldi temp, 255 ; 0b1111111 - constante para setar os pinos como saida
	out  DDRB,temp		
	out  DDRC,temp	
	out  DDRD,temp

	; Seta os estados inicais dos semáforos nas portas B e C
	out PORTB,sema12
	out PORTC,sema34

	ldi r17, 0b01000000 ; valor inicial da porta D (ativar pino D6)

	; === Configura Timer1 (CTC, OCR1A = 62500 ~ 1s, prescaler 256) ===
	ldi temp, high(TOP) 
	sts OCR1AH, temp
	ldi temp, low(TOP)
	sts OCR1AL, temp

	ldi temp, ((WGM&0b11) << WGM10) 
	sts TCCR1A, temp
	ldi temp, ((WGM>> 2) << WGM12)|(PRESCALE << CS10)
	sts TCCR1B, temp 

	; habilita interrupção Compare Match A do Timer1
	lds	temp, TIMSK1
	sbr temp, (1<<OCIE1A)
	sts TIMSK1, temp

	; === Configura Timer0 (CTC, OCR0A = 78 ~ 5ms, prescaler 1024) ===
    ldi temp, 78            ; OCR0A = 78 ~= 5 ms com prescaler 1024
    sts  OCR0A, temp

	ldi temp, (1<<WGM01) 
    sts  TCCR0A, temp
	ldi temp, (1<<CS02) | (1<<CS00)
    sts  TCCR0B, temp

    ; habilita interrupção Compare Match A do Timer0
    lds  temp, TIMSK0
    sbr  temp, (1<<OCIE0A)
    sts  TIMSK0, temp    

	sei ; habilita interrupcoes globais

; =============== MAIN LOOP  =======================================
main_loop:
	
	;rcall delay1000ms
	;rcall Display_Alternate

	cpi count, 0 ; quando o contador chegar a zero, passa pra o próximo estado
	brne main_loop

	; ---------- Desativa apenas a interrupção OCIE0A (Timer0 Compare A) ----------
    lds  temp, TIMSK0
    andi temp, ~(1<<OCIE0A)   ; limpa o bit OCIE0A
    sts  TIMSK0, temp

	; ========================= Switch Case para os estados   =================================================
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

	; ========================= Seta proximos estados =================================================
	fiat:
		; ENDEREÇO DOS ESTADOS
		ldi ZL, low(state_table*2)
		ldi ZH, high(state_table*2)

		add ZL, state
		adc ZH, zero

		add ZL, state
		adc ZH, zero
		
		lpm sema12, Z+ 
		out PORTB, sema12

		lpm sema34, Z
		out PORTC, sema34

		; ---------- Reativa a interrupção OCIE0A ----------
		; limpa qualquer flag pendente pra evitar chamada imediata
		ldi  temp, (1<<OCF0A)
		sts  TIFR0, temp

		lds  temp, TIMSK0
		ori  temp, (1<<OCIE0A)
		sts  TIMSK0, temp

		rjmp main_loop

; =============== Função via interrupção por timer  ===============
OCI1A_Interrupt:
    in   temp, SREG    
    push temp ; salva SREG

    dec  count ; decrementa contador de estado
	
    ; Caso A: units == 0 ?
    cpi  units, 0
    breq units_is_zero

    ; Caso B: units > 0
    ;    - se units == 1 e tens == 0 -> avançar estado agora (pois 1->0 seria 00)
    cpi  units, 1
    brne dec_units             ; units >= 2 -> dec normal
    cpi  tens, 0
    breq call_next_state       ; units==1 && tens==0 -> próximo estado
    ; Caso C: units == 1 && tens > 0 -> dec normal
	dec_units:
		dec  units
		rjmp done_isr

	units_is_zero:
		; units == 0 && tens > 0 -> "borrow"
		ldi  units, 9
		dec  tens
		rjmp done_isr

	call_next_state:
		rcall NextS2State            ; incrementa s2idx e carrega tens/units via LoadState
		; após return, tens/units já atualizados
		rjmp done_isr

	done_isr:
		pop  temp
		out  SREG, temp
		reti

; =============== Carrega timer do semáforo 2  ========================
LoadS2State:
    ; calcula endereço base states + idx*2 e posiciona z
    ldi ZL, low(s2timer*2)      ; z low
    ldi ZH, high(s2timer*2)     ; z high

    mov temp, s2idx
    lsl temp                   ; temp = idx * 2 (multiplica por 2)
    ; temp é 8-bit; se num_s2timer*2 <= 255, isso basta. para tabelas maiores, usar 16-bit mult.
    add ZL, temp
    adc ZH, zero               ; zero deve ser r1=0

    ; lê tens e units da flash
    lpm tens,  Z+              ; lê primeiro byte (tens), z <- z + 1
    lpm units, Z               ; lê segundo byte (units)

    ret

; =============== Vai para o próximo timer do semáforo 2  ===============
NextS2State:
    inc s2idx ; incrementa indice
    cpi s2idx, NUM_S2TIMER 
    brlo skip_s2idx_reset ; se o indice for igual a posição final da tabela:
    ldi s2idx, 0 ; reseta o indice

	skip_s2idx_reset:
		rcall LoadS2State ; carrega próximo timer do semáforo
		ret

OCI0A_Interrupt:
    in   temp, SREG
    push temp

    ; Alterna r17 entre 0b01000000 e 0b10000000 (D6 / D7)
    ldi  temp, 0b11000000
    eor  r17, temp

    ; Atualiza porta D de acordo com r17: se bit D6 set -> mostra units; else -> tens
    ; Monta máscara final em temp2 e escreve PORTD
    mov  temp, r17       ; temp2 = r17

    ; Se D6 (0b01000000) está ativo -> mostrar units
    ; Se D7 (0b10000000) ativo -> mostrar tens
    ; Se r17 == 0b01000000 -> OR com units; se r17 == 0b10000000 -> OR com tens
    cpi  r17, 0b01000000
    breq show_units
    ; caso contrário é a outra posição
    or   temp, tens
    out  PORTD, temp
    rjmp end_isr

	show_units:
		or   temp, units
		out  PORTD, temp

	end_isr:
		pop  temp
		out  SREG, temp
		reti

; =============== Rotina de delay  ===============
/*delay1000ms:
    ldi r26, byte3(ClockMHz * 1000 * DelayMs / 5)
    ldi r27, high(ClockMHz * 1000 * DelayMs / 5)
    ldi r28, low(ClockMHz * 1000 * DelayMs / 5)

delay_loop:
    subi r28, 1
    sbci r27, 0
    sbci r26, 0
    brcc delay_loop
    ret*/