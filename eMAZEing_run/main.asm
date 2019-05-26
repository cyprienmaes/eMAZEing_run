;
; Keyboard.asm
;
; Created: 2019-03-19 08:52:37
; Author : Mateusz
;
.INCLUDE "m328pdef.inc"
.ORG 0x0000 
RJMP PRESSstart
.ORG 0x001A
RJMP Timer1OverflowInterrupt
.ORG 0x0020
RJMP Timer0OverflowInterrupt

; -------------------------------------------------------- PRESS START ------------------------------------------------------------------
PRESSstart :
/*
 * Y pointer register is used to write 'PRESS START' on the screen. 
 * The characters are defined in the flash meory in the CharTable at the botton of the code.
 */
	LDI YL,0x00
	LDI YH,0x01
	LDI R16,0b00
	LDI R16,16         ;P
	ST Y+,R16		  
	LDI R16,17		  ;R
	ST Y+,R16
	LDI R16,12		  ;E
	ST Y+,R16
	LDI R16,18		  ;S
	ST Y+,R16
	ST Y+,R16         ;S
	LDI R16,10
	LDI R17,6
	loop :
		ST Y+,R16
		DEC R17
	BRNE loop
	LDI R16,18         ;S
	ST Y+,R16
	LDI R16,19         ;T
	ST Y+,R16
	LDI R16,11         ;A
	ST Y+,R16
	LDI R16,17         ;R
	ST Y+,R16
	LDI R16,19         ;T
	ST Y,R16

init :
/*
 * Initializing the screen outputs (shift registers) and setting up the counter for the random number. 
 */

	.DEF random = R23
	LDI R22,200				; Counter for the flashing PRESS START
	LDI random,255
	SET						; Set T in SREG.
   
	; Setting up the SDI (PB3).
	SBI DDRB,3			    ; Pin PB3 is an output
	CBI PORTB,3	
	
	; Setting up the data latch (LE/DM1)
	SBI DDRB,4				; Pin PB4 is an output
	CBI PORTB,4
	
	; Enabling the shift latch clock.
	SBI DDRB,5				; Pin PB5 is an output
	CBI PORTB,5

	RJMP start

; ------------------- shift of the row in the screen ------------------------
rowon :
	ROL R21				; Rotate to the left
	BRCC rowoff			; Branch if Carry Cleared
	SBI PORTB,3
rowoff :
	SBI PORTB,5
	CBI PORTB,5
	CBI PORTB,3
	DEC R17           ; Do this 8 times
	BRNE rowon

SBI PORTB,4           ; PB4 need to stay at one a certain amount of time
LDI R19,255
LDI R20, 9
wait1:
	wait2:
		DEC R20
		BRNE wait2
	LDI R20,9
	DEC R19
	BRNE wait1
CBI PORTB,4

DEC R16                ; Change the position of the byte in flash memory
LSR R18                ; shift to the rigth the shift register
BREQ start             ; if shift equal to 0 => go to start
RJMP display           ; go to display either
; --------------------------------------------------------------------------

start :
	LDI R16,6               ; Count from 6 to 0 to have all the flash line
	LDI R18, 0b01000000     ; Send the row
	DEC R22
	BRNE display
	BRTS clearT				; Branch if T Flag Set.
	LDI R22,200
	SET
	RJMP display
	clearT :
		LDI R22,25
		CLT

display :
	LDI YL,0x10
	LDI YH,0x01             ; 16 blocks to display
	LDI R17,8               ; constant
	LDI R19,16              ; counter of each blocks

	LDI R21,0xFF            ; Transition on PIN D (intermediate state)
	OUT DDRD,R21
	OUT PORTD,R21

	; Configure the PIN D of the keyboard
	LDI R21,0xF0   
	OUT DDRD,R21            ; PIN 7:4 are outputs and 3:0 are inputs
	LDI R21,0x0F
	OUT PORTD,R21			; PIN 3:0 have pull-up resistor on
	RJMP COUNTloop

NEWcounter :
	LDI random,255

