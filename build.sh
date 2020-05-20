#!/usr/bin/env bash
docker pull bluetoothkeyboard/arduino-cli-bluefruit-nrf52:latest
docker run -it --mount src=${PWD},target=/opt/BlueMicro_BLE,type=bind  bluetoothkeyboard/arduino-cli-bluefruit-nrf52:latest /opt/BlueMicro_BLE/.build.sh
