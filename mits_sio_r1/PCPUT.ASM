;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;PCPUT -- Send files via XMODEM to a PC
;
;Supports MITS 88-SIO rev 1 with default strapping.
;
;This CP/M program send a file from CP/M via a serial 
;port to a PC. The file transfer uses the XMODEM protocol.
;
;Copyright (c) 2023 Glitch Works, LLC
;
;See LICENSE included in the project root for licensing
;information.
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

	INCLUDE "../PCPUT.INC"	;Bring in core PCPUT library

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;HAVEFN -- Set up machine-specific implementation details
;
;This function is called when START in the core library
;has determined that we have a filename and are ready to
;begin the transfer.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
HAVEFN:	MVI	B,CONDR		;Default to CONSOLE port
	MVI	C,CONCR		
	LXI	D,MRCVC		;CONSOLE port send message
	RET			;Back to the core PCGET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Message Strings
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
MRCVC:	db	'Start XMODEM file receive on CONSOLE port now...$'
MHELP:	db	CR,LF,'PCPUT v1.1 for MITS 88-SIO rev 1',CR,LF,LF
	db	'Transmits a file to a PC through a serial port '
	db	'using the XMODEM protocol.',CR,LF,LF
	db	'Usage: PCPUT file.ext',CR,LF
	db	'   88-SIO channel at 0/1 used by default',CR,LF,'$'

	END