COUNTloop :
	LDI R21,0xFF            ; Transition on PIN D (intermediate state)
	OUT DDRD,R21
	OUT PORTD,R21

	LDI R21,0xF0   
	OUT DDRD,R21            ; PIN 7:4 are outputs and 3:0 are inputs
	LDI R21,0x0F
	OUT PORTD,R21			; PIN 3:0 have pull-up resistor on

	DEC random              ; Decrement random
	CPI random,1		    ; IF random equal 1
	BREQ NEWcounter
	SBIS PIND,0				; Button is pushed in the column 0 go to the next instruction
	RJMP READloop
	RJMP blocksloop

READloop :
	LDI R21,0xFF            ; Transition on PIN D
	OUT DDRD,R21
	OUT PORTD,R21

	LDI R21,0x0F			; PIN 7:4 are inputs and 3:0 are outputs
	OUT DDRD,R21
	LDI R21,0xF0			; PIN 7:4 have pull-up resistor on
	OUT PORTD,R21
	NOP

	SBIS PIND,4				; Button is pushed in the column 0 and row 4 go to the next instruction
	RJMP begin

blocksloop :
	LDI ZL,low(CharTable << 1)			; First element in flash memory
	LDI ZH,high(CharTable << 1)
	BRTS show							; Branch if T Flag Set.

notshow :
	LDI R21,0
	RJMP block

show :
/*
 * Z ponints toward the chartable and Y points toward the index of the chosen symbol in the chartable.
 * This branch is responsible for showing the chosen symbols from the CharTable.
 */
	LD R21,-Y                       ; Load the line that we need on the flash (Load Indirect and Pre-Dec.) Last is sent first.
	MUL R21,R17                     ; multiply by eight to have the first element of the line R1:R0 <- Rd x Rr
	MOV R21,R0						; Move Between Registers Rd <- Rr
	ADD R21,R16					    ; Add row to have the byte of the line
	ADC ZL,R21                      ; Add this value on Z
	BRCC nc							; Branch if Carry Cleared
	LDI R21,1
	ADD ZH,R21
	nc :
	LPM R21,Z		                ; Load the byte at the position stored in Z in R21
	LDI R20,5                       ; We must shift 5 times

block :
	ROR R21           ; shift to the right R21 
	BRCC turnoff   
	SBI PORTB,3		  ; If it's a one turn on the LED

turnoff :
	SBI PORTB,5       ; Rising edge to put in the shift register
	CBI PORTB,5
	CBI PORTB,3       ; Don't forget to clear PB3
	DEC R20           ; Decrement counter2 5 times
	BRNE block

DEC R19               ; Decrement counter1 16 times (corresponding to the number of block)
BRNE blocksloop
MOV R21,R18           ; Put the row shifting on another register
RJMP rowon

; ---------------------------------------------------------------------------------------------------------------------------------------
; -------------------------------------------------------- GAME ------------------------------------------------------------------------

begin:
	.DEF direction	= R25
	.DEF bytesnake	= R17
	.DEF bytefood	= R18
	.DEF speed		= R22
	.DEF toggle		= R24			; Used to make the fruit darker
	.DEF score1		= R8
	.DEF score2     = R9
	LDI speed,0x0F
	LDI R16,0
	MOV score1,R16
	MOV score2, R16
	LDI toggle, 1
	;-------------------TIMERS----------------------------------

	;Set timer0 prescaler to 256
	LDI	R16,4
	OUT TCCR0B,R16	

	; The PRTIM1 bit in ”PRR – Power Reduction Register” must be written to zero to enable Timer/Counter1 module.
	LDI R16,0
	STS PRR,R16
	;Set timer1 prescaler to 1024
	LDI	R16,3
	STS TCCR1B,R16	

	;Setting the TCNT0 value at 312Hz
	LDI R16,56	
	OUT TCNT0,R16

	;Setting the initial TCNT1 value.
	LDI R16,0xFF	
	MOV R19,speed
	STS TCNT1H,R19
	STS TCNT1L,R16

	;enable global interrupt & timer0 and timer1 interrupt
	LDI	R16,0x80
	OUT	SREG,R16
	LDI R16,1
	STS	TIMSK0,R16
	STS TIMSK1,R16

	;Clearing the outputs
	SBI DDRB,3			    ; Pin PB3 is an output
	CBI PORTB,3	

	SBI DDRB,4				; Pin PB4 is an output
	CBI PORTB,4

	SBI DDRB,5				; Pin PB5 is an output
	CBI PORTB,5

