# NODEMCU Firmware Building

Instruções para fazer build do firmware do NODEMCU módulos específicos.

Apresentamos duas maneiras de criar o firmware: via **Cloud Build Service** e **Build manual**.

Para este projeto é necessário realizar o **Build manual** porque precisaremos do luac.cross para compilar
o código LUA para binário para ser gravado no LFS.

## Cloud Build Service

Acesse https://nodemcu-build.com/

- Branch: release
- Módulos: bit,color_utils,file,gpio,net,node,pcm,píxbuf,rtctime,sjson,sntp,tmr,uart,websocket,wifi,ws2812,ws2812_effects
- LFS size: 64Kb  (0x10000)
- SPIFFS base: 0
- SPIFFS size: 128Kb  (0x20000)

Não precisa selecionar as opções variadas:
- [ ] TLS/SSL Support
- [ ] debug ON
- [ ] FatFS support

## Build local

Para o build, é necessário usar o `luac.cross` que transforma o código em lua em binário
para ser usado no LFS.

Para fazer build do firmware localmente e usar o `luac.cross`:

1. Clone o nodemcu-firmware no Ubuntu (WSL):


    sudo apt-get install git -y
    mkdir nodemcu
    cd nodemcu
    git clone --recurse-submodules https://github.com/nodemcu/nodemcu-firmware.git nodemcu-firmware

2. Editar `app/include/user_modules.h` para habilitar e desabilitar os módulos para o firmware.
3. Editar `app/include/user_config.h` para deixar habilitado apenas as seguintes opções:
    - #define FLASH_4M  _(para Espressif ESP8266 ESP-12E)_
    - #define BIT_RATE_DEFAULT BIT_RATE_115200
    - #define LUA_NUMBER_INTEGRAL
    - #define LUA_FLASH_STORE                   0x10000   _(para LFS = 64K)_

4. Fazer o build do firmware:


    sudo apt-get install unzip -y
    sudo apt-get install python3 -y
    sudo update-alternatives --install /usr/bin/python python /usr/bin/python3 10
    cd nodemcu-firmware
    make

5. Confira os binários do firmware estão na pasta `bin` e o `luac.cross` e o `luac.cross.int` foram criados na raiz.


## Gravando o firmware no ESP8266

O firmware está separado em vários arquivos na pasta `bin`. Supondo que sejam 
dois arquivos (`0x00000`, `0x10000`), o comando para upload é:

    cd ~/nodemcu/nodemcu-firmware
    esptool.py --port /dev/ttyUSB0 --chip esp8266 \
          --before default_reset --after hard_reset \
          write_flash 0x00000 ./bin/0x00000.bin 0x10000 ./bin/0x10000.bin

## Compilando o código .lua para o LFS

6. Execute o `build.sh` se estiver tudo certo ou, faça-o manualmente no ubuntu:


    cd /mnt/c/Users/smarc/CLionProjects/LedMatrixPanel/LedMatrix/
    mkdir out
    cd ./src/SPIFFS
    cp init.lua ../../out/
    cp reload_LFS.lua ../../out/
    cp ok.flag ../../out/

    cd ../lfs/
    ~/nodemcu/nodemcu-firmware/luac.cross.int -o ../../out/lfs.img -f *.lua


## Para testar o lua:

    nodemcu-tool upload --port=/dev/ttyUSB0 ./src/SPIFFS/teste.lua
    nodemcu-tool terminal --port=/dev/ttyUSB0
    >dofile("teste.lua")


