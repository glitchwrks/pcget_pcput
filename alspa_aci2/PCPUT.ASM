;
;  Alspa ACI-2 version, 4 MHz Z80
;
;  PCPUT - This CP/M program sends a file from a CP/M system to a PC
;  via a serial The file transfer uses the XMODEM protocol. 
;
;  Note this program is gutted from the Ward Christenson Modem program.
;
;  Hacked together by Mike Douglas for the VG Bitstreamer II board
;  Updated by Glitch Works for the Alspa ACI-2
;
;  Glitch Works customization and cleanup is:
;
;  Copyright (c) 2019 The Glitch Works
;  http://www.glitchwrks.com/
;
;  Glitch Works customizations are released under the GNU GPLv3.
;
;	Ver	Date	   Desc
;   	---    --------    -----------------------------------------------
;	1.0.1  2019-06-07  Customized for the Alspa ACI-2
;
;	1.0    10/7/15	   Initial version. This code is almost the same 
;			   as the Vector Graphic version as both use the
;			   same 8251 ports for serial I/O.

;  Serial Port Equates

CONCR	EQU	3		;Console port control register (port 2)
CONDR	EQU	2		;Console port data register
MODEMCR	EQU	5		;Modem port control register (port 4)
MODEMDR	EQU	4		;Modem port data register
PRINTCR	EQU	1		;Printer port control register (port 0)
PRINTDR EQU	0		;Printer port data register

XMTMASK	EQU	1		;MASK TO ISOLATE XMIT READY BIT
XMTRDY	EQU	1		;VALUE WHEN READY
RCVMASK	EQU	2		;MASK TO ISOLATE RECEIVE READY BIT
RCVRDY	EQU	2		;VALUE WHEN READY

ERRLMT	EQU	5		;MAX ALLOWABLE ERRORS

;DEFINE ASCII CHARACTERS USED

SOH	EQU	1
EOT	EQU	4
ACK	EQU	6
NAK	EQU	15H
CTRLC	EQU	3		;Control-C
LF	EQU	10
CR	EQU	13

	org	100h

;  Verify a file name was specified

	lda	PARAM1		;A=1st character of parameter 1
	cpi	' '		;make sure file name present
	jnz	haveFn		;yes, have a file name
	lxi	d,mHelp		;display usage message
	mvi	c,PRINT
	call	BDOS
	ret			;return to CPM

;  See if an alternate port was specified

haveFn	mvi	b,CONDR		;assume CONSOLE port used
	lxi	d,mRcvC		;Console port send message
	lda	PARAM2		;A=1st character of parameter 2
	ani	5fh		;force upper case
	cpi	'M'		;Modem port specified?
	jz	usePtM		;Yes, use it
	cpi	'P'		;Printer port specified?
	jnz	doXfer		;no, go do the transfer
	mvi	b,PRINTDR	;Use printer port
	lxi	d,mRcvP		;Printer port send message
	call	initP
	jmp	doXfer
usePtM	mvi	b,MODEMDR	;use modem port
	lxi	d,mRcvM		;Modem port send message
	call	initM		;Initialize MODEM port
	jmp	doXfer

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;initM -- Initialize the MODEM port
;
;This routine ensures that the MODEM port is initialized
;and in a sane state. Sets 8251A for x16 clock, 8N1
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
initM:	MVI	A,0
	OUT	MODEMCR
	OUT	MODEMCR
	OUT	MODEMCR
	MVI	A,40H
	OUT	MODEMCR
	MVI	A,4EH
	OUT	MODEMCR
	MVI	A,37H
	OUT	MODEMCR
	RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;initP -- Initialize the PRINTER port
;
;This routine ensures that the PRINTER port is initialized
;and in a sane state. Sets 8251A for x16 clock, 8N1
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
initP:	MVI	A,0
	OUT	PRINTCR
	OUT	PRINTCR
	OUT	PRINTCR
	MVI	A,40H
	OUT	PRINTCR
	MVI	A,4EH
	OUT	PRINTCR
	MVI	A,37H
	OUT	PRINTCR
	RET

;  doXfer - Switch to local stack and do the transfer

doXfer	mov	a,b		;a=address of serial port to use
	sta	rcvSDR		;modify IN instruction for data register
	sta	sndSDR		;modify OUT instruction for data register
	inr	a		;a=serial port control register address
	sta	rcvSCR		;modify IN for control register in RECV
	sta	sndSCR		;modify IN for control register in SEND
	LXI	H,0		;HL=0
	DAD	SP		;HL=STACK FROM CP/M
	SHLD	STACK		;..SAVE IT
	LXI	SP,STACK	;SP=MY STACK
	xra	a		
	sta	SECTNO		;initialize sector number to zero
	PUSH	D		;Save message string pointer
	CALL	OPEN$FILE	;OPEN THE FILE
	POP	D		;Restore message string pointer
	MVI	C,PRINT
	CALL	BDOS		;PRINT ID MESSAGE

;  GOBBLE UP GARBAGE CHARS FROM THE LINE