;Send maze to screenbuffer------------------------------------------------------------------------------
LDI XL,0x00						
LDI XH,0x03						
LDI R16 ,0x00					
LDI R19,7						
WriteMazeToScreenbuffer:
	ST X+,R16					
	DEC R19
	BRNE WriteMazeToScreenbuffer	


LDI R16 ,0x10					
ST X+,R16


LDI R16 ,0x00					
LDI R19,8					
WriteMazeToScreenbuffer2:		
	ST X+,R16		
	DEC R19
	BRNE WriteMazeToScreenbuffer2	

LDI R16 ,0xFE					
ST X+,R16	

LDI R16 ,0x1F					
ST X+,R16	

LDI R16 ,0x00					
LDI R19,8					
WriteMazeToScreenbuffer3:		
	ST X+,R16		
	DEC R19
	BRNE WriteMazeToScreenbuffer3

LDI R16 ,0x02					
ST X+,R16

LDI R16 ,0x10					
ST X+,R16

LDI R16 ,0x00					
LDI R19,4					
WriteMazeToScreenbuffer4:		
	ST X+,R16		
	DEC R19
	BRNE WriteMazeToScreenbuffer4

LDI R16 ,0xF0					
ST X+,R16

LDI R16 ,0xFF					
LDI R19,3					
WriteMazeToScreenbuffer5:		
	ST X+,R16		
	DEC R19
	BRNE WriteMazeToScreenbuffer5

LDI R16 ,0x03					
ST X+,R16

LDI R16 ,0xF0					
ST X+,R16

LDI R16 ,0xFF					
LDI R19,2					
WriteMazeToScreenbuffer6:		
	ST X+,R16		
	DEC R19
	BRNE WriteMazeToScreenbuffer6

LDI R16 ,0xFF					
ST X+,R16

LDI R16 ,0x7F					
ST X+,R16

LDI R16 ,0x10					
ST X+,R16

LDI R16 ,0x00					
LDI R19,9					
WriteMazeToScreenbuffer7:		
	ST X+,R16		
	DEC R19
	BRNE WriteMazeToScreenbuffer7

LDI R16 ,0x10					
ST X+,R16

LDI R16 ,0x00					
LDI R19,9					
WriteMazeToScreenbuffer8:		
	ST X+,R16		
	DEC R19
	BRNE WriteMazeToScreenbuffer8

LDI R16 ,0x10					
ST X+,R16

LDI R16 ,0x00					
LDI R19,7					
WriteMazeToScreenbuffer9:		
	ST X+,R16		
	DEC R19
	BRNE WriteMazeToScreenbuffer9


;Send data to screenbuffer------------------------------------------------------------------------------
LDI ZL,0x00						; ZL is the register R30------Z = ZL+ZH
LDI ZH,0x01						; init Z to point do address 0x0100----------ZH is the register R31
LDI R16 ,0x00					; We will write this value to every byte of the whole screenbuffer

LDI R19,70						; Need to write 70 bytes to fill the whole screenbuffer
WriteByteToScreenbuffer:
	ST Z+,R16					;write value from Ra to address pointed by Z and auto-increase Z pointer
	DEC R19
	BRNE WriteByteToScreenbuffer	;write 70 bytes
;-------------------------------------------------------------------------------------------------------

;Send obstacle to screenbuffer------------------------------------------------------------------------------
LDI YL,0x00						; YL is the register R32------Y = YL+YH
LDI YH,0x02						; init Y to point do address 0x0200----------YH is the register R33

LDI R19,70						;need to write 70 bytes to fill the whole screenbuffer
WriteObstacleToScreenbuffer:
	ST Y+,R16						;write value from Ra to address pointed by Y and auto-increase Y pointer
	DEC R19
	BRNE WriteObstacleToScreenbuffer	;write 70 bytes
;-------------------------------------------------------------------------------------------------------

; Add the move point on the screen at a deterministic place
LDI ZL,0					    ; Take the position of the byte
LDI bytesnake, 0x01                   ; Set one bit on the byte
ST Z,bytesnake                        ; Put the value pointed by Z

;Add food for snake on the screen
generate :
	ANDI random,0b011111111         ; We want a random number < 70 => we need 7 bits => random,7 = 0
	CPI random,70                   ; Compare random register to 70
	BRSH LSFR270                    ; If it's equal or bigger than 70 use LSFR
	RJMP food                       
