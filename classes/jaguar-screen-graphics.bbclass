def jaguar_screen_graphics_header_content(d):
    overrides = set((d.getVar('OVERRIDES') or '').split(':'))
    enabled = 'dd-graphics-etnaviv' in overrides
    return '#define JAGUAR_SCREEN_ETNAVIV ' + ('1' if enabled else '0') + '\n'

python jaguar_screen_graphics_header() {
    if d.getVar('MACHINE') != 'imx8mm-jaguar-screen':
        return

    import os
    header = os.path.join(d.getVar('WORKDIR'), 'imx8mm-jaguar-screen-graphics.h')
    with open(header, 'w') as output:
        output.write(jaguar_screen_graphics_header_content(d))
}
