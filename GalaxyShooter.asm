  .inesprg 1   ; 1x 16KB PRG code

  .ineschr 1   ; 1x  8KB CHR data

  .inesmap 0   ; mapper 0 = NROM, no bank swapping
  .inesmir 1   ; background mirroring
  
; ---- Variables ----
  .rsset $0000
  
variables .rs 16

randomNum .rs 1     

playerX .rs 1
playerY .rs 1
PLAYER_SPEED = $02

score .rs 1
buttons1 .rs 1       ; ABSeSt UDLR
oamPointer .rs 1     ; index for unfilled OAM buffer

MAX_BULLET = 8
bulletsPosX .rs MAX_BULLET
bulletsPosY .rs MAX_BULLET
bulletsState .rs MAX_BULLET  ; Axxx xxxx , Active
bulletSpawnTimer .rs 1

BULLET_SPEED = $04
BULLET_SPAWN_TIME_INTERVAL = $06

MAX_ENEMIES = 10
enemiesPosX .rs MAX_ENEMIES
enemiesPosY .rs MAX_ENEMIES
enemiesState .rs MAX_ENEMIES   ; AHHx xxTT , Active Health Type
enemySpawnTimer .rs 1
enemyZigZagTimer .rs 1

ENEMY_SPEED = $01
ENEMY_SPAWN_TIME_INTERVAL = $40
ENEMY_ZIG_ZAG_TIME_INTERVAL = $FF

LEFT_EDGE = $04
RIGHT_EDGE = $F4
BOTTOM_EDGE = $FC
TOP_EDGE = $20

  
  
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


;----- APU Registers -----

APU_SQUARE1_ENV = $4000   ; DDLC VVVV
APU_SQUARE1_SWEEP = $4001  ; EPPP NSSS
APU_SQUARE1_LOW = $4002    ; llll llll  , low timer
APU_SQUARE1_LEN_HI = $4003   ; LLLL LHHH  ,   Length, High timer

APU_SQUARE2_ENV = $4004
APU_SQUARE2_SWEEP = $4005
APU_SQUARE2_LOW = $4006
APU_SQUARE2_HI = $4007

APU_TRI_CTRL = $4008 ; CRRR RRRR 
APU_TRI_LOW = $400A 
APU_TRI_HI = $400B  ; LLLL LHHH , Length, High timer

APU_NOISE_ENV = $400C
APU_NOISE_MODE_PERIOD = $400E
APU_NOISE_LENGTH = $400F

APU_STATUS = $4015      ; xxxD NT21, IFxD NT21 : write, read
APU_FRAME_COUNT = $4017   ; MIxx xxxx


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
  LDA #$FE      ; all sprites invisible
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
  JSR UpdateGame
  
  ; Transfer sprites
  LDA #$00
  STA OAM_ADDR       ; set the low byte (00) of the RAM address
  LDA #$02
  STA OAM_DMA       ; set the high byte (02) of the RAM address, start the transfer
  
  
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
  LDA #$26  ; Random seed
  STA randomNum
  RTS
  
  
UpdateGame:
  JSR ClearOAM
  JSR ReadButtons1
  JSR UpdatePlayer
  JSR ShootBullet
  JSR UpdateBullets
  JSR UpdateEnemies
  JSR DetectCollisions
  
  RTS
  
  


UpdatePlayer:
  JSR MovePlayerLeft
  JSR MovePlayerRight
  JSR MovePlayerUp
  JSR MovePlayerDown
  JSR DrawPlayer
  RTS
  
  
ClearOAM:
  LDA #$FE     ; make all sprites below the screen (invisible)
  LDX #$00
.loop:
  STA $0200, X
  INX
  CPX oamPointer
  BCC .loop
  
  LDA #$00
  STA oamPointer    ; Reset oamPointer to 0

  RTS
  
  
DrawPlayer:
  LDX oamPointer
  
  ; x-pos
  LDA playerX
  STA $0203, X   ;top-left
  STA $0203+8, X   ;bottom-left
  CLC
  ADC #$08
  STA $0203+4, X   ;top-right
  STA $0203+12, X   ;bottom-right
  
  ; y-pos
  LDA playerY
  STA $0200, X   ;top-left
  STA $0200+4, X   ;top-right
  CLC
  ADC #$08
  STA $0200+8, X   ;bottom-left
  STA $0200+12, X   ;bottom-right
  
  ; tiles
  LDA #$01
  STA $0201, X  
  LDA #$02
  STA $0201+4, X
  LDA #$11
  STA $0201+8, X
  LDA #$12
  STA $0201+12, X
  
  ; attributes
  LDA #$00
  STA $0202, X  
  STA $0202+4, X
  STA $0202+8, X
  STA $0202+12, X
  
  TXA 
  CLC
  ADC #$10
  STA oamPointer
  
  RTS
  

  
