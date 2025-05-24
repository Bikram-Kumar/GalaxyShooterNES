  .inesprg 1   ; 1x 16KB PRG code

  .ineschr 1   ; 1x  8KB CHR data

  .inesmap 0   ; mapper 0 = NROM, no bank swapping
  .inesmir 1   ; background mirroring
  
; ---- Variables ----
  .rsset $0000
  
vars .rs 16
playerX .rs 1
playerY .rs 1
score .rs 1
buttons1 .rs 1       ; ABSeSt UDLR



LEFT_EDGE = $04
RIGHT_EDGE = $F4
BOTTOM_EDGE = $E0
TOP_EDGE = $20
PLAYER_SPEED = $02
  
  
  
; --- PPU Registers ---

PPU_CTRL  = $2000  ; VPHB SINN
PPU_MASK  = $2001  ; BGRs bMmG
PPU_STATUS = $2002
OAM_ADDR  = $2003
OAM_DATA  = $2004
PPU_SCROLL = $2005
PPU_ADDR  = $2006
PPU_DATA  = $2007
OAM_DMA  = $4014

JOYPAD1 = $4016
JOYPAD2 = $4017

APU_FRAME_COUNT = $4017

;;;;;;;;;;;;;;;

    
  .bank 0
  .org $C000 
RESET:
  SEI          ; disable IRQs
  CLD          ; disable decimal mode
  LDX #$40
  STX APU_FRAME_COUNT    ; disable APU frame IRQ
  LDX #$FF
  TXS          ; Set up stack
  INX          ; now X = 0
  STX PPU_CTRL    ; disable NMI
  STX PPU_MASK    ; disable rendering
  STX $4010    ; disable DMC IRQs

vblankwait1:       ; First wait for vblank to make sure PPU is ready
  BIT PPU_STATUS
  BPL vblankwait1

clrmem:
  LDA #$00
  STA $0000, x
  STA $0100, x
  STA $0300, x
  STA $0400, x
  STA $0500, x
  STA $0600, x
  STA $0700, x
  LDA #$FE
  STA $0200, x
  INX
  BNE clrmem
   
vblankwait2:      ; Second wait for vblank, PPU is ready after this
  BIT PPU_STATUS
  BPL vblankwait2


LoadPalettes:
  LDA PPU_STATUS             ; read PPU status to reset the high/low latch
  LDA #$3F
  STA PPU_ADDR             ; write the high byte of $3F00 address
  LDA #$00
  STA PPU_ADDR             ; write the low byte of $3F00 address
  LDX #$00              ; start out at 0
LoadPalettesLoop:
  LDA palette, x        
  STA $2007             ; write to PPU
  INX                   ; X = X + 1
  CPX #$20              ; Compare X to hex $10, decimal 16 - copying 16 bytes = 4 sprites
  BNE LoadPalettesLoop  ; Branch to LoadPalettesLoop if compare was Not Equal to zero
                        ; if compare was equal to 32, keep going down



LoadSprites:
  LDX #$00              ; start at 0
LoadSpritesLoop:
  LDA sprites, x        ; load data from address (sprites +  x)
  STA $0200, x          ; store into RAM address ($0200 + x)
  INX                   ; X = X + 1
  CPX #$10              ; Compare X to hex $10, decimal 16
  BNE LoadSpritesLoop   ; Branch to LoadSpritesLoop if compare was Not Equal to zero
                        ; if compare was equal to 16, keep going down
              
              
              
LoadBackground:
  LDA PPU_STATUS             ; read PPU status to reset the high/low latch
  LDA #$20
  STA PPU_ADDR             ; write the high byte of $2000 address
  LDA #$00
  STA PPU_ADDR             ; write the low byte of $2000 address
  LDX #$00              ; start out at 0
LoadBackgroundLoop:
  LDA background, x     ; load data from address (background + the value in x)
  STA $2007             ; write to PPU
  INX                   ; X = X + 1
  CPX #$80              ; Compare X to hex $80, decimal 128 - copying 128 bytes
  BNE LoadBackgroundLoop  ; Branch to LoadBackgroundLoop if compare was Not Equal to zero
                        ; if compare was equal to 128, keep going down
              
              
LoadAttribute:
  LDA PPU_STATUS             ; read PPU status to reset the high/low latch
  LDA #$23
  STA PPU_ADDR             ; write the high byte of $23C0 address
  LDA #$C0
  STA PPU_ADDR             ; write the low byte of $23C0 address
  LDX #$00              ; start out at 0
LoadAttributeLoop:
  LDA attribute, x      ; load data from address (attribute + the value in x)
  STA $2007             ; write to PPU
  INX                   ; X = X + 1
  CPX #$08              ; Compare X to hex $08, decimal 8 - copying 8 bytes
  BNE LoadAttributeLoop  ; Branch to LoadAttributeLoop if compare was Not Equal to zero
                        ; if compare was equal to 128, keep going down


  JSR InitGame
  
  
              
  LDA #%10010000   ; enable NMI, sprites from Pattern Table 0, background from Pattern Table 1
  STA PPU_CTRL

  LDA #%00011110   ; enable sprites, enable background, no clipping on left side
  STA PPU_MASK
  

Forever:
  JMP Forever     ;jump back to Forever, infinite loop
  
 

