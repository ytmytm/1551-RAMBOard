
// 1551 ROM patch for drives with RAM expanded into $8000-$9FFF
//      and additional ROM mapped into $A000-$BFFF
//      (32K ROM with lowest 8K not available)
// by Maciej 'YTM/Elysium' Witkowiak <ytm@elysium.pl>, V1.0

// Configuration

// RAM expansion base address, we need 8K ($2000) area, by default $8000-$9FFF
.const RAMEXP = $8000 // 8K of expanded RAM

// which ROM to patch?
// uncomment one of the definitions below or pass them to KickAss as a command line option, e.g. -define ROM1551

// 1551
#define ROM1551
// no other alternative ROMs for 1551

// INFO
// - read whole track at once and cache
// - decode headers to get the order of sectors
// - needs only one disk revolution (20ms with 300rpm) to read and decode the whole track
// - sector GCR decoding errors are reported normally
// - header GCR decoding errors are not reported - but if a sector is not found we fall back on ROM routine which should report it during next disk revolution
// - keep option for embedded fastloader code (signature and jumptable at $A000); we could place fastloader to be called from Parobek there and skip the whole M-W thing

// Excellent resources:
// http://yape.homeserver.hu/download/C1551.ASM - 1551 ROM disassembly
// https://github.com/mist64/cbmsrc/tree/master/DOS_1551 - 1551 ROM source code
// http://www.unusedino.de/ec64/technical/formats/g64.html - 10 header GCR bytes? but DOS reads only 8 http://unusedino.de/ec64/technical/aay/c1541/ro41f3b1.htm (because header has 6 binary bytes) 
// http://unusedino.de/ec64/technical/aay/c1541
//	- note: 1581 disassembly contains references to 1571 ROM
// https://spiro.trikaliotis.net/cbmrom

.const HEADER = $18 // (5) ($18-$1C: ID1, ID2, T, S, CHK); $16 on 1541 
.const TRACK  = $1A // within HEADER
.const SECTOR = $1B // within HEADER
.const HDRPNT = $20 // (2) active header pointer; $32 on 1541
.const BUFPNT = $27 // (2) current buffer pointer; $30 on 1541
.const BTAB   = $F9 // (4) GCR decoding

// 1551 ROM locations
.const LC2BB = $C2BB // find drive number, instruction patched at $D121
.const LF406 = $F406 // next instruction after patch at $F403
.const LF50E = $F50E // 'ok' ending of read sector, A=1, jump to FA12 - error message
.const LF513 = $F513 // wait for header and then for sync (F560), patched instruction at $F403
.const LF560 = $F560 // wait for sync, set Y to 0
.const LFA12 = $FA12 // error number in A

// GCR decoding tables from 1551 ROM
.const V_F6FF = $F6FF
.const V_F70C = $F70C
.const V_F71C = $F71C
.const V_F729 = $F729

// note: if these zero-page location would cause compatibility issues, they can be moved to RAMBUF page, just making code a bit larger
//       the only exceptions are pointers bufpage/bufrest but these *may* be moved to workarea at BTAB ($F9)
// DOS unused zp
.const bufpage = $18	// (2) same as HEADER+0: ID1/ID2 before encoding; pointer to page GCR data, increase by $0100
.const counter = $1C	// (1) same as HEADER+4: header checksum before encoding; counter of read sectors, saved in RE_max_sector (alternatively use $4B DOS attempt counter for header find); written to by powerup routine at $EBBA (write protect drive 1), but that's ok
.const hdroffs = $1D	// (1) (drive number, must be reset to 0) offset to header GCR data at RE_cached_headers during data read and header decoding
//.const hdroffsold = $F5 // (1) (moved from zp to extra RAM) temp storage needed to compare current header with 1st read header
.const bufrest = BTAB+2 	// (1) counts decoded headers up to counter

// sizes
.const hdrsize = 8						// header size in GCR (8 GCR bytes become 5 header bytes)
.const maxsector = 22					// rather 21 but we have space