LSFR270 :
	MOV R16, random                 ; Clone random to R16                    ex : R16 = 0b01111110
	MOV R19, random                 ; Clone random to R19                         R17 = 0b01111110
	LSR random                      ; Shift to the right random                   random = 0b00111111
	BST R16,0					    ; Take the first (LSB) bit of R16                   T = 0
	BLD random,6                    ; Put this at seventh place of random         random = 0b00111111
	BLD R19,6                       ; Same for R19                                R17 = 0b00111110
	EOR R19,R16                     ; R19 = R16 xor R19                           R17 = 0b01000000
	BST R19,6                       ; Take the seventh bit of R19                 T = 1
	BLD random,5                    ; Put this at the sixth place of random       random = 0b00111111
	RJMP generate                   ; Test if the new random is smaller than 70

food :
	LDI bytefood, 0x80                   ; Set one bit on the byte
	LDI XL,0x00
	ADD XL,random
	LD R25,X
	AND R25,bytefood				; Checkin if the generated position of the fruit is free.
	CPI R25,0						; Compare Register with Immediate
	BRNE LSFR270
	LDI YL,0x00                     ; Begin Y = 0x0200
	ADD YL,random				    ; Add it the random number smaller than 70
	ST Y,bytefood			      	    ; Put the value pointed by Y

LDI direction,6						;Initial direction (right) of the snake


InitKeyboard:
    ; Configure input pin PD0 
	LDI R16,0xFF
	OUT DDRD,R16
	OUT PORTD,R16               ; Transition of PIND (intermediate state)

	LDI R16,0xF0		        ; PIND 7:4 are outputs and 3:0 are inputs
	OUT DDRD,R16
	LDI R16,0x0F				; PIND 3:0 have pull-up resistor
	OUT PORTD,R16
	
Main:
/*
 * The Main is responsible for reading user's inputs on the keyboard.
 */
	SBIS PIND,0					; Skip if Bit in I/O Register is Set
	RJMP restart
	SBIS PIND,1	    
	RJMP right
	SBIS PIND,2
	RJMP upOrDown
	SBIS PIND,3
	RJMP left
	RJMP Main

restart :
/*
 * Bottons on the first column from the right are reponsible for pausing and resterting the game.
 */

	; Transition of PIND (intermediate state)
	LDI R16,0xFF
	OUT DDRD,R16
	OUT PORTD,R16				

	; Iversion of the inputs and outputs of the keyboard
	LDI R16,0x0F
	OUT DDRD,R16
	LDI R16,0xF0
	OUT PORTD,R16
	NOP

	; If the player press' D the game pauses
	LDI R16,0
	SBIS PIND,5
	STS TIMSK1,R16				; desable timer1 interrupt

	; If the player press' E the pause is over. 
	LDI R16,1
	SBIS PIND,6
	STS TIMSK1,R16				; enable timer1 interrupt

	RJMP InitKeyboard

right:
/*
 * Sets the direction of the sprite to the right.
 */

	; Transition of PIND (intermediate state)
	LDI R16,0xFF
	OUT DDRD,R16
	OUT PORTD,R16				
	
	; Iversion of the inputs and outputs of the keyboard
	LDI R16,0x0F
	OUT DDRD,R16
	LDI R16,0xF0
	OUT PORTD,R16
	NOP

	SBIS PIND,5				; If 3 is pressed direction is set to down
	LDI direction,6
	
	RJMP InitKeyboard

upOrDown:
/*
 * Sets the direction of the sprite up or down.
 */

	; Transition of PIND (intermediate state)
	LDI R16,0xFF
	OUT DDRD,R16
	OUT PORTD,R16

	; Iversion of the inputs and outputs of the keyboard
	LDI R16,0x0F
	OUT DDRD,R16
	LDI R16,0xF0
	OUT PORTD,R16
	NOP

	SBIS PIND,4				; If 0 is pressed direction is set to down
	LDI direction,2
	SBIS PIND,6				; If 5 is pressed direction is set to up
	LDI direction,8

	RJMP InitKeyboard

