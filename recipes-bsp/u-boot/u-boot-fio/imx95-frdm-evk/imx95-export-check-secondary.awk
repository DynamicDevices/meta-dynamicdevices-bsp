/^#ifdef CONFIG_IMX95$/ { imx95 = 1 }
imx95 && /^bool check_secondary_cnt_set/ && !done {
	print "#endif"
	print ""
	done = 1
}
imx95 && done && /^#endif$/ { imx95 = 0; next }
{ print }
END {
	if (!done)
		exit 1
}
