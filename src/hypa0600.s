
HYPA0600:
        ldx     #<HYPALOAD_060E
        ldy     #>HYPALOAD_060E
        stx     RAM_ILOAD
        sty     RAM_ILOAD+1
        rts

ROM_LOAD:
        lda     VERFCK
        ldy     $D0
        jmp     LF04A

HYPALOAD_060E:
        sta     VERFCK
        sty     $D0
        tay
        bne     ROM_LOAD        // verify
        lda     RAM_FA
        cmp     #$04
        bcc     ROM_LOAD
        lda     RAM_FNLEN
        beq     ROM_LOAD
        lda     #RAM_FNADR
        sta     a07DF
        ldy     #$00
        jsr     RAM_RLUDES
        cmp     #'$'
        beq     ROM_LOAD
        ldx     #<E0633
        ldy     #>E0633
        stx     RAM_ISTOP
        sty     RAM_ISTOP+1
        jmp     LF06B

E0633:  pla                     ; XXX entrypoint
        pla
        ldx     #<EF265
        ldy     #>EF265
        stx     RAM_ISTOP
        sty     RAM_ISTOP+1
;        jsr     L077C
L077C:  jsr     LEF3B
        jsr     LF211
        lda     TED_BORDER      ; remember border color
        sta     $D0
        lda     TED_FF06        ; remember screen status
        sta     $D1
        lda     #$01            ; close channel 1 (LOAD)
        jsr     CLOSE
;
        lda     #$01            ; reopen as command channel
        ldx     #DEV1551
        ldy     #$0F
        jsr     SETLFS
        lda     #$05
        ldx     #<HYPA0400      ; M-E, $A003
        ldy     #>HYPA0400
        jsr     SETNAM
        jsr     OPEN
        jmp     E0455


E0697:  tya                     ; XXX entrypoint end of LOAD
        pha
        lda     #$00
        sta     ($9D),y
        tay
        sta     BANK_RAM        ; enable whole RAM
        dey
        sty     TCBM_DEV8_3     ; port DDR = $FF, output only
        ldy     #$40
        sty     TCBM_DEV8_2     ; DAV=1
;        ldy     #$1B           ; Y overwritten
;        jmp     L067B
L067B:  pla                     ; executed after load, before 65e
        pha
        tay
        dey
        lda     ($9D),y         ; why checking for $FF at the end of the file?
        cmp     #$FF
        bne     L068C
        pla
        tya
        pha
        lda     #$00
        sta     ($9D),y
L068C:  lda     $D1            ; screen possibly on
        sta     TED_FF06
        sta     BANK_ROM        ; restore ROM bank
;        jmp     L06D3
L06D3:  cli
        pla
        clc
        adc     #$01
        sta     $9D
;        jmp     L065E
L065E:  lda     $9E             ; executed after load
        adc     #$00
        sta     $9E
        lda     $9D             ; $2D/2E VARTAB Pointer: start of BASIC variables
        sta     $2D
        lda     $9E
        sta     $2E
        lda     $D0
        sta     TED_BORDER      ; restore border color
        ldx     $9D             ; X/Y end of data address
        ldy     $9E
        rts

E06B0:  sei                     ; XXX entrypoint, start LOAD
        sta     BANK_RAM        ; enable whole RAM
        lda     #$0B            ; screen off
        sta     TED_FF06
        ldy     #$00
        sty     TCBM_DEV8_2     ; DAV=0
        sty     TCBM_DEV8_3     ; port DDR = $00, input only
        ; get load address
-       lda     TCBM_DEV8_2
        bmi     -
        lda     TCBM_DEV8_1     ; status EOF?
        bne     E0697 ; L0445
        lda     TCBM_DEV8       ; read data
        sta     $9D
+       lda     #$40
        sta     TCBM_DEV8_2     ; DAV=1 - acknowledge data
-       lda     TCBM_DEV8_2
        bpl     -
        lda     TCBM_DEV8_1
        bne     E0697; L0445
        lda     TCBM_DEV8
        sta     $9E
        ldx     #0
        stx     TCBM_DEV8_2     ; DAV=0 - acknowledge data

        lda     RAM_SA
        bne     +
        lda     $B4
        sta     $9D
        lda     $B5
        sta     $9E
+
        rts                     ; Y must be 0 at the end of the routine! (initial data offset)