left :
/*
 * Sets the direction of the sprite to the left.
 */

	; Transition of PIND (intermediate state)
	LDI R16,0xFF
	OUT DDRD,R16
	OUT PORTD,R16

	; Iversion of the inputs and outputs of the keyboard
	LDI R16,0x0F
	OUT DDRD,R16
	LDI R16,0xF0
	OUT PORTD,R16
	NOP

	SBIS PIND,5				; If 1 is pressed direction is set to down
	LDI direction,4

	RJMP InitKeyboard


moveRight:
/*
 * The horizontal movement is done throught rotation of the byte where is located the sprite.
 * If the carry of the rotation is set then the sprite has to switch to the next 
 * LED module according to the direction of its movement.
 */
	
	ROR bytesnake						; Horisontal diplacement
	BRCC isZero

	; The carry bit is set so we've got to change the rectangle to the one on the right 

	ST Z,bytesnake						; Write bytesnake to the current Z
	ROR bytesnake						; Rotating R17 here puts back the carry into the bit sequence
	LDI R16,65							; We've got to check if we reached the screen boundary

	; Check if the sprite is on the upper right LED module. 
	CheckWall5:							; Addresses 05,10,15,20,25,30,35,40,45,50,55,60,65 has to be checked
		CP ZL,R16						; Compare Rd - Rr
		BRNE notLineX5
	ADIW Z,4							; Sprite switch to the oder side of the screen.
	ST Z,bytesnake						; Write the sprite to the next address.
	CLC
	RJMP notDown
	notLineX5:
		SUBI R16,5
		BRGE CheckWall5

	; The sprite doesn't change the side of the seen
	ST -Z,bytesnake						; Write the sprite to the next address. 
	CLC
	RJMP notDown						; Finish the move.
	isZero:
		ST Z,bytesnake					; Horisontal diplacement
		RJMP notDown					; Finish the move.
	

moveLeft:
	/*
	 * The horizontal movement is done throught rotation of the byte where is located the sprite.
	 * If the carry of the rotation is set then the sprite has to switch to the next 
	 * LED module according to the direction of its movement.
	 */

	ROL bytesnake						; Horisontal diplacement
	BRCC noCarry

	; The carry bit is set so we've got to change the rectangle to the one on the left
	ST Z,bytesnake						; Write bytesnake to the current Z
	ROL bytesnake						; Rotating R17 here puts back the carry into the bit sequence
							
	LDI R16,69							; We've got to check if we reached the screen boundary
	CheckWall9:							; Addresses 4,9,14,19,24,29,34,39,44,49,54,59,64,69 has to be checked
		CP ZL,R16						; Compare Rd - Rr
		BRNE notLineX9
	SBIW Z,4							; Sprite switch to the oder side of the screen.
	ST Z,bytesnake						; Write the sprite to the next address.
	CLC
	RJMP notDown						; Finish the move.
	notLineX9:
		SUBI R16,5
		BRGE CheckWall9					; Finish the move.

	; The sprite doesn't change the side of the seen
	ADIW Z,1
	ST Z,bytesnake
	CLC
	RJMP notDown						; Finish the move.
	noCarry:
		ST Z,bytesnake					; Horisontal diplacement
		RJMP notDown


