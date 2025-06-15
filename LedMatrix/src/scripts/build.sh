#!/bin/bash
# Execute esse script no terminal Ubuntu

cd /mnt/c/Users/smarc/CLionProjects/LedMatrixPanel/LedMatrix || exit

echo Clean...
rm out/*

echo Copiando SPIFFS...
cd ./src/SPIFFS || exit
cp init.lua ../../out/
cp reload_LFS.lua ../../out/
cp memfree.lua ../../out/
cp ok.flag ../../out/
cp config.json ../../out/

echo Copiando web pages
cd ../web || exit
cp *.html ../../out
cp *.svg ../../out
cp *.js ../../out
cp *.css ../../out

echo Imagem LFS...
cd ../lfs/ || exit
 ~/nodemcu/nodemcu-firmware/luac.cross.int -o ../../out/lfs.img -f *.lua

echo comprimindo web pages
cd ../../out || exit
gzip --best *.html *.svg *.js *.css
