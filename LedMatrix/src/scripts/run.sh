#!/bin/bash
# Execute esse script no terminal Ubuntu

nodemcu-tool --port=/dev/ttyUSB0 run reload_LFS.lua || exit
nodemcu-tool --port=/dev/ttyUSB0 terminal