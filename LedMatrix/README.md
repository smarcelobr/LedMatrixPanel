# Led Matrix

## para baixar esse repositório:

$ git clone https://github.com/smarcelobr/relogioBPICM.git

## NODEMCU Firmware

Para criar o firmware: Acesse https://nodemcu-build.com/

- Branch: release
- Módulos: bit,color_utils,file,gpio,net,node,pcm,rtctime,sjson,sntp,tmr,uart,websocket,wifi,ws2812,ws2812_effects
- LFS size: 64Kb
- SPIFFS base: 0  
- SPIFFS size: 128Kb

Para gravar o firmware:

tool:  https://github.com/espressif/esptool

comando:

    esptool.py --port <serial-port-of-ESP8266> write_flash -fm <flash-mode> 0x00000 <nodemcu-firmware>.bin

exemplo: (Powershell NATALENE)

    cd .\home\sergio\IdeaProjects\LedMatrixPanel\firmware\
    esptool.py --port COM3 write_flash -fm dio 0x00000 nodemcu-release-16-modules-2021-04-01-00-52-53-integer.bin

## Construindo os artefatos:

Execute o script build.sh no Ubuntu.

## Uploading para ESP8266

Execute o script 'upload.ps1' no powershell.

## executando o código novo:

Execute o script 'run.ps1' no powershell.

file.remove("ok.flag")
