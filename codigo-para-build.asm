.include "m328pdef.inc"

.cseg
.org 0x00

; =====================================================================
; =============== Definição de nomes para registradores =============== 
; =====================================================================
.def zero  = r1 
.def units = r16
.def tens  = r18
.def temp  = r19
.def s2idx = r20 ; índice para tabela do semaforo 2
.def sema12 = r21 ; semaforo 1 e 2
.def sema34 = r22 ; semaforo 3 e 4
.def count  = r24 ; contador dos estados
.def state  = r25 ; estado atual

; ===== Registradores (USART) - renomeados para evitar conflitos ======
.def current_state_ser = r23
.def time_remaining_ser = r26
.def serial_temp = r27
.def serial_temp2 = r28

; =====================================================================
; =============== Declaração de variaveis  ============================
; =====================================================================
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

; =============== Definições USART ============================
.equ F_CPU = 16000000
.equ BAUD = 9600
.equ UBRRVAL = 103

; =============== Definições TOP1/TIMER1  ===============
#define CLOCK 16.0e6
#define DELAY 1 ; 1
.equ PRESCALE_DIV = 256
.equ TOP = int(0.5 + (CLOCK/PRESCALE_DIV)*DELAY) - 1
.if TOP > 65535
.error "TOP is out of range"
.endif

; =============== Definições TOP2/TIMER2  ===============
#define TIMER2_DELAY 0.005 ; segundos
.equ PRESCALE2_DIV = 1024
;calculo mais preciso usando arredondamento
.equ TOP2 = int((CLOCK * TIMER2_DELAY) / PRESCALE2_DIV - 1)
.if TOP2 > 255
.error "TOP2 is out of range"
.endif

.equ NUM_S2TIMER = 3 ; número de posições na s2timer

rjmp RESET

; =====================================================================
; TABELA DE VETORES DE INTERRUPÇÃO UNIFICADA (Timer1, Timer2 e USART)
; =====================================================================
.org OC2Aaddr
rjmp TIM2_COMPA ; rotina para alternar displays
.org OC1Aaddr
rjmp TIM1_COMPA ; rotina para decrementar o contador de estados e contar
				; de forma decrescente os tempos do semaforo 2

; =====================================================================
; TABELAS DE DADOS NA FLASH
; =====================================================================
.org 0x0030  ; Posiciona após vetores para evitar conflitos

; Tabela de estados dos semaforos
state_table:
	.dw 0x0C0C ; Ex: 0001100 => semaforo 1: vermelho; semaforo 2: verde
	.dw 0x140C
	.dw 0x240C
	.dw 0x2414
	.dw 0x2424
	.dw 0x2124
	.dw 0x2121
	.dw 0x2122
	.dw 0x2222
	.dw 0x220C


; Tabela de tempos para o semaforo 2
s2timer: 
    .db 8, 8 ;dezena, unidade
    .db 0, 4  
    .db 4, 8

vermelho_str: .db " Vermelho ",0
verde_str: .db " Verde ",0
amarelo_str: .db " Amarelo ",0


; --- STRINGS USART ---
semaforo1_str: .db " SEMAFORO 1:",0
semaforo2_str: .db " SEMAFORO 2:",0
semaforo3_str: .db " SEMAFORO 3:",0
semaforo4_str: .db " SEMAFORO 4:",0
timer_str: .db " Timer:",0,0
segundos: .db "s",0,0,0
nova_linha: .db 13,10,0

; =====================================================================
; Configuração inicial/Inicializações
; =====================================================================
RESET:	
	cli

	clr zero 
	ldi s2idx, 0 ; inicializa indice da tabela s2timer
	rcall LoadS2State ; carrega os valores iniciais de s2times em units e tens
	dec units ; o primeiro tempo de s2 eh 87s

	; Seta estado inicial
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
	ldi temp, 255 ;  0b1111111 - constante para setar os pinos como saida
	out DDRB, temp		
	out DDRC, temp	
	; PORTD: PD1 (TX) deve ser saída, PD0 (RX) entrada
	;PD2-PD7 saídas (BCD e displays)
	ldi temp, 0b11111110 ; PD1-PD7 saída, PD0 entrada
	out DDRD, temp

	; Seta os estados inicais dos semaforos nas portas B e C
	out PORTB, sema12
	out PORTC, sema34

	ldi r17, 0b01000000 ; valor inicial da porta D (ativar pino D6)

	; =================================================================
	; === Configura Timer1 (CTC, OCR1A = 62500 ~ 1s, prescaler 256) ===
	; =================================================================
	ldi temp, high(TOP)
	sts OCR1AH, temp
	ldi temp, low(TOP)
	sts OCR1AL, temp

	ldi temp, (0<<WGM11) | (0<<WGM10)
	sts TCCR1A, temp
	ldi temp, (1<<WGM12) | (1<<CS12)
	sts TCCR1B, temp

	; habilita interrupcao Compare Match A do Timer1
	lds temp, TIMSK1
	sbr temp, (1<<OCIE1A)
	sts TIMSK1, temp

	; ==================================================================================
	; === Configura Timer2 (CTC, OCR1A = 78 (0x4E) para 5ms ~ 5ms, prescaler = 1024) ===
	; ==================================================================================
	ldi temp, TOP2
    sts OCR2A, temp 
	; Configura modo CTC - WGM02 = 0, WGM01 = 1, WGM00 = 0
	ldi temp, (1<<WGM21)
    sts TCCR2A, temp
	; Prescaler 1024 (CS02 = 1, CS01 = 1, CS00 = 1)
	ldi temp, (1<<CS22) | (1<<CS21) | (1<<CS20)
    sts TCCR2B, temp
	; Habilita interrupcao Compare Match A
	lds temp, TIMSK2
    sbr temp, (1<<OCIE2A)
    sts TIMSK2, temp

	; === Inicializacao USART ===
	rcall usart_init
	rcall send_status ; envia status iniciais

	sei ; habilita interrupcoes globais

