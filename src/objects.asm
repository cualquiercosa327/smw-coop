;Yay, the dreaded custom object interaction code!
;points: 	0: left foot
;			1: right foot
;			2: center 
;			3: head
;			4: left side body
;			5: left side head
;			6: right side body
;			7: right side head
DATA_00E830:
;  0       1       2       3       4       5       6       7   
db $05,$00,$0B,$00,$08,$00,$08,$00,$02,$00,$02,$00,$0E,$00,$0E,$00	;1 small
db $05,$00,$0B,$00,$08,$00,$08,$00,$02,$00,$02,$00,$0E,$00,$0E,$00	;2 big
DATA_00E89C:
;  0       1       2       3       4       5       6       7   
db $20,$00,$20,$00,$18,$00,$12,$00,$1A,$00,$16,$00,$1A,$00,$16,$00	;1 small
db $20,$00,$20,$00,$12,$00,$08,$00,$1A,$00,$0F,$00,$1A,$00,$0F,$00	;2 big

Objects:
		LDA $0DB9
		AND #$04
		LSR
		STA $14BE			;set bit 2 of $14BE if in water last frame
		LDA #$04
		TRB $0DB9
		LDA #$40
		TRB $0F6A
		STZ $1933
		JSR TileTouches

		LDA $5B
		BPL +
		JSR Layer2

	+
		JSR WaterInteraction
		LDA $1588,x
		BIT #$04		;reset various addresses if touching ground
		BEQ .offtheground
		LDA #$01
		TRB $0F6A
		STZ $0F61
		BRA .ontheground

	.offtheground
		STZ $0F69
	.ontheground
		RTS

GetL2Offsets:
		LDA $5B
		BIT #$02
		BNE .vertical
		LDA #$10
		STA $00
		STZ $01
		RTS

	.vertical
		STZ $00
		LDA #$0E
		STA $01
		RTS

Layer2:
		INC $1933
		LDA $1588,x		; Save and zero the touch-direction flags
		PHA			; They'll be OR'd with the values that come out of the new interaction
		STZ $1588,x

		JSR GetL2Offsets	; Set $00 and $01 to be the high-byte offsets
		LDA $E4,x		; Move sprite's position to be on top of the layer 2 tiles
		CLC
		ADC $26
		STA $E4,x
		LDA $14E0,x
		ADC $27
		CLC
		ADC $00
		STA $14E0,x
		LDA $D8,x
		CLC
		ADC $28
		STA $D8,x
		LDA $14D4,x
		ADC $29
		CLC
		ADC $01
		STA $14D4,x

		JSR TileTouches		; Do the interaction for layer 2 now

		JSR GetL2Offsets
		LDA $E4,x		; Restore sprite's position
		SEC
		SBC $26
		STA $E4,x
		LDA $14E0,x
		SBC $27
		SEC
		SBC $00
		STA $14E0,x
		LDA $D8,x
		SEC
		SBC $28
		STA $D8,x
		LDA $14D4,x
		SBC $29
		SEC
		SBC $01
		STA $14D4,x

		LDA $1588,x
		ASL #4
		ORA $1588,x
		STA $00
		PLA
		ORA $00
		STA $1588,x

		LDA $1588,x
		BIT #$40
		BEQ .notobot

		REP #$20			; We're standing on layer 2. Update position accordingly.
		LDA $1E
		SEC
		SBC $1466
		SEC
		SBC $1A
		CLC
		ADC $1462
		STA $00
		LDA $20
		SEC
		SBC $1468
		SEC
		SBC $1C
		CLC
		ADC $1464
		STA $02
		SEP #$20

		LDA $E4,x
		CLC
		ADC $00
		STA $E4,x
		LDA $14E0,x
		ADC $01
		STA $14E0,x

		;LDA $D8,x
		;CLC
		;ADC $02
		;STA $D8,x
		;LDA $14D4,x
		;ADC $03
		;STA $14D4,x

		LDA #$10
		STA $AA,x
	.notobot
		RTS


