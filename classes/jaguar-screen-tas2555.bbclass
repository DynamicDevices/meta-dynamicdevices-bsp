TAS2555_I2C_ADDRESS ??= "0x4c"

def jaguar_screen_tas2555_header_content(d):
    features = set((d.getVar('MACHINE_FEATURES') or '').split())
    enabled = 'tas2555' in features
    rom1_dev = 'tas2555-rom1-dev' in features

    if rom1_dev and not enabled:
        bb.fatal('tas2555-rom1-dev requires the base tas2555 machine feature')

    if rom1_dev and d.getVar('DEV_MODE') != '1':
        bb.fatal('tas2555-rom1-dev is an unprotected development mode and requires DEV_MODE=1')

    if not enabled:
        return '\n'.join([
            '#define TAS2555_ENABLED 0',
            '#define TAS2555_ROM1_DEV 0',
            '',
        ])

    address = (d.getVar('TAS2555_I2C_ADDRESS') or '').lower()
    if address not in ('0x4c', '0x4d', '0x4e', '0x4f'):
        bb.fatal('TAS2555_I2C_ADDRESS must be a seven-bit address from 0x4c to 0x4f')

    return '\n'.join([
        '#define TAS2555_ENABLED 1',
        '#define TAS2555_I2C_ADDRESS ' + address,
        '#define TAS2555_UNIT_ADDRESS ' + address[2:],
        '#define TAS2555_ROM1_DEV ' + ('1' if rom1_dev else '0'),
        '',
    ])

python jaguar_screen_tas2555_header() {
    if d.getVar('MACHINE') != 'imx8mm-jaguar-screen':
        return

    import os
    header = os.path.join(d.getVar('WORKDIR'), 'imx8mm-jaguar-screen-tas2555.h')
    with open(header, 'w') as output:
        output.write(jaguar_screen_tas2555_header_content(d))
}
