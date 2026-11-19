// SPDX-License-Identifier: GPL-2.0-only
/*
 * Plain LT9611 boot splash for DT510, not LT9611UXC/UXD.
 * Register sequences ported from Linux lontium-lt9611.c (GPL-2.0).
 * NXP SEC DSIM expects a UCLASS_PANEL endpoint; control remains on I2C3.
 * First milestone: fixed CEA-4 1280x720p60 RGB888, no audio/EDID/handover.
 * Assisted-by: Briar
 */
#include <common.h>
#include <dm.h>
#include <dm/device_compat.h>
#include <i2c.h>
#include <mipi_dsi.h>
#include <panel.h>
#include <asm/gpio.h>
#include <linux/delay.h>

struct lt9611_priv {
	struct gpio_desc reset;
	int page;
	bool configured;
	bool enabled;
};

struct lt9611_reg { u16 reg; u8 value; };

static const struct display_timing lt9611_timing = {
	.pixelclock = { 74250000, 74250000, 74250000 },
	.hactive = { 1280, 1280, 1280 },
	.hfront_porch = { 110, 110, 110 },
	.hback_porch = { 220, 220, 220 },
	.hsync_len = { 40, 40, 40 },
	.vactive = { 720, 720, 720 },
	.vfront_porch = { 5, 5, 5 },
	.vback_porch = { 20, 20, 20 },
	.vsync_len = { 5, 5, 5 },
	.flags = DISPLAY_FLAGS_HSYNC_HIGH | DISPLAY_FLAGS_VSYNC_HIGH,
};

static int lt9611_page(struct udevice *dev, u16 reg)
{
	struct lt9611_priv *priv = dev_get_priv(dev);
	u8 page = reg >> 8;
	int ret;

	if (priv->page == page)
		return 0;
	ret = dm_i2c_write(dev, 0xff, &page, 1);
	priv->page = ret ? -1 : page;
	return ret;
}

static int lt9611_write(struct udevice *dev, u16 reg, u8 value)
{
	struct lt9611_priv *priv = dev_get_priv(dev);
	int ret = lt9611_page(dev, reg);

	if (!ret)
		ret = dm_i2c_write(dev, reg & 0xff, &value, 1);
	if (ret) {
		priv->page = -1;
		dev_err(dev, "LT9611 write %04x=%02x failed: %d\n", reg, value, ret);
	}
	return ret;
}

static int lt9611_read(struct udevice *dev, u16 reg, u8 *value)
{
	struct lt9611_priv *priv = dev_get_priv(dev);
	int ret = lt9611_page(dev, reg);

	if (!ret)
		ret = dm_i2c_read(dev, reg & 0xff, value, 1);
	if (ret)
		priv->page = -1;
	return ret;
}

static int lt9611_sequence(struct udevice *dev,
			  const struct lt9611_reg *seq, unsigned int count)
{
	unsigned int i;
	int ret;

	for (i = 0; i < count; i++) {
		ret = lt9611_write(dev, seq[i].reg, seq[i].value);
		if (ret)
			return ret;
	}
	return 0;
}

/* Same documented system initialization as the plain-LT9611 Linux driver. */
static const struct lt9611_reg lt9611_system[] = {
	{ 0x8101, 0x18 }, /* Select crystal: report errors, never hide this failure. */
	{ 0x821b, 0x69 }, { 0x821c, 0x78 }, { 0x82cb, 0x69 }, { 0x82cc, 0x78 },
	{ 0x8251, 0x01 }, { 0x8258, 0x0a }, { 0x8259, 0x80 }, { 0x829e, 0xf7 },
	{ 0x8004, 0xf0 }, { 0x8006, 0xf0 }, { 0x800a, 0x80 },
	{ 0x800b, 0x40 }, { 0x800d, 0xef }, { 0x8011, 0xfa },
};

