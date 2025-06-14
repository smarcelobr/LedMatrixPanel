# Led Matrix

## Guia rápido

  Se já realizou o setup (instalação do Ubuntu e do usbpid), segue os comandos rotineiros:

### Compartilhamento da Porta Serial USB para o Ubuntu

1. Conecte o ESP8266 na porta USB;
2. No command prompt do windows, obtenha o USBID da Porta Serial e conecte-a no Ubuntu:


    C:\Users\smarc> usbipd list
    BUSID  VID:PID    DEVICE                                                        STATE
    3-4    10c4:ea60  Silicon Labs CP210x USB to UART Bridge (COM8)                 Shared

3. Conecte-a no Ubuntu:


    C:\Users\smarc> usbipd attach --wsl --busid=3-4

### Ative o Python Virtual Enviroment do projeto

   Etapa necessária para usar o `esptool.py` no Ubuntu.

    cd ~/nodemcu
    source .venv/bin/activate

### build do código .lua e LFS

    cd /mnt/c/Users/smarc/CLionProjects/LedMatrixPanel/LedMatrix/    
    cd ./src/SPIFFS
    cp init.lua ../../out/
    cp reload_LFS.lua ../../out/
    cp ok.flag ../../out/

    cd ../lfs/
    ~/nodemcu/nodemcu-firmware/luac.cross.int -o ../../out/lfs.img -f *.lua

### Upload para o ESP8266 (ESP-12)

    cd /mnt/c/Users/smarc/CLionProjects/LedMatrixPanel/LedMatrix/
    cd out
    nodemcu-tool upload --port=/dev/ttyUSB0 lfs.img *.lua ok.flag


### executando o código novo:

Execute o script 'run.ps1' no powershell, 
ou, no Ubuntu:

    nodemcu-tool --port=/dev/ttyUSB0 run reload_LFS.lua
    nodemcu-tool --port=/dev/ttyUSB0 terminal

## Ferramentas

- IDE: Jetbrains CLion (Licença free para hobbistas a partir da versão 2025.1)

_Como o código é em Lua, pode ser qualquer IDE da JetBrains._

- Esptool: https://github.com/espressif/esptool
- (Ubuntu) Lua upload/terminal: [NodeMCU-Tool](https://github.com/andidittrich/NodeMCU-Tool)

## Preparando o Ubuntu (WSL)

Consulte o documento [SETUP-WSL-UBUNTU](SETUP-WSL-UBUNTU.md).

## Clonar repositório:

$ git clone https://github.com/smarcelobr/LedMatrixPanel

## NODEMCU Firmware

- Código fonte (release) do firmware nodemcu para ESP8266:
      https://github.com/nodemcu/nodemcu-firmware/tree/release

- Documentação do nodemcu: 
      https://nodemcu.readthedocs.io

### Building a firmware

Documentação com opções para construir o firmware:
   https://nodemcu.readthedocs.io/en/release/build/

### Writing the firmware

Para gravar o firmware:

Ferramenta:  https://github.com/espressif/esptool

comando:

    esptool.py --port <serial-port-of-ESP8266> write_flash -fm <flash-mode> 0x00000 <nodemcu-firmware>.bin

exemplo: (Powershell NATALENE)

    cd .\home\sergio\IdeaProjects\LedMatrixPanel\firmware\
    esptool.py --port COM3 write_flash -fm dio 0x00000 nodemcu-release-16-modules-2021-04-01-00-52-53-integer.bin