; =====================================================================
; ============================ MAIN LOOP ==============================
; =====================================================================
main_loop:

	cpi count, 0 ; quando o contador chegar a zero, passa para o proximo estado
	brne main_loop

	; ========================= Switch Case para os estados ============
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

	; ========================= Seta proximos estados ==================
	fiat:
		; ENDERECO DOS ESTADOS
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

		; ========== INTEGRAÇÃO USART: Envia status ao mudar de estado ========
		mov current_state_ser, state
		mov time_remaining_ser, count

		rcall send_status

		rjmp main_loop

; =====================================================================
; ============ Interrupção TIMER1 - Decrementa contadores =============
; =====================================================================
TIM1_COMPA:
    in temp, SREG    
    push temp ; salva SREG

    dec count ; decrementa o contador de estado

	; Caso A: units == 0?
    cpi units, 0
    breq units_is_zero

	; Caso B: units > 0
    ;    - se units == 1 e tens == 0 -> avançar estado agora (pois 1->0 seria 00)
    cpi units, 1
    brne dec_units				; units >=2 -> dec normal
    cpi tens, 0
    breq call_next_state		; units == 1 && tens == 0 -> proximo estado
	; Caso C: units == 1 && tens > 0 -> dec normal
	dec_units:
		dec units
		rjmp done_isr

	units_is_zero:
		; units == 0  && tens > 0 -> "borrow"
		ldi units, 9
		dec tens
		rjmp done_isr

	call_next_state:
		rcall NextS2State ; incrementa s2idx e carrega tens/units via LoadState
		; apos return, tens/units ja atualizados
		rjmp done_isr

	done_isr:
		pop temp
		out SREG, temp
		reti

; =====================================================================
; =============== Interrupção TIMER2 - Alterna displays ===============
; =====================================================================
TIM2_COMPA:
    in temp, SREG
    push temp
	push r29
	
	; Alterna r17 entre 0b01000000 e 0b10000000 (D6 / D7)
    ldi temp, 0b11000000
    eor r17, temp
	; ------ TIM1

	; Atualiza porta D de acordo com r17: se bit D6 set -> mostra units; else -> tens
    ; Monta mascara final em temp2 e escreve PORTD
    mov temp, r17			; temp2 = r17

	; Se D6 (0b01000000) esta ativo -> mostrar units
    ; Se D7 (0b10000000) ativo -> mostrar tens
    ; Se r17 == 0b01000000 -> OR com units; se r17 == 0b10000000 -> OR com tens
    cpi r17, 0b01000000
    breq show_units

	; caso contrario eh a outra posicao
	mov r29, tens
	lsl r29
	lsl r29
	andi r29, 0b00111100
	or temp, r29
    out PORTD, temp
    rjmp end_isr

	show_units:
		mov r29, units
		lsl r29
		lsl r29
		andi r29, 0b00111100
		or temp, r29
		out PORTD, temp

	end_isr:
		pop r29
		pop temp
		out SREG, temp
		reti

; =====================================================================
; FUNÇÕES DE CONTROLE DE ESTADO DO SEMaFORO 2
; =====================================================================
LoadS2State:
	; calcula endereco base states + idx*2 e posicona z
    ldi ZL, low(s2timer*2) ; z low
    ldi ZH, high(s2timer*2) ; z high

    mov temp, s2idx
    lsl temp ; temp = idx * 2 (multiplica por 2)
	;temp é 8-bit; se num_s2timer*2 <= 255, isso basta. para tabelas maiores, usar 16-bit mult.
    add ZL, temp
    adc ZH, zero ; zero deve ser r1 = 0

	;le tens e units da flash
    lpm tens, Z+ ; le primeiro byte (tens), z <- z + 1
    lpm units, Z ; le segundo byte (units)
    ret

NextS2State:
    inc s2idx ; incrementa indice
    cpi s2idx, NUM_S2TIMER 
    brlo skip_s2idx_reset ;se o indice for igual a posicao final da tabela:
    ldi s2idx, 0 ; reseta o indice

	skip_s2idx_reset:
		rcall LoadS2State ; carrega o proximo timer do semaforo
		ret

