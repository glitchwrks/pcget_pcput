;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;PCPUT -- Send files via XMODEM to a PC
;
;Pegasus II machine-specific version, 4 MHz Z80. Supports
;CONSOLE port on Delta Products CPU board.
;
;This CP/M program send a file from CP/M via a serial 
;port to a PC. The file transfer uses the XMODEM protocol.
;
;Copyright (c) 2020 Glitch Works, LLC
;
;See LICENSE included in the project root for licensing
;information.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Serial Port Equates
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
TTYCR	EQU	070H		;TTY port control register
TTYDR	EQU	071H		;TTY port data register
CRTCR	EQU	072H		;CRT port control register
CRTDR	EQU	073H		;CRT port data register

XMTMASK	EQU	2		;MASK TO ISOLATE XMIT READY BIT
XMTRDY	EQU	2		;VALUE WHEN READY
RCVMASK	EQU	1		;MASK TO ISOLATE RECEIVE READY BIT
RCVRDY	EQU	1		;VALUE WHEN READY

CONCR	EQU	TTYCR		;Default to TTY port
CONDR	EQU	TTYDR

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Machine-Specific Protocol Equates
;
;DELAY must be set based on the processor speed. The MSEC
;function requires 63 cycles.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
DELAY	EQU	248		;63 cycles, 4.032ms/iteration*248=1s (4MHz)

	INCLUDE "../PCPUT.INC"	;Bring in core PCPUT library

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;HAVEFN -- Set up machine-specific implementation details
;
;This function is called when START in the core library
;has determined that we have a filename and are ready to
;begin the transfer.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
HAVEFN:	MVI	B,TTYDR		;Default to TTY port
	MVI	C,TTYCR		
	LXI	D,MRCVT		;TTY port send message
	LDA	PARAM2		;A=1st character of parameter 2
	ANI	5FH		;force upper case
	CPI	'C'		;CRT port specified?
	JZ	USECRT		;Yes, use it
	RET			;no, do transfer on TTY port

USECRT:	MVI	B,CRTDR		;use MODEM port
	MVI	C,CRTCR
	LXI	D,MRCVC		;CRT port send message
	RET			;Back to the core PCGET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Message Strings
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
MRCVT:	db	'Start XMODEM file receive on TTY port now...$'
MRCVC:	db	'Start XMODEM file receive on CRT port now...$'
MHELP:	db	CR,LF,'PCPUT v1.1 for SMB and SMB II',CR,LF,LF
	db	'Transmits a file to a PC through a serial port '
	db	'using the XMODEM protocol.',CR,LF,LF
	db	'Usage: PCPUT file.ext [C]',CR,LF
	db	'   TTY port used by default',CR,LF
	db	'   Specify C to use CRT port',CR,LF,'$'

	END
