/*
 * Minimal power_init_board implementation for imx93-jaguar-eink
 * Copyright 2025 Dynamic Devices Ltd
 * 
 * This provides a minimal power_init_board function to satisfy
 * U-Boot SPL linking requirements for the imx93-jaguar-eink board.
 */

#include <common.h>
#include <asm/arch/power.h>

/*
 * Board-specific power initialization for SPL
 * This is called early in the SPL boot process
 */
int power_init_board(void)
{
    /*
     * For imx93-jaguar-eink, power management is handled by:
     * 1. MCXC143VFM microcontroller (external)
     * 2. Device tree power regulators (runtime)
     * 3. Minimal SPL requirements only
     */
    
    /* No specific power initialization needed in SPL for this board */
    return 0;
}