UpdateBullets:
  LDA bulletSpawnTimer
  BEQ skip_bulletSpawnTimerUpdate
  DEC bulletSpawnTimer
skip_bulletSpawnTimerUpdate:
  LDX #$00
loop_UpdateBullets:
  LDA bulletsState, X
  AND #$80
  BEQ skip_bulletPosUpdate
  
  LDA bulletsPosY, X
  SEC
  SBC #BULLET_SPEED
  STA bulletsPosY, X
  BCC bulletDestroy  ; if overflow from screen, destroy bullet
  
  CMP #TOP_EDGE
  BCS skip_bulletDestroy 
bulletDestroy:
  LDA bulletsState, X
  EOR #$80        ; make state inactive
  STA bulletsState, X
  
skip_bulletDestroy:
 
  ; Draw the Bullet
  LDY oamPointer
  LDA bulletsPosX, X
  STA $0203, Y
  LDA bulletsPosY, X
  STA $0200, Y
  LDA #$00  ; Tile 
  STA $0201, Y
  LDA #$00  ; Attribute
  STA $0202, Y
  INY
  INY
  INY
  INY
  STY oamPointer
  
skip_bulletPosUpdate:
  INX
  CPX #MAX_BULLET
  BCC loop_UpdateBullets

  RTS


ShootBullet:
  LDA buttons1
  AND #$80
  BEQ .end
  
  ; check bullet spawn timer and continue if 0 and reset
  LDA bulletSpawnTimer
  BNE .end
  
  LDA #BULLET_SPAWN_TIME_INTERVAL
  STA bulletSpawnTimer
  
; check if any bullet is not active in array and spawn a new bullet there, otherwise skip
  LDX #$00
.bulletCheckLoop:
  LDA bulletsState, X
  AND #$80
  BEQ .spawnBullet
  INX
  CPX #MAX_BULLET
  BNE .bulletCheckLoop
  
  JMP .end
.spawnBullet:
   LDA #$80
   STA bulletsState, X
   LDA playerX
   CLC
   ADC #$07              ; add offset from player position for the bullets
   STA bulletsPosX, X
   LDA playerY
   SEC
   SBC #$02
   STA bulletsPosY, X
   JSR PlayBulletSound
  

.end:
  RTS
  
  
  
UpdateEnemies:

  INC enemyZigZagTimer
  INC enemyZigZagTimer
  INC enemyZigZagTimer
  INC enemyZigZagTimer

  LDA enemySpawnTimer
  BEQ skip_enemySpawnTimerUpdate
  
  DEC enemySpawnTimer
  JMP skip_enemySpawn  ; if timer not over, skip spawn
  
skip_enemySpawnTimerUpdate:
  JSR SpawnEnemy
skip_enemySpawn:
  LDX #$00
loop_UpdateEnemies:
  LDA enemiesState, X
  AND #$80
  BEQ skip_enemyPosUpdate
  
  LDA enemyZigZagTimer
  CMP #$80
  BCC moveRight_UpdateEnemy 
  
  LDA enemiesPosX, X
  SEC
  SBC #ENEMY_SPEED
  STA enemiesPosX, X

  JMP endmoveRight_UpdateEnemy
  
moveRight_UpdateEnemy:
  LDA enemiesPosX, X
  CLC
  ADC #ENEMY_SPEED
  STA enemiesPosX, X

endmoveRight_UpdateEnemy:
  LDA enemiesPosY, X
  CLC
  ADC #ENEMY_SPEED
  STA enemiesPosY, X
  BCS enemyDestroy  ; if overflow from screen, destroy enemy
  
  CMP #BOTTOM_EDGE
  BCC skip_enemyDestroy 
enemyDestroy:
  LDA enemiesState, X
  EOR #$80        ; make state inactive
  STA enemiesState, X
  
skip_enemyDestroy:
 
  ; Draw enemy sprite
  LDY oamPointer
  LDA enemiesPosX, X
  STA $0203, Y
  LDA enemiesPosY, X
  STA $0200, Y
  LDA #$02  ; Tile 
  STA $0201, Y
  LDA #$01  ; Attribute
  STA $0202, Y
  INY
  INY
  INY
  INY
  STY oamPointer
  
skip_enemyPosUpdate:
  INX
  CPX #MAX_ENEMIES
  BCC loop_UpdateEnemies
  
  RTS
  
  
  
SpawnEnemy:
  
  LDA #ENEMY_SPAWN_TIME_INTERVAL
  STA enemySpawnTimer
  
; check if any enemy is not active in array and spawn a new enemy there, otherwise skip
  LDX #$00
.loop:
  LDA enemiesState, X
  AND #$80
  BEQ .continue
  INX
  CPX #MAX_ENEMIES
  BNE .loop
  
  JMP .end
