#!/usr/bin/env bash
docker pull bluetoothkeyboard/arduino-cli-bluefruit-nrf52:latest
docker run -it \
	--mount src=${PWD},target=/opt/BlueMicro_BLE,type=bind \
	--workdir=/opt/BlueMicro_BLE \
	bluetoothkeyboard/arduino-cli-bluefruit-nrf52:latest \
        ./build/docker/nrf.sh
