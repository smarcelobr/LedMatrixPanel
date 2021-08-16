#!/bin/bash
# Execute esse script no terminal Ubuntu

cd /home/sergio/IdeaProjects/LedMatrixPanel/LedMatrix || exit

cd ./src/SPIFFS || exit
cp init.lua ../../out/
cp reload_LFS.lua ../../out/
cp ok.flag ../../out/

# cria imagem LFS
cd ../lfs/ || exit
//mnt/c/Users/smarc/esp8266/nodemcu-firmware/luac.cross.int -o ../../out/lfs.img -f *.lua