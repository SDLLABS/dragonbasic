{ -- MF/TIN modes 3 and 5 graphics library
  -- Copyright (c) 2003 by Jeff Massung }

\ returns the current graphics mode (bitmapped)
code-thumb display-mode ( -- n )
	tos push
	
	\ load REG_DISPCNT
	$40 ## tos mov,
	20 ## tos tos lsl,
	tos 0@ tos ldrh,
	
	\ mask off other bits
	29 ## tos tos lsl,
	29 ## tos tos lsr,
	ret
end-code

\ return the width (in bytes) of the display (inlined)
icode-thumb view-width ( mode -- u )
	\ works for only modes 3 and 5!
	tos w mov,
	160 ## tos mov,
	5 ## w cmp,
	4 #offset eq? b,
	240 ## tos mov,
	1 ## tos tos lsl,
end-code

\ return the size (in words) of the display (inlined)
icode-thumb view-size ( mode -- u )
	\ set mode 3 display size
	$4b ## w mov,
	8 ## w w lsl,	\ $4b00
	3 ## tos cmp,
	
	\ if not mode 3 then multiply by 2
	4 #offset ne? b,
	1 ## w w lsl,
	w tos mov,
end-code

\ return the current draw buffer address
code-thumb screen ( -- addr )
	tos push
	$60 ## tos mov,
	20 ## tos tos lsl,	\ VRAM
	
	\ get the screen mode
	$40 ## v2 mov,
	20 ## v2 v2 lsl,	\ REGISTERS
	v2 0@ v1 ldrh,
	
	\ test for mode 3
	7 ## v2 mov,
	v1 v2 and,
	3 ## v2 cmp,
	4 #offset ne? b,
	ret
	
	\ test for back buffer bit
	$10 ## v2 mov,
	v2 v1 tst,
	4 #offset eq? b,
	ret
	
	\ use backbuffer
	$a0 ## v2 mov,
	8 ## v2 v2 lsl,		\ BACKBUFFER
	v2 tos tos add,
	ret
end-code

\ clear the screen with a solid color
code-thumb (cls) ( color a size -- )
	\ load arguments
	$40000d0 v0 LITERAL	\ REGISTERS + $d0
	v1 v2 pop
	
	\ store color, load new tos
	16 ## v2 a lsl,
	a v2 orr,
	v2 a mov,
	sp 0@ v2 ldr,
	sp 0@ a str,
	
	\ set 32-bit 
	v0 $8 #( v1 str,	\ REGISTERS + $d8
	sp v1 mov,
	v0 $4 #( v1 str,	\ REGISTERS + $d4
	$85 ## v1 mov,
	24 ## v1 v1 lsl,	\ $85000000
	
	\ enable dma 3 to write 32-bit blocks
	tos v1 v1 add,
	v0 $c #( v1 str,	\ REGISTERS + $dc
	
	\ done
	4 ## sp add,
	v2 tos mov,
	ret
end-code

\ paste an image on the screen
code-thumb (wallpaper) ( a-source a-dest size -- )
	v1 v2 pop
	$40000d0 v0 LITERAL	\ REGISTERS + $d0
	
	\ setup DMA transfer
	$95000000 a movi
	a tos tos add,
	v0 $4 #( v2 str,	\ REGISTERS + $d4
	v0 $8 #( v1 str,	\ REGISTERS + $d8
	v0 $c #( tos str,	\ REGISTERS + $dc

	\ done
	tos pop
	ret
end-code

\ make the back buffer visible
code-thumb flip ( -- )
	REGISTERS v1 movi
	v1 0@ v2 ldrh,
	
	\ toggle the backbuffer bit
	$10 ## w mov,
	w v2 eor,
	v1 0@ v2 strh,
	
	\ done
	ret
end-code

\ wrappers for all bitmap graphics functions
: cls ( color -- ) screen display-mode view-size (cls) ;
: wallpaper ( a -- ) screen display-mode view-size (wallpaper) ;

