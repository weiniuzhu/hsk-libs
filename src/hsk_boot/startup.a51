$NOMOD51

; Stack Pointer address
SP      DATA    81H

                NAME    ?C_STARTUP
?C_C51STARTUP   SEGMENT   CODE
?STACK          SEGMENT   IDATA

                RSEG    ?STACK
                DS      1

                EXTRN CODE (?C_START)
                PUBLIC  ?C_STARTUP

                CSEG    AT      0
?C_STARTUP:     LJMP    STARTUP1
                RSEG    ?C_C51STARTUP

; Initialise the Stack Pointer
STARTUP1:       MOV     SP,#?STACK-1
; Execute early startup function before global/static initialisation
		EXTRN CODE (_sdcc_external_startup)
		LCALL   _sdcc_external_startup
; Execute global/static initialisation and enter main()
                LJMP    ?C_START

; Overwrite ?C?DPSEL address for XC8xx Device
PUBLIC ?C?DPSEL
?C?DPSEL        DATA    0A2H   ; DPSEL address for Mentor M8051EW

                END
