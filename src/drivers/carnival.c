/***************************************************************************

Carnival memory map (preliminary)

0000-3fff ROM
4000-7fff ROM mirror image (this is the one actually used)
e000-e3ff Video RAM + other
e400-e7ff RAM
e800-efff Character RAM

I/O ports:
read:
00        ?
01        IN1 (just an arbitrary name)
          bit 3 = vblank
		  bit 4 = ?
		  bit 5 = ?

write:
01        ?
02        ?

***************************************************************************/

#include "driver.h"
#include "vidhrdw/generic.h"



extern int carnival_IN1_r(int offset);
extern int carnival_interrupt(void);

extern unsigned char *carnival_characterram;
extern void carnival_characterram_w(int offset,int data);
extern void carnival_vh_screenrefresh(struct osd_bitmap *bitmap);



static struct MemoryReadAddress readmem[] =
{
	{ 0xe000, 0xefff, MRA_RAM },
	{ 0x4000, 0x7fff, MRA_ROM },
	{ -1 }	/* end of table */
};

static struct MemoryWriteAddress writemem[] =
{
	{ 0xe000, 0xe3ff, videoram_w, &videoram },
	{ 0xe400, 0xe7ff, MWA_RAM },
	{ 0xe800, 0xefff, carnival_characterram_w, &carnival_characterram },
	{ 0x4000, 0x7fff, MWA_ROM },
	{ -1 }	/* end of table */
};



static struct IOReadPort readport[] =
{
	{ 0x01, 0x01, carnival_IN1_r },
	{ -1 }	/* end of table */
};

static struct IOWritePort writeport[] =
{
	{ -1 }	/* end of table */
};



static struct InputPort input_ports[] =
{
	{ -1 }
};



static struct DSW dsw[] =
{
	{ -1 }
};



static struct GfxLayout charlayout1 =
{
	8,8,	/* 8*8 characters */
	40,	/* 40 characters */
	1,	/* 1 bit per pixel */
	{ 0 },
	{ 0, 1, 2, 3, 4, 5, 6, 7 },	/* pretty straightforward layout */
	{ 0*8, 1*8, 2*8, 3*8, 4*8, 5*8, 6*8, 7*8, 8*8, 9*8 },
	8*8	/* every char takes 10 consecutive bytes */
};

struct GfxLayout carnival_charlayout =
{
	8,8,	/* 8*8 characters */
	256,	/* 256 characters */
	1,	/* 1 bit per pixel */
	{ 0 },
	{ 0*8, 1*8, 2*8, 3*8, 4*8, 5*8, 6*8, 7*8, 8*8, 9*8 },
	{ 7, 6, 5, 4, 3, 2, 1, 0 },	/* pretty straightforward layout */
	8*8	/* every char takes 10 consecutive bytes */
};



static struct GfxDecodeInfo gfxdecodeinfo[] =
{
	{ 0, 0x01e8, &charlayout1, 0, 1 },	/* letters */
	{ 0, 0xe800, &carnival_charlayout, 0, 1 },	/* the game dynamically modifies this */
	{ -1 } /* end of array */
};



static unsigned char palette[] =
{
	0x00,0x00,0x00,	/* BLACK */
	0xff,0xff,0xff	/* WHITE */
};

enum { BLACK,WHITE };

static unsigned char colortable[] =
{
	BLACK,WHITE
};



static struct MachineDriver machine_driver =
{
	/* basic machine hardware */
	{
		{
			CPU_Z80,
			3072000,	/* 3.072 Mhz (?) */
			0,
			readmem,writemem,readport,writeport,
			carnival_interrupt,1
		}
	},
	60,
	0,

	/* video hardware */
	32*8, 32*8, { 2*8, 30*8-1, 0*8, 32*8-1 },
	gfxdecodeinfo,
	sizeof(palette)/3,sizeof(colortable),
	0,

	0,
	generic_vh_start,
	generic_vh_stop,
	carnival_vh_screenrefresh,

	/* sound hardware */
	0,
	0,
	0,
	0,
	0
};



/***************************************************************************

  Game driver(s)

***************************************************************************/

ROM_START( carnival_rom )
	ROM_REGION(0x10000)	/* 64k for code */
	ROM_LOAD( "651u33.cpu", 0x0000, 0x0400 )
	ROM_CONTINUE(           0x4000, 0x0400 )
	ROM_LOAD( "652u32.cpu", 0x0400, 0x0400 )
	ROM_CONTINUE(           0x4400, 0x0400 )
	ROM_LOAD( "653u31.cpu", 0x0800, 0x0400 )
	ROM_CONTINUE(           0x4800, 0x0400 )
	ROM_LOAD( "654u30.cpu", 0x0c00, 0x0400 )
	ROM_CONTINUE(           0x4c00, 0x0400 )
	ROM_LOAD( "655u29.cpu", 0x1000, 0x0400 )
	ROM_CONTINUE(           0x5000, 0x0400 )
	ROM_LOAD( "656u28.cpu", 0x1400, 0x0400 )
	ROM_CONTINUE(           0x5400, 0x0400 )
	ROM_LOAD( "657u27.cpu", 0x1800, 0x0400 )
	ROM_CONTINUE(           0x5800, 0x0400 )
	ROM_LOAD( "658u26.cpu", 0x1c00, 0x0400 )
	ROM_CONTINUE(           0x5c00, 0x0400 )
	ROM_LOAD( "659u8.cpu",  0x2000, 0x0400 )
	ROM_CONTINUE(           0x6000, 0x0400 )
	ROM_LOAD( "660u7.cpu",  0x2400, 0x0400 )
	ROM_CONTINUE(           0x6400, 0x0400 )
	ROM_LOAD( "661u6.cpu",  0x2800, 0x0400 )
	ROM_CONTINUE(           0x6800, 0x0400 )
	ROM_LOAD( "662u5.cpu",  0x2c00, 0x0400 )
	ROM_CONTINUE(           0x6c00, 0x0400 )
	ROM_LOAD( "663u4.cpu",  0x3000, 0x0400 )
	ROM_CONTINUE(           0x7000, 0x0400 )
	ROM_LOAD( "664u3.cpu",  0x3400, 0x0400 )
	ROM_CONTINUE(           0x7400, 0x0400 )
	ROM_LOAD( "665u2.cpu",  0x3800, 0x0400 )
	ROM_CONTINUE(           0x7800, 0x0400 )
	ROM_LOAD( "666u1.cpu",  0x3c00, 0x0400 )
	ROM_CONTINUE(           0x7c00, 0x0400 )
ROM_END



struct GameDriver carnival_driver =
{
	"carnival",
	&machine_driver,

	carnival_rom,
	0, 0,

	input_ports, dsw,

	0, palette, colortable,
	3, 14,
	0, 0,
	8*13, 8*16, 0,

	0, 0
};