// actual area used: $8000-9BFF (track 1, 21 sectors)
.const RAMBUF = RAMEXP+$1E00 // last page for various stuff
.const RAMEXP_REST = RAMEXP+(maxsector*$0100)	// this is where remainder GCR data starts, make sure that it doesn't overlap RAMBUF (with sector headers)
.const RE_cached_track = RAMBUF+$ff
.const RE_max_sector = RAMBUF+$fe
.const RE_lastmode = RAMBUF+$fd
.const RE_cached_headers = RAMBUF+$0100
.const RE_cached_checksums = RAMBUF-$0100
.const hdroffsold = RAMBUF+$fc

/////////////////////////////////////

#if !ROM1551
.error "You have to choose ROM to patch"
#endif

#if ROM1551
.print "Assembling stock 1551 ROM 318008-01"
.segmentdef Combined  [outBin="1551.318008-01-patched.bin", segments="Base,Patch1,Patch3,Patch4,Patch5,Patch7,MainPatch", allowOverlap]
.segment Base [start = $8000, max=$ffff]
	.var data = LoadBinary("rom/1551.318008-01.bin")
	.fill $4000, $ff
	.fill data.getSize(), data.get(i)
#endif

/////////////////////////////////////

.segment Patch1 []
		.pc = $F403 "Patch sector read"
		jmp ReadSector

.segment Patch3 []
		.pc = $C72A "Patch disk change"
		jsr ResetCache

.segment Patch4 []
		.pc = $E9F4 "Patch ROM checksum"
		nop
		nop

.segment Patch5 []
		.pc = $F19F "Patch IRQ routine for disk controller"
		jsr InvalidateCacheForJob

.segment Patch7 []
		.pc = $D121 "Patch 'I' command"
		jsr InitializeAndResetCache

/////////////////////////////////////

.segment MainPatch [min=$A000,max=$BFFF]

		.pc = $A000
		.text "RAM"				// signature, last byte is the version number: 'M' is version 1
		// API
SpeedDOSRun:					// $A003
		jmp FastLoader			// SpeedDOS loader at a fixed address for C64 Kernal side
		jmp ReadTrack
		jmp ReadSector
		jmp ResetOnlyCache

/////////////////////////////////////

FastLoader:
		// not implemented yet
		rts

/////////////////////////////////////

InvalidateCacheForJob: {
		tya						// enters with Y as job number (5,4,3,2,1,0), we can change A,X but not Y
		tax
		lda $02,x				// job?
		bpl return				// no job
		cmp #$D0				// execute code?
		beq return				// yes, exec doesn't seek to track
		cmp #$90				// write sector?
		beq resetcache			// yes, always invalidate cache
		tya						// get track
		asl						// *2
		tax
		lda $08,x				// check track parameter for job
		cmp RE_cached_track		// is it cached already?
		beq return				// yes, there will be no track change
resetcache:
		jsr ResetOnlyCache		// invalidate cache
return:
		lda $02,y				// instruction from patched $F19F, must change CPU flags
		rts
}

/////////////////////////////////////

InitializeAndResetCache:
		jsr ResetOnlyCache
		jmp LC2BB				// instruction from patched $D121

/////////////////////////////////////

ResetCache:						// enters with A=$FF
		sta $0298				// instruction from patched $C72A, set error flag
ResetOnlyCache:
		lda #$ff
		sta RE_cached_track		// set invalid values
		sta RE_max_sector
		rts

/////////////////////////////////////

ReadSector:
		// required sector number is in (HDRPNT)+1, required track in (HDRPNT), data goes into buffer at (BUFPNT)
		ldy #0
		sty hdroffs				// always reset to 0 (could have been modified by ReadTrack)
		lda (HDRPNT),y			// is cached track the same as required track?
		sta TRACK				// fastloaders might need it here (what F519 does)
		cmp RE_cached_track
		beq ReadCache			// yes - read from cache
		jmp ReadTrack			// no - read the track

