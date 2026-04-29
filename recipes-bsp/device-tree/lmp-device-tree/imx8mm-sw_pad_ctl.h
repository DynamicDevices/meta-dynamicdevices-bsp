/* SPDX-License-Identifier: (GPL-2.0 OR MIT) */
/*
 * i.MX 8M Mini — full SW_PAD_CTL words for &iomuxc fsl,pins (second cell).
 *
 * Register layout (typical pad — confirm IMX8MMRM "SW_PAD_CTL_PAD_<NAME>" for each pad):
 *
 *     31..17    16      15..14    13    12    11    10    9..8    7..6     5..3    2..1    0
 *              HYS     PUS       PUE   PKE   ODE   —    PDRV    SPEED    DSE     B21     SRE
 *
 * Field macros: imx8mm-sw_pad_ctl-fields.h
 *
 * **Mux vs pad control:** The first cell of each fsl,pins entry (MX8MM_IOMUXC_* macro) selects the
 * **signal routing** (UART, SAI, GPIO, …). The **second** cell is **only** the SW_PAD_CTL electrical
 * image — pull/drive/speed. It does **not** select the GPIO1 block or any other peripheral; NXP EVK
 * pinmux spreadsheets often **name rows after SoC ball labels** (e.g. GPIO1_IO03), which is historical
 * naming for that pad on the EVK, not a claim about mux mode.
 *
 * Presets below are named by **electrical intent** (EVK_* = same hex as imx8mm-evk.dtsi / EVK tables).
 * Deprecated aliases IMX8MM_PAD_GPIO_* kept for older DTS; they referred to those EVK row labels.
 *
 * IMX8MM_PAD_ENET_MDIO equals 0x3 — only for ENET MDIO/MDC pad mux lines, not unrelated 0x3 literals.
 */

#ifndef __IMX8MM_SW_PAD_CTL_H
#define __IMX8MM_SW_PAD_CTL_H

#include "imx8mm-sw_pad_ctl-fields.h"

/*
 * --- EVK-aligned CMOS / strap presets (hex matches NXP imx8mm-evk.dtsi where noted) ---
 */

#define IMX8MM_PAD_EVK_STRAP						\
	(   IMX8MM_SW_PAD_CTL_PDRV_1				\
	  | IMX8MM_SW_PAD_CTL_SPEED_MEDIUM )			/* 0x140 */

#define IMX8MM_PAD_EVK_IO00						\
	(   IMX8MM_SW_PAD_CTL_PDRV_1				\
	  | IMX8MM_SW_PAD_CTL_DSE_X2				\
	  | IMX8MM_SW_PAD_CTL_SPEED_LOW				\
	  | IMX8MM_SW_PAD_CTL_B21(2) )				/* 0x114 */

#define IMX8MM_PAD_EVK_GENERAL						\
	(   IMX8MM_SW_PAD_CTL_PDRV_1				\
	  | IMX8MM_SW_PAD_CTL_DSE_X2				\
	  | IMX8MM_SW_PAD_CTL_SPEED_LOW				\
	  | IMX8MM_SW_PAD_CTL_B21(3) )				/* 0x116 */

#define IMX8MM_PAD_EVK_IO05_SPEED					\
	(   IMX8MM_SW_PAD_CTL_PDRV_1				\
	  | IMX8MM_SW_PAD_CTL_DSE_X2				\
	  | IMX8MM_SW_PAD_CTL_SPEED_MEDIUM			\
	  | IMX8MM_SW_PAD_CTL_B21(3) )				/* 0x156 */

#define IMX8MM_PAD_EVK_SYNC_HEAVY					\
	(   IMX8MM_SW_PAD_CTL_PDRV_1				\
	  | IMX8MM_SW_PAD_CTL_DSE_X2				\
	  | IMX8MM_SW_PAD_CTL_SPEED_LOW				\
	  | IMX8MM_SW_PAD_CTL_ODE_EN				\
	  | IMX8MM_SW_PAD_CTL_PKE_EN				\
	  | IMX8MM_SW_PAD_CTL_B21(3) )				/* 0x1916 */

/*
 * SAI1 — second cell when mux is SAI1_* (MCLK, BCLK, DATA); same SW_PAD word as EVK_GENERAL (0x116).
 */
#define IMX8MM_PAD_SAI1_BUS_STD				IMX8MM_PAD_EVK_GENERAL

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

/*
 * Deprecated aliases — "GPIO" referred to NXP EVK pad row names (ball labels), not mux = GPIO.
 */
#define IMX8MM_PAD_GPIO_DEFAULT				IMX8MM_PAD_EVK_STRAP
#define IMX8MM_PAD_GPIO1_IO00					IMX8MM_PAD_EVK_IO00
#define IMX8MM_PAD_GPIO1_IO_STD					IMX8MM_PAD_EVK_GENERAL
#define IMX8MM_PAD_GPIO1_IO05					IMX8MM_PAD_EVK_IO05_SPEED
#define IMX8MM_PAD_GPIO_HIGH_DRIVE				IMX8MM_PAD_EVK_SYNC_HEAVY

#endif /* __IMX8MM_SW_PAD_CTL_H */