; =====================================================================
; ====================== Funções USART ================================
; =====================================================================
usart_init:
    push serial_temp

    ldi serial_temp, high(UBRRVAL)
    sts UBRR0H, serial_temp
    ldi serial_temp, low(UBRRVAL)
    sts UBRR0L, serial_temp

	; Configura formato: 8 bits de dados, 1 stop bit, sem paridade
    ldi serial_temp, (1<<UCSZ01)|(1<<UCSZ00) ; USBS0 = 0, ou seja, 1-bit
    sts UCSR0C, serial_temp

    ;ldi serial_temp, (1<<TXEN0) 
	ldi serial_temp, (1<<RXEN0)| (1<<TXEN0)| (1<<RXCIE0)    
    sts UCSR0B, serial_temp

    pop serial_temp
    ret

; Transmissao byte por byte
usart_transmit:
    push temp
usart_transmit_wait:
    lds temp, UCSR0A ; regsitrador com as flags da USART
    sbrs temp, UDRE0 ; o bit UDRE0, USART Data Register Empty i.e  o registrador de buffer de transmissão (UDR0), esta vazio?
					 ; se sim, pule a proxima instrução 
					 ; se nao, volte ao incio do loop ate o buffer (UDR0) estiver vazio.
    rjmp usart_transmit_wait
    sts UDR0, r24 ; CARREGAR DADOS NO BUFFER e evniar na comunicacao serial
    pop temp
    ret

; Transmissao de strings (sequencia de bytes)
; Comece no primeiro byte da string
usart_print_string:
    push r24
    push r30
    push r31
    usart_print_loop:
        lpm r24, Z+
        cpi r24, 0            ; cheguei ao fim da minha string, i.e, cheguei no byte "0"?
        breq usart_print_end  ; sim: volte ao fluxo normal de instrucoes
        rcall usart_transmit  ; nao: transmita o byte atual da string
        rjmp usart_print_loop ; volte o inicio do loop ate transmitir a string completa
    usart_print_end:
        pop r31
        pop r30
        pop r24
        ret

send_status:
    push r21 
    push r22
	push r24
	push r30
	push r31

	; Status SEMÁFORO 1
	; Carregar string "SEMAFORO 1" em Z
	ldi ZL, low(semaforo1_str*2) 
	ldi ZH, high(semaforo1_str*2)

	; Enviar string via comunicação serial
	rcall usart_print_string
	
	; Pegar status do semáforo 1 via os 3 primeiros bits de r21
	; 001 = verde - 010 = amarelo - 100 = vermelho
	mov r24, r21 ; sema 12
    andi r24, (1 << 0) | (1 << 1) | (1 << 2) ; maskara com 0b00000111 separa bits do semáforo 1

	; Carregar a string com o status ("verde", "amarelo" ou "vermelho") do semáforo em Z
	rcall get_color_string

	; Enviar o status via comunicação serial.
	rcall usart_print_string

	; Status SEMÁFORO 2
	ldi ZL, low(semaforo2_str*2)
	ldi ZH, high(semaforo2_str*2)
	rcall usart_print_string

	mov r24, r21 ; sema 12
	andi r24, (1 << 3) | (1 << 4) | (1 << 5) ; maskara com 0b00111000 separa bits do semáforo 2
	; desloca bits para direita: Ex: se (sema2 = 00100000 = vermelho) => (00100000 >> 3 = 0b00000100)
	lsr r24
	lsr r24
	lsr r24

	rcall get_color_string
	rcall usart_print_string

	; Status SEMÁFORO 3
	ldi ZL, low(semaforo3_str*2)
	ldi ZH, high(semaforo3_str*2)
	rcall usart_print_string
	
	mov r24, r22 ; sema 34
	andi r24, (1 << 0) | (1 << 1) | (1 << 2) ; maskara
	rcall get_color_string
	rcall usart_print_string

	; Status SEMÁFORO 4
	ldi ZL, low(semaforo4_str*2)
	ldi ZH, high(semaforo4_str*2)
	rcall usart_print_string

	mov r24, r22 ; sema 34
	andi r24, (1 << 3) | (1 << 4) | (1 << 5)

	lsr r24
	lsr r24
	lsr r24

	rcall get_color_string
	rcall usart_print_string

	; Adiciona quebra de linha
	ldi ZL, low(nova_linha*2)
	ldi ZH, high(nova_linha*2)
	rcall usart_print_string

	pop r31
	pop r30
	pop r24
    pop r22
    pop r21

    ret
	
; Qual a cor correspondente aos 3 bits atuais?
; 001 = verde 
; 010 = amarelo
; 100 = vermelho
get_color_string:
	
    cpi r24, 0x04 ; r24 = 100 ?
    breq return_red

    cpi r24, 0x02 ; r24 = 010 ?
    breq return_yellow

    cpi r24, 0x01 ; r24 = 001 ?
    breq return_green

    ; Valor invalido, retorna ponteiro nulo
    
return_red:
    ldi r30, low(vermelho_str*2)
    ldi r31, high(vermelho_str*2)
    ret

return_yellow:
    ldi r30, low(amarelo_str*2)
    ldi r31, high(amarelo_str*2)
    ret

return_green:
	ldi r30, low(verde_str*2)
	ldi r31, high(verde_str*2)
	ret

