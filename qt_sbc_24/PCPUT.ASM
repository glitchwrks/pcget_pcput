;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;PCPUT -- Send files via XMODEM to a PC
;
;Quick and Timely SBC 2/4 version, 4 MHz Z80. Supports 
;built-in console port.
;
;PCPUT won't work over the console port with the stock Q&T
;ROM monitor, since it sets the consle port as 7E1 instead
;of 8N1. Consider running GWMON as an alternative!
;
;This CP/M program sends a file to a PC via a serial port.
;The file transfer uses the XMODEM protocol. 
;
;Note this program is gutted from the Ward Christenson 
;MODEM program.
;
;Hacked together by Mike Douglas for the VG Bitstreamer II
;Updated by Glitch Works for the Q&T SBC 2/4
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
;1.0.1  2019-06-07 Customized for the Q&T SBC 2/4
;
;1.0    10/7/15	   Initial version. This code is almost the
;		   same as the Vector Graphic version as 
;		   both use the same 8251 ports for serial 
;		   I/O.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Serial Port Equates
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
CONCR	EQU	2FH		;Console port control register
CONDR	EQU	2EH		;Console port data register

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
ERRLMT	EQU	5		;MAX ALLOWABLE ERRORS

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
FCB	EQU	5CH	;SYSTEM FCB
PARAM1	EQU	FCB+1	;COMMAND LINE PARAMETER 1 IN FCB
PARAM2	EQU	PARAM1+16	;COMMAND LINE PARAMETER 2

	ORG	100h

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
	LXI	D,MRCVC		;CONSOLE port send message

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
	STA	SECTNO		;initialize sector number to zero
	PUSH	D		;Save message string pointer
	CALL	OPEN$FILE	;OPEN THE FILE
	POP	D		;Restore message string pointer
	MVI	C,PRINT
	CALL	BDOS		;PRINT ID MESSAGE

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;PURGE -- Consume garbage characters from the line
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
PURGE:	MVI	B,1		;times out after 1 second if no data
	CALL	RECV
	JC	LINECL		;line is clear, go wait for initial NAK
	CPI	CTRLC		;exit if abort requested
	JZ	ABORT
	JMP	PURGE

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;LINECL -- Wait for initial NAK, start XMODEM send
;
;This routine falls through to SENDB to start the transfer.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
LINECL:	XRA	A		;clear crc flag = checksum mode
	STA	CRCFLAG
WAINAK:	MVI	B,1		;TIMEOUT DELAY
	CALL	RECV
	JC	WAINAK
	CPI	CTRLC		;abort requested?
	JZ	ABORT
	CPI	NAK		;NAK RECEIVED?
	JZ	SENDB		;yes, send file in checksum mode
	CPI	'C'		;'C' for CRC mode received?
	JNZ	WAINAK		;no, keep waiting
	STA	CRCFLAG		;set CRC flag non-zero = true

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;SENDB -- Start the actual XMODEM send
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
SENDB:	CALL	READ$SECTOR
	LDA	SECTNO		;INCR SECT NO.
	INR	A
	STA	SECTNO

REPTB:	MVI	A,SOH		;SEND OR REPEAT SECTOR
	CALL	SEND
	LDA	SECTNO
	CALL	SEND
	LDA	SECTNO
	CMA
	CALL	SEND
	LXI	H,0		;init crc to zero
	SHLD	CRC16
	MOV	C,H		;init checksum in c to zero
	LXI	H,80H
SENDC:	MOV	A,M
	CALL	SEND
	CALL	CALCRC		;update CRC
	INX	H
	MOV	A,H
	CPI	1		;DONE WITH SECTOR?
	JNZ	SENDC

	LDA	CRCFLAG		;crc or checksum?
	ORA	A
	JZ	SNDCKS		;flag clear = checksum
	LDA	CRC16+1		;a=high byte of CRC
	CALL	SEND		;send it
	LDA	CRC16		;a=low byte of crc
	JMP	SNDSKP		;skip next instruction	
SNDCKS:	MOV	A,C		;send the checksum byte
SNDSKP:	CALL	SEND
				;GET ACK ON SECTOR
	MVI	B,4		;WAIT 4 SECONDS MAX
	CALL	RECV
	JC	REPTB		;TIMEOUT, SEND AGAIN
				;NO TIMEOUT SENDING SECTOR
	CPI	ACK		;ACK RECIEVED?
	JZ	SENDB		;..YES, SEND NEXT SECT
	CPI	CTRLC		;control-c to abort?
	JZ	ABORT
	JMP	REPTB		;PROBABLY NAK - TRY AGAIN

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;OPEN$FILE -- Open disk file for reading
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
OPEN$FILE:
	LXI	D,FCB
	MVI	C,OPEN
	CALL	BDOS
	INR	A		;OPEN OK?
	RNZ			;GOOD OPEN
	CALL	ERXIT
	DB	CR,LF,"Can't Open File",CR,LF,'$'

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
	RET			;--EXIT-- TO CP/M

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;RECV -- XMODEM receive routine
;
;This routine contains code that will be modified at run
;time if a non-default port is selected for the transfer.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
RECV:	PUSH	D		;SAVE
MSEC:	LXI	D,63		;63 cycles, 4.032ms/wrap*248=1s (4MHz)

