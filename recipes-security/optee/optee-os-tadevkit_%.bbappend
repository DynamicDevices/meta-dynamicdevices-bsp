# optee-os-tadevkit includes optee-os-fio when virtual/optee-os is optee-os-fio, but
# bbappend variables are recipe-scoped: OPTEEMACHINE in optee-os-fio_%.bbappend does
# not apply here. NXP i.MX95 OP-TEE platform is imx-mx95evk (plat-imx), not MACHINE.
OPTEEMACHINE:mx95-nxp-bsp = "imx-mx95evk"
OPTEEMACHINE:imx95-frdm-evk = "imx-mx95evk"
OPTEEMACHINE:imx95-15x15-lpddr4x-frdm = "imx-mx95evk"
