/* SPDX-License-Identifier: (GPL-2.0 OR MIT) */
/*
 * i.MX 8M Mini — full SW_PAD_CTL words for &iomuxc fsl,pins (second cell).
 *
 * Register layout is **not** the i.MX6 map. Use imx8mm-sw_pad_ctl-fields.h (IMX8MMRM Ch. 8).
 *
 * **Mux vs pad control:** The first cell (MX8MM_IOMUXC_* macro) selects signal routing. The second cell
 * is only SW_PAD_CTL electricals. EVK spreadsheets naming rows GPIO1_IOxx are ball labels, not mux mode.
 *
 * Hex targets below match arch/arm64/boot/dts/freescale/imx8mm-evk.dtsi unless noted.
 *
 * Deprecated aliases IMX8MM_PAD_GPIO_* kept for older DTS.
 */

#ifndef __IMX8MM_SW_PAD_CTL_H
#define __IMX8MM_SW_PAD_CTL_H

#include "imx8mm-sw_pad_ctl-fields.h"

/*
 * --- EVK-aligned presets (same hex as imx8mm-evk.dtsi UART/GPIO-style pads) ---
 */

/* 0x140 — PE + pull-up (Linux MX8MM_PULL_ENABLE | MX8MM_PULL_UP); UART sideband, many hog straps */
#define IMX8MM_PAD_EVK_BASIC						\
	(   IMX8MM_SW_PAD_CTL_PE_EN				\
	  | IMX8MM_SW_PAD_CTL_PUE_UP )

#define IMX8MM_PAD_EVK_STRAP				IMX8MM_PAD_EVK_BASIC	/* deprecated name */

/* 0x114 — PE + fast slew + DSE X2 */
#define IMX8MM_PAD_EVK_IO00						\
	(   IMX8MM_SW_PAD_CTL_PE_EN				\
	  | IMX8MM_SW_PAD_CTL_FSEL_FAST				\
	  | IMX8MM_SW_PAD_CTL_DSE_X2 )

/* 0x116 — PE + fast slew + DSE X6 + pull-down select */
#define IMX8MM_PAD_EVK_GENERAL						\
	(   IMX8MM_SW_PAD_CTL_PE_EN				\
	  | IMX8MM_SW_PAD_CTL_FSEL_FAST				\
	  | IMX8MM_SW_PAD_CTL_DSE_X6				\
	  | IMX8MM_SW_PAD_CTL_PUE_DOWN )

/*
 * 0x156 — like GENERAL but adds internal pull-up (PUE bit); mislabeled “SPEED” under old i.MX6 macros.
 */
#define IMX8MM_PAD_EVK_IO05_SPEED					\
	(   IMX8MM_SW_PAD_CTL_PE_EN				\
	  | IMX8MM_SW_PAD_CTL_PUE_UP				\
	  | IMX8MM_SW_PAD_CTL_FSEL_FAST				\
	  | IMX8MM_SW_PAD_CTL_DSE_X6 )

/*
 * Historical DTS used 0x1916 — bits above [8:0] were i.MX6 ODE/PKE positions (reserved on IMX8MM).
 * Silicon applied 0x116 only; keep aligned with EVK_GENERAL unless HW review demands true open-drain.
 */
#define IMX8MM_PAD_EVK_SYNC_HEAVY				IMX8MM_PAD_EVK_GENERAL

#define IMX8MM_PAD_SAI1_BUS_STD				IMX8MM_PAD_EVK_GENERAL

/* USDHC — imx8mm-evk usdhc2grp / 100 MHz / 200 MHz */

#define IMX8MM_PAD_USDHC_CLK						\
	(   IMX8MM_SW_PAD_CTL_PE_EN				\
	  | IMX8MM_SW_PAD_CTL_HYS_SCHMITT			\
	  | IMX8MM_SW_PAD_CTL_FSEL_FAST				\
	  | IMX8MM_SW_PAD_CTL_DSE_X1 )

#define IMX8MM_PAD_USDHC_BUS						\
	(   IMX8MM_SW_PAD_CTL_PE_EN				\
	  | IMX8MM_SW_PAD_CTL_HYS_SCHMITT			\
	  | IMX8MM_SW_PAD_CTL_PUE_UP				\
	  | IMX8MM_SW_PAD_CTL_FSEL_FAST				\
	  | IMX8MM_SW_PAD_CTL_DSE_X1 )

#define IMX8MM_PAD_USDHC_CLK_100MHZ					\
	(   IMX8MM_SW_PAD_CTL_PE_EN				\
	  | IMX8MM_SW_PAD_CTL_HYS_SCHMITT			\
	  | IMX8MM_SW_PAD_CTL_FSEL_FAST				\
	  | IMX8MM_SW_PAD_CTL_DSE_X2 )

#define IMX8MM_PAD_USDHC_BUS_100MHZ					\
	(   IMX8MM_SW_PAD_CTL_PE_EN				\
	  | IMX8MM_SW_PAD_CTL_HYS_SCHMITT			\
	  | IMX8MM_SW_PAD_CTL_PUE_UP				\
	  | IMX8MM_SW_PAD_CTL_FSEL_FAST				\
	  | IMX8MM_SW_PAD_CTL_DSE_X2 )

#define IMX8MM_PAD_USDHC_CLK_200MHZ					\
	(   IMX8MM_SW_PAD_CTL_PE_EN				\
	  | IMX8MM_SW_PAD_CTL_HYS_SCHMITT			\
	  | IMX8MM_SW_PAD_CTL_FSEL_FAST				\
	  | IMX8MM_SW_PAD_CTL_DSE_X6 )

#define IMX8MM_PAD_USDHC_BUS_200MHZ					\
	(   IMX8MM_SW_PAD_CTL_PE_EN				\
	  | IMX8MM_SW_PAD_CTL_HYS_SCHMITT			\
	  | IMX8MM_SW_PAD_CTL_PUE_UP				\
	  | IMX8MM_SW_PAD_CTL_FSEL_FAST				\
	  | IMX8MM_SW_PAD_CTL_DSE_X6 )

/*
 * ENET / RGMII — literals from imx8mm-evk fec1grp (field-by-field decode differs by pad); do not reuse 0x03 elsewhere.
 */
#define IMX8MM_PAD_ENET_MDIO						0x03

#define IMX8MM_PAD_ENET_RGMII_TX					0x1f

#define IMX8MM_PAD_ENET_RGMII_RX					0x91

/* SAI — imx8mm-evk sai2/sai3/spdif style */
#define IMX8MM_PAD_SAI_DEFAULT						\
	(   IMX8MM_SW_PAD_CTL_HYS_SCHMITT			\
	  | IMX8MM_SW_PAD_CTL_PUE_UP				\
	  | IMX8MM_SW_PAD_CTL_FSEL_FAST				\
	  | IMX8MM_SW_PAD_CTL_DSE_X6 )

/*
 * Deprecated aliases — "GPIO" referred to NXP EVK pad row names (ball labels), not mux = GPIO.
 */
#define IMX8MM_PAD_GPIO_DEFAULT				IMX8MM_PAD_EVK_BASIC
#define IMX8MM_PAD_GPIO1_IO00					IMX8MM_PAD_EVK_IO00
#define IMX8MM_PAD_GPIO1_IO_STD					IMX8MM_PAD_EVK_GENERAL
#define IMX8MM_PAD_GPIO1_IO05					IMX8MM_PAD_EVK_IO05_SPEED
#define IMX8MM_PAD_GPIO_HIGH_DRIVE				IMX8MM_PAD_EVK_SYNC_HEAVY

#endif /* __IMX8MM_SW_PAD_CTL_H */