RCVSCR:	EQU	$+1		;address of I/O port for the following IN
MWTI:	IN	CONCR		;(10)
	ANI	RCVMASK		;(7)
	CPI	RCVRDY		;(7)
	JZ	MCHAR		;(10) GOT CHAR

	CPI	0		;(7) No character present, decrement countdown
	CPI	0		;(7) waste some time
	DCR	E		;(5) COUNT DOWN
	JNZ	MWTI		;(10) FOR TIMEOUT
	DCR	D		;do msb every 256th time
	JNZ	MWTI
	DCR	B		;DCR # OF SECONDS
	JNZ	MSEC

	POP	D		;Receive timeout, restore DE
	STC			;CARRY SHOWS TIMEOUT
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
SEND:	PUSH	PSW		;CHECK IF MONITORING OUTPUT
	ADD	C		;CALC CKSUM
	MOV	C,A

SNDSCR:	EQU	$+1		;address of I/O port for the following IN
SENDW:	IN	CONCR
	ANI	XMTMASK
	CPI	XMTRDY
	JNZ	SENDW
	POP	PSW		;GET CHAR

SNDSDR:	EQU	$+1		;address of I/O port for the following IN
	OUT	CONDR
	RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;READ$SECTOR -- Read a file sector into memory
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
READ$SECTOR:
	LXI	D,FCB
	MVI	C,READ
	CALL	BDOS
	ORA	A
	RZ
	DCR	A		;EOF?
	JNZ	RDERR		;No, we have an error

	XRA	A		;Reached EOF
	STA	ERRCT
SEOT:	MVI	A,EOT
	CALL	SEND
	MVI	B,3		;WAIT 3 SEC FOR TIMEOUT
	CALL	RECV
	JC	EOTERR		;EOT TIMEOUT
	CPI	ACK
	JZ	XFER$CPLT

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;EOTERR -- Handle no EOT at end of transfer
;
;This routine is called when we've finished the transfer
;but never received an EOT from the receiver.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
EOTERR:	LDA	ERRCT
	INR	A
	STA	ERRCT
	CPI	ERRLMT
	JC	SEOT
	CALL	ERXIT
	DB	CR,LF,LF
	DB	'No ACK received on EOT, but transfer is complete.',CR,LF,'$'

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;RDERR -- Handle file read error
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
RDERR:	CALL	ERXIT
	DB	CR,LF,'File Read Error',CR,LF,'$'

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;XFER$CPLT -- XMODEM transfer done, clean up
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
XFER$CPLT:
	CALL	ERXIT
	DB	CR,LF,LF,'Transfer Complete',CR,LF,'$'

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;ABORT -- Exit from a user abort
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
ABORT	CALL	ERXIT
	DB	CR,LF,LF,'Transfer Aborted',CR,LF,'$'

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;CALCRC -- Update the 16-bit CRC value with another byte
;
;This routine copied from Martin Eberhard
;
;A and DE registers are not preserved.
;
;pre: A contains byte to add to CRC
;pre: CRC16 holds the current CRC value
;post: CRC16 has been updated
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
CALCRC:	PUSH	B		;save bc, hl
	PUSH	H
	LHLD	CRC16		;get CRC so far
	XRA	H		;XOR into CRC top byte
	MOV	H,A
	LXI	B,1021H		;bc=CRC16 polynomial
	MVI	D,8		;prepare to rotate 8 bits

CROTLP:	DAD	H		;16-bit shift
	JNC	CCLR		;skip if bit 15 was 0
	MOV	A,H		;CRC=CRC xor 1021H
	XRA	B
	MOV	H,A
	MOV	A,L
	XRA	C
	MOV	L,A
CCLR:	DCR	D
	JNZ	CROTLP		;rotate 8 times

	SHLD	CRC16		;save updated CRC
	POP	H		;restore hl, bc
	POP	B
	RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Message Strings
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
MRCVC:	db	'Start XMODEM file receive on CONSOLE port now...$'
MHELP:	db	CR,LF,'PCPUT v1.0.1 for Quick and Timely SBC 2/4',CR,LF,LF
	db	'Transmits a file to a PC through a serial port',CR,LF
	db	'using the XMODEM protocol.',CR,LF,LF
	db	'Usage: PCPUT file.ext',CR,LF
	db	'   CONSOLE port used by default',CR,LF,'$'

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Variables and Storage Defines
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	DS	40	;STACK AREA
STACK	DS	2	;STACK POINTER
SECTNO	DS	1	;CURRENT SECTOR NUMBER 
ERRCT	DS	1	;ERROR COUNT
CRCFLAG	ds	1	;non-zero if using CRC
CRC16	ds	2	;computed crc

	END
