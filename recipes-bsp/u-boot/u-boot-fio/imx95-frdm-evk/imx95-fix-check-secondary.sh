#!/bin/sh
# Close #ifdef CONFIG_IMX95 before check_secondary_cnt_set in scmi/soc.c (factory SPL link).
set -e
soc="$1/arch/arm/mach-imx/imx9/scmi/soc.c"
awkf="$2"
if [ ! -f "$soc" ]; then
	echo "imx95-frdm-evk: missing $soc" >&2
	exit 1
fi
if grep -q 'imx95-frdm-evk: check_secondary export fix applied' "$soc"; then
	exit 0
fi
awk -f "$awkf" "$soc" > "$soc.tmp" || exit 1
printf '%s\n' '/* imx95-frdm-evk: check_secondary export fix applied */' >> "$soc.tmp"
mv "$soc.tmp" "$soc"
