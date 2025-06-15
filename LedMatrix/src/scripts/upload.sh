#!/bin/bash
# Execute esse script no terminal Ubuntu

cd /mnt/c/Users/smarc/CLionProjects/LedMatrixPanel/LedMatrix || exit

nodemcu-tool upload --port=/dev/ttyUSB0 ./out/*