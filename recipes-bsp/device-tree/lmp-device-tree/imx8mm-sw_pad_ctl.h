/* SPDX-License-Identifier: (GPL-2.0 OR MIT) */
/*
 * i.MX 8M Mini — full SW_PAD_CTL words for &iomuxc fsl,pins (second cell).
 *
 * Register layout (typical pad — confirm IMX8MMRM "SW_PAD_CTL_PAD_<NAME>" for each pad):
 *
 *     31..17    16      15..14    13    12    11    10    9..8    7..6     5..3    2..1    0
 *              HYS     PUS       PUE   PKE   ODE   —    PDRV    SPEED    DSE     B21     SRE
 *              (— if unused in preset)
 *
 * Field macros live in imx8mm-sw_pad_ctl-fields.h. Each IMX8MM_PAD_* below is a bitwise OR
 * of those pieces — same numeric result as NXP imx8mm-evk.dtsi hex literals.
 *
 * IMX8MM_PAD_ENET_MDIO evaluates to 0x3: use only on ENET MDIO/MDC pad mux lines, not for
 * unrelated 0x3 (I2C addresses, RDC domains, etc.).
 */

#ifndef __IMX8MM_SW_PAD_CTL_H
#define __IMX8MM_SW_PAD_CTL_H

#include "imx8mm-sw_pad_ctl-fields.h"

/*
 * GPIO presets — imx8mm-evk style (hex matches NXP reference DTS).
 *
 * These names are **pad electrical settings** for specific balls when the mux is GPIO,
 * not GPIO controller programming. Use the macro whose hex matches the pinmux row for
 * that pad (PDRV/DSE/SPEED/B21 come from the EVK table; see IMX8MMRM field meanings).
 *
 * IMX8MM_PAD_GPIO1_IO_STD — default recipe for most GPIO1_IO* header pins (0x116).
 *
 * IMX8MM_PAD_GPIO1_IO00 — GPIO1_IO00 only: same SPEED/DSE/PDRV family as STD but bits [2:1]
 * (B21) encoded as 2 instead of 3 (0x114 vs 0x116); follows NXP GPIO1_IO00 row.
 *
 * IMX8MM_PAD_GPIO1_IO05 — GPIO1_IO05 only: **same as STD except SPEED is MEDIUM, not LOW**
 * (only bits [7:6] differ). EVK pinmux uses a higher SPEED bin on this ball than on the
 * other “STD” GPIO1 lines — board routing/load often differs per pin; net function is
 * named in the board DTS (e.g. DT510 connector pin for GPIO1_IO5).
 */

#define IMX8MM_PAD_GPIO_DEFAULT					\
	(   IMX8MM_SW_PAD_CTL_PDRV_1				\
	  | IMX8MM_SW_PAD_CTL_SPEED_MEDIUM )			/* 0x140 */

#define IMX8MM_PAD_GPIO1_IO00					\
	(   IMX8MM_SW_PAD_CTL_PDRV_1				\
	  | IMX8MM_SW_PAD_CTL_DSE_X2				\
	  | IMX8MM_SW_PAD_CTL_SPEED_LOW				\
	  | IMX8MM_SW_PAD_CTL_B21(2) )				/* 0x114 */

#define IMX8MM_PAD_GPIO1_IO_STD					\
	(   IMX8MM_SW_PAD_CTL_PDRV_1				\
	  | IMX8MM_SW_PAD_CTL_DSE_X2				\
	  | IMX8MM_SW_PAD_CTL_SPEED_LOW				\
	  | IMX8MM_SW_PAD_CTL_B21(3) )				/* 0x116 */

#define IMX8MM_PAD_GPIO1_IO05					\
	(   IMX8MM_SW_PAD_CTL_PDRV_1				\
	  | IMX8MM_SW_PAD_CTL_DSE_X2				\
	  | IMX8MM_SW_PAD_CTL_SPEED_MEDIUM			\
	  | IMX8MM_SW_PAD_CTL_B21(3) )				/* 0x156: STD + SPEED_MEDIUM */