Timer1OverflowInterrupt:
/*
This interrupt moves the spread. It takes the direction set by the player and runs the corresponding branch.
*/
	PUSH YL
	PUSH XL
	PUSH R16
	PUSH R19

	LDI ZH,0x01

	CPI direction,6						; Compare Register with Immediate
	BRNE notRight
	RJMP moveRight
	
	notRight:
		CPI direction,4					; Compare Register with Immediate
		BRNE notLeft
	RJMP moveLeft

	notLeft:
		CPI direction,8					; Compare Register with Immediate
		BRNE notUp

	;Vertical movement up-------------------------------
	LDI R16,0
	ST Z,R16							; Set Z to 0

	MOV R19,ZL
	CPI ZL,60							; Compare ZL to 60 if higher then change the rect
	BRLO ChangeBlockUp					; Branch if Lower
	LDI R16,65
	SUB ZL,R16							;Subtract 65 from ZL but don't worry we add 10 at the end!
	CPI R19,65							;Compare the original ZL with 75 to see if we are at the top of the screen
	BRLO ChangeBlockUp					; Branch if Lower
	SBIW ZL,10
	ChangeBlockUp:
		ADIW ZL,10						; Subtract 10 from Z
		LDI ZH,0x01
		ST Z,bytesnake
	RJMP notDown
	
	notUp:
		CPI direction,2					; Compare Register with Immediate
		BRNE notDown
	;Vertical movement down-------------------------------
	LDI R16,0
	ST Z,R16							; Set Z to 0

	MOV R19,ZL							; Value of ZL to R19
	CPI ZL,10							; Compare ZL to 10 if smaller then change the rect
	BRSH ChangeBlock					; Branch if Same or Higher
	LDI R16,65						
	ADD ZL,R16							;Adding 65 to ZL since it is lower than 20
	CPI R19,5							;Compare the original ZL with 5 to see if we are at the bottom of the screen
	BRSH ChangeBlock					; Branch if Same or Higher
	ADIW ZL,10							;We're at the bottom so ZL = ZL + 65 + 10
	ChangeBlock:
		SBIW ZL,10							; Subtract 10 from Z
		LDI ZH,0x01
		ST Z,bytesnake

	notDown:
	/*
	This small section is responisible for eating an obstacle/object.
	*/
	MOV XL,ZL
	LD R19,X
	AND R19,bytesnake					; Check if the sprite is on the wall.
	CPI R19,0
	BRNE Gameover
	MOV YL,ZL
	LD R19,Y
	SUB R19,bytesnake					; Check if the sprite is on the fruit .
	BRNE noOnFood

	ST Y,R19         

	; Updating the score
	LDI R16,1
	ADD score1,R16
	MOV R16,score1
	CPI R16,9
	BRNE speedTurn 
	LDI R16,0
	MOV score1,R16
	LDI R16,1
	ADD score2,R16

speedTurn:
	; Turning up the speed
	LDI R16,15
	LDI R19,0xF0
	CPSE speed,R19						; Compare, Skip if Equal -> so we reached maximum speed
	ADD speed,R16

	            
	LSFR270new :
		MOV R16, random                 ; Clone random to R16                    ex : R16 = 0b01111110
		MOV R19, random                 ; Clone random to R19                         R17 = 0b01111110
		LSR random                      ; Shift to the right random                   random = 0b00111111
		BST R16,0					    ; Take the first bit of R16                   T = 0
		BLD random,6                    ; Put this at seventh place of random         random = 0b00111111
		BLD R19,6                       ; Same for R19                                R17 = 0b00111110
		EOR R19,R16                     ; R19 = R16 xor R19                           R17 = 0b01000000
		BST R19,6                       ; Take the seventh bit of R19                 T = 1
		BLD random,5                    ; Put this at the sixth place of random       random = 0b00111111
	generatenew :
		ANDI random,0b011111111         ; We want a random number < 70 => we need 7 bits => random,7 = 0
		CPI random,70                   ; Compare random register to 70
		BRSH LSFR270new                 ; If it's equal or bigger than 70 use LSFR
		LDI XL,0x00
		ADD XL,random
		LD R16,X
		AND R16,bytesnake				; Check if the fruits is generated on the sprite.
		CPI R16,0
		BRNE LSFR270new 
	foodnew : 
		LDI YL,0x00                     ; Begin Y = 0x0200
		ADD YL,random				    ; Add it the random number smaller than 70
		ST Y,bytesnake			      	    ; Put the value pointed by Y
	noOnFood:

		;Setting the TCNT1 

		LDI R16,0xFF	
		STS TCNT1H,speed
		STS TCNT1L,R16



		POP R19
		POP R16
		POP XL
		POP YL
		RETI

Gameover :
	RJMP mazeGame

Timer0OverflowInterrupt:
/*
The goal of the interrupt is to refresh the screen,
*/
;Initialising Z
PUSH R16
PUSH R17						;save R17 on the stack
PUSH R18
PUSH R19
PUSH R22
PUSH R25

PUSH ZL
PUSH YL
/* 
We use 2 poiners registers for the screen Z contains the snake while Y the object the snake can eat.
*/
LDI ZL,0x00
LDI ZH,0x01						;init Z to point do address 0x0100
LD R17,Z+						;write value from address pointed by Z to Ra and auto-increse Z pointer

LDI YL,0x00
LDI YH,0x02						;init Z to point do address 0x0100
LD R18,Y+						;write value from address pointed by Z to Ra and auto-increse Z pointer

LDI XL,0x00
LDI XH,0x03						
LD R25,X+						

