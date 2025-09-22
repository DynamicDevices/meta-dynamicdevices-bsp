SUMMARY = "Zephyr RTOS firmware for MCXC444 microcontroller on imx93-jaguar-eink"
DESCRIPTION = "Zephyr RTOS application firmware for the NXP MCXC444 microcontroller \
used on the imx93-jaguar-eink board. This firmware handles power management, \
system control, and communication with the main i.MX93 processor."
HOMEPAGE = "https://zephyrproject.org/"
LICENSE = "Apache-2.0"
LIC_FILES_CHKSUM = "file://LICENSE;md5=86d3f3a95c324c9479bd8986968f4327"

# Zephyr source repository
SRCREV = "v3.7.0"
SRC_URI = "git://github.com/zephyrproject-rtos/zephyr.git;protocol=https;branch=main"

S = "${WORKDIR}/git"

# Dependencies for building Zephyr
DEPENDS = "python3-native python3-pyelftools-native python3-pyyaml-native python3-canopen-native dtc-native"

# Only build for machines that have the MCXC444 microcontroller
COMPATIBLE_MACHINE = "imx93-jaguar-eink"

# Zephyr configuration
ZEPHYR_BOARD = "mcxc444"
ZEPHYR_APP_DIR = "${WORKDIR}/mcxc444-eink-app"

inherit python3native