\ plot a pixel in modes 3 and 5
code-thumb (plot) ( x y c a u -- )
	a v0 v1 v2 pop
	
	\ plot pixel
	tos v1 mul,
	1 ## v2 v2 lsl,
	v2 v1 v1 add,
	a v1 +( v0 strh,
	
	\ done
	tos pop
	ret
end-code

\ plot a pixel in mode 4
code-thumb (plot-4) ( x y c a -- )
	v1 v2 w pop
	
	\ get address
	240 ## v0 mov,
	v0 v2 mul,
	w v2 v2 add,
	tos v2 v2 add,
	
	\ get aligned address and load
	1 ## a mov,
	v2 v0 mov,
	a v0 bic,
	v0 0@ w ldrh,
	
	\ mask off a byte
	$ff ## tos mov,
	a v2 tst,
	6 #offset eq? b,
	\ odd pixel, leave mask at $ff, shift color up
	8 ## v1 v1 lsl,
	4 #offset b,
	\ even pixel, shift mask up, leave color
	8 ## tos tos lsl,

	tos w and,
	\ store desired byte
	v1 w orr,
	
	\ set and done
	v0 0@ w strh,
	tos pop
	ret
end-code

\ get a pixel color in modes 3 and 5
code-thumb (pixel) ( x y a u -- c )
	v1 v2 w pop
	
	\ get pixel
	tos v2 mul,
	1 ## w w lsl,
	w v2 v2 add,
	v1 v2 +( tos ldrh,
	
	\ done
	ret
end-code

\ get a pixel in mode 4
code-thumb (pixel-4) ( x y a -- c )
	v1 v2 pop
	
	\ get address
	240 ## v0 mov,
	v0 v1 mul,
	v2 v1 v1 add,
	tos v1 v1 add,
	
	\ mis-aligned will load properly
	v1 0@ tos ldrb,
	$ff ## v1 mov,
	v1 tos and,
	
	\ done
	ret
end-code

\ wrapper function to plot a pixel on the screen
: plot ( x y c -- )
	screen display-mode dup 4 # = 
		if drop (plot-4) else
	view-width (plot) then ;

\ wrapper function to get a pixel off the screen
: pixel ( x y -- c )
	screen display-mode dup 4 # =
		if drop (pixel-4) else
	view-width (pixel) then ;

\ blit a bitmap onto the screen (modes 3 and 5)
code-thumb (blit) ( a x y w h screen u -- )
	tos v4 mov,
	\ pop arguments
	tos a v0 v1 v2 w pop
	v0 v3 mov,
	v4 v0 mov,

	\ calculate first address: v1=tos+((v1*v3+v2)<<1)
	v0 v1 mul,
	1 ## v2 v2 lsl,
	v2 v1 v1 add,
	v1 tos tos add,
	v3 v2 mov,
	1 ## v2 v2 lsl,
	v2 v0 v0 sub,
	
	l: __blit
	\ draw each scanline
	v3 v2 mov,

	l: __scanline
	\ load mask and store
	w 0@ v1 ldrh,
	2 ## w w add,

	v1 v1 tst,
	4 #offset eq? b,
	tos 0@ v1 strh,

	2 ## tos tos add,
	\ loop until w=0
	1 ## v2 sub,		\ subs, actually
	__scanline ne? b,

	v0 tos tos add,
	\ loop until h=0
	1 ## a sub,	\ subs, actually
	__blit ne? b,

	tos pop
	ret
end-code

\ blit an image in mode 4
code-thumb (blit-4) ( a x y w h screen -- )
	ret
end-code

\ wrapper function for blitting an image
: blit ( a x y w h -- )
	screen display-mode dup 4 # =
		if drop (blit-4) else
	view-width (blit) then ;

\ finish drawing a line
code /line ( -- )
	sp db u r9 ldm,
	tos pop
	ret
end-code

\ draw a horizontal bresenham line
code (h-line) ( -- )
	r6 1 #lsr r5 r10 sub,

	l: __loop
	
	\ test done
	r2 r4 cmp,
	/line eq? b,

	\ horizontal loop
	0 ## r10 cmp,
	r9 r3 r3 pl? add,
	r6 r10 r10 pl? sub,
	r8 r4 r4 add,
	r5 r10 r10 add,
	
	\ write pixel
	r4 1 #lsl r11 mov,
	r11 r3 +( r0 strh,
	__loop b,
end-code

\ draw a vertical bresenham line
code (v-line) ( -- )
	r5 1 #lsr r6 r10 sub,
	
	l: __loop
	
	r3 r1 cmp,
	/line eq? b,

	\ vertical loop 
	0 ## r10 cmp,
	r8 r4 r4 pl? add,
	r5 r10 r10 pl? sub,
	r9 r3 r3 add,
	r6 r10 r10 add,
	
	\ write pixel
	r4 1 #lsl r11 mov,
	r11 r3 +( r0 strh,
	__loop b,
end-code

\ draw a bresenham line
code line ( screen x1 y1 x2 y2 color -- )
	\ get screen width
	REGISTERS ## r1 mov,
	r1 0@ r1 ldrh,
	7 ## r1 r1 and,
	5 ## r1 cmp,
	320 ## r9 eq? mov,
	480 ## r9 ne? mov,

	\ load arguments and save forth registers
	sp ia! r1 r2 r3 r4 r10 ldm,
	sp db u r9 stm,

	\ prepare
	1 ## r8 mov,
	r3 r1 r5 s! sub,
	r9 r1 r1 mul,
	r9 r3 r3 mul,

	\ setup bresenham algorithm
	0 ## r5 r5 mi? rsb,
	0 ## r9 r9 mi? rsb,
	r4 r2 r6 s! sub,
	0 ## r6 r6 mi? rsb,
	0 ## r8 r8 mi? rsb,
	r5 1 #lsl r5 mov,
	r6 1 #lsl r6 mov,
	r10 1 #lsr r4 r4 add,
	r10 1 #lsr r2 r2 add,
	
	\ write the first pixel at (x,y)
	r4 1 #lsl r11 mov,
	r11 r3 +( r0 strh,
	r5 r6 cmp,
	
	\ if dy < dx then horizontal bresenham 
	(h-line) gt? b,
	(v-line) b,
end-code