;Rows counter
LDI R22,0x02

Send1Row:
	;Byte counter
	LDI R20,8
	;Columns counter
	LDI R16,80	
	CLC
	COLUMNS:
		CBI PORTB,3							;Set PB3 low
		ROR R17								;Rotate R17 right througth carry
		BRCC NOPB3							;Branch if carry is 0
		SBI PORTB,3							;carry is 1 => set PB3 high
	NOPB3:
		ROR R18								;Rotate R18 right througth carry
		BRCC maze						;Branch if carry is 0
		SUBI toggle,1
		BRNE maze
		SBI PORTB,3							;carry is 1 => set PB3 high
		LDI toggle,3
	maze:
		ROR R25								;Rotate R18 right througth carry
		BRCC noObstacle						;Branch if carry is 0
		SBI PORTB,3							;carry is 1 => set PB3 high
		
	
	noObstacle:
		CBI PORTB,5							;Set PB5 low
		SBI PORTB,5							;Set PB5 high
		DEC R20
		BRNE CONTINUE						;Branch if not all the bits have been analysed
								
	LDI R20,8
	LD R17,Z+							;write value from address pointed by Z to Ra and auto-increse Z pointer
	LD R18,Y+
	LD R25,X+

	CONTINUE:
		DEC R16
		BRNE COLUMNS

	LDI R16,8	;Rows counter
	CLC
	ROWS:
		CBI PORTB,3							;Set PB3 low
		ROR R22								;Rotate R22 right througth carry
		BRCC NOONE							;Branch if carry is 0
		SBI PORTB,3							;carry is 1 => set PB3 high
	NOONE:
		CBI PORTB,5							;Set PB5 low
		SBI PORTB,5							;Set PB5 high
		DEC R16
		BRNE ROWS
	
	notRow8:
		CBI PORTB,4								;Set PB4 low
		SBI PORTB,4								;Set PB4 high

	;PB4 delay parameters
	LDI R16,9								;Setting up the delay between SBI PB4 and CBI PB4
	LDI R20,255
	time1:
		time2:
			DEC R16
			BRNE time2
			LDI R16,9
		DEC R20
	BRNE time1
	LDI R20,255
	CBI PORTB,4								;Set PB4 low

	TST R22									;Check if R22 = 0x00
	BRNE Send1Row							;If R22 != 0x00 plot next row if not, stop the time interrupt
	
	;Setting the TCNT0 value at 312Hz
	LDI R16,56	
	OUT TCNT0,R16

	POP YL
	POP ZL

	POP R25
	POP R22
	POP R19
	POP R18
	POP R17									;restore R17 from the stack
	POP R16
	CLC
	RETI

// ---------------------- Game over --------------------------------------------
mazeGame :
	LDI XL,0x00
	LDI XH,0x01
	LDI R16,13								;G
	ST X+,R16
	LDI R16,11								;A
	ST X+,R16
	LDI R16,14								;M
	ST X+,R16
	LDI R16,12								;E
	ST X+,R16
	LDI R16,10								;space
	ST X+,R16
	ST X+,R16
	MOV R16,score2
	ST X+,R16
	MOV R16,score1
	ST X+,R16
	LDI R16,15								;O
	ST X+,R16
	LDI R16,20								;V
	ST X+,R16
	LDI R16,12								;E
	ST X+,R16
	LDI R16,17								;R
	ST X+,R16
	LDI R16,10								;space
	ST X+,R16
	LDI R16,16								;P
	ST X+,R16
	LDI R16,19								;T
	ST X+,R16
	LDI R16,18								;S
	ST X,R16

startGame :
	LDI R16,6								; Count from 6 to 0 to have all the flash line
	LDI R18,0b01000000						; Send the row

displayGame :
	LDI XL,0x10
	LDI XH,0x01
	LDI R17,8
	LDI R19,16
	 
blocksloopGame :
	LDI ZL,low(CharTable << 1)
	LDI ZH,high(CharTable << 1)
	LD R21,-X
	MUL R21,R17								; multiply by eight to have the first element of the line R1:R0 <- Rd x Rr
	MOV R21,R0								; Move Between Registers Rd <- Rr
	ADD R21,R16								; Add row to have the byte of the line
	ADC ZL,R21								; Add with Carry two Registers
	BRCC ncGame								; Branch if carry cleared
	LDI R21,1
	ADD ZH,R21
	ncGame :
		LPM R21,Z							; Load the byte at the position stored in Z in R21
		LDI R20,5							; The diplayed symbol is 5 bits large.

