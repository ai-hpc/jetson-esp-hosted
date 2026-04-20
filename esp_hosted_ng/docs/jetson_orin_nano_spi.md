# Jetson Orin Nano 8GB SPI Host Bring-Up

This note describes the Jetson-specific host-side port for `ESP-Hosted-NG` over SPI.

## Scope

- Host platform: Jetson Orin Nano 8GB Developer Kit
- Transport: SPI
- ESP peer: ESP32-C6 or another ESP-Hosted-NG SPI target

The Raspberry Pi helper script `host/rpi_init.sh` is not a drop-in fit for Jetson because it assumes:

- Raspberry Pi GPIO numbering
- Raspberry Pi `dtoverlay` flow for `spidev`
- Raspberry Pi `pinctrl` UART setup

This fork adds a Jetson-native loader script:

```bash
esp_hosted_ng/host/jetson_orin_nano_init.sh
```

It also makes the host SPI driver configurable at module load time instead of hardcoding Raspberry Pi defaults.

## Jetson header defaults

The script defaults match the Jetson Orin Nano dev kit 40-pin header wiring used for the ESP32-C6 SPI path:

| Jetson header pin | Header label | Purpose | Linux GPIO number |
| --- | --- | --- | --- |
| 15 | `J12 pin 15` | ESP `Data Ready` | legacy global GPIO `433` |
| 22 | `J12 pin 22` | ESP `Handshake` | legacy global GPIO `471` |
| 19 | `SPI1_MOSI` | SPI MOSI | bus `0`, chip-select path |
| 21 | `SPI1_MISO` | SPI MISO | bus `0`, chip-select path |
| 23 | `SPI1_SCLK` | SPI clock | bus `0`, chip-select path |
| 24 | `SPI1_CS0` | SPI chip select 0 | `spidev0.0` / `spi0.0` |

Jetson pin `18` can be used as an optional host-driven ESP reset line via legacy global GPIO `473`, but this fork disables that path by default. On real bring-up, keeping Jetson `18` tied to ESP `EN/RST` can block ESP boot or interfere with USB flashing. Start with `resetpin=-1`, then opt in to `resetpin=473` only after proving your reset wiring is stable.

## Prerequisites

1. Enable `SPI1` on the 40-pin header with `jetson-io`.
2. Reboot.
3. Verify the Jetson header SPI device exists:

```bash
ls -l /dev/spidev0.0
```

If `spidev0.0` exists, that proves the SPI controller is exposed to Linux. The host script will unbind `spidev` from `spi0.0` for the current boot so `esp32_spi.ko` can reuse the existing device.

## Build and load on Jetson

From `esp_hosted_ng/host/`:

```bash
./jetson_orin_nano_init.sh
```

That builds `esp32_spi.ko` and loads it with these defaults:

```text
resetpin=-1
spi_handshake_gpio=471
spi_dataready_gpio=433
spi_bus_num=0
spi_chip_select=0
spi_mode=2
clockspeed=10
```

Example with explicit arguments:

```bash
./jetson_orin_nano_init.sh \
  resetpin=-1 \
  handshakepin=471 \
  datareadypin=433 \
  spibus=0 \
  spics=0 \
  spimode=2 \
  clockspeed=10
```

## What changed in the driver

The SPI host path is no longer tied to Raspberry Pi defaults. The module now accepts:

- `spi_bus_num`
- `spi_chip_select`
- `spi_handshake_gpio`
- `spi_dataready_gpio`
- `spi_mode`

It will also:

- reuse an existing SPI device such as `spi0.0` if it already exists in the device tree and is unbound
- fall back to creating a new SPI device if none exists

## Notes

- `473`, `471`, and `433` are **legacy global GPIO numbers** used by the current host driver, not `gpiochip` offsets.
- If `spi0.0` is bound to a non-`spidev` driver, the Jetson helper refuses to steal it.
- The script handles the current boot only. A production setup should still disable the generic `spidev` binding for the target chip select in the device tree or overlay.
- `spidev1.*` and other SPI controllers are not automatically the 40-pin header SPI bus. For the Orin Nano dev kit flow above, use the verified header path, usually `spi0.0`.