.continue:
   LDA #$80
   STA enemiesState, X
   JSR UpdateRandomNum
   LDA randomNum
   STA enemiesPosX, X
   LDA #$10
   STA enemiesPosY, X
   
.end:

  RTS



DetectCollisions:

  LDX #$00
loop_collisionBullets:
  LDA bulletsState, X
  AND #$80
  BEQ skip_collisionBullets
  
  LDY #$00
loop_collisionEnemies:
    LDA enemiesState, Y
    AND #$80
    BEQ skip_collisionEnemies
    
    ; a.x2 > b.x1 && a.x1 < b.x2
    LDA bulletsPosX, X    
    CLC 
    ADC #$08
    CMP enemiesPosX, Y
    BCC skip_collisionEnemies   ; skip if a.x2 < b.x1
    
    LDA enemiesPosX, Y
    CLC 
    ADC #$08
    CMP bulletsPosX, X    
    BCC skip_collisionEnemies   ; skip if b.x2 < a.x1
    
    ; a.y2 > b.y1 && a.y1 < b.y2
    LDA bulletsPosY, X    
    CLC 
    ADC #$08
    CMP enemiesPosY, Y
    BCC skip_collisionEnemies   ; skip if a.y2 < b.y1
    
    LDA enemiesPosY, Y
    CLC 
    ADC #$08
    CMP bulletsPosY, X    
    BCC skip_collisionEnemies   ; skip if b.y2 < a.y1
    
    ; if not skipped, collision
    LDA bulletsState, X
    EOR #$80       ; deactivate bullet
    STA bulletsState, X
    
    LDA enemiesState, Y
    EOR #$80       ; deactivate enemy
    STA enemiesState, Y
    
    JSR PlayColisionSound
    
skip_collisionEnemies:
    INY
    CPY #MAX_ENEMIES
    BCC loop_collisionEnemies

skip_collisionBullets:
  INX
  CPX #MAX_BULLET
  BCC loop_collisionBullets
  

  RTS




MovePlayerLeft:
  LDA buttons1
  AND #$02
  BEQ .end
  
  LDA playerX
  SEC
  SBC #PLAYER_SPEED
  STA playerX
  
.end:
  RTS
  
  
  
  
  
  
MovePlayerRight:
  LDA buttons1
  AND #$01
  BEQ .end
  
  LDA playerX
  CLC
  ADC #PLAYER_SPEED
  STA playerX
  
.end:
  RTS
  
  
MovePlayerUp:
  LDA buttons1
  AND #$08
  BEQ .end
  
  LDA playerY
  SEC
  SBC #PLAYER_SPEED
  STA playerY
  
.end:
  RTS
  
  
  
MovePlayerDown:
  LDA buttons1
  AND #$04
  BEQ .end
  
  LDA playerY
  CLC
  ADC #PLAYER_SPEED
  STA playerY
  
.end:
  RTS
  
  
  
  

PlayColisionSound:

  LDA #%00000001
  STA $4015 ;enable square 1

  LDA #%10011111 ;Duty 10, Volume F
  STA APU_SQUARE1_ENV
  LDA #$C9 ;0C9 is a C# in NTSC mode
  STA APU_SQUARE1_LOW
  LDA #$10
  STA APU_SQUARE1_LEN_HI
  
  RTS
  
  
PlayBulletSound:

  LDA #%00000001
  STA $4015 ;enable square 1

  LDA #%10011111 ;Duty 10, Volume F
  STA APU_SQUARE1_ENV
  LDA #$00 
  STA APU_SQUARE1_LOW
  LDA #$13
  STA APU_SQUARE1_LEN_HI
  
  RTS



 
ReadButtons1: 
  LDA #$01
  STA buttons1   ; buttons = 1, to stop loop after 8 times
  STA JOYPAD1    ; Poll Input, 1 -> JOYPAD1
  LSR A          ; A -> 0
  STA JOYPAD1    ; Finish Polling, 0 -> JOYPAD1
.loop:
  LDA JOYPAD1
  LSR A
  ROL buttons1    ; Carry -> bit 0; but 7 -> Carry
  BCC .loop
  RTS
 
 
 
UpdateRandomNum:
  LDA randomNum
  
  ROL randomNum
  ROL randomNum
  ROL randomNum
  
  EOR randomNum
  STA randomNum
  
  ROR randomNum
  ROR randomNum
  ROR randomNum
  ROR randomNum
  ROR randomNum
  
  EOR randomNum
  STA randomNum
  
  RTS
 
 
;;;;;;;;;;;;;;  
  
  .bank 1
  .org $E000
palette:
  .db $1E,$2A,$28,$1C,  $1F,$36,$17,$0F,  $1F,$30,$21,$0F,  $1F,$27,$17,$0F   ;;background palette
  .db $1F,$2A,$28,$1C,  $1F,$02,$38,$3C,  $1F,$1C,$15,$14,  $1F,$02,$38,$3C   ;;sprite palette

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