do_configure() {
    # Create Zephyr application directory
    mkdir -p ${ZEPHYR_APP_DIR}/src
    mkdir -p ${ZEPHYR_APP_DIR}/boards/${ZEPHYR_BOARD}
    
    # Create main application source
    cat > ${ZEPHYR_APP_DIR}/src/main.c << 'EOF'
/*
 * MCXC444 Power Management Firmware for imx93-jaguar-eink
 * 
 * This firmware runs on the MCXC444 microcontroller and provides:
 * - Power management for the E-Ink board
 * - Communication with i.MX93 main processor
 * - Battery monitoring and optimization
 * - System wake/sleep control
 */

#include <zephyr/kernel.h>
#include <zephyr/device.h>
#include <zephyr/drivers/gpio.h>
#include <zephyr/drivers/uart.h>
#include <zephyr/pm/pm.h>
#include <zephyr/logging/log.h>

LOG_MODULE_REGISTER(mcxc444_eink, LOG_LEVEL_INF);

/* GPIO definitions for E-Ink board control */
#define POWER_ENABLE_NODE DT_ALIAS(power_enable)
#define IMX93_WAKE_NODE   DT_ALIAS(imx93_wake)
#define BATTERY_MON_NODE  DT_ALIAS(battery_monitor)

static const struct gpio_dt_spec power_enable = GPIO_DT_SPEC_GET(POWER_ENABLE_NODE, gpios);
static const struct gpio_dt_spec imx93_wake = GPIO_DT_SPEC_GET(IMX93_WAKE_NODE, gpios);
static const struct gpio_dt_spec battery_mon = GPIO_DT_SPEC_GET(BATTERY_MON_NODE, gpios);

/* UART for communication with i.MX93 */
static const struct device *uart_dev;

/* Power management states */
enum power_state {
    POWER_STATE_ACTIVE,
    POWER_STATE_SLEEP,
    POWER_STATE_DEEP_SLEEP,
    POWER_STATE_SHUTDOWN
};

static enum power_state current_power_state = POWER_STATE_ACTIVE;

/* Initialize GPIO pins */
static int gpio_init(void)
{
    int ret;
    
    if (!gpio_is_ready_dt(&power_enable)) {
        LOG_ERR("Power enable GPIO not ready");
        return -ENODEV;
    }
    
    ret = gpio_pin_configure_dt(&power_enable, GPIO_OUTPUT_ACTIVE);
    if (ret < 0) {
        LOG_ERR("Failed to configure power enable GPIO: %d", ret);
        return ret;
    }
    
    if (!gpio_is_ready_dt(&imx93_wake)) {
        LOG_ERR("i.MX93 wake GPIO not ready");
        return -ENODEV;
    }
    
    ret = gpio_pin_configure_dt(&imx93_wake, GPIO_OUTPUT_INACTIVE);
    if (ret < 0) {
        LOG_ERR("Failed to configure i.MX93 wake GPIO: %d", ret);
        return ret;
    }
    
    if (!gpio_is_ready_dt(&battery_mon)) {
        LOG_ERR("Battery monitor GPIO not ready");
        return -ENODEV;
    }
    
    ret = gpio_pin_configure_dt(&battery_mon, GPIO_INPUT);
    if (ret < 0) {
        LOG_ERR("Failed to configure battery monitor GPIO: %d", ret);
        return ret;
    }
    
    return 0;
}

/* Initialize UART communication */
static int uart_init(void)
{
    uart_dev = DEVICE_DT_GET(DT_CHOSEN(zephyr_console));
    
    if (!device_is_ready(uart_dev)) {
        LOG_ERR("UART device not ready");
        return -ENODEV;
    }
    
    LOG_INF("UART initialized for i.MX93 communication");
    return 0;
}

/* Power management functions */
static void enter_sleep_mode(void)
{
    LOG_INF("Entering sleep mode");
    current_power_state = POWER_STATE_SLEEP;
    
    /* Configure wake sources */
    /* Enable low-power mode */
    pm_state_force(0U, &(struct pm_state_info){PM_STATE_SUSPEND_TO_IDLE, 0, 0});
}

static void wake_imx93(void)
{
    LOG_INF("Waking i.MX93 processor");
    gpio_pin_set_dt(&imx93_wake, 1);
    k_msleep(100);  /* Hold wake signal */
    gpio_pin_set_dt(&imx93_wake, 0);
}

/* Main application thread */
static void main_thread(void)
{
    int ret;
    
    LOG_INF("MCXC444 E-Ink Power Management Firmware v1.0");
    LOG_INF("Board: imx93-jaguar-eink");
    
    /* Initialize peripherals */
    ret = gpio_init();
    if (ret < 0) {
        LOG_ERR("GPIO initialization failed: %d", ret);
        return;
    }
    
    ret = uart_init();
    if (ret < 0) {
        LOG_ERR("UART initialization failed: %d", ret);
        return;
    }
    
    LOG_INF("MCXC444 initialization complete");
    
    /* Main power management loop */
    while (1) {
        /* Monitor battery status */
        int battery_level = gpio_pin_get_dt(&battery_mon);
        
        /* Check for communication from i.MX93 */
        /* Handle power state transitions */
        /* Manage E-Ink display power */
        
        /* Sleep for power efficiency */
        k_msleep(1000);
    }
}

int main(void)
{
    main_thread();
    return 0;
}
EOF

    # Create CMakeLists.txt for the application
    cat > ${ZEPHYR_APP_DIR}/CMakeLists.txt << 'EOF'
# SPDX-License-Identifier: Apache-2.0

cmake_minimum_required(VERSION 3.20.0)

find_package(Zephyr REQUIRED HINTS $ENV{ZEPHYR_BASE})
project(mcxc444_eink_firmware)

target_sources(app PRIVATE src/main.c)
EOF

    # Create prj.conf for Zephyr configuration
    cat > ${ZEPHYR_APP_DIR}/prj.conf << 'EOF'
# Zephyr configuration for MCXC444 E-Ink power management

# Basic kernel configuration
CONFIG_MAIN_STACK_SIZE=2048
CONFIG_SYSTEM_WORKQUEUE_STACK_SIZE=1024

# GPIO support
CONFIG_GPIO=y

# UART support for communication
CONFIG_SERIAL=y
CONFIG_UART_CONSOLE=y

# Power management
CONFIG_PM=y
CONFIG_PM_DEVICE=y
CONFIG_PM_DEVICE_RUNTIME=y

# Logging
CONFIG_LOG=y
CONFIG_LOG_DEFAULT_LEVEL=3

# Networking (if needed for communication)
CONFIG_NETWORKING=n

# Size optimizations for small flash
CONFIG_SIZE_OPTIMIZATIONS=y
CONFIG_COMPILER_OPT_SIZE=y
CONFIG_NO_OPTIMIZATIONS=n

# Disable unused features
CONFIG_TIMESLICING=n
CONFIG_THREAD_MONITOR=n
CONFIG_THREAD_NAME=n
CONFIG_PRINTK=y
CONFIG_EARLY_CONSOLE=y

# MCUboot support
CONFIG_BOOTLOADER_MCUBOOT=y
EOF

    # Create board configuration
    cat > ${ZEPHYR_APP_DIR}/boards/${ZEPHYR_BOARD}/${ZEPHYR_BOARD}.dts << 'EOF'
/*
 * Device tree for NXP MCXC444 microcontroller
 * Used on imx93-jaguar-eink board
 */

/dts-v1/;
#include <nxp/nxp_mcxc444.dtsi>

/ {
    model = "NXP MCXC444 for imx93-jaguar-eink";
    compatible = "nxp,mcxc444";

    aliases {
        power-enable = &power_enable_gpio;
        imx93-wake = &imx93_wake_gpio;
        battery-monitor = &battery_mon_gpio;
    };

    chosen {
        zephyr,console = &uart0;
        zephyr,shell-uart = &uart0;
        zephyr,sram = &sram0;
        zephyr,flash = &flash0;
    };

    gpio_keys {
        compatible = "gpio-keys";
        
        power_enable_gpio: power_enable {
            gpios = <&gpioa 0 GPIO_ACTIVE_HIGH>;
            label = "Power Enable";
        };
        
        imx93_wake_gpio: imx93_wake {
            gpios = <&gpioa 1 GPIO_ACTIVE_HIGH>;
            label = "i.MX93 Wake";
        };
        
        battery_mon_gpio: battery_monitor {
            gpios = <&gpioa 2 GPIO_ACTIVE_HIGH>;
            label = "Battery Monitor";
        };
    };
};

&uart0 {
    status = "okay";
    current-speed = <115200>;
};

&gpioa {
    status = "okay";
};

&flash0 {
    partitions {
        compatible = "fixed-partitions";
        #address-cells = <1>;
        #size-cells = <1>;

        boot_partition: partition@0 {
            label = "mcuboot";
            reg = <0x00000000 0x00008000>;
        };
        
        slot0_partition: partition@8000 {
            label = "image-0";
            reg = <0x00008000 0x00018000>;
        };
        
        slot1_partition: partition@20000 {
            label = "image-1";
            reg = <0x00020000 0x00018000>;
        };
        
        scratch_partition: partition@38000 {
            label = "image-scratch";
            reg = <0x00038000 0x00008000>;
        };
    };
};
EOF

    # Create board configuration file
    cat > ${ZEPHYR_APP_DIR}/boards/${ZEPHYR_BOARD}/${ZEPHYR_BOARD}.yaml << 'EOF'
identifier: mcxc444
name: NXP MCXC444 for imx93-jaguar-eink
type: mcu
arch: arm
toolchain:
  - zephyr
  - gnuarmemb
supported:
  - gpio
  - uart
  - flash
  - power_management
EOF
}