/* Fixed CEA-4 values, calculated from the Linux timing/PLL/PCR helpers. */
static const struct lt9611_reg lt9611_video[] = {
	/* Four lanes, MIPI port A only. */
	{ 0x8300, 0x00 }, { 0x830a, 0x00 }, { 0x824f, 0x80 },
	{ 0x8250, 0x10 }, { 0x8302, 0x0a }, { 0x8306, 0x0a },
	/* TX PLL: 74.25 MHz pixel clock, post-divider 2. */
	{ 0x8123, 0x40 }, { 0x8124, 0x64 }, { 0x8125, 0x80 },
	{ 0x8126, 0x55 }, { 0x812c, 0x37 }, { 0x812f, 0x01 },
	{ 0x8126, 0x55 }, { 0x8127, 0x66 }, { 0x8128, 0x88 },
	{ 0x812a, 0x20 }, { 0x812d, 0x99 },
	{ 0x82e3, 0x00 }, { 0x82e4, 0x91 }, { 0x82e5, 0x05 },
	{ 0x82de, 0x20 }, { 0x82de, 0xe0 }, { 0x8016, 0xf1 }, { 0x8016, 0xf3 },
	/* Totals 1650x750; active 1280x720; positive H/V sync. */
	{ 0x830d, 0x02 }, { 0x830e, 0xee }, { 0x830f, 0x02 }, { 0x8310, 0xd0 },
	{ 0x8311, 0x06 }, { 0x8312, 0x72 }, { 0x8313, 0x05 }, { 0x8314, 0x00 },
	{ 0x8315, 0x05 }, { 0x8316, 0x28 }, { 0x8317, 0x05 }, { 0x8318, 0x19 },
	{ 0x8319, 0x6e }, { 0x831a, 0x01 }, { 0x831b, 0x04 },
	/* PCR M = floor(74250 * 5 * 2 / 27000) = 27. */
	{ 0x831d, 0x10 }, { 0x830b, 0x01 }, { 0x830c, 0x10 },
	{ 0x8348, 0x00 }, { 0x8349, 0x81 }, { 0x8321, 0x4a },
	{ 0x8324, 0x71 }, { 0x8325, 0x30 }, { 0x832a, 0x01 },
	{ 0x834a, 0x40 }, { 0x832d, 0x38 }, { 0x8331, 0x08 },
	{ 0x8326, 0x1b }, { 0x8011, 0x5a }, { 0x8011, 0xfa },
	/* Input analog setup (same sequence as Linux), DC-coupled HDMI PHY. */
	{ 0x8106, 0x40 }, { 0x810a, 0xfe }, { 0x810b, 0xbf },
	{ 0x8111, 0x40 }, { 0x8115, 0xfe }, { 0x8116, 0xbf },
	{ 0x811c, 0x03 }, { 0x8120, 0x03 },
	{ 0x82d6, 0x8c }, { 0x82d7, 0x04 },
	{ 0x8130, 0x6a }, { 0x8131, 0x44 }, { 0x8132, 0x4a }, { 0x8133, 0x0b },
	{ 0x8134, 0x00 }, { 0x8135, 0x00 }, { 0x8136, 0x00 }, { 0x8137, 0x44 },
	{ 0x813f, 0x0f }, { 0x8140, 0xa0 }, { 0x8141, 0xa0 }, { 0x8142, 0xa0 },
	{ 0x8143, 0xa0 }, { 0x8144, 0x0a },
};

static int lt9611_enable(struct udevice *dev)
{
	struct lt9611_priv *priv = dev_get_priv(dev);
	struct mipi_dsi_panel_plat *plat = dev_get_plat(dev);
	/* AVI v2, RGB, active picture aspect, 16:9, CEA VIC4, no pixel repeat. */
	static const u8 avi[] = {
		0x82, 0x02, 0x0d, 0x33, 0x10, 0x28, 0x00, 0x04,
		0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
	};
	u8 revision;
	unsigned int i;
	int ret;

	if (priv->configured)
		return 0;
	if (!plat->device)
		return -ENODEV;
	ret = mipi_dsi_attach(plat->device);
	if (ret)
		return ret;
	/* Descriptor values are logical: 1 asserts active-low RSTn. */
	ret = dm_gpio_set_value(&priv->reset, 0);
	if (ret)
		return ret;
	mdelay(100);
	ret = dm_gpio_set_value(&priv->reset, 1);
	if (ret)
		return ret;
	mdelay(20);
	ret = dm_gpio_set_value(&priv->reset, 0);
	if (ret)
		return ret;
	mdelay(100);
	priv->page = -1;
	ret = lt9611_write(dev, 0x80ee, 0x01);
	if (ret)
		return ret;
	ret = lt9611_read(dev, 0x8002, &revision);
	if (ret)
		return ret;
	dev_info(dev, "plain LT9611 revision %02x; selecting crystal in U-Boot\n", revision);
	ret = lt9611_sequence(dev, lt9611_system, ARRAY_SIZE(lt9611_system));
	if (ret)
		return ret;
	dev_info(dev, "LT9611 crystal selection completed\n");
	ret = lt9611_sequence(dev, lt9611_video, ARRAY_SIZE(lt9611_video));
	if (ret)
		return ret;
	for (i = 0; i < ARRAY_SIZE(avi); i++) {
		ret = lt9611_write(dev, 0x8440 + i, avi[i]);
		if (ret)
			return ret;
	}
	ret = lt9611_write(dev, 0x843d, 0x0a);
	if (ret)
		return ret;
	priv->configured = true;
	return 0;
}

