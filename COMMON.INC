;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;COMMON.INC -- Common equates for PCGET and PCPUT
;
;This is the common equates library for core PCGET and
;PCPUT. It will not assemble in a meaningful way by itself.
;
;Copyright (c) 2015 Mike Douglas
;Copuright (c) 2020 The Glitch Works
;
;See LICENSE included in the project root for licensing
;information.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

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
FCB	EQU	5CH	;DEFAULT FCB
PARAM1	EQU	FCB+1	;COMMAND LINE PARAMETER 1 IN FCB
PARAM2	EQU	PARAM1+16	;COMMAND LINE PARAMETER 2