TileTouches:
LDA $0F6A
AND #$04			; Climbing on net
LSR
STA $142E			; Was climbing last frame 
LDA #$0E			; \ Reset all the different climbing flags
TRB $0F6A			; /
JSR GetHeight
BEQ .smallluigi
LDY #$10
BRA .loopinit		; Basically if you're small use a different set of hitpoint values
.smallluigi
LDY #$00
.loopinit
STY $142D			; Current hitpoint index goes in $142D
LDA #$00
.loopstart
STA $142C			; Which hitpoint we're currently on (0,1,2..7) goes in $142C
LDA $14E0,x
XBA
LDA $E4,x
REP #$20
CLC
ADC.w DATA_00E830,y
AND #$FFF0
STA $9A					; x-pos of contacted block
LSR #4
STA $00					; block x-index
SEP #$20
LDA $14D4,x
XBA
LDA $D8,x
REP #$20
CLC
ADC.w DATA_00E89C,y
SEC
SBC #$0010
AND #$FFF0
STA $98					; y-pos of contacted block
LSR #4
STA $02					; block y-index

LDA $5B
BIT #$0001
BNE .vertical			; handle vertical levels differently

LDA $00
AND #$000F
CLC
ADC $98
STA $04					; block index in map16 table
LDA $00
LSR #4
SEP #$20
STA $4202
LDA #$1B
STA $4203
NOP #4
REP #$20
LDA $4216
ASL #4
CLC
ADC $04
STA $04					; final equation: X = y_index + x_index[low] + x_index[high] * 0x1B
BRA .injection

.vertical
LDA $00
AND #$000F
STA $04
LDA $98
AND #$00F0
CLC
ADC $04
STA $04
LDA $9A
AND #$0100
CLC
ADC $04
STA $04
LDA $98
AND #$FF00
ASL
CLC
ADC $04
STA $04					; final equation: X = x_index[low] + y_index[mid] + x_index[high] * 0x10 + y_index[high] * 0x200

.injection
JSR LoadTileNumber
LDA $E4,x				; \ 
AND #$0F				;  |
STA $06					;  | $06 = x-pos % 16
LDA $D8,x				;  | $07 = y-pos % 16
AND #$0F				;  |
STA $07					; / 
JSR BlockRoutines
.premature
SEP #$30
LDA $142C
INC
CMP #$08
BEQ .loopend
LDY $142D
INY
INY
STY $142D
JMP .loopstart
.loopend
RTS

LoadTileNumber:
REP #$10
TAX
SEP #$20
LDA $7FC800,x			; \ 
STA $0F					;  | Load current Map16 number into $0F:$0E
LDA $7EC800,x			;  |
STA $0E					; / 
REP #$20
LDA $06F624
CMP #$FFFF				; \ If for some strange reason the pointer hasn't been installed yet, bail out
BEQ .lm_not_installed   ; /
STA $00
LDA $06F625
STA $01
LDA $0E
.loopfurther			; \ 
ASL						;  |
TAY						;  | Loop through 'acts like' setting until it's something reasonable
LDA [$00],y				;  |
STA $0E					;  |
CMP #$0200				;  |
BCS .loopfurther		; /
.lm_not_installed
SEP #$30
LDX $15E9
RTS


BlockRoutines:
LDA $0F				; \ Everything on Map16 page 0 is walk-through :P 
BEQ .blanksjmpa		; /
LDA $0E
CMP #$11
BCC .cloudsjmpa		; Everything 100 - 110 acts like a cloud-ledge
PHA
SEC
SBC #$10
CMP #$49
PLA
BCC .solidsjmpa		; Everything 111 - 158 acts like a solid block
CMP #$6E
BCC .tssolidsjmp	; tileset specific solids
CMP #$FB
BCS .deathwater		; 1FB - 1FF are lava
CMP #$D8
BCS .jipblocks		; 1D8 - 1FA "pick-up" slope blocks
CMP #$D2
BCS +
CMP #$CE
BCS .escalatorsjmp
CMP #$CA
BCS .ssslopesjmp
CMP #$C4
BCS .uslopesjmp
XBA
LDA $142C
CMP #$02
BCS +
LDA $AA,x
BMI +
XBA
CMP #$C0
BCS .sslopes2jmp
CMP #$BC
BCS .nslopes2jmp
CMP #$B8
BCS .gslopes2jmp
CMP #$B6
BCS .ssslopes2jmp
CMP #$B4
BCS .trianglesjmp
CMP #$AA
BCS .sslopesjmp
CMP #$96
BCS .nslopesjmp
CMP #$6E
BCS .gslopesjmp
+
RTS

