/*
 * Startup Code for S3C44B0 CPU-core
 *
 * (C) Copyright 2004
 * DAVE Srl
 *
 * http://www.dave-tech.it
 * http://www.wawnet.biz
 * mailto:info@wawnet.biz
 *
 * See file CREDITS for list of people who contributed to this
 * project.
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License as
 * published by the Free Software Foundation; either version 2 of
 * the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston,
 * MA 02111-1307 USA
 */

#include <asm-offsets.h>
#include <config.h>
#include <version.h>

/*
 * Jump vector table
 */


.globl _start
_start:	b       reset
	add	pc, pc, #0x0c000000
	add	pc, pc, #0x0c000000
	add	pc, pc, #0x0c000000
	add	pc, pc, #0x0c000000
	add	pc, pc, #0x0c000000
	add	pc, pc, #0x0c000000
	add	pc, pc, #0x0c000000

	.balignl 16,0xdeadbeef


/*
 *************************************************************************
 *
 * Startup Code (reset vector)
 *
 * do important init only if we don't start from memory!
 * relocate u-boot to ram
 * setup stack
 * jump to second stage
 *
 *************************************************************************
 */

.globl _TEXT_BASE
_TEXT_BASE:
	.word	CONFIG_SYS_TEXT_BASE

/*
 * These are defined in the board-specific linker script.
 */
.globl _bss_start
_bss_start:
	.word __bss_start

.globl _bss_end
_bss_end:
	.word _end

#ifdef CONFIG_USE_IRQ
/* IRQ stack memory (calculated at run-time) */
.globl IRQ_STACK_START
IRQ_STACK_START:
	.word	0x0badc0de

/* IRQ stack memory (calculated at run-time) */
.globl FIQ_STACK_START
FIQ_STACK_START:
	.word 0x0badc0de
#endif

/* IRQ stack memory (calculated at run-time) + 8 bytes */
.globl IRQ_STACK_START_IN
IRQ_STACK_START_IN:
	.word	0x0badc0de

.globl _datarel_start
_datarel_start:
	.word __datarel_start

.globl _datarelrolocal_start
_datarelrolocal_start:
	.word __datarelrolocal_start

.globl _datarellocal_start
_datarellocal_start:
	.word __datarellocal_start

.globl _datarelro_start
_datarelro_start:
	.word __datarelro_start

.globl _got_start
_got_start:
	.word __got_start

.globl _got_end
_got_end:
	.word __got_end

/*
 * the actual reset code
 */

reset:
	/*
	 * set the cpu to SVC32 mode
	 */
	mrs	r0,cpsr
	bic	r0,r0,#0x1f
	orr	r0,r0,#0xd3
	msr	cpsr,r0

	/*
	 * we do sys-critical inits only at reboot,
	 * not when booting from ram!
	 */
#ifndef CONFIG_SKIP_LOWLEVEL_INIT
	bl	cpu_init_crit
	/*
	 * before relocating, we have to setup RAM timing
	 * because memory timing is board-dependend, you will
	 * find a lowlevel_init.S in your board directory.
	 */
	bl	lowlevel_init
#endif

/* Set stackpointer in internal RAM to call board_init_f */
call_board_init_f:
	ldr	sp, =(CONFIG_SYS_INIT_SP_ADDR)
	ldr	r0,=0x00000000
	bl	board_init_f

/*------------------------------------------------------------------------------*/

/*
 * void relocate_code (addr_sp, gd, addr_moni)
 *
 * This "function" does not return, instead it continues in RAM
 * after relocating the monitor code.
 *
 */
	.globl	relocate_code
relocate_code:
	mov	r4, r0	/* save addr_sp */
	mov	r5, r1	/* save addr of gd */
	mov	r6, r2	/* save addr of destination */
	mov	r7, r2	/* save addr of destination */

	/* Set up the stack						    */
stack_setup:
	mov	sp, r4

	adr	r0, _start
	ldr	r2, _TEXT_BASE
	ldr	r3, _bss_start
	sub	r2, r3, r2		/* r2 <- size of armboot	    */
	add	r2, r0, r2		/* r2 <- source end address	    */
	cmp	r0, r6
	beq	clear_bss

copy_loop:
	ldmia	r0!, {r9-r10}		/* copy from source address [r0]    */
	stmia	r6!, {r9-r10}		/* copy to   target address [r1]    */
	cmp	r0, r2			/* until source end address [r2]    */
	blo	copy_loop