ReadCache:
		iny						// yes, track is cached, just put data back and jump into ROM
		lda (HDRPNT),y			// needed sector number
		sta SECTOR				// fastloader might need it here (what F519 does)
		// setup pointers
		lda #>RAMEXP			// pages - first 256 bytes
		sta bufpage+1
		lda #0
		sta bufpage
		// find sector
		ldx #0
!loop:	lda RE_cached_headers,x	// cached sectors in fact
		cmp SECTOR
		beq !found+
		// no, next one
		inc bufpage+1
		inx
		cpx RE_max_sector
		bne !loop-
		// not found? fall back on ROM and try to read it again
		jsr LF513				// replaced instruction
		jmp LF406				// next instruction

!found:	// copy data and fall back into ROM		
		ldy #0
!:		lda (bufpage),y
		sta (BUFPNT),y
		iny
		bne !-

		jmp LF50E				// we have data as if it came from the disk, continue in ROM, return 'ok'

ReadTrack:
		sta RE_cached_track		// this will be our new track for caching

		lda #>RAMEXP			// decoded data pages
		sta bufpage+1
		lda #0
		sta bufpage
		sta hdroffs				// 8-byte counter for sector headers at RAMBUF
		sta counter				// data block counter

		// end loop when header we just read is the same as 1st read counter (full disk revolution) or block counter is 23
ReadHeader:
		jsr	LF560			// ; wait for SYNC, Y=0
		ldx hdroffs
		stx hdroffsold
		//ldy #0			// F560 sets Y to 0
		lda #$52			// header magic value
!:		bit $01
		bpl !-
		cmp $4001			// is that a header?
		bne ReadHeader		// no, wait until next SYNC
		sta RE_cached_headers,x
		inx
		iny					// yes, read remaining 8 bytes (or 10?)
!:		bit $01
		bpl !-
		lda $4001
		sta RE_cached_headers,x
		inx
		iny
		cpy #hdrsize		// whole header?
		bne !-
		stx hdroffs			// new header offset
		// do we have that sector already? (tested on VICE that there is enough time to check it before sector sync even on the fastest speedzone (track 35))
		ldx hdroffsold
		beq ReadGCRSector	// it's first sector, nothing to compare with
		ldy #0
!:		lda RE_cached_headers+1,x	// skip magic value byte
		cmp RE_cached_headers+1,y
		bne ReadGCRSector
		inx
		iny
		cpy #3				// last few bytes are identical too
		bne !-
		jmp DecodeData		// yes, no need to read more

ReadGCRSector:
		jsr LF560			// wait for SYNC, will set Y=0
		// copied from F403 onwards: read and decode sector on the fly
		// but replaced sta (BUFPNT),y by sta (bufpage),y
!:		bit $01
		bpl !-
		lda $4001
		sta BTAB+1
		and #$F8
		tax
		lda V_F70C,X
		sta BTAB
		lda BTAB+1
		and #$07
		sta BTAB+1
!:		bit $01
		bpl !-
		lda $4001
		sta BTAB+2
		and #$C0
		ora BTAB+1
		tax
		lda V_F70C,X
		ora BTAB
		pha
		bne B_F464
		beq B_F464
B_F435:
!:		bit $01
		bpl !-
		lda $4001
		sta BTAB+1
		and #$F8
		tax
		lda V_F70C,X
		sta BTAB
		lda BTAB+1
		and #$07
		sta BTAB+1
!:		bit $01
		bpl !-
		lda $4001
		sta BTAB+2
		and #$C0
		ora BTAB+1
		tax
		lda V_F70C,X
		ora BTAB
		sta (bufpage),Y
		iny
		beq B_F4D9
B_F464:
		lda BTAB+2
		and #$3E
		tax
		lda V_F70C,X
		sta BTAB
		lda BTAB+2
		and #$01
		sta BTAB+2
!:		bit $01
		bpl !-
		lda $4001
		sta BTAB+3
		and #$F0
		ora BTAB+2
		tax
		lda V_F70C + 2,X
		ora BTAB
		sta (bufpage),Y
		iny
		lda BTAB+3
		and #$0F
		sta BTAB+3
