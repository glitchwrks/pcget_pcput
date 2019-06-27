;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;PCGET -- Receive files via XMODEM from a PC
;
;SD Systems SBC-200 version, 4 MHz Z80. Supports built-in
;console port.
;
;This CP/M program receives a file from a PC via a serial 
;port and writes it to a file on the CP/M system. The file
;transfer uses the XMODEM protocol. 
;
;Note this program is gutted from the Ward Christenson 
;MODEM program.
;
;Hacked together by Mike Douglas for the Horizon Computer
;Updated by Glitch Works for the SD Systems SBC-200
;
;Glitch Works customization and cleanup is:
;
;Copyright (c) 2019 The Glitch Works
;http://www.glitchwrks.com/
;
;Glitch Works customizations are released under the GNU GPLv3.
;
;Ver	Date	   Desc
;---    --------   ----------------------------------------
;1.0.1  2019-06-27 Customized for the SD Systems SBC-200
;
;1.0    10/7/15	   Initial version. This code is almost the
;		   same as the Vector Graphic version as 
;		   both use the same 8251 ports for serial 
;		   I/O.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Serial Port Equates
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
CONCR	EQU	7DH		;Console port control register (port 2)
CONDR	EQU	7CH		;Console port data register

XMTMASK	EQU	1		;MASK TO ISOLATE XMIT READY BIT
XMTRDY	EQU	1		;VALUE WHEN READY
RCVMASK	EQU	2		;MASK TO ISOLATE RECEIVE READY BIT
RCVRDY	EQU	2		;VALUE WHEN READY

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;XMODEM Protocol Equates
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
SOH	EQU	1
EOT	EQU	4
ACK	EQU	6
NAK	EQU	21
CTRLC	EQU	3
LF	EQU	10
CR	EQU	13

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;CP/M 2 BDOS Equates
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
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

	ORG	100H

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;START -- Get ready and begin the transfer
;
;This routine checks for the presence of a filename. If no
;filename is supplied, a help message is printed and we
;exit.
;
;Falls through to DOXFER
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
START:	LDA	PARAM1		;A=1st character of parameter 1
	CPI	' '		;make sure file name present
	JNZ	HAVEFN		;yes, have a file name
	LXI	D,MHELP		;display usage message
	MVI	C,PRINT
	CALL	BDOS
	RET			;return to CPM

HAVEFN:	MVI	B,CONDR		;Default to CONSOLE port
	LXI	D,MSENDC	;CONSOLE port send message

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;DOXFER -- Switch to a local stack and start transfer
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
DOXFER:	MOV	A,B		;a=address of serial port to use
	STA	RCVSDR		;modify IN instruction for data register
	STA	SNDSDR		;modify OUT instruction for data register
	INR	A		;a=serial port control register address
	STA	RCVSCR		;modify IN for control register in RECV
	STA	SNDSCR		;modify IN for control register in SEND
	LXI	H,0		;HL=0
	DAD	SP		;HL=STACK FROM CP/M
	SHLD	STACK		;..SAVE IT
	LXI	SP,STACK	;SP=MY STACK
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
EXIT:	LHLD	STACK		;GET ORIGINAL STACK
	SPHL			;RESTORE IT
	RET			;Back to CP/M

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;RECV -- XMODEM receive routine
;
;This routine contains code that will be modified at run
;time if a non-default port is selected for the transfer.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
RECV:	PUSH	D		;Save DE
MSEC:	LXI	D,63		;63 cycles, 4.032ms/wrap*248=1s (4MHz)

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
;Message Strings
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
MSENDC:	db	'Send file using XMODEM on CONSOLE port...$'
MHELP:	db	CR,LF,'PCGET v1.0.1 for SD Systems SBC-200',CR,LF,LF
	db	'Receives a file from a PC through a serial port',CR,LF
	db	'using the XMODEM protocol.',CR,LF,LF
	db	'Usage: PCGET file.ext',CR,LF
	db	'   CONSOLE port used by default',CR,LF,'$'

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Variables and Storage Defines
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	DS	40	;STACK AREA
STACK	DS	2	;STACK POINTER
RSECTNO	DS	1	;RECEIVED SECTOR NUMBER
SECTNO	DS	1	;CURRENT SECTOR NUMBER

	END