#ifndef CONFIG_PRELOADER
	/* fix got entries */
	ldr	r1, _TEXT_BASE		/* Text base */
	mov	r0, r7			/* reloc addr */
	ldr	r2, _got_start		/* addr in Flash */
	ldr	r3, _got_end		/* addr in Flash */
	sub	r3, r3, r1
	add	r3, r3, r0
	sub	r2, r2, r1
	add	r2, r2, r0

fixloop:
	ldr	r4, [r2]
	sub	r4, r4, r1
	add	r4, r4, r0
	str	r4, [r2]
	add	r2, r2, #4
	cmp	r2, r3
	blo	fixloop
#endif
/*
	now copy to sram the interrupt vector
*/
	adr	r0, real_vectors
	add	r2, r0, #1024
	ldr	r1, =0x0c000000
	add	r1, r1, #0x08
vector_copy_loop:
	ldmia	r0!, {r3-r10}
	stmia	r1!, {r3-r10}
	cmp	r0, r2
	blo	vector_copy_loop

clear_bss:
#ifndef CONFIG_PRELOADER
	ldr	r0, _bss_start
	ldr	r1, _bss_end
	ldr	r3, _TEXT_BASE		/* Text base */
	mov	r4, r7			/* reloc addr */
	sub	r0, r0, r3
	add	r0, r0, r4
	sub	r1, r1, r3
	add	r1, r1, r4
	mov	r2, #0x00000000		/* clear			    */

clbss_l:str	r2, [r0]		/* clear loop...		    */
	add	r0, r0, #4
	cmp	r0, r1
	bne	clbss_l

	bl coloured_LED_init
	bl red_LED_on
#endif

/*
 * We are done. Do not return, instead branch to second part of board
 * initialization, now running from RAM.
 */
	ldr	r0, _TEXT_BASE
	ldr	r2, _board_init_r
	sub	r2, r2, r0
	add	r2, r2, r7	/* position from board_init_r in RAM */
	/* setup parameters for board_init_r */
	mov	r0, r5		/* gd_t */
	mov	r1, r7		/* dest_addr */
	/* jump to it ... */
	mov	lr, r2
	mov	pc, lr

_board_init_r: .word board_init_r

/*
 *************************************************************************
 *
 * CPU_init_critical registers
 *
 * setup important registers
 * setup memory timing
 *
 *************************************************************************
 */

#define INTCON (0x01c00000+0x200000)
#define INTMSK (0x01c00000+0x20000c)
#define LOCKTIME (0x01c00000+0x18000c)
#define PLLCON (0x01c00000+0x180000)
#define CLKCON (0x01c00000+0x180004)
#define WTCON (0x01c00000+0x130000)
cpu_init_crit:
	/* disable watch dog */
	ldr	r0, =WTCON
	ldr	r1, =0x0
	str	r1, [r0]

	/*
	 * mask all IRQs by clearing all bits in the INTMRs
	 */
	ldr	r1,=INTMSK
	ldr	r0, =0x03fffeff
	str	r0, [r1]

	ldr	r1, =INTCON
	ldr	r0, =0x05
	str	r0, [r1]

	/* Set Clock Control Register */
	ldr	r1, =LOCKTIME
	ldrb	r0, =800
	strb	r0, [r1]

	ldr	r1, =PLLCON

#if CONFIG_S3C44B0_CLOCK_SPEED==66
	ldr	r0, =0x34031	/* 66MHz (Quartz=11MHz) */
#elif CONFIG_S3C44B0_CLOCK_SPEED==75
	ldr	r0, =0x610c1 /*B2: Xtal=20mhz Fclk=75MHz  */
#else
# error CONFIG_S3C44B0_CLOCK_SPEED undefined
#endif

	str	r0, [r1]

	ldr	r1,=CLKCON
	ldr	r0, =0x7ff8
	str	r0, [r1]

	mov	pc, lr


/*************************************************/
/*	interrupt vectors	*/
/*************************************************/
real_vectors:
	b	reset
	b	undefined_instruction
	b	software_interrupt
	b	prefetch_abort
	b	data_abort
	b	not_used
	b	irq
	b	fiq

/*************************************************/

undefined_instruction:
	mov	r6, #3
	b	reset

software_interrupt:
	mov	r6, #4
	b	reset

prefetch_abort:
	mov	r6, #5
	b	reset

data_abort:
	mov	r6, #6
	b	reset

not_used:
	/* we *should* never reach this */
	mov	r6, #7
	b	reset

irq:
	mov	r6, #8
	b	reset

fiq:
	mov	r6, #9
	b	reset