blockGame :
	ROR R21									; shift to the right R21 
	BRCC turnoffGame
	SBI PORTB,3								; If it's a one turn on the LED

turnoffGame :
	SBI PORTB,5
	CBI PORTB,5
	CBI PORTB,3
	DEC R20
	BRNE blockGame

DEC R19
BRNE blocksloopGame
MOV R21,R18

rowonGame :
	ROL R21
	BRCC rowoffGame
	SBI PORTB,3

rowoffGame :
	SBI PORTB,5
	CBI PORTB,5
	CBI PORTB,3
	DEC R17									; Decrement the rows
	BRNE rowonGame

SBI PORTB,4
LDI R19,255
LDI R20,9
wait1Game:
	wait2Game:
		DEC R20
		BRNE wait2Game
	LDI R20,9
	DEC R19
	BRNE wait1Game
CBI PORTB,4

DEC R16
LSR R18										; Logical Shift Right
BREQ startGame
RJMP displayGame

CharTable:
/*
 *Every character in the flash memory by using the .db directive.
 */
.db 0b00011111,0b00010001,0b00010001,0b00010001,0b00010001,0b00010001,0b00011111,0b00000000 ; 0
.db 0b00000100,0b00001100,0b00010100,0b00000100,0b00000100,0b00000100,0b00011111,0b00000000 ; 1
.db 0b00011111,0b00010001,0b00000001,0b00000010,0b00000100,0b00001000,0b00011111,0b00000000 ; 2
.db 0b00011111,0b00000001,0b00000001,0b00011111,0b00000001,0b00000001,0b00011111,0b00000000 ; 3
.db 0b00010001,0b00010001,0b00010001,0b00011111,0b00000001,0b00000001,0b00000001,0b00000000 ; 4
.db 0b00011111,0b00010000,0b00010000,0b00011111,0b00000001,0b00000001,0b00011111,0b00000000 ; 5
.db 0b00011111,0b00010000,0b00010000,0b00011111,0b00010001,0b00010001,0b00011111,0b00000000 ; 6
.db 0b00011111,0b00010001,0b00000001,0b00000010,0b00000100,0b00001000,0b00010000,0b00000000 ; 7 
.db 0b00011111,0b00010001,0b00010001,0b00011111,0b00010001,0b00010001,0b00011111,0b00000000 ; 8
.db 0b00011111,0b00010001,0b00010001,0b00011111,0b00000001,0b00000001,0b00011111,0b00000000 ; 9
.db 0b00000000,0b00000000,0b00000000,0b00000000,0b00000000,0b00000000,0b00000000,0b00000000 ; nothing 10
.db 0b00000100,0b00001010,0b00010001,0b00010001,0b00011111,0b00010001,0b00010001,0b00000000 ;A => 11
.db 0b00011111,0b00010000,0b00010000,0b00011111,0b00010000,0b00010000,0b00011111,0b00000000 ;E => 12
.db 0b00011111,0b00010000,0b00010000,0b00010111,0b00010001,0b00010001,0b00011111,0b00000000 ;G => 13
.db 0b00010001,0b00011011,0b00010101,0b00010001,0b00010001,0b00010001,0b00010001,0b00000000 ;M => 14
.db 0b00011111,0b00010001,0b00010001,0b00010001,0b00010001,0b00010001,0b00011111,0b00000000 ;O => 15
.db 0b00011111,0b00010001,0b00010001,0b00011111,0b00010000,0b00010000,0b00010000,0b00000000 ;P => 16
.db 0b00011111,0b00010001,0b00010001,0b00011111,0b00010100,0b00010010,0b00010001,0b00000000 ;R => 17
.db 0b00011111,0b00010000,0b00010000,0b00011111,0b00000001,0b00000001,0b00011111,0b00000000 ;S => 18
.db 0b00011111,0b00000100,0b00000100,0b00000100,0b00000100,0b00000100,0b00000100,0b00000000 ;T => 19
.db 0b00010001,0b00010001,0b00010001,0b00010001,0b00010001,0b00001010,0b00000100,0b00000000 ;V => 20

