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
DELAY	EQU	248		;63 cycles, 4.032ms/iteration*248=1s (4MHz)

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
MHELP:	db	CR,LF,'PCPUT v1.1 for Pegasus II',CR,LF,LF
	db	'Transmits a file to a PC through a serial port '
	db	'using the XMODEM protocol.',CR,LF,LF
	db	'Usage: PCPUT file.ext',CR,LF
	db	'   CONSOLE port used by default',CR,LF,'$'

	END
