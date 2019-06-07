;
;  Alspa ACI-2 version, 4 MHz Z80
;
;  PCGET - This CP/M program receives a file from a PC via a serial 
;  port and writes it to a file on the CP/M system. The file transfer uses
;  the XMODEM protocol. 
;
;  Note this program is gutted from the Ward Christenson Modem program.
;
;  Hacked together by Mike Douglas for the Horizon Computer
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

;  Transfer related equates

SOH	EQU	1
EOT	EQU	4
ACK	EQU	6
NAK	EQU	15H
CTRLC	EQU	3		;Control-C
LF	EQU	10
CR	EQU	13

	ORG	100H

;  Verify a file name was specified

	lda	PARAM1		;A=1st character of parameter 1
	cpi	' '		;make sure file name present
	jnz	haveFn		;yes, have a file name
	lxi	d,mHelp		;display usage message
	mvi	c,PRINT
	call	BDOS
	ret			;return to CPM

;  See if an alternate port was specified

haveFn	mvi	b,CONDR		;assume port a used
	lxi	d,mSendC	;port a send message
	lda	PARAM2		;A=1st character of parameter 2
	ani	5fh		;force upper case
	cpi	'M'		;Modem port specified?
	jz	usePtM		;Yes, use it
	cpi	'P'		;Printer port specified?
	jnz	doXfer		;no, go do the transfer
	mvi	b,PRINTDR	;Use printer port
	lxi	d,mSendP	;Printer port send message
	call	initP
	jmp	doXfer
usePtM	mvi	b,MODEMDR	;use modem port
	lxi	d,mSendM	;Modem port send message
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
	
;  doXfer - Switch to local stack and do the transfer.

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
	sta	SECTNO		;init sector number to zero
	MVI	C,PRINT		;print the send message
	CALL	BDOS		;PRINT ID MESSAGE

;  GOBBLE UP GARBAGE CHARS FROM THE LINE

purge	MVI	B,1		;times out after 1 second if no data
	CALL	RECV
	jc	RECEIVE$FILE	;line is clear, go receive the file
	cpi	CTRLC		;exit if abort requested
	jz	abort
	jmp	purge
;
;**************RECEIVE FILE****************
;
RECEIVE$FILE:
	CALL	ERASE$OLD$FILE
	CALL	MAKE$NEW$FILE
	MVI	A,NAK
	CALL	SEND		;SEND NAK

RECV$LOOP:
RECV$HDR:
	MVI	B,3		;3 SEC TIMEOUT
	CALL	RECV
	JNC	RHNTO		;NO TIMEOUT

RECV$HDR$TIMEOUT:
RECV$SECT$ERR:			;PURGE THE LINE OF INPUT CHARS
	MVI	B,1		;1 SEC W/NO CHARS
	CALL	RECV
	JNC	RECV$SECT$ERR 	;LOOP UNTIL SENDER DONE
	MVI	A,NAK
	CALL	SEND		;SEND NAK
	JMP	RECV$HDR

;GOT CHAR - MUST BE SOH OR CTRL-C TO ABORT

RHNTO:	CPI	SOH
	JZ	GOT$SOH
	cpi	CTRLC		;control-c to abort?
	jz	abort
	CPI	EOT
	JZ	GOT$EOT
	JMP	RECV$SECT$ERR

GOT$SOH:
	MVI	B,1
	CALL	RECV
	JC	RECV$HDR$TIMEOUT
	MOV	D,A		;D=BLK #
	MVI	B,1
	CALL	RECV		;GET CMA'D SECT #
	JC	RECV$HDR$TIMEOUT
	CMA
	CMP	D		;GOOD SECTOR #?
	JZ	RECV$SECTOR
	JMP	RECV$SECT$ERR

;  Receive Sector

RECV$SECTOR:
	MOV	A,D		;GET SECTOR #
	STA	RSECTNO
	MVI	C,0		;INIT CKSUM
	LXI	H,80H		;POINT TO BUFFER