.blanksjmpa
JMP .blanks
.cloudsjmpa
JMP .clouds
.solidsjmpa
JMP .solids
.nslopesjmp
JMP .nslopes

.escalatorsjmp
JMP .escalators
.tssolidsjmp
JMP .tssolids
.sslopesjmp
JMP .sslopes
.ssslopesjmp
JMP .ssslopes
.trianglesjmp
JMP .triangles
.ssslopes2jmp
JMP .ssslopes2
.gslopes2jmp
JMP .gslopes2
.nslopes2jmp
JMP .nslopes2
.sslopes2jmp
JMP .sslopes2
.gslopesjmp
JMP .gslopes
.uslopesjmp
JMP .uslopes

.deathwater
LDA $142C
CMP #$02
BNE +
JSR KillLuigi
+
RTS

.jipblocks			; "pick-up" slope blocks
LDA $142C
CMP #$02
BCS +				; Don't interact with anything but feet
LDA $AA,x
BMI +				; Don't interact if moving upward
;LDA $07
;CMP #$08
;BCS +
LDA #$0F
STA $07
REP #$30
PLA						;discard previous JSR
LDA $98
SEC
SBC #$0010
STA $98
LDA $04
SEC
SBC #$0010
STA $04
JMP TileTouches_injection	;BREAK 4TH WALL

.escalators
+
RTS

.uslopes
LDA $1931
BEQ .spipes
CMP #$07
BEQ .spipes
.reallyuslope
-
RTS

.spipes
LDA $AA,x
BMI -
LDA $0E
CMP #$C8
BCS .reallyuslope
CMP #$C7
BEQ .spup
CMP #$C4
BEQ .spup
LDA #$AF
STA $0E
JMP .sslopes
.spup
LDA #$AE
STA $0E
JMP .sslopes

.gslopes2
SEC
SBC #$38
STA $0E
JMP .gslopes

.nslopes2
SEC
SBC #$1E
STA $0E
JMP .nslopes

.sslopes2
SEC
SBC #$13
STA $0E
JMP .sslopes

.ssslopes2

.triangles

.gslopes
LDY #$00
LDA $0E
CMP #$73
BCC .gup
INY
CMP #$78
BCC .gup
INY
CMP #$7D
BCC .gup
INY
CMP #$82
BCC .gup
CMP #$87
BCC .gdown
DEY
CMP #$8C
BCC .gdown
DEY
CMP #$91
BCC .gdown
DEY
.gdown
TYA
ASL #2
STA $00
LDA $142C
BNE +					; Only interact with foot #0
LDA #$01
STA $0D
LDA #$0F
SEC
SBC $06
BRA ++
+
RTS
.gup
TYA
ASL #2
STA $00
LDA $142C
CMP #$01
BNE +					; Only interact with foot #1
LDA #$FF
STA $0D
LDA $06
++
CLC
ADC #$0B
AND #$0F
LSR #2
JSR SlopeInteract
+
RTS

.nslopes
LDY #$00
LDA $0E
CMP #$9B
BCC .nup
INY
CMP #$9F
BCC .nup
CMP #$A5
BCC .ndown
DEY
.ndown
TYA
ASL #3
STA $00
LDA $142C
BNE +
LDA #$02
STA $0D
LDA #$0F
SEC
SBC $06
BRA ++
.nup
TYA
ASL #3
STA $00
LDA $142C
CMP #$01
BNE +
LDA #$FE
STA $0D
LDA $06
++
CLC
ADC #$0B
AND #$0F
LSR
JSR SlopeInteract
+
RTS


.sslopes
LDA $0E
CMP #$AF
BCC .sup
LDA $142C
BNE .sdownfoot
.sdownokay
LDA #$03
STA $0D
LDA #$0F
SEC
SBC $06
BRA ++
.sup
LDA $142C
CMP #$01
BNE .supfoot
.supokay
LDA #$FD
STA $0D
LDA $06
++
CLC
ADC #$0B
AND #$0F
DEC
DEC
BPL .snospecialcase
CLC
ADC #$10
PHA
REP #$20
LDA $98
CLC
ADC #$0010
STA $98
SEP #$20
PLA
.snospecialcase
STZ $00
JSR SlopeInteract
+
-
RTS
.supfoot
CMP #$00
BNE -
LDA $0F69
BNE -
LDA $06
CLC
ADC #$06
AND #$0F
STA $06
BRA .supokay
.sdownfoot
CMP #$01
BNE -
LDA $0F69
BNE -
LDA #$06
SEC
SBC #$06
AND #$0F
STA $06
BRA .sdownokay