/* Use the same plain-LT9611 video counters as the Linux driver. */
static int lt9611_read_word(struct udevice *dev, u16 reg)
{
	u8 hi, lo;
	int ret;

	ret = lt9611_read(dev, reg, &hi);
	if (ret)
		return ret;
	ret = lt9611_read(dev, reg + 1, &lo);
	return ret ? ret : (hi << 8) | lo;
}

static int lt9611_wait_input(struct udevice *dev)
{
	int hactive = 0, vactive = 0, vtotal = 0, htotal = 0;
	unsigned int sample, stable = 0;

	/* Bounded readiness check, not a retry of reset/PLL initialization. */
	for (sample = 0; sample < 20; sample++) {
		hactive = lt9611_read_word(dev, 0x8382);
		if (hactive < 0)
			return hactive;
		vactive = lt9611_read_word(dev, 0x8282);
		if (vactive < 0)
			return vactive;
		vtotal = lt9611_read_word(dev, 0x826c);
		if (vtotal < 0)
			return vtotal;
		htotal = lt9611_read_word(dev, 0x8286);
		if (htotal < 0)
			return htotal;
		if (hactive == 1280 * 3 && vactive == 720 &&
		    vtotal == 750 && htotal > 0) {
			if (++stable == 2) {
				printf("LT9611: valid port-A input 1280x720, vtotal %d, htotal_sysclk %d\n",
				       vtotal, htotal);
				return 0;
			}
		} else {
			stable = 0;
		}
		mdelay(25);
	}
	printf("LT9611: invalid input: hactive_bytes=%d vactive=%d vtotal=%d htotal_sysclk=%d\n",
	       hactive, vactive, vtotal, htotal);
	return -ETIMEDOUT;
}

/* LCDIF calls this after starting pixels. No dimming or assumed link success. */
static int lt9611_set_backlight(struct udevice *dev, int percent)
{
	struct lt9611_priv *priv = dev_get_priv(dev);
	int ret;

	if (percent != 0 && percent != 100)
		return -EINVAL;
	if (!priv->configured)
		return -EPIPE;
	if (priv->enabled == !!percent)
		return 0;
	/* Match the Linux bridge's settling interval, now with a running input. */
	if (percent) {
		mdelay(500);
		ret = lt9611_wait_input(dev);
		if (ret) {
			printf("LT9611: input verification failed: %d; HDMI remains disabled\n", ret);
			return ret;
		}
	}
	ret = lt9611_write(dev, 0x8130, percent ? 0xea : 0x6a);
	if (ret)
		return ret;
	priv->enabled = !!percent;
	if (percent)
		printf("LT9611: TX enable written after input verification (physical output unverified)\n");
	return 0;
}

static int lt9611_get_timing(struct udevice *dev, struct display_timing *timing)
{
	struct mipi_dsi_panel_plat *plat = dev_get_plat(dev);

	*timing = lt9611_timing;
	if (plat->device) {
		plat->device->lanes = 4;
		plat->device->format = MIPI_DSI_FMT_RGB888;
		plat->device->mode_flags = MIPI_DSI_MODE_VIDEO |
			MIPI_DSI_MODE_VIDEO_SYNC_PULSE | MIPI_DSI_MODE_VIDEO_HSE;
	}
	return 0;
}

static int lt9611_probe(struct udevice *dev)
{
	struct lt9611_priv *priv = dev_get_priv(dev);

	priv->page = -1;
	if (dev_read_u32_default(dev, "dsi-lanes", 0) != 4)
		return -EINVAL;
	return gpio_request_by_name(dev, "reset-gpios", 0, &priv->reset, GPIOD_IS_OUT);
}

static const struct panel_ops lt9611_ops = {
	.enable_backlight = lt9611_enable,
	.set_backlight = lt9611_set_backlight,
	.get_display_timing = lt9611_get_timing,
};

static const struct udevice_id lt9611_ids[] = {
	{ .compatible = "lontium,lt9611" },
	{ }
};

U_BOOT_DRIVER(lt9611_dt510) = {
	.name = "lt9611_dt510",
	.id = UCLASS_PANEL,
	.of_match = lt9611_ids,
	.ops = &lt9611_ops,
	.probe = lt9611_probe,
	.priv_auto = sizeof(struct lt9611_priv),
	.plat_auto = sizeof(struct mipi_dsi_panel_plat),
};
