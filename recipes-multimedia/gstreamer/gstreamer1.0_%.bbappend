# gst-launch-1.0 and gst-inspect-1.0 belong to the main gstreamer1.0 package
# in the pinned i.MX recipe; there is no separate gstreamer1.0-tools package.
PACKAGECONFIG:append:imx8mm-jaguar-dt510 = " tools"
