#!/usr/bin/env bash

# SPDX-License-Identifier: Apache-2.0

set -euo pipefail

IF_TYPE="spi"
MODULE_NAME="esp32_spi.ko"
RESETPIN=-1
HANDSHAKEPIN=471
DATAREADYPIN=433
SPI_BUS_NUM=0
SPI_CHIP_SELECT=0
SPI_MODE=2
CLOCKSPEED=10
RAW_TP_MODE=0
AP_SUPPORT=0
OTA_FILE=""

bringup_network_interface()
{
	if [ -n "${1:-}" ] && ifconfig -a | grep -q "$1"; then
		sudo ifconfig "$1" up
	fi
}

usage()
{
	echo "Build and load ESP-Hosted-NG for Jetson Orin Nano over SPI."
	echo
	echo "Usage: ./jetson_orin_nano_init.sh [arguments]"
	echo
	echo "Arguments:"
	echo "  resetpin=-1         Disable host-driven ESP reset by default"
	echo "  handshakepin=471    Host GPIO connected to ESP handshake (Jetson header pin 22)"
	echo "  datareadypin=433    Host GPIO connected to ESP data-ready (Jetson header pin 15)"
	echo "  spibus=0            SPI controller bus number to use"
	echo "  spics=0             SPI chip-select number to use"
	echo "  spimode=2           SPI mode to use for ESP transport"
	echo "  clockspeed=10       Initial SPI clock in MHz"
	echo "  ap_support          Enable AP support in the module build"
	echo "  rawtp_host_to_esp   Enable raw throughput host->ESP test mode"
	echo "  rawtp_esp_to_host   Enable raw throughput ESP->host test mode"
	echo "  ota_file=/path      Pass OTA file path through the module"
	echo
	echo "Notes:"
	echo "  - Defaults match Jetson Orin Nano 8GB dev kit header wiring:"
	echo "      pin 15 -> data-ready (legacy global GPIO 433)"
	echo "      pin 22 -> handshake  (legacy global GPIO 471)"
	echo "  - Host-driven reset is disabled by default because driving ESP EN/RST from"
	echo "    Jetson pin 18 can hold the ESP in reset or interfere with USB flashing."
	echo "    If your wiring is known-good, opt in with resetpin=473."
	echo "  - This helper currently supports the SPI transport only."
	echo "  - These GPIO values are legacy global Linux GPIO numbers, not gpiochip offsets."
	echo "  - If spi0.0 is bound to spidev, the script unbinds it for the current boot"
	echo "    so esp32_spi.ko can reuse the existing SPI device."
}

parse_arguments()
{
	while [ "${1:-}" != "" ]; do
		case "$1" in
			--help|-h)
				usage
				exit 0
				;;
			spi)
				;;
			sdio)
				echo "This helper is Jetson SPI-specific. SDIO is not handled here."
				exit 1
				;;
			resetpin=*)
				RESETPIN=${1#*=}
				;;
			handshakepin=*)
				HANDSHAKEPIN=${1#*=}
				;;
			datareadypin=*)
				DATAREADYPIN=${1#*=}
				;;
			spibus=*)
				SPI_BUS_NUM=${1#*=}
				;;
			spics=*)
				SPI_CHIP_SELECT=${1#*=}
				;;
			spimode=*)
				SPI_MODE=${1#*=}
				;;
			clockspeed=*)
				CLOCKSPEED=${1#*=}
				;;
			ap_support)
				AP_SUPPORT=1
				;;
			rawtp_host_to_esp)
				RAW_TP_MODE=1
				;;
			rawtp_esp_to_host)
				RAW_TP_MODE=2
				;;
			ota_file=*)
				OTA_FILE=${1#*=}
				;;
			*)
				echo "$1 : unknown option"
				usage
				exit 1
				;;
		esac
		shift
	done
}

unbind_spi_driver()
{
	local spi_dev="spi${SPI_BUS_NUM}.${SPI_CHIP_SELECT}"
	local driver_link="/sys/bus/spi/devices/${spi_dev}/driver"
	local driver_name=""

	if [ ! -e "/sys/bus/spi/devices/${spi_dev}" ]; then
		echo "No existing SPI device ${spi_dev} found; esp32_spi.ko will create one."
		return
	fi

	if [ ! -L "$driver_link" ]; then
		echo "SPI device ${spi_dev} is present and currently unbound."
		return
	fi

	driver_name=$(basename "$(readlink -f "$driver_link")")
	if [ "$driver_name" = "spidev" ]; then
		echo "Unbinding ${spi_dev} from spidev for this boot..."
		echo "$spi_dev" | sudo tee /sys/bus/spi/drivers/spidev/unbind > /dev/null
		return
	fi

	echo "SPI device ${spi_dev} is already bound to ${driver_name}; refusing to steal it."
	exit 1
}

wlan_init()
{
	local custom_opts=()
	local arch_found
	local insmod_args

	if lsmod | grep -q '^esp32_'; then
		sudo rmmod esp32_sdio 2>/dev/null || true
		sudo rmmod esp32_spi 2>/dev/null || true
	fi

	if [ "$AP_SUPPORT" = "1" ]; then
		custom_opts+=(CONFIG_AP_SUPPORT=y)
	fi

	case "$(uname -m)" in
		aarch64|arm64)
			arch_found="arm64"
			;;
		arm*)
			arch_found="arm"
			;;
		x86_64)
			arch_found="x86"
			;;
		*)
			arch_found="$(uname -m)"
			;;
	esac

	make -j"$(nproc)" target="$IF_TYPE" KERNEL="/lib/modules/$(uname -r)/build" \
		ARCH="$arch_found" "${custom_opts[@]}"

	unbind_spi_driver

	sudo modprobe bluetooth
	sudo modprobe cfg80211

	insmod_args=(
		resetpin="$RESETPIN" \
		clockspeed="$CLOCKSPEED" \
		raw_tp_mode="$RAW_TP_MODE" \
		spi_bus_num="$SPI_BUS_NUM" \
		spi_chip_select="$SPI_CHIP_SELECT" \
		spi_handshake_gpio="$HANDSHAKEPIN" \
		spi_dataready_gpio="$DATAREADYPIN" \
		spi_mode="$SPI_MODE"
	)

	if [ -n "$OTA_FILE" ]; then
		insmod_args+=(ota_file="$OTA_FILE")
	fi

	sudo insmod "$MODULE_NAME" "${insmod_args[@]}"

	echo "esp32_spi module inserted"
	sleep 4
	bringup_network_interface "wlan0"
	echo "ESP32 host init successfully completed"
}

parse_arguments "$@"
wlan_init