.ssslopes
+
RTS

.tssolids
LDA $1931
ASL
TAY
LDA.w .tilesetptrs,y
STA $00
LDA.w .tilesetptrs+1,y
STA $01
JMP ($0000)

.tilesetptrs
dw .solids
dw .castle
dw .solids
dw .underground
dw .solids
dw .ghost
dw .solids
dw .solids
dw .solids
dw .solids
dw .solids
dw .solids
dw .solids
dw .ghost
dw .solids

.hurtthensolid				;\ 
JSR HurtLuigi				; |EXACTLY WHAT'S ON THE TIN
JMP .solids					;/

.castle
LDA $0E
SEC
SBC #$66
CMP #$04
BCC .hurtthensolid
LDA $0E
SEC
SBC #$59
CMP #$04
BCC .hurtthensolid
JMP .solids

.underground
LDA $0E
SBC #$58
CMP #$03
BCC .killifhead
JMP .solids
.killifhead
LDA $142C
CMP #$03
BNE +
JMP KillLuigi

.blanksjmp
JMP .blanks
.cloudsjmp
JMP .clouds
.solidsjmp
JMP .solids

.ghost
LDA $0E
SEC
SBC #$59
CMP #$03
BCC .hurtthensolid
JMP .solids

.invisibleblocks
LDA $142C
CMP #$03
BNE +
LDA $AA,x
BPL +
LDA $0E
SEC
SBC #$04
PHX
TAX
LDY #$00
JSL $00F17F
PLX
+
RTS

.empty
LDA $142E
BIT #$02
BEQ .save
LDA $142C
CMP #$03
BNE +
LDA $1588,x
ORA #$08
STA $1588,x
+
LDA $0F6A
BIT #$02
BEQ ++
LDA $142C
LSR
CMP #$02
BNE +
LDA $1588,x
ORA #$02
STA $1588,x
RTS
+
CMP #$03
BNE ++
LDA $1588,x
BIT #$02
BNE .bleh
ORA #$01
STA $1588,x
++
.save
RTS
.bleh
LDA $1588,x
AND #$FC
STA $1588,x
RTS

.blanks
LDA $0E
CMP #$25
BEQ .empty
CMP #$04
BCC .waterjmp
CMP #$06
BEQ .vinejmp
CMP #$07
BCC +
CMP #$1D
BCC .netsjmp
+
CMP #$1F
BEQ .door
CMP #$20
BEQ .door
CMP #$27
BEQ .pdoor
CMP #$28
BEQ .pdoor
CMP #$38
BEQ .midptjmp
CMP #$2B
BEQ .coinjmp
CMP #$2A
BEQ .icoinjmp
CMP #$2C
BEQ .purplecoinjmp
CMP #$2D
BEQ .yoshicoinjmp
CMP #$2E
BEQ .yoshicoinbottomjmp
CMP #$6E
BEQ .moonjmp
CMP #$6F
BEQ .checkptjmp
CMP #$70
BEQ .checkptjmp
CMP #$71
BEQ .checkptjmp
CMP #$72
BEQ .checkgtjmp
CMP #$EC
BCC +
CMP #$FE
BCS .save
LDA $1931
CMP #$04
BNE +
JMP .solids
+
SEC
SBC #$21
CMP #$04
BCC .invisibleblocksjmp
RTS

.waterjmp
JMP .water
.invisibleblocksjmp
JMP .invisibleblocks
.netsjmp
JMP .nets
.vinejmp
JMP .vine
.checkptjmp
JMP .checkpt
.coinjmp
JMP .coin
.moonjmp
JMP .moon
.purplecoinjmp
JMP .purplecoin
.icoinjmp
JMP .icoin
.checkgtjmp
JMP .checkgt
.midptjmp
JMP .midpt
.yoshicoinjmp
JMP .yoshicoin
.yoshicoinbottomjmp
JMP .yoshicoinbottom


.pdoor
LDA $14AD
BEQ +
.door
LDA $142C
CMP #$03
BNE +
LDA $0DA7
BIT #$08
BEQ +
LDA #$85
STA $1504,x
STZ $151C,x
LDA #$0F
STA $1DFC
+
RTS