#define IMX8MM_PAD_GPIO_HIGH_DRIVE				\
	(   IMX8MM_SW_PAD_CTL_PDRV_1				\
	  | IMX8MM_SW_PAD_CTL_DSE_X2				\
	  | IMX8MM_SW_PAD_CTL_SPEED_LOW				\
	  | IMX8MM_SW_PAD_CTL_ODE_EN				\
	  | IMX8MM_SW_PAD_CTL_PKE_EN				\
	  | IMX8MM_SW_PAD_CTL_B21(3) )				/* 0x1916: stronger clock/sync drive */

/* USDHC — SDIO / eMMC speed groups ...................................... hex */

#define IMX8MM_PAD_USDHC_CLK					\
	(   IMX8MM_SW_PAD_CTL_PDRV_1				\
	  | IMX8MM_SW_PAD_CTL_DSE_X2				\
	  | IMX8MM_SW_PAD_CTL_SPEED_FAST )			/* 0x190 */

#define IMX8MM_PAD_USDHC_BUS					\
	(   IMX8MM_SW_PAD_CTL_PDRV_1				\
	  | IMX8MM_SW_PAD_CTL_DSE_X2				\
	  | IMX8MM_SW_PAD_CTL_SPEED_MAX )			/* 0x1d0 */

#define IMX8MM_PAD_USDHC_CLK_100MHZ				\
	(   IMX8MM_SW_PAD_CTL_PDRV_1				\
	  | IMX8MM_SW_PAD_CTL_DSE_X2				\
	  | IMX8MM_SW_PAD_CTL_SPEED_FAST			\
	  | IMX8MM_SW_PAD_CTL_B21(2) )				/* 0x194 */

#define IMX8MM_PAD_USDHC_BUS_100MHZ				\
	(   IMX8MM_SW_PAD_CTL_PDRV_1				\
	  | IMX8MM_SW_PAD_CTL_DSE_X2				\
	  | IMX8MM_SW_PAD_CTL_SPEED_MAX				\
	  | IMX8MM_SW_PAD_CTL_B21(2) )				/* 0x1d4 */

#define IMX8MM_PAD_USDHC_CLK_200MHZ				\
	(   IMX8MM_SW_PAD_CTL_PDRV_1				\
	  | IMX8MM_SW_PAD_CTL_DSE_X2				\
	  | IMX8MM_SW_PAD_CTL_SPEED_FAST			\
	  | IMX8MM_SW_PAD_CTL_B21(3) )				/* 0x196 */

#define IMX8MM_PAD_USDHC_BUS_200MHZ				\
	(   IMX8MM_SW_PAD_CTL_PDRV_1				\
	  | IMX8MM_SW_PAD_CTL_DSE_X2				\
	  | IMX8MM_SW_PAD_CTL_SPEED_MAX				\
	  | IMX8MM_SW_PAD_CTL_B21(3) )				/* 0x1d6 */

/* ENET / RGMII — imx8mm-evk fec1grp ..................................... hex */

#define IMX8MM_PAD_ENET_MDIO					\
	(   IMX8MM_SW_PAD_CTL_SRE_FAST				\
	  | IMX8MM_SW_PAD_CTL_B21(1) )				/* 0x03 */

#define IMX8MM_PAD_ENET_RGMII_TX				\
	(   IMX8MM_SW_PAD_CTL_SRE_FAST				\
	  | IMX8MM_SW_PAD_CTL_DSE_X3				\
	  | IMX8MM_SW_PAD_CTL_SPEED_LOW				\
	  | IMX8MM_SW_PAD_CTL_B21(3) )				/* 0x1f */

#define IMX8MM_PAD_ENET_RGMII_RX				\
	(   IMX8MM_SW_PAD_CTL_SRE_FAST				\
	  | IMX8MM_SW_PAD_CTL_DSE_X2				\
	  | IMX8MM_SW_PAD_CTL_SPEED_FAST )			/* 0x91 */

/* SAI / I2S ............................................................. hex */

#define IMX8MM_PAD_SAI_DEFAULT					\
	(   IMX8MM_SW_PAD_CTL_DSE_X2				\
	  | IMX8MM_SW_PAD_CTL_SPEED_MAX				\
	  | IMX8MM_SW_PAD_CTL_B21(3) )				/* 0xd6 */

#endif /* __IMX8MM_SW_PAD_CTL_H */
