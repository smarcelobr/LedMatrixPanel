#!/bin/bash

echo Restarting nodemcu...
nodemcu-tool --port=/dev/ttyUSB0 run memfree.lua