NMI:
  LDA #$00
  STA OAM_ADDR       ; set the low byte (00) of the RAM address
  LDA #$02
  STA OAM_DMA       ; set the high byte (02) of the RAM address, start the transfer
  
  JSR ReadButtons1
  JSR UpdatePlayer
  
  

  
PPU_Cleanup:
  LDA #%10010000   ; enable NMI, sprites from Pattern Table 0, background from Pattern Table 1
  STA PPU_CTRL
  LDA #%00011110   ; enable sprites, enable background, no clipping on left side
  STA PPU_MASK
  LDA #$00        ;;tell the ppu there is no background scrolling
  STA PPU_SCROLL
  STA PPU_SCROLL
  
  RTI             ; return from interrupt
 
 
; ------- SUBROUTINES -------

InitGame:
  LDA #$80
  STA playerX
  STA playerY
  RTS

UpdatePlayer:
  JSR MovePlayerLeft
  JSR MovePlayerRight
  JSR MovePlayerUp
  JSR MovePlayerDown
  LDA playerX
  STA $0203
  STA $020B
  CLC
  ADC #$08
  STA $0207
  STA $020F
  LDA playerY
  STA $0200
  STA $0204
  CLC
  ADC #$08
  STA $0208
  STA $020C
  RTS



MovePlayerLeft:
  LDA buttons1
  AND #$02
  BEQ end_MovePlayerLeft
  
  LDA playerX
  SEC
  SBC #PLAYER_SPEED
  STA playerX
  
end_MovePlayerLeft:
  RTS
  
MovePlayerRight:
  LDA buttons1
  AND #$01
  BEQ end_MovePlayerRight
  
  LDA playerX
  CLC
  ADC #PLAYER_SPEED
  STA playerX
  
end_MovePlayerRight:
  RTS
  
  
MovePlayerUp:
  LDA buttons1
  AND #$08
  BEQ end_MovePlayerUp
  
  LDA playerY
  SEC
  SBC #PLAYER_SPEED
  STA playerY
  
end_MovePlayerUp:
  RTS
  
  
  
MovePlayerDown:
  LDA buttons1
  AND #$04
  BEQ end_MovePlayerDown
  
  LDA playerY
  CLC
  ADC #PLAYER_SPEED
  STA playerY
  
end_MovePlayerDown:
  RTS



 
ReadButtons1: 
  LDA #$01
  STA buttons1   ; buttons = 1, to stop loop after 8 times
  STA JOYPAD1    ; Poll Input, 1 -> JOYPAD1
  LSR A          ; A -> 0
  STA JOYPAD1    ; Finish Polling, 0 -> JOYPAD1
loop_ReadButtons1:
  LDA JOYPAD1
  LSR A
  ROL buttons1    ; Carry -> bit 0; but 7 -> Carry
  BCC loop_ReadButtons1
  RTS
 
 
 
;;;;;;;;;;;;;;  
  
  .bank 1
  .org $E000
palette:
  .db $1E,$2A,$28,$1C,  $1F,$36,$17,$0F,  $1F,$30,$21,$0F,  $1F,$27,$17,$0F   ;;background palette
  .db $1F,$2A,$28,$1C,  $1F,$02,$38,$3C,  $1F,$1C,$15,$14,  $1F,$02,$38,$3C   ;;sprite palette

sprites:
     ;vert tile attr horiz
  .db $80, $01, $00, $80   ;sprite 0
  .db $80, $02, $00, $88   ;sprite 1
  .db $88, $11, $00, $80   ;sprite 2
  .db $88, $12, $00, $88   ;sprite 3


background:
  .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24  ;;row 1
  .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24  ;;all sky

  .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24  ;;row 2
  .db $24,$24,$24,$00,$24,$00,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24  ;;all sky

  .db $24,$24,$24,$24,$00,$03,$04,$24,$45,$45,$45,$45,$45,$45,$24,$24  ;;row 3
  .db $24,$24,$24,$24,$24,$13,$14,$24,$24,$24,$24,$24,$53,$54,$24,$24  ;;some brick tops

  .db $24,$24,$24,$24,$47,$47,$24,$24,$47,$47,$47,$47,$47,$47,$24,$24  ;;row 4
  .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$55,$56,$24,$24  ;;brick bottoms

attribute:
  .db %00000000, %00010000, %01010000, %00010000, %00000000, %00000000, %00000000, %00110000

  .db $24,$24,$24,$24, $47,$47,$24,$24 ,$47,$47,$47,$47, $47,$47,$24,$24 ,$24,$24,$24,$24 ,$24,$24,$24,$24, $24,$24,$24,$24, $55,$56,$24,$24  ;;brick bottoms



  .org $FFFA     ;first of the three vectors starts here
  .dw NMI        ;when an NMI happens (once per frame if enabled) the 
                   ;processor will jump to the label NMI:
  .dw RESET      ;when the processor first turns on or is reset, it will jump
                   ;to the label RESET:
  .dw 0          ;external interrupt IRQ is not used in this tutorial
  
  
;;;;;;;;;;;;;;  
  
  
  .bank 2
  .org $0000
  .incbin "GalaxyShooter.chr"   ;includes 8KB graphics file from SMB1