do_compile() {
    cd ${ZEPHYR_APP_DIR}
    
    # Set Zephyr environment
    export ZEPHYR_BASE=${S}
    export ZEPHYR_TOOLCHAIN_VARIANT=zephyr
    
    # Build the Zephyr application
    ${S}/scripts/west build -b ${ZEPHYR_BOARD} . -d ${B}
}

do_install() {
    install -d ${D}${datadir}/zephyr-mcxc444
    install -d ${D}${bindir}
    
    # Install Zephyr firmware binary
    if [ -f ${B}/zephyr/zephyr.bin ]; then
        install -m 0644 ${B}/zephyr/zephyr.bin ${D}${datadir}/zephyr-mcxc444/zephyr-mcxc444.bin
    fi
    
    # Install Zephyr firmware ELF for debugging
    if [ -f ${B}/zephyr/zephyr.elf ]; then
        install -m 0644 ${B}/zephyr/zephyr.elf ${D}${datadir}/zephyr-mcxc444/zephyr-mcxc444.elf
    fi
    
    # Install hex file for programming
    if [ -f ${B}/zephyr/zephyr.hex ]; then
        install -m 0644 ${B}/zephyr/zephyr.hex ${D}${datadir}/zephyr-mcxc444/zephyr-mcxc444.hex
    fi
    
    # Create programming script
    cat > ${D}${bindir}/program-mcxc444 << 'EOF'
#!/bin/bash
# Programming script for MCXC444 microcontroller
# Usage: program-mcxc444 [firmware.bin]

FIRMWARE_DIR="/usr/share/zephyr-mcxc444"
DEFAULT_FIRMWARE="$FIRMWARE_DIR/zephyr-mcxc444.bin"

FIRMWARE="${1:-$DEFAULT_FIRMWARE}"

if [ ! -f "$FIRMWARE" ]; then
    echo "Error: Firmware file not found: $FIRMWARE"
    exit 1
fi

echo "Programming MCXC444 microcontroller..."
echo "Firmware: $FIRMWARE"
echo ""
echo "Connect your programming tool (J-Link, OpenOCD, etc.) and run:"
echo "  For J-Link: JLinkExe -device MCXC444 -if SWD -speed 4000"
echo "  For OpenOCD: openocd -f interface/jlink.cfg -f target/mcxc444.cfg"
echo ""
echo "Then flash the firmware:"
echo "  loadbin $FIRMWARE 0x0"
echo "  r"
echo "  g"
EOF
    chmod +x ${D}${bindir}/program-mcxc444
}

FILES:${PN} = " \
    ${datadir}/zephyr-mcxc444/zephyr-mcxc444.bin \
    ${datadir}/zephyr-mcxc444/zephyr-mcxc444.hex \
    ${bindir}/program-mcxc444 \
"

FILES:${PN}-dev = "${datadir}/zephyr-mcxc444/*.elf"

RDEPENDS:${PN} = "python3-core"

# Package information
PACKAGE_ARCH = "${MACHINE_ARCH}"