RECV$CHAR:
	MVI	B,1		;1 SEC TIMEOUT
	CALL	RECV		;GET CHAR
	JC	RECV$HDR$TIMEOUT
	MOV	M,A		;STORE CHAR
	INR	L		;DONE?
	JNZ	RECV$CHAR

;VERIFY CHECKSUM

	MOV	D,C		;SAVE CHECKSUM
	MVI	B,1		;TIMEOUT
	CALL	RECV		;GET CHECKSUM
	JC	RECV$HDR$TIMEOUT
	CMP	D		;CHECK
	JNZ	RECV$SECT$ERR
;
;GOT A SECTOR, WRITE IF = 1+PREV SECTOR
;
	LDA	RSECTNO
	MOV	B,A		;SAVE IT
	LDA	SECTNO		;GET PREV
	INR	A		;CALC NEXT SECTOR #
	CMP	B		;MATCH?
	JNZ	DO$ACK

;GOT NEW SECTOR - WRITE IT

	LXI	D,FCB
	MVI	C,WRITE
	CALL	BDOS
	ORA	A
	JNZ	WRITE$ERROR
	LDA	RSECTNO
	STA	SECTNO		;UPDATE SECTOR #
DO$ACK	MVI	A,ACK
	CALL	SEND
	JMP	RECV$LOOP

WRITE$ERROR:
	CALL	ERXIT
	DB	13,10,10,'Error Writing File',13,10,'$'

GOT$EOT:
	MVI	A,ACK		;ACK THE EOT
	CALL	SEND
	LXI	D,FCB
	MVI	C,CLOSE
	CALL	BDOS
	INR	A
	JNZ	XFER$CPLT
	CALL	ERXIT
	DB	13,10,10,'Error Closing File',13,10,'$'
;
ERASE$OLD$FILE:
	LXI	D,FCB
	MVI	C,SRCHF		;SEE IF IT EXISTS
	CALL	BDOS
	INR	A		;FOUND?
	RZ			;NO, RETURN
ERAY:	LXI	D,FCB
	MVI	C,ERASE
	CALL	BDOS
	RET
;
MAKE$NEW$FILE:
	LXI	D,FCB
	MVI	C,MAKE
	CALL	BDOS
	INR	A		;FF=BAD
	RNZ			;OPEN OK

;DIRECTORY FULL - CAN'T MAKE FILE
	CALL	ERXIT
	db	13,10,10,"Error - Can't Make File",13,10
	db	"(directory must be full)",13,10,'$'
;
; S U B R O U T I N E S
;
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

;-----------------------------------------
;  messages
;-----------------------------------------

mSendC	db	'Send file using XMODEM on CONSOLE port (port 2)...$'
mSendM	db	'Send file using XMODEM on MODEM port (port 4)...$'
mSendP	db	'Send file using XMODEM on PRINTER port (port 0)...$'
mHelp	db	CR,LF,'PCGET v1.0.1 for Alspa ACI-2',CR,LF,LF
	db	'Receives a file from a PC through a serial port',CR,LF
	db	'using the XMODEM protocol.',CR,LF,LF
	db	'Usage: PCGET file.ext [MP]',CR,LF
	db	'   CONSOLE port (port 2) used by default',CR,LF
	db	'   Specify M to use MODEM port (port 4)',CR,LF
	db	'   Specify P to use PRINTER port (port 0)',CR,LF,'$'

;DONE - CLOSE UP SHOP

XFER$CPLT:
	CALL	ERXIT
	DB	13,10,10,'Transfer Complete',13,10,'$'

abort:	call	ERXIT
	db	13,10,10,'Transfer Aborted',13,10,'$'

	DS	40	;STACK AREA
STACK	DS	2	;STACK POINTER
RSECTNO	DS	1	;RECEIVED SECTOR NUMBER
SECTNO	DS	1	;CURRENT SECTOR NUMBER 
serPort	ds	1	;I/O address of serial port to use
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
FCB	EQU	5CH	;DEFAULT FCB
PARAM1	EQU	FCB+1	;COMMAND LINE PARAMETER 1 IN FCB
PARAM2	EQU	PARAM1+16	;COMMAND LINE PARAMETER 2
	END