purge	MVI	B,1		;times out after 1 second if no data
	CALL	RECV
	jc	lineClr		;line is clear, go wait for initial NAK
	cpi	CTRLC		;exit if abort requested
	jz	abort
	jmp	purge

; WAIT FOR INITIAL NAK, THEN SEND THE FILE
	
lineClr	xra	a		;clear crc flag = checksum mode
	sta	crcFlag
WAITNAK	MVI	B,1		;TIMEOUT DELAY
	CALL	RECV
	JC	WAITNAK
	cpi	CTRLC		;abort requested?
	jz	abort
	CPI	NAK		;NAK RECEIVED?
	jz	SENDB		;yes, send file in checksum mode
	cpi	'C'		;'C' for CRC mode received?
	JNZ	WAITNAK		;no, keep waiting
	sta	crcFlag		;set CRC flag non-zero = true
				;fall through to start the send operation
;
;*****************SEND A FILE***************
;

;READ SECTOR, SEND IT

SENDB	CALL	READ$SECTOR
	LDA	SECTNO		;INCR SECT NO.
	INR	A
	STA	SECTNO

;SEND OR REPEAT SECTOR

REPTB	MVI	A,SOH
	CALL	SEND
	LDA	SECTNO
	CALL	SEND
	LDA	SECTNO
	CMA
	CALL	SEND
	lxi	h,0		;init crc to zero
	shld	crc16
	mov	c,h		;init checksum in c to zero
	LXI	H,80H
SENDC	MOV	A,M
	CALL	SEND
	call	calCrc		;update CRC
	INX	H
	MOV	A,H
	CPI	1		;DONE WITH SECTOR?
	JNZ	SENDC

; Send checksum or CRC based on crcFlag

	lda	crcFlag		;crc or checksum?
	ora	a
	jz	sndCsum		;flag clear = checksum
	lda	crc16+1		;a=high byte of CRC
	call	SEND		;send it
	lda	crc16		;a=low byte of crc
	jmp	sndSkip		;skip next instruction	
sndCsum	mov	a,c		;send the checksum byte
sndSkip	call	SEND

;GET ACK ON SECTOR

	MVI	B,4		;WAIT 4 SECONDS MAX
	CALL	RECV
	JC	REPTB		;TIMEOUT, SEND AGAIN

;NO TIMEOUT SENDING SECTOR

	CPI	ACK		;ACK RECIEVED?
	JZ	SENDB		;..YES, SEND NEXT SECT
	cpi	CTRLC		;control-c to abort?
	jz	abort
	JMP	REPTB		;PROBABLY NAK - TRY AGAIN
;
;
; S U B R O U T I N E S
;
;OPEN FILE
OPEN$FILE LXI	D,FCB
	MVI	C,OPEN
	CALL	BDOS
	INR	A		;OPEN OK?
	RNZ			;GOOD OPEN
	CALL	ERXIT
	DB	13,10,"Can't Open File",13,10,'$'

; - - - - - - - - - - - - - - -
;EXIT PRINTING MESSAGE FOLLOWING 'CALL ERXIT'
ERXIT	POP	D		;GET MESSAGE
	MVI	C,PRINT
	CALL	BDOS		;PRINT MESSAGE
EXIT	LHLD	STACK		;GET ORIGINAL STACK
	SPHL			;RESTORE IT
	RET			;--EXIT-- TO CP/M

; - - - - - - - - - - - - - - -
;MODEM RECV
;-------------------------------------
RECV	PUSH	D		;SAVE
MSEC	lxi	d,63		;63 cycles, 4.032ms/wrap*248=1s (4MHz)

rcvSCR	equ	$+1		;address of I/O port for the following IN
MWTI	IN	CONCR		;(10)
	ANI	RCVMASK		;(7)
	CPI	RCVRDY		;(7)
	JZ	MCHAR		;(10) GOT CHAR

; no character present, decrement timeout

	cpi	0		;(7) waste some time
	cpi	0		;(7) waste some time
	DCR	E		;(5) COUNT DOWN
	JNZ	MWTI		;(10) FOR TIMEOUT
	DCR	D		;do msb every 256th time
	JNZ	MWTI
	DCR	B		;DCR # OF SECONDS
	JNZ	MSEC

;MODEM TIMED OUT RECEIVING

	POP	D		;RESTORE D,E
	STC			;CARRY SHOWS TIMEOUT
	RET

;GOT MODEM CHAR

rcvSDR	equ	$+1		;address of I/O port for the following IN
MCHAR	IN	CONDR
	POP	D		;RESTORE DE
	PUSH	PSW		;CALC CHECKSUM
	ADD	C
	MOV	C,A
	POP	PSW
	ORA	A		;TURN OFF CARRY TO SHOW NO TIMEOUT
	RET

; - - - - - - - - - - - - - - -
;MODEM SEND CHAR ROUTINE
;----------------------------------
;
SEND	PUSH	PSW		;CHECK IF MONITORING OUTPUT
	ADD	C		;CALC CKSUM
	MOV	C,A

