#!/bin/sh
# ZBOSS mux launcher — DT510 overrides SPI/GPIO vs generic imx8mm-evk defaults.
# Installed only for imx8mm-jaguar-dt510 via zigbee-rcp-sdk.bbappend.

soc_id=$(cat /sys/devices/soc0/soc_id)
dt_compat=$(tr '\0' ' ' </proc/device-tree/compatible 2>/dev/null || true)

sed "s/soc_id=toConfigure/soc_id=${soc_id}/g" -i /etc/default/zb_mux.env

spi_dev=""
int_dev=""
int_line=""
rst_dev=""
rst_line=""

# DT510: Zigbee RCP on ECSPI1 (/dev/spidev0.0), ZB_INT = GPIO4_IO22 (libgpiod gpiochip3 line 22).
# No SoC ZB_RST# — omit zb_mux -R (see imx8mm-jaguar-dt510.dts banner).
case " ${dt_compat} " in
*"fsl,imx8mm-jaguar-dt510"*)
	spi_dev="/dev/spidev0.0"
	int_dev="/dev/gpiochip3"
	int_line=22
	;;
esac

if [ -z "${spi_dev}" ]; then
	case ${soc_id} in
	i.MX8MM|i.MX8MN|i.MX8MP)
		spi_dev="/dev/spidev1.0"
		int_dev="/dev/gpiochip5"
		int_line=12
		rst_dev="/dev/gpiochip5"
		rst_line=13
		;;
	i.MX93)
		spi_dev="/dev/spidev0.0"
		int_dev="/dev/gpiochip5"
		int_line=10
		rst_dev="/dev/gpiochip4"
		rst_line=1
		;;
	*)
		echo "unsupported platform ${soc_id}, ABORT"
		exit 1
		;;
	esac
fi

rm -f /var/local/zboss/zb_mux.log
rm -f /var/local/zboss/zb_mux.console

echo "Start ZBOSS Muxer"

rst_arg=""
if [ -n "${rst_line}" ] && [ -n "${rst_dev}" ]; then
	rst_arg="-R ${rst_line}:${rst_dev}"
fi

exec /usr/sbin/zb_mux -i "${spi_dev}" -o 0:/tmp/ttyOpenThread -o 2:/tmp/ttyZigbee \
	-s -S "${spi_speed}" -m 0 -I "${int_line}:${int_dev}" ${rst_arg} -t "${mux_trace}"
