TAS2555_I2C_ADDRESS ??= "0x4c"

def jaguar_screen_tas2555_header_content(d):
    enabled = 'tas2555' in (d.getVar('MACHINE_FEATURES') or '').split()
    if not enabled:
        return '#define TAS2555_ENABLED 0\n'

    address = (d.getVar('TAS2555_I2C_ADDRESS') or '').lower()
    if address not in ('0x4c', '0x4d', '0x4e', '0x4f'):
        bb.fatal('TAS2555_I2C_ADDRESS must be a seven-bit address from 0x4c to 0x4f')

    return '\n'.join([
        '#define TAS2555_ENABLED 1',
        '#define TAS2555_I2C_ADDRESS ' + address,
        '#define TAS2555_UNIT_ADDRESS ' + address[2:],
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
