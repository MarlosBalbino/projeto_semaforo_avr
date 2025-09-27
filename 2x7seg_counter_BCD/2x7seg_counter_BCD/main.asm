.cseg 
.org 0 

.equ ClockMHz = 16
.equ DelayMs = 100

rjmp RESET 

RESET:
	; Ativa as portas B e D
    ldi r16, 0b11111111 
    out DDRB, r16
	out DDRD, r16

	; Inicia o valores que serão mostrados no display
	ldi r18, 2
    ldi r16, 4  
	ldi r17, 0b00000001 ; valor inicial da porta D



send:	
		out PORTD, r17 ; Ativa o pino D0

		; Verifica o valor de r17 para controlar a saída
		cpi r17, 0b00000001
		brne saida_portb
		
		; Coloca o valor de r16 na porta B se r17 = 0b00000001, ou seja, se o pino D0 estiver ativo
		out PORTB, r16       
		rjmp alternar
    
	saida_portb:
		; Coloca o valor de r18 na porta B se r17 = 0b00000010	
		out PORTB, r18

	alternar:
		; Alterna ou valores de r17 entre 0b00000001 e 0b00000010. Ou seja, alterna entre os pinos D0 e D1
		ldi r19, 0b00000011
		eor r17, r19  ; 01 XOR 03 = 02, 02 XOR 03 = 01
		
		rcall delay1000ms

		rjmp send

counter:
    ; rcall delay1000ms

    inc r16  ; Incrementa o índice da tabela
    
    ; Verifica se r16 > 9 (0-9 são 10 valores)
    cpi r16, 10
    brlo counter ; Se menor que 10, continua no loop
    
    ; Se chegou a 10:
    ldi r16, 0 ; reseta r16 para 0
	inc r18    ; incrementa r18
    rjmp counter

; --- Sub-rotina de delay (1000ms) ---
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