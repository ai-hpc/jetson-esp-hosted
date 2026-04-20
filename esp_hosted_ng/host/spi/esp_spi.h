// SPDX-License-Identifier: GPL-2.0-only
/*
 * SPDX-FileCopyrightText: 2015-2023 Espressif Systems (Shanghai) CO LTD
 *
 */

#ifndef _ESP_SPI_H_
#define _ESP_SPI_H_

#include "esp.h"

#define DEFAULT_HANDSHAKE_PIN           22
#define DEFAULT_SPI_DATA_READY_PIN      27
#define DEFAULT_SPI_BUS_NUM             0
#define DEFAULT_SPI_CHIP_SELECT         0
#define DEFAULT_SPI_MODE                2
#define SPI_BUF_SIZE            1600

enum spi_flags_e {
	ESP_SPI_BUS_CLAIMED,
	ESP_SPI_BUS_SET,
	ESP_SPI_DEVICE_CREATED,
	ESP_SPI_GPIO_HS_REQUESTED,
	ESP_SPI_GPIO_HS_IRQ_DONE,
	ESP_SPI_GPIO_DR_REQUESTED,
	ESP_SPI_GPIO_DR_IRQ_DONE,
	ESP_SPI_DATAPATH_OPEN,
};

struct esp_spi_context {
	struct esp_adapter          *adapter;
	struct spi_device           *esp_spi_dev;
	struct sk_buff_head         tx_q[MAX_PRIORITY_QUEUES];
	struct sk_buff_head         rx_q[MAX_PRIORITY_QUEUES];
	struct workqueue_struct     *spi_workqueue;
	struct work_struct          spi_work;
	struct workqueue_struct     *nw_cmd_reinit_workqueue;
	struct work_struct          nw_cmd_reinit_work;
	uint8_t                     spi_clk_mhz;
	uint8_t                     spi_clk_cap_mhz;
	uint8_t                     spi_mode;
	uint16_t                    spi_bus_num;
	uint16_t                    spi_chip_select;
	int                         handshake_gpio;
	int                         dataready_gpio;
	int                         handshake_irq;
	int                         dataready_irq;
	unsigned long               spi_flags;
};

enum {
	CLOSE_DATAPATH,
	OPEN_DATAPATH,
};


#endif
