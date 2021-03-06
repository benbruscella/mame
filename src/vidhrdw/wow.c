/***************************************************************************

  vidhrdw.c

  Functions to emulate the video hardware of the machine.

***************************************************************************/

#include "driver.h"
#include "vidhrdw/generic.h"
#include "Z80.h"



unsigned char *wow_videoram;
int magic_expand_color, magic_control, collision;



int wow_intercept_r(int offset)
{
	int res;


	res = collision;
	collision = 0;

	return res;
}



void wow_videoram_w(int offset,int data)
{
	if (wow_videoram[offset] != data)
	{
		int i;
		unsigned char *bm;


		wow_videoram[offset] = data;

		if (offset >= 2*40*204) return;

		if ((offset & 1) == 0)
		{
			offset /= 2;
			bm = tmpbitmap->line[offset / 40] + 8 * (offset % 40);
		}
		else
		{
			offset /= 2;
			bm = tmpbitmap->line[offset / 40] + 8 * (offset % 40) + 4;
		}

		for (i = 0;i < 4;i++)
		{
			*bm = 0;

			if (data & 0x80) *bm |= 1;
			if (data & 0x40) *bm |= 2;
/*/// TODO: remap the pixel color thru the color table */

			bm++;
			data <<= 2;
		}
	}
}



void wow_magic_expand_color_w(int offset,int data)
{
if (errorlog) fprintf(errorlog,"%04x: magic_expand_color = %02x\n",Z80_GetPC(),data);
	magic_expand_color = data;
}



void wow_magic_control_w(int offset,int data)
{
if (errorlog) fprintf(errorlog,"%04x: magic_control = %02x\n",Z80_GetPC(),data);
	magic_control = data;
}



static void copywithflip(int offset,int data)
{
	if (magic_control & 0x40)	/* copy backwards */
	{
		int bits,stib,k;

		bits = data;
		stib = 0;
		for (k = 0;k < 4;k++)
		{
			stib >>= 2;
			stib |= (bits & 0xc0);
			bits <<= 2;
		}

		data = stib;
	}

	if (magic_control & 0x40)	/* copy backwards */
	{
		int shift,data1,mask;


		shift = magic_control & 3;
		data1 = 0;
		mask = 0xff;
		while (shift > 0)
		{
			data1 <<= 2;
			data1 |= (data & 0xc0) >> 6;
			data <<= 2;
			mask <<= 2;
			shift--;
		}

		if (magic_control & 0x30)
		{
			/* TODO: the collision detection should be made independently for */
			/* each of the four pixels */
			if ((mask & wow_videoram[offset]) || (~mask & wow_videoram[offset-1]))
				collision |= 0xff;
			else collision &= 0x0f;
		}

		if (magic_control & 0x20) data ^= wow_videoram[offset];	/* draw in XOR mode */
		else if (magic_control & 0x10) data |= wow_videoram[offset];	/* draw in OR mode */
		else data |= ~mask & wow_videoram[offset];	/* draw in copy mode */
		wow_videoram_w(offset,data);
		if (magic_control & 0x20) data1 ^= wow_videoram[offset-1];	/* draw in XOR mode */
		else if (magic_control & 0x10) data1 |= wow_videoram[offset-1];	/* draw in OR mode */
		else data1 |= mask & wow_videoram[offset-1];	/* draw in copy mode */
		wow_videoram_w(offset-1,data1);
	}
	else
	{
		int shift,data1,mask;


		shift = magic_control & 3;
		data1 = 0;
		mask = 0xff;
		while (shift > 0)
		{
			data1 >>= 2;
			data1 |= (data & 0x03) << 6;
			data >>= 2;
			mask >>= 2;
			shift--;
		}

		if (magic_control & 0x30)
		{
			/* TODO: the collision detection should be made independently for */
			/* each of the four pixels */
			if ((mask & wow_videoram[offset]) || (~mask & wow_videoram[offset+1]))
				collision |= 0xff;
			else collision &= 0x0f;
		}

		if (magic_control & 0x20)
			data ^= wow_videoram[offset];	/* draw in XOR mode */
		else if (magic_control & 0x10)
			data |= wow_videoram[offset];	/* draw in OR mode */
		else
			data |= ~mask & wow_videoram[offset];	/* draw in copy mode */
		wow_videoram_w(offset,data);
		if (magic_control & 0x20)
			data1 ^= wow_videoram[offset+1];	/* draw in XOR mode */
		else if (magic_control & 0x10)
			data1 |= wow_videoram[offset+1];	/* draw in OR mode */
		else
			data1 |= mask & wow_videoram[offset+1];	/* draw in copy mode */
		wow_videoram_w(offset+1,data1);
	}
}



