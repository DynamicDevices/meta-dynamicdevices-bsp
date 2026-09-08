# FRDM-IMX95 manufacturing bundle

Place this directory beside the Foundries image artifacts, then put the board
in USB serial-download mode.

Program the board (verification is not run):

    sudo ./mfgtool-files-imx95-frdm-evk/uuu \
        ./mfgtool-files-imx95-frdm-evk/full_image.uuu

Optionally perform a complete read-back CRC of the WIC payload after flashing:

    sudo ./mfgtool-files-imx95-frdm-evk/uuu \
        ./mfgtool-files-imx95-frdm-evk/verify_image.uuu

Both scripts use `imx-boot-mfgtool`, built from the i.MX95 `flash_all` target,
and decompress the neighbouring `.wic.gz` on the host. The production
`imx-boot` and `u-boot.itb` remain the Foundries build artifacts.
