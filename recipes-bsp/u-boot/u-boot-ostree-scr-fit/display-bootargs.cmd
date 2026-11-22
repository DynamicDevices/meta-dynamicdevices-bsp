# Filter exact numbered VT consoles only; retain serial and deployment tokens.
# setexpr regex is already required by the upstream OSTree boot header.
# U-Boot's SLRE treats bracket contents as a literal set: no [0-9] ranges.
setenv aesl_display_args
for aesl_display_arg in ${bootargs}; do
    if setexpr aesl_display_keep sub "^console=tty[0123456789]+$" "AESL_VT" "${aesl_display_arg}"; then
        # Only a successful exact VT match is discarded.
        true
    else
        # U-Boot setexpr returns 1 on no match. Errors also retain the token.
        setenv aesl_display_args "${aesl_display_args} ${aesl_display_arg}"
    fi
done
setenv bootargs "${aesl_display_args} splash logo.nologo vt.global_cursor_default=0@@AESL_DISPLAY_MODE@@"
setenv aesl_display_args
setenv aesl_display_arg
setenv aesl_display_keep