void wow_magicram_w(int offset,int data)
{
	if (magic_control & 0x08)	/* expand mode */
	{
		int bits,bibits,k;

static int count;

count ^= 1;
if (!count) return;

		bits = data;
		bibits = 0;
		for (k = 0;k < 4;k++)
		{
			bibits <<= 2;
			if (bits & 0x80) bibits |= (magic_expand_color >> 2) & 0x03;
			else bibits |= magic_expand_color & 0x03;
			bits <<= 1;
		}

		if (magic_control & 0x40)	/* copy backwards */
			copywithflip(offset+1,bibits);
		else
			copywithflip(offset,bibits);

		bits = data;
		bibits = 0;
		for (k = 0;k < 4;k++)
		{
			bibits <<= 2;
			if (bits & 0x08) bibits |= (magic_expand_color >> 2) & 0x03;
			else bibits |= magic_expand_color & 0x03;
			bits <<= 1;
		}
		if (magic_expand_color == 0) bibits = 0;
		else if (magic_expand_color == 4) bibits &= 0x55;
		else if (magic_expand_color == 8) bibits &= 0xaa;

		if (magic_control & 0x40)	/* copy backwards */
			copywithflip(offset,bibits);
		else
			copywithflip(offset+1,bibits);
	}
	else
	{
		copywithflip(offset,data);
	}
}



void wow_pattern_board_w(int offset,int data)
{
	static int src;
	static int mode;	/* ?? */
	static int skip;	/* bytes to skip after row copy */
	static int dest;
	static int length;	/* row length */
	static int loops;	/* rows to copy - 1 */


	switch (offset)
	{
		case 0:
			src = data;
			break;
		case 1:
			src = src + data * 256;
			break;
		case 2:
			mode = data & 0x3f;	/* register is 6 bit wide */
			break;
		case 3:
			skip = data;
			break;
		case 4:
			dest = skip + data * 256;	/* register 3 is shared between skip and dest */
			break;
		case 5:
			length = data;
			break;
		case 6:
			loops = data;
			break;
	}

	if (offset == 6)	/* trigger blit */
	{
		int i,j;


if (errorlog) fprintf(errorlog,"%04x: blit src %04x mode %02x skip %d dest %04x length %d loops %d\n",
		Z80_GetPC(),src,mode,skip,dest,length,loops);

/*//		if ((mode & 0x09) == 0x00)	* copy from 1 bitplane */
/*//		else if ((mode & 0x09) == 0x08)	* copy from 2 bitplanes */

		for (i = 0; i <= loops;i++)
		{
			for (j = 0;j <= length;j++)
			{
if (!(mode & 0x08) || j < length)
				cpu_writemem(dest,RAM[src]);
				if (mode & 0x20) dest++;	/* copy forwards */
				else dest--;				/* backwards */

				if ((j & 1) || !(mode & 0x02))	/* don't increment source on odd loops */
					if (mode & 0x04) src++;
			}

			if ((j & 1) && (mode & 0x02))	/* always increment source at end of line */
				if (mode & 0x04) src++;
if (mode & 0x08) src--;

if (mode & 0x20) dest--;	/* copy forwards */
else dest++;				/* backwards */

			dest += (int)((signed char)skip);	/* extend the sign of the skip register */

		/* Note: actually the hardware doesn't handle the sign of the skip register, */
		/* when incrementing the destination address the carry bit is taken from the */
		/* mode register. To faithfully emulate the hardware I should do: */
#if 0
			{
				int lo,hi;

				lo = dest & 0x00ff;
				hi = dest & 0xff00;
				lo += skip;
				if (mode & 0x10)
				{
					if (lo < 0x100) hi -= 0x100;
				}
				else
				{
					if (lo > 0xff) hi += 0x100;
				}
				dest = hi | (lo & 0xff);
			}
#endif
		}
	}
}



/***************************************************************************

  Draw the game screen in the given osd_bitmap.
  Do NOT call osd_update_display() from this function, it will be called by
  the main emulation engine.

***************************************************************************/
void wow_vh_screenrefresh(struct osd_bitmap *bitmap)
{
	/* copy the character mapped graphics */
	copybitmap(bitmap,tmpbitmap,0,0,0,0,&Machine->drv->visible_area,TRANSPARENCY_NONE,0);
}
