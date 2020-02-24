;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;PCGET.INC -- Receive files via XMODEM from a PC
;
;This is the core machine-independent library for PCGET
;implementations. It will not assemble in a meaningful
;way by itself.
;
;Copyright (c) 2015 Mike Douglas
;Copuright (c) 2020 The Glitch Works
;
;See LICENSE included in the project root for licensing
;information.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;NOTE: we currently have to include up a level due to a bug
;      in the A85 assembler. It doesn't maintain context
;      when INCLUDEing a file.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	INCLUDE "../COMMON.INC"	;Common equates

	ORG	100H

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;START -- Get ready and begin the transfer
;
;This routine checks for the presence of a filename. If no
;filename is supplied, a help message is printed and we
;exit.
;
;Calls out to HAVEFN in the machine-specific implementation
;when a filename is present, then jumps to DOXFER.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
START:	LDA	PARAM1		;A=1st character of parameter 1
	CPI	' '		;make sure file name present
	JZ	NOFN		;No filename
	CALL	HAVEFN		;Call HAVEFN, machine-specific implementation
	JMP	DOXFER		;Do the transfer

NOFN:	LXI	D,MHELP		;display usage message
	MVI	C,PRINT
	CALL	BDOS
	RET			;return to CPM

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;DOXFER -- Get ready and start transfer
;
;This routine sets up the control and data ports for the 
;selected serial port and begins the transfer.
;
;pre: B register contains address of serial data port
;pre: C register contains address of serial control port
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
DOXFER:	MOV	A,B		;B contains address of serial port to use
	STA	RCVSDR		;modify IN instruction for data register
	STA	SNDSDR		;modify OUT instruction for data register
	MOV	A,C		;C contains serial port control register address
	STA	RCVSCR		;modify IN for control register in RECV
	STA	SNDSCR		;modify IN for control register in SEND
	XRA	A
	STA	SECTNO		;init sector number to zero
	MVI	C,PRINT		;print the send message
	CALL	BDOS		;PRINT ID MESSAGE

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;PURGE -- Consume garbage characters from the line
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
PURGE:	MVI	B,1		;times out after 1 second if no data
	CALL	RECV
	JC	RECEIVE$FILE	;line is clear, go receive the file
	CPI	CTRLC		;exit if abort requested
	JZ	ABORT
	JMP	PURGE

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;RECEIVE$FILE -- Receive the file via XMODEM
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
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
	CPI	CTRLC		;control-c to abort?
	JZ	ABORT
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

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;RECV$SECTOR -- Get a sector via XMODEM
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
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

	LDA	RSECTNO		;GOT A SECTOR, WRITE IF = 1+PREV SECTOR
	MOV	B,A		;SAVE IT
	LDA	SECTNO		;GET PREV
	INR	A		;CALC NEXT SECTOR #
	CMP	B		;MATCH?
	JNZ	DO$ACK

	LXI	D,FCB		;GOT NEW SECTOR - WRITE IT
	MVI	C,WRITE
	CALL	BDOS
	ORA	A
	JNZ	WRITE$ERROR
	LDA	RSECTNO
	STA	SECTNO		;UPDATE SECTOR #
DO$ACK:	MVI	A,ACK
	CALL	SEND
	JMP	RECV$LOOP

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;WRITE$ERROR -- Print file write error and exit
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
WRITE$ERROR:
	CALL	ERXIT
	DB	CR,LF,LF,'Error Writing File',CR,LF,'$'

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;GOT$EOT -- Handle end-of-transfer
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
GOT$EOT:
	MVI	A,ACK		;ACK THE EOT
	CALL	SEND
	LXI	D,FCB
	MVI	C,CLOSE
	CALL	BDOS
	INR	A
	JNZ	XFER$CPLT
	CALL	ERXIT
	DB	CR,LF,LF,'Error Closing File',CR,LF,'$'

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;ERASE$OLD$FILE -- Delete any existing file before transfer
;
;Caution! If the transfer fails, the old file will stilll
;have been deleted!
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
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
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;MAKE$NEW$FILE -- Create a new empty file to write to
;
;This empty file will be what's left if the transfer fails,
;since we call ERASE$OLD$FILE first.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
MAKE$NEW$FILE:
	LXI	D,FCB
	MVI	C,MAKE
	CALL	BDOS
	INR	A		;FF=BAD
	RNZ			;OPEN OK

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;DIRFUL -- Print directory full error and exit
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
DIRFUL:	CALL	ERXIT
	DB	CR,LF,LF,"Error - Can't Make File",CR,LF
	DB	"(directory must be full)",CR,LF,'$'

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;ERXIT -- Exit and print an error message
;
;The error message to be printed by this routine should be
;a $-terminated string following the call to ERXIT.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
ERXIT:	POP	D		;GET MESSAGE
	MVI	C,PRINT
	CALL	BDOS		;PRINT MESSAGE
EXIT:	JMP	0		;Warm boot CP/M

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;RECV -- XMODEM receive routine
;
;This routine contains code that will be modified at run
;time if a non-default port is selected for the transfer.
;
;DELAY must be set in the machine-specific implementation.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
RECV:	PUSH	D		;Save DE
MSEC:	LXI	D,DELAY		;Set this in the machine-specific
				;implementation

RCVSCR:	EQU	$+1		;Address of I/O port for the following IN
MWTI:	IN	CONCR		;(10)
	ANI	RCVMASK		;(7)
	CPI	RCVRDY		;(7)
	JZ	MCHAR		;(10) GOT CHAR

	CPI	0		;(7) No char present, decrement countdown
	CPI	0		;(7) waste some time
	DCR	E		;(5) COUNT DOWN
	JNZ	MWTI		;(10) FOR TIMEOUT
	DCR	D		;do msb every 256th time
	JNZ	MWTI
	DCR	B		;DCR # OF SECONDS
	JNZ	MSEC

	POP	D		;Receive timed out, restore DE
	STC			;Set carry flag to show timeout
	RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;MCHAR -- Process XMODEM character
;
;This routine contains code that will be modified at run
;time if a non-default port is selected for the transfer.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
RCVSDR:	EQU	$+1		;address of I/O port for the following IN
MCHAR:	IN	CONDR
	POP	D		;RESTORE DE
	PUSH	PSW		;CALC CHECKSUM
	ADD	C
	MOV	C,A
	POP	PSW
	ORA	A		;TURN OFF CARRY TO SHOW NO TIMEOUT
	RET


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;SEND -- Transmit an XMODEM character
;
;This routine contains code that will be modified at run
;time if a non-default port is selected for the transfer.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
SEND	PUSH	PSW		;CHECK IF MONITORING OUTPUT
	ADD	C		;CALC CKSUM
	MOV	C,A

SNDSCR	EQU	$+1		;address of I/O port for the following IN
SENDW	IN	CONCR
	ANI	XMTMASK
	CPI	XMTRDY
	JNZ	SENDW
	POP	PSW		;GET CHAR

SNDSDR	EQU	$+1		;address of I/O port for the following IN
	OUT	CONDR
	RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;XFER$CPLT -- XMODEM transfer done, clean up
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
XFER$CPLT:
	CALL	ERXIT
	DB	CR,LF,LF,'Transfer Complete',CR,LF,'$'

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;ABORT -- Exit from a user abort
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
ABORT:	call	ERXIT
	db	CR,LF,LF,'Transfer Aborted',CR,LF,'$'

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Variables and Storage Defines
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
RSECTNO	DS	1	;RECEIVED SECTOR NUMBER
SECTNO	DS	1	;CURRENT SECTOR NUMBER