!:		bit $01
		bpl !-
		lda $4001
		sta BTAB+4
		and #$80
		ora BTAB+3
		tax
		lda V_F71C,X
		sta BTAB
		lda BTAB+4
		and #$7C
		tax
		lda V_F70C + 1,X
		ora BTAB
		sta (bufpage),Y
		iny
		lda BTAB+4
		and #$03
		sta BTAB+4
!:		bit $01
		bpl !-
		lda $4001
		sta BTAB+1
		and #$E0
		ora BTAB+4
		tax
		lda V_F729,X
		sta BTAB
		lda BTAB+1
		and #$1F
		tax
		lda V_F6FF,X
		ora BTAB
		sta (bufpage),Y
		iny
		jmp B_F435

B_F4D9:
		lda BTAB+2
		and #$3E
		tax
		lda V_F70C,X
		sta BTAB
		lda BTAB+2
		and #$01
		sta BTAB+2
!:		bit $01
		bpl !-
		lda $4001
		and #$F0
		ora BTAB+2
		tax
		lda V_F70C + 2,X
		ora BTAB
		sta BTAB+1
		pla
		cmp	#$07			// was DBID but near F409 it's cmp #$07 directly 
		bne	B_F50B			// issue error 4
		ldx counter
		lda BTAB + 1
		sta RE_cached_checksums,x	// save expected checksum for later, we can't checksum that sector now
		jmp ReadGCRSectorOK
CheckSumErr:
		ldx #$05			// issue error 5
		.byte $2c
B_F50B:	ldx #$04			// issue error 4
		jsr ResetOnlyCache	// any error invalidates cache, nothing is cached
		txa
		jmp	LFA12			// return with error

ReadGCRSectorOK:
		// there were no checksum errors yet, continue reading sectors
		// adjust pointers
		inc bufpage+1
		inc counter
		lda counter
		cmp #maxsector		// do we have all sectors already? (should be never equal)
		beq DecodeData  	// this jump should be never taken
		jmp ReadHeader		// not all sectors, read the next one

		// almost the same as DecodeData but we need to validate sector checksums and return back into ReadSector
		// we use different header decoding ROM routine, probably faster(?)
DecodeData:
		// check checksums of all sectors
		lda #>RAMEXP			// can reuse bufpage here
		sta bufpage+1
		ldx #0
		// this came from F60A
CheckLoop:
		lda #0
		tay
!:		eor (bufpage),y
		iny
		bne !-
		cmp RE_cached_checksums,x
		bne CheckSumErr
		inc bufpage+1
		inx
		cpx counter
		bne CheckLoop

		// GCR data was decoded on the fly, but we also need those sector numbers
		// so go through all headers and decode them, put them back
		// this is the same as DecodeHeaders for 1541, but we use L952F, apparently faster GCR decoder
		ldx #0
		stx bufrest		// reuse for counter

.const S_F928 = $F928	// decode 5 GCR bytes from (zp27)+zp2D into zp41-zp44
.const zp2D = $2d
.const zp41 = $41
		lda BUFPNT+1
		pha
		lda BUFPNT
		pha
		lda #<RE_cached_headers
		sta BUFPNT
		lda #>RE_cached_headers
		sta BUFPNT+1

DecodeLoop:
		lda #0			// this is changed every S_F928 call
		sta zp2D
		jsr S_F928		// decode 5 GCR bytes from (BUFPNT)+zp2D into zp41-44
		// XXX check header checksum here to mark mangled sector headers?
		ldx bufrest
		lda zp41+2
		sta RE_cached_headers,x	// store decoded sector number
		lda BUFPNT
		clc
		adc #hdrsize
		sta BUFPNT
		inx
		stx bufrest		// next header counter
		cpx counter
		bne DecodeLoop
		stx RE_max_sector
		// all was said and done, now read the sector from cache
		pla
		sta BUFPNT
		pla
		sta BUFPNT+1
		jmp ReadSector
