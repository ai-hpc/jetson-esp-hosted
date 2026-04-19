# Building ESP-Hosted-NG on Jetson Orin Nano 8GB

This README explains how to build and load the `ESP-Hosted-NG` Linux host driver on the **Jetson Orin Nano 8GB Developer Kit** for the **SPI** transport.

The Jetson-specific helper added in this fork is:

```bash
./jetson_orin_nano_init.sh
```

It builds `esp32_spi.ko`, unbinds `spidev` from the selected SPI device for the current boot if needed, and loads the module with Jetson Orin Nano defaults.

## Jetson dev kit wiring assumed here

This README assumes the Jetson 40-pin header is wired like this:

| Jetson header pin | Signal | ESP side role | Linux GPIO / SPI mapping |
| --- | --- | --- | --- |
| 19 | `SPI1_MOSI` | MOSI | `spi0.0` data path |
| 21 | `SPI1_MISO` | MISO | `spi0.0` data path |
| 23 | `SPI1_SCLK` | SCLK | `spi0.0` clock |
| 24 | `SPI1_CS0` | CS0 | `spi0.0` chip select |
| 15 | `GPIO15` | Data Ready | `350` |
| 18 | `GPIO18` | Reset / EN | `390` |
| 22 | `GPIO22` | Handshake | `391` |

## 1. Prepare the Jetson

Enable SPI1 on the 40-pin header with `jetson-io`, then reboot.

After reboot, verify that the header SPI bus is present:

```bash
ls -l /dev/spidev0.0
```

If `spidev0.0` exists, the Jetson header SPI controller is exposed to Linux. The helper script below will unbind `spidev` from `spi0.0` for the current boot before loading `esp32_spi.ko`.

Install build dependencies:

```bash
sudo apt update
sudo apt install -y \
  build-essential \
  linux-headers-$(uname -r)
```

## 2. Build and load with the Jetson helper

From this directory:

```bash
cd esp_hosted_ng/host
./jetson_orin_nano_init.sh
```

Default module arguments used by the script:

```text
resetpin=390
spi_handshake_gpio=391
spi_dataready_gpio=350
spi_bus_num=0
spi_chip_select=0
spi_mode=2
clockspeed=10
```

Example with explicit overrides:

```bash
./jetson_orin_nano_init.sh \
  resetpin=390 \
  handshakepin=391 \
  datareadypin=350 \
  spibus=0 \
  spics=0 \
  spimode=2 \
  clockspeed=10
```

## 3. Manual build and load

If you do not want to use the helper script, build manually:

```bash
cd esp_hosted_ng/host
make clean
make -j"$(nproc)" target=spi KERNEL="/lib/modules/$(uname -r)/build" ARCH=arm64
```

Then load manually:

```bash
sudo modprobe bluetooth
sudo modprobe cfg80211
sudo insmod ./esp32_spi.ko \
  resetpin=390 \
  clockspeed=10 \
  spi_bus_num=0 \
  spi_chip_select=0 \
  spi_handshake_gpio=391 \
  spi_dataready_gpio=350 \
  spi_mode=2
```

Important:

- if `spi0.0` is still bound to `spidev`, unbind it first
- if `spi0.0` is bound to some other driver, do not steal it blindly

Manual `spidev` unbind for the current boot:

```bash
echo spi0.0 | sudo tee /sys/bus/spi/drivers/spidev/unbind
```

## 4. Check the driver

Watch the kernel log while loading:

```bash
sudo dmesg -w
```

Useful expected lines:

```text
Config - SPI GPIOs: Handshake[391] Dataready[350]
Config - SPI clock[10MHz] bus[0] cs[0] mode[2]
```

Once the transport comes up, confirm the network interface appears:

```bash
ip link show
nmcli device status
```

## 5. Notes

- This helper is for the **Jetson Orin Nano dev kit SPI path**. It is not a generic replacement for `rpi_init.sh`.
- The script handles only the current boot. For production, disable the generic `spidev` binding for the target SPI chip-select in your device tree or overlay.
- `spidev1.*` and other SPI controllers are not automatically the 40-pin header SPI bus. For the standard dev kit flow here, use the verified header path, usually `spi0.0`.

For a slightly broader explanation of the Jetson port, see:

- [`../docs/jetson_orin_nano_spi.md`](../docs/jetson_orin_nano_spi.md)