sndSCR	equ	$+1		;address of I/O port for the following IN
SENDW	IN	CONCR
	ANI	XMTMASK
	CPI	XMTRDY
	JNZ	SENDW
	POP	PSW		;GET CHAR

sndSDR	equ	$+1		;address of I/O port for the following IN
	OUT	CONDR
	RET

;
;FILE READ ROUTINE
;
READ$SECTOR:
	LXI	D,FCB
	MVI	C,READ
	CALL	BDOS
	ORA	A
	RZ
	DCR	A		;EOF?
	JNZ	RDERR

;EOF

	XRA	A
	STA	ERRCT
SEOT	MVI	A,EOT
	CALL	SEND
	MVI	B,3		;WAIT 3 SEC FOR TIMEOUT
	CALL	RECV
	JC	EOTTOT		;EOT TIMEOUT
	CPI	ACK
	JZ	XFER$CPLT

;ACK NOT RECIEVED

EOTERR	LDA	ERRCT
	INR	A
	STA	ERRCT
	CPI	ERRLMT
	JC	SEOT
	CALL	ERXIT
	db	13,10,10
	db	'No ACK received on EOT, but transfer is complete.',13,10,'$'

;
;TIMEOUT ON EOT
;
EOTTOT	JMP	EOTERR
;
;READ ERROR
;
RDERR	CALL	ERXIT
	DB	13,10,'File Read Error',13,10,'$'

;DONE - CLOSE UP SHOP

XFER$CPLT:
	CALL	ERXIT
	DB	13,10,10,'Transfer Complete',13,10,'$'

abort	call	ERXIT
	DB	13,10,10,'Transfer Aborted',13,10,'$'

;-----------------------------------------------------------------------------
; calCrc - update the 16-bit CRC with one more byte. 
;    (Copied from M. Eberhard)
; On Entry:
;   a has the new byte
;   crc16 is current except this byte
; On Exit:
;   crc16 has been updated
;   Trashes a,de
;-----------------------------------------------------------------------------
calCrc	push	b		;save bc, hl
	push	h
	lhld	crc16		;get CRC so far
	xra	h		;XOR into CRC top byte
	mov	h,a
	lxi	b,1021h		;bc=CRC16 polynomial
	mvi	d,8		;prepare to rotate 8 bits

; do 8 bit shift/divide by CRC polynomial

cRotLp	dad	h		;16-bit shift
	jnc	cClr		;skip if bit 15 was 0
	mov	a,h		;CRC=CRC xor 1021H
	xra	b
	mov	h,a
	mov	a,l
	xra	c
	mov	l,a
cClr	dcr	d
	jnz	cRotLp		;rotate 8 times

; save the updated CRC and exit

	shld	crc16		;save updated CRC
	pop	h		;restore hl, bc
	pop	b
	ret

;-----------------------------------------
;  messages
;-----------------------------------------

mRcvC	db	'Start XMODEM file receive on CONSOLE port (port 2) now...$'
mRcvM	db	'Start XMODEM file receive on MODEM port (port 4) now...$'
mRcvP	db	'Start XMODEM file receive on PRINTER port (port 0) now...$'
mHelp	db	CR,LF,'PCPUT v1.0.1 for Alspa ACI-2',CR,LF,LF
	db	'Transmits a file to a PC through a serial port',CR,LF
	db	'using the XMODEM protocol.',CR,LF,LF
	db	'Usage: PCPUT file.ext [MP]',CR,LF
	db	'   CONSOLE port (port 2) used by default',CR,LF
	db	'   Specify M to use MODEM port (port 4)',CR,LF
	db	'   Specify P to use PRINTER port (port 0)',CR,LF,'$'

; Data Area

	DS	40	;STACK AREA
STACK	DS	2	;STACK POINTER
SECTNO	DS	1	;CURRENT SECTOR NUMBER 
ERRCT	DS	1	;ERROR COUNT
crcFlag	ds	1	;non-zero if using CRC
crc16	ds	2	;computed crc

;
; BDOS EQUATES (VERSION 2)
;
RDCON	EQU	1
WRCON	EQU	2
PRINT	EQU	9
CONST	EQU	11	;CONSOLE STAT
OPEN	EQU	15	;0FFH=NOT FOUND
CLOSE	EQU	16	;   "	"
SRCHF	EQU	17	;   "	"
SRCHN	EQU	18	;   "	"
ERASE	EQU	19	;NO RET CODE
READ	EQU	20	;0=OK, 1=EOF
WRITE	EQU	21	;0=OK, 1=ERR, 2=?, 0FFH=NO DIR SPC
MAKE	EQU	22	;0FFH=BAD
REN	EQU	23	;0FFH=BAD
STDMA	EQU	26
BDOS	EQU	5
REIPL	EQU	0
FCB	EQU	5CH	;SYSTEM FCB
PARAM1	EQU	FCB+1	;COMMAND LINE PARAMETER 1 IN FCB
PARAM2	EQU	PARAM1+16	;COMMAND LINE PARAMETER 2
	END