.midpt
LDA #$05
STA $1DF9
LDA #$02
STA $9C
JSR BlockSparkle
JSL $00BEB0
LDA #$01
STA $13CE
LDA $0DB9
BIT #$18
BNE .midend
LDA #$08
TSB $0DB9
.midend
RTS

.vine
LDA $142C
CMP #$02
BCC +
BEQ .vinebody
CMP #$03
BEQ .vinehead
LDA $142E			;142E: ------AB Already climbing, Body touch
BIT #$02
BEQ +
BIT #$01
BNE +
LDA #$0C
TSB $0F6A
RTS

.vinehead
LDA $142E
BIT #$02
BNE ++
BIT #$01
BNE .vineintercept
BRA ++

.vinebody
LDA $142E
BIT #$02
BNE .climbvine
BIT #$01
BEQ ++
.vineintercept
LDA $0DA3
BIT #$0C
BEQ ++
.climbvine
LDA #$04
TSB $0F6A
++
LDA #$01
TSB $142E
+
RTS

.nets
LDA $142C
CMP #$03
BEQ .derpnet
CMP #$02
BNE +
LDA $142E
BIT #$02
BNE .climbnet
BIT #$01
BEQ .setnet
.checknet
LDA $0DA3
BIT #$0C
BEQ +
.climbnet
LDA #$06
TSB $0F6A
+
RTS
.derpnet
LDA $142E
BIT #$02
BNE .setnet
BIT #$01
BNE .checknet
.setnet
LDA #$01
TSB $142E
RTS



.icoin
LDA $14AD
BNE .purplecoin
RTS

.solidsjmp2
JMP .solids

.coin
LDA $14AD
BNE .solidsjmp2
.purplecoin
JSL $05B34A			;+1 coin
LDA #$02
STA $9C
JSR BlockSparkle
JSL $00BEB0
RTS

.moon
LDA #$01
STA $9C
JSL $00BEB0
PHX
TXY
LDA #$12
JSL $02ACEF
PLX
LDA #$1F
STA $01
LDA #$EE
STA $00
JMP MarkLevel

.checkpt
PHA
LDA $1421
CMP #$04
PLA
BCS .checkend
SEC
SBC #$6F
CMP $1421
BEQ .checkinc
INC
CMP $1421
BNE .checkzero
RTS
.checkinc
INC $1421
RTS
.checkzero
STZ $1421
.checkend
RTS
.checkgt
LDA $1421
CMP #$04
BCS .checkend
CMP #$03
BCC .checkzero
INC $1421
PHX
LDX #$0B
-
LDA $14C8,x
BEQ +
DEX
BPL -
PLX
RTS
+
PHK
PEA.w .returnpoint-$01
PHX
JML $03C2E6
.returnpoint
TXY
PLX
LDA $E4,x
STA $00E4,y
LDA $14E0,x
STA $14E0,y
LDA $D8,x
STA $00D8,y
LDA $14D4,x
STA $14D4,y
RTS


.yoshicoinbottom
REP #$20
LDA $98
SEC
SBC #$0010
STA $98
SEP #$20
.yoshicoin
LDA #$18
STA $9C
JSL $00BEB0
JSR BlockSparkle
LDA #$1C
STA $1DF9
JSL $00F377
LDA $E4,x
STA $16ED,y
LDA $14E0,x
STA $16F3,y
LDA $D8,x
STA $16E7,y
LDA $14D4,x
STA $16F9,y
INC $1422
LDA $1422
CMP #$05
BCC +
LDA #$1F
STA $01
LDA #$2F
STA $00
JSR MarkLevel
+
RTS

.water
LDA $142C
CMP #$03
BNE +
LDA #$04
TSB $0DB9
LDA $14BE
BIT #$02
BNE ++
STZ $AA,x
JMP WaterSplash
+
CMP #$02
BNE ++
LDA #$01
TSB $14BE
++
RTS

.clouds
LDA $142C
CMP #$02
BCS .end
.solidtop
LDA $142E
BIT #$02
BEQ +
LDA $0DA3
BIT #$04
BEQ .end
LDA #$0E
TRB $0F6A
+
LDA $AA,x
BMI .end
LDA $07
CMP #$05
BCS .end
JSR SwitchPalaces
LDA $0F
BEQ .notspecialtop
LDA $0E
CMP #$1E
BEQ .shatterturn
SEC
SBC #$37
CMP #$02
BCC .verticalpipedown
.notspecialtop
;LDA #$00
STZ $0F69
STZ $AA,x
LDA $1588,x
ORA #$04
STA $1588,x
LDA $D8,x
AND #$F0
STA $D8,x
.end
RTS

