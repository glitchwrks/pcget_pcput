;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;PCGET -- Receive files via XMODEM from a PC
;
;Supports MITS 88-SIO rev 1 with default strapping.
;
;This CP/M program receives a file from a PC via a serial 
;port and writes it to a file on the CP/M system. The file
;transfer uses the XMODEM protocol. 
;
;Copyright (c) 2023 Glitch Works, LLC
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Serial Port Equates
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
CONCR	EQU	0		;Console port control register
CONDR	EQU	1		;Console port data register

XMTMASK	EQU	10000000b	;MASK TO ISOLATE XMIT READY BIT
XMTRDY	EQU	00000000b	;VALUE WHEN READY
RCVMASK	EQU	00000001b	;MASK TO ISOLATE RECEIVE READY BIT
RCVRDY	EQU	00000000b	;VALUE WHEN READY

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Machine-Specific Protocol Equates
;
;DELAY must be set based on the processor speed. The MSEC
;function requires 63 cycles.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
DELAY	EQU	124		;63 cycles, 8.064ms/iteration*248=1s (2MHz)

	INCLUDE "../PCGET.INC"	;Bring in core PCGET library

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
MHELP:	db	CR,LF,'PCGET v1.1 for MITS 88-SIO rev 1',CR,LF,LF
	db	'Receives a file from a PC through a serial port '
	db	'using the XMODEM protocol.',CR,LF,LF
	db	'Usage: PCGET file.ext',CR,LF
	db	'   88-SIO channel at 0/1 used by default',CR,LF,'$'

	END
