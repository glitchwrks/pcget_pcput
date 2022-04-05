;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;PCGET -- Receive files via XMODEM from a PC
;
;TDL SMB and TDL/CDL SMB-II machine-specific version.
;Assumes 4 MHz Z80. Supports TTY and VIDEO serial ports.
;
;This CP/M program receives a file from a PC via a serial 
;port and writes it to a file on the CP/M system. The file
;transfer uses the XMODEM protocol. 
;
;Copyright (c) 2022 Glitch Works, LLC
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

	INCLUDE "../PCGET.INC"	;Bring in core PCGET library

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;HAVEFN -- Set up machine-specific implementation details
;
;This function is called when START in the core library
;has determined that we have a filename and are ready to
;begin the transfer.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
HAVEFN:	MVI	B,TTYDR		;Default to TTY port
	MVI	C,TTYCR		
	LXI	D,MSENDT	;TTY port send message
	LDA	PARAM2		;A=1st character of parameter 2
	ANI	5FH		;force upper case
	CPI	'C'		;CRT port specified?
	JZ	USECRT		;Yes, use it
	RET			;no, do transfer on TTY port

USECRT:	MVI	B,CRTDR		;use MODEM port
	MVI	C,CRTCR
	LXI	D,MSENDC	;CRT port send message
	RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Message Strings
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
MSENDT:	db	'Send file using XMODEM on TTY port...$'
MSENDC:	db	'Send file using XMODEM on CRT port...$'
MHELP:	db	CR,LF,'PCGET v1.1 for SMB and SMB II',CR,LF,LF
	db	'Receives a file from a PC through a serial port '
	db	'using the XMODEM protocol.',CR,LF,LF
	db	'Usage: PCGET file.ext [C]',CR,LF
	db	'   TTY port used by default',CR,LF
	db	'   Specify C to use CRT port',CR,LF,'$'

	END