.shatterturn
LDA $0DB9
BIT #$18
BEQ .notspecialtop
BIT #$01
BEQ .notspecialtop
PHX
LDA $7D
PHA
PHB
LDA #$02
PHA
PLB
JSL $028758
PLB
PLA
PLX
STA $7D
LDA #$D0
STA $AA,x
RTS
.tablething

.verticalpipedown
CMP #$01
BNE +
LDA $9A
SEC
SBC #$10
STA $9A
LDA $9B
SBC #$00
STA $9B
+
LDA $14E0,x
XBA
LDA $E4,x
REP #$20
SEC
SBC $9A
SEC
SBC #$0003
CMP #$000A
SEP #$20
BCS .notspecialtop
LDA $0DA3
BIT #$04
BEQ .notspecialtop
LDA #$84
STA $1504,x
LDA #$20
STA $151C,x
LDA #$22
STA $9D
LDA #$04
STA $1DF9
STA $1588,x
RTS


.brownblock
LDA $14AD
BEQ .notspecialsolid
JMP .purplecoin

.muncher
LDA $14AE
BEQ +
JMP .purplecoin
+
JSR HurtLuigi
BRA .notspecialsolid

.solids
CMP #$32
BEQ .brownblock
CMP #$2F
BEQ .muncher
.notspecialsolid
LDA $142C
CMP #$03
BEQ .hitheadsolid
CMP #$02
BCC .solidtopjmp
CMP #$04
BCS .leftsidesolid
RTS

.solidtopjmp
JMP .solidtop
.rightsidesolidjmp
JMP .rightsidesolid

.leftsidesolid
CMP #$06
BCS .rightsidesolidjmp
LDA $B6,x
BEQ ++
BPL +
++
LDA $E4,x
AND #$F0
CLC
ADC #$0D
STA $E4,x
;LDA #$00
STZ $B6,x
LDA $1588,x
ORA #$02
STA $1588,x
LDA $0E
CMP #$3F
BNE +
LDA $1588,x
BIT #$04
BEQ +
LDA $0DA3
BIT #$02
BEQ +
LDA #$81
STA $1504,x
LDA #$28
STA $151C,x
LDA #$30
STA $9D
LDA #$04
STA $1DF9
REP #$20
LDA $98
DEC
DEC
SEP #$20
STA $D8,x
XBA
STA $14D4,x
+
RTS

.hitheadsolid
LDA $0E
SEC
SBC #$37
CMP #$02
BCC .verticalpipeup
.notspecialbottom
LDA $0E
PHX
TAX
LDY #$00
JSL $00F160
PLX
LDA #$04
STA $AA,x
LDA #$01
STA $1DF9
LDA $1588,x
ORA #$08
STA $1588,x
JSR GetHeight
BEQ .hitheadsolidsmall
LDA $D8,x
AND #$F0
CLC
ADC #$07
STA $D8,x
RTS

.hitheadsolidsmall
LDA $D8,x
AND #$F0
CLC
ADC #$0E
STA $D8,x
STZ $AA,x
RTS

.verticalpipeup
CMP #$01
BNE +
LDA $9A
SEC
SBC #$10
STA $9A
LDA $9B
SBC #$00
STA $9B
+
LDA $14E0,x
XBA
LDA $E4,x
REP #$20
SEC
SBC $9A
SEC
SBC #$0003
CMP #$000A
SEP #$20
BCS .notspecialbottom
LDA $0DA3
BIT #$08
BEQ .notspecialbottom
LDA #$83
STA $1504,x
LDA #$20
STA $151C,x
LDA #$22
STA $9D
LDA #$04
STA $1DF9
RTS

.rightsidesolid
LDA $B6,x
BMI +
LDA $E4,x
AND #$F0
INC : INC
STA $E4,x
;LDA #$00
STZ $B6,x
LDA $1588,x
ORA #$01
STA $1588,x
LDA $0E
CMP #$3F
BNE +
LDA $1588,x
BIT #$04
BEQ +
LDA $0DA3
BIT #$01
BEQ +
LDA #$82
STA $1504,x
LDA #$28
STA $151C,x
LDA #$30
STA $9D
LDA #$04
STA $1DF9
REP #$20
LDA $98
DEC
DEC
SEP #$20
STA $D8,x
XBA
STA $14D4,x
+
RTS

