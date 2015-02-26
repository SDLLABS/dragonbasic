{ -- MF/TIN SPRITE functions
  -- Original code by Jeff Massung, 2003 }

{ -- OAM data is duplicated at 0x3000000 - 0x3000400
  -- and every updatesprites call waits for a vertical
  -- blank and copies the data to 0x7000000 - 0x7000400
  -- all function calls that return the address of a
  -- sprite return the duplicated address }

\ return the address of a sprite
:n sprite ( n -- a ) 3 # n* $3000000 # + ;

\ copy sprite data from ROM to VRAM
: loadsprite ( n a blocks -- )
	5 # n* a! swap 5 # n* $6000000 # + $10000 # + swap a copy ;

\ returns the current frame character of a sprite
: spriteframe ( n -- char )
	sprite 2 # + peek $fc00 # com and ;

\ create a new sprite
code makesprite ( sprite n -- )
	sp ia! v1 v3 ldm,
	IWRAM ## v2 mov,
	v1 3 #lsl v2 v1 add,
	
	\ clear sprite attribute 0 and set 256 color bit
	$2000 ## v2 mov,
	v1 2 (# v2 strh,
	
	\ clear attribute 1
	0 ## v2 mov,
	v1 2 (# v2 strh,
	
	\ set name bits of attribute 2
	v1 0@ tos strh,
	v3 tos mov,
	ret
end-code

\ set the shape and size of a sprite
code sizesprite ( sprite shape size -- )
	sp ia! v1 v2 ldm,
	IWRAM ## v3 mov,
	
	\ get sprite address
	v2 3 #lsl v3 v2 add,
	
	\ load shape bit and clear
	v2 0@ v4 ldrh,
	$c200 ## v4 v4 bic,
	v4 v1 v4 orr,
	v2 0@ v4 strh,
	
	\ load size and bit clear
	v2 2 #( v4 ldrh,
	$c000 ## v4 v4 bic,
	v4 tos v4 orr,
	v2 2 #( v4 strh,
	
	\ done
	tos pop
	ret
end-code

\ set a sprite to 16-color and select palette
code-thumb colorsprite ( sprite index -- )
	w pop
	
	\ sprite address
	IWRAM v2 LITERAL
	3 ## w v1 lsl,
	v1 v2 w add,
	
	\ set palette entry
	w 4 #( v2 ldrh, 
	$f000 v1 LITERAL
	v1 v2 bic,
	12 ## tos v1 lsl,
	v1 v2 orr,
	w 4 #( v2 strh,
	
	\ clear 256-color bit
	w 0@ v2 ldrh,
	$2000 v1 LITERAL
	v1 v2 bic,
	w 0@ v2 strh,

	\ done
	tos pop
	ret
end-code

\ flips a sprite or mirrors it
code flipsprite ( sprite x y -- )
	sp ia! v1 v2 ldm,
	IWRAM ## v3 mov,
	
	v2 3 #lsl v3 v2 add,
	
	\ clear flip bits
	v2 2 #( v3 ldrh,
	$3000 ## v3 v3 bic,
	
	\ set x flip bit
	0 ## v1 cmp,
	$1000 ## v3 v3 ne? orr,
	
	\ set y flip bit
	0 ## tos cmp,
	$2000 ## v3 v3 ne? orr,
	
	\ done
	v2 2 #( v3 strh,
	tos pop
	ret
end-code

\ return the x coordinate of a sprite
code spritex ( sprite -- x )
	IWRAM ## w mov,
	tos 3 #lsl w tos add,
	tos 2 #( tos ldrh,
	
	\ x >= 240 then negate
	$FE00 ## tos tos bic,
	$f0 ## tos cmp,
	$200 ## tos tos ge? sub,
	
	\ done
	ret
end-code

\ return the y coordinate of a sprite
code spritey ( sprite -- y )
	IWRAM ## w mov,
	tos 3 #lsl w tos add,
	tos 0@ tos ldrh,
	
	\ y >= 160 then negate
	$ff ## tos tos and,
	$a0 ## tos cmp,
	$100 ## tos tos ge? sub,
	
	\ done
	ret
end-code

\ move the sprite offscreen so it is hidden
code hidesprite ( sprite -- )
	IWRAM ## w mov,
	tos 3 #lsl w tos add,
	
	\ y = 160
	tos 0@ w ldrh,
	$ff ## w w bic,
	$a0 ## w w orr,
	tos 0@ w strh,
	
	\ x = 240
	tos 2 #( w ldrh,
	$FE00 ## w w and,
	$f0 ## w w orr,
	tos 2 #( w strh,
	
	\ done
	tos pop
	ret
end-code

\ returns -1 if sprite is offscreen or 0 if onscreen
code spritehidden ( sprite -- flag )
	IWRAM ## w mov,
	r0 3 #lsl w r0 add,
	
	\ check y >= 160
	r0 0@ w ldrh,
	$ff00 ## w w bic,
	$a0 ## w cmp,
	0 ## tos ge? mvn, \ tos = -1
	ge? ret
	
	\ check x >= 240
	r0 2 #( w ldrh,
	$fe00 ## w w bic,
	$f0 ## w cmp,
	0 ## tos ge? mvn, \ tos = -1
	ge? ret
	
	\ done
	0 ## tos mov, \ tos = 0
	ret
end-code

\ set the absolute position of a sprite
code-thumb positionsprite ( sprite x y -- )
	v1 v2 pop

	IWRAM w LITERAL
	3 ## v2 v2 lsl,
	v2 w v2 add,
	
	\ fix position
	$100 w LITERAL
	0 ## tos cmp,
	4 #offset ge? b,
	w tos tos add,
	0 ## v1 cmp,
	6 #offset ge? b,
	w v1 v1 add,
	w v1 v1 add,
	
	\ y position
	v2 0@ w ldrh,
	$ff00 v0 LITERAL
	v0 w and,
	tos w orr,
	v2 0@ w strh,
	
	\ x position
	v2 2 #( w ldrh,
	$fe00 v0 LITERAL
	v0 w and,
	v1 w orr,
	v2 2 #( w strh,
	
	\ done
	tos pop
	ret
end-code

\ relative movement of a sprite
code movesprite ( sprite dx dy -- )
	sp ia! v1 v2 ldm,

	\ get address
	IWRAM ## w mov,
	v2 3 #lsl w v2 add,
	
	\ setup registers for speed
	$100 ## v4 mov,
	$ff ## v5 mov,
	
	\ load y and mask out
	v2 0@ v3 ldrh,
	v5 v3 v6 bic,
	v3 v5 v3 and,
	
	\ add dy to y position
	tos v3 v3 s! add,
	v4 v3 v3 lt? add,
	
	\ write new y position
	v5 v3 v3 and,
	v6 v3 v3 orr,
	v2 0@ v3 strh,
	
	\ x position is 9-bit
	$100 ## v5 v5 add,
	
	\ load x and mask out
	v2 2 #( v3 ldrh,
	v5 v3 v6 bic,
	v5 v3 v3 and,
	
	\ add dx to x position
	v1 v3 v3 s! add,
	v4 1 #lsl v3 v3 lt? add,
	
	\ write new x position
	v5 v3 v3 and,
	v6 v3 v3 orr,
	v2 2 #( v3 strh,
	
	\ done
	tos pop
	ret
end-code

\ set the draw priority of a sprite
code ordersprite ( sprite priority -- )
	w pop
	
	\ address of sprite
	IWRAM ## v2 mov,
	w 3 #lsl v2 w add,
	
	\ load, clear and set priority bit
	w 4 #( v2 ldrh,
	$c00 ## v2 v2 bic,
	tos 10 #lsl v2 v2 orr,
	w 4 #( v2 strh,

	\ done
	tos pop
	ret
end-code

\ update the frame of a sprite
code animsprite ( sprite start end blocks -- )
	sp ia! v1 v2 v3 ldm,
	
	\ sprite address
	IWRAM ## v0 mov,
	v3 3 #lsl v0 v0 add,
	
	\ load current frame
	v0 4 #( w ldrh,
	$fc00 ## w v4 bic,
	$fc00 ## w w and,
	
	\ if v4 < start || v4 > end then v4 = start - blocks
	v2 v4 cmp,
	tos v2 v4 lt? sub,
	v1 v4 gt? cmp,
	tos v2 v4 gt? sub,
	
	\ add blocks to v4 and reset if > end
	tos v4 v4 add,
	v1 v4 cmp,
	v2 v4 gt? mov,
	
	\ write back
	v4 w w orr,
	v0 4 #( w strh,
	
	\ done
	tos pop
	ret
end-code

\ sprite size constants (in ROM)
label __sizes

$00080008 , $00100010 , $00200020 , $00300030 , \ sqaure
$00100008 , $00200008 , $00200010 , $00300020 , \ wide
$00080010 , $00080020 , $00100020 , $00200030 , \ tall

\ check to see if two sprites overlap at all
code bumpsprites ( sprite1 sprite2 -- flag )
	v6 pop
	tos v7 mov,
	
	\ get address of size table
	IWRAM ## v5 mov,
	__sizes tos LITERAL
	
	\ get addresses of sprites
	v6 3 #lsl v5 v6 add,
	v7 3 #lsl v5 v7 add,

	\ get the size of sprite 1 (V6->[V0,V1])
	v6 0@ v4 ldrh,
	v6 2 #( v5 ldrh,
	$c000 ## v4 v4 and,
	v4 12 #lsr v4 mov,
	v5 14 #lsr v4 v4 orr,
	tos v4 2 #lsl +( v0 ldr,
	$ff ## v0 v1 and,
	v0 16 #lsr v0 mov,

	\ get the position of sprite 1 (V6->[V2,V6])
	v6 2 #( v2 ldrh,
	v6 0@ v6 ldrh,
	$ff ## v6 v6 and,
	$fe00 ## v2 v2 bic,

	\ make sure that negative values will collide
	240 ## v2 cmp,
	$200 ## v2 v2 ge? sub,
	160 ## v6 cmp,
	$100 ## v6 v6 ge? sub,

	\ get the size of sprite 2 (V7->[V5,V3])
	v7 0@ v4 ldrh,
	v7 2 #( v5 ldrh,
	$c000 ## v4 v4 and,
	v4 12 #lsr v4 mov,
	v5 14 #lsr v4 v4 orr,
	tos v4 2 #lsl +( v5 ldr,
	$ff ## v5 v3 and,
	v5 16 #lsr v5 mov,

	\ get the position of sprite 2 (V7->[V4,V7])
	v7 2 #( v4 ldrh,
	v7 0@ v7 ldrh,
	$ff ## v7 v7 and,
	$fe00 ## v4 v4 bic,

	\ make sure that negative values will collide
	240 ## v4 cmp,
	$200 ## v4 v4 ge? sub,
	160 ## v7 cmp,
	$100 ## v7 v7 ge? sub,

	\ set collision to false
	0 ## tos mov,

	\ test x direction (V4 > V2+V0 = fail)
	v0 v2 w add,
	w v4 cmp,
	gt? ret \ fail

	\ test x direction (V4+V5 < V2 = fail)
	v5 v4 w add,
	w v2 cmp,
	gt? ret \ fail

	\ test y direction (V7 > V6+V1 = fail)
	v1 v6 w add,
	w v7 cmp,
	gt? ret \ fail

	\ test y direction (V7+V3 < V6 = fail)
	v3 v7 w add,
	w v6 cmp,

	\ success
	0 ## tos le? mvn,
	ret
end-code

\ copy all updated sprite data from IWRAM to OAM
code updatesprites ( -- )
	IWRAM ## v3 mov,
	$7000000 ## v1 mov,
	$400 ## v2 mov,
	
	\ loop until r2 = 0
	l: __update
	16 ## v2 v2 s! sub,
	v3 ia! v4 v5 v6 v7 ldm,
	v1 ia! v4 v5 v6 v7 stm,
	__update gt? b,
	
	\ done
	ret
end-code