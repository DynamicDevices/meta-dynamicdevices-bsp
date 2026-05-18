# Drop modsign for local/KAS builds without factory-keys.
# meta-integrity linux_ima.inc gates KERNEL_FEATURES modsign.scc and inherit
# kernel-modsign on DISTRO_FEATURES modsign (not MODSIGN_ENABLE alone).
# Foundries: MODSIGN_ENABLE=1 and conf/factory-keys/privkey_modsign.pem present.
# Included from conf/layer.conf so this always runs when the BSP layer is in
# BBLAYERS (lmp.bbclass may load another layer's lmp-factory-custom.inc first).
DISTRO_FEATURES:remove = "${@' modsign' if (d.getVar('LOCAL_DEVELOPMENT_BUILD') or '0') == '1' or (d.getVar('MODSIGN_ENABLE') or '1') == '0' or (d.getVar('MODSIGN') or '1') == '0' else ''}"