BlockSparkle:
LDA $15C4,x
;LDA $15A0,x                   ;\ 
;ORA $186C,x                 ; |Return if player offscreen
BNE .return          ;/
LDY #$03                
.loop
LDA $17C0,y          
BEQ .foundslot           
DEY                       
BPL .loop        
.return   
RTS                       ; Return 

.foundslot
LDA #$05                
STA $17C0,y           
LDA $9A       
AND #$F0                
STA $17C8,y             
LDA $98
AND #$F0                
STA $17C4,Y             
LDA $1933               
BEQ .skip         
LDA $9A
SEC                       
SBC $26                   
AND #$F0                
STA $17C8,y     
LDA $98
SEC                       
SBC $28                   
AND #$F0                
STA $17C4,y             
.skip
LDA #$10                
STA $17CC,y             
RTS                       ; Return 

MarkLevel:
PHX
LDA $13BF
PHA
LSR #3
TAY
PLA
AND #$07
TAX
LDA $05B35B,x
ORA ($00),y
STA ($00),y
PLX
RTS

SlopeInteract:
CLC
ADC $00
STA $00
STZ $01
REP #$20
LDA $98
SEC
SBC $00
DEC
STA $02
CLC
ADC #$0008
STA $00
SEP #$20
LDA $14D4,x
XBA
LDA $D8,x
REP #$20
CMP $00
;BCS +
LDY $0F69
BNE ++
CMP $02
BCC +
++
LDA $02
INC
SEP #$20
STA $D8,x
XBA
STA $14D4,x
STZ $AA,x
LDA $1588,x
ORA #$04
STA $1588,x
LDA $0D
STA $0F69
SEC
RTS
+
SEP #$21
RTS

SwitchPalaces:
LDA $0E
PHA
LDA $0F
PHA
BNE .end
LDA $0E
SEC
SBC #$EC
CMP #$10
BCS .end			; Only match the right block numbers
BIT #$02
BNE .end			; Only match the tops! :P
LSR
LSR
TAY					; Turn it into an index by color, [green, yellow, blue, red]
LDA $1F27,y
BNE .end			; If we've already gotten this switch palace, nope the heck out of here
INC
STA $1F27,y			; Mark this palace gotten
STA $13D2			; Enable switch palace message
STY $191E			; Which depressed switch sprite to leave behind
LDA #$20
STA $1887			; Set earthquake timer
PHY
LDY #$02
LDA #$60
STA $009E,y			; Spawn sprite x60 (flag switch) in hardcoded slot 2?
LDA #$08
STA $14C8,y
LDA $9A				; Set x/y position based on positions of the block the player is currently touching
STA $00E4,y
LDA $9B
STA $14E0,y
LDA $98
CLC
ADC #$10
STA $00D8,y
LDA $99
ADC #$00
STA $14D4,y
PHX
TYX
JSL $07F7D2			; Load sprite tables
PLX
LDA #$5E			; In all.log this is 5F, but it's a timer and there's an off-by-one error somewhere because it's being spawned elsewhere???
STA $1540,y			; Set some sprite property
LDA #$0C
STA $1DFB			; Set music
LDA #$FF
STA $0DDA			; Set sound effect
LDA #$08
STA $1493			; Set end level timer
PLY
.end
PLA
STA $0F
PLA
STA $0E
RTS

WaterSplash:
; LDA $E4,x
; STA $00
; LDA $14E0,x
; STA $01
; LDA $D8,x
; STA $02
; LDA $14D4,x
; STA $03
LDY #$0B
-
LDA $17F0,y
BEQ +
DEY
BPL -
INY
+
LDA $D8,x
CLC
ADC #$08
PHP
AND #$F0
CLC
ADC #$03
STA $17FC,y
LDA $14D4,x
ADC #$00
PLP
ADC #$00
STA $1814,y
LDA $E4,x
STA $1808,y
LDA $14E0,x
STA $18EA,y
LDA #$07
STA $17F0,y
LDA #$00
STA $1850,y
RTS
