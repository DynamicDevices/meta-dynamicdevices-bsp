# The manual DT510 HDMI playback path uses kmssink directly, without Weston.
# Keep this explicit even when the i.MX recipe already defaults to KMS.
PACKAGECONFIG:append:imx8mm-jaguar-dt510 = " kms"
