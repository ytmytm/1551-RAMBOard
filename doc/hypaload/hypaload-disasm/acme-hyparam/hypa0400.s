HYPA0400:
        !text   "M-E"
        !word   $A003

E0455:  jsr     L0461   ; entry point XXX call delay

L0408:  jsr     E06B0   ; setup for LOAD DAV=0, Y=0
L040B:  
-       lda     TCBM_DEV8_2
        bmi     -
        lda     TCBM_DEV8_1     ; status EOF?
        bne     L0445
        lda     TCBM_DEV8       ; read data
        sta     ($9D),y
        iny
        bne     +
        inc     $9E
+       lda     #$40
        sta     TCBM_DEV8_2     ; DAV=1 - acknowledge data
        lda     TED_BORDER      ; toggle border color
        eor     #$E0
        sta     TED_BORDER
-       lda     TCBM_DEV8_2
        bpl     -
        lda     TCBM_DEV8_1
        bne     L0445
        lda     TCBM_DEV8
        sta     ($9D),y
        lda     #$00
        sta     TCBM_DEV8_2     ; DAV=0 - acknowledge data
        iny
        bne     L040B
        lda     TED_BORDER      ; toggle border color
        eor     #$E0
        sta     TED_BORDER
        inc     $9E
        bne     L040B
L0445:  jmp     E0697

L0461:  ldx     #$03
--      ldy     #$00
-       nop
        iny
        bne     -
        dex
        bpl     --
        rts
