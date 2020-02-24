;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;PCGET -- Receive files via XMODEM from a PC
;
;Glitch Works 8085 SBC rev 3 machine-specific version, 
;2 MHz 8085. Supports built-in CONSOLE port.
;
;This CP/M program receives a file from a PC via a serial 
;port and writes it to a file on the CP/M system. The file
;transfer uses the XMODEM protocol. 
;
;Copyright (c) 2020 The Glitch Works
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Serial Port Equates
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
CONCR	EQU	1		;Console port control register (port 2)
CONDR	EQU	0		;Console port data register

XMTMASK	EQU	1		;MASK TO ISOLATE XMIT READY BIT
XMTRDY	EQU	1		;VALUE WHEN READY
RCVMASK	EQU	2		;MASK TO ISOLATE RECEIVE READY BIT
RCVRDY	EQU	2		;VALUE WHEN READY

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Machine-Specific Protocol Equates
;
;DELAY must be set based on the processor speed. The MSEC
;function requires 63 cycles.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
DELAY	EQU	124		;63 cycles, 8.064ms/iteration*248=1s (2MHz)

	INCLUDE "../PCGET.LIB"	;Bring in core PCGET library

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;HAVEFN -- Set up machine-specific implementation details
;
;This function is called when START in the core library
;has determined that we have a filename and are ready to
;begin the transfer.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
HAVEFN:	MVI	B,CONDR		;Default to CONSOLE port
	MVI	C,CONCR		
	LXI	D,MSENDC	;CONSOLE port send message
	RET			;Back to the core PCGET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Message Strings
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
MSENDC:	db	'Send file using XMODEM on CONSOLE port...$'
MHELP:	db	CR,LF,'PCGET v1.1 for Glitch Works 8085 SBC rev 3',CR,LF,LF
	db	'Receives a file from a PC through a serial port'
	db	'using the XMODEM protocol.',CR,LF,LF
	db	'Usage: PCGET file.ext',CR,LF
	db	'   CONSOLE port used by default',CR,LF,'$'

	END
