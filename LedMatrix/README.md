# Led Matrix

## Ferramentas

- IDE: Jetbrains CLion (Licença free para hobbistas a partir da versão 2025.1)

_Como o código é em Lua, pode ser qualquer IDE da JetBrains._

- Esptool: https://github.com/espressif/esptool
- (Ubuntu) Lua upload/terminal: [NodeMCU-Tool](https://github.com/andidittrich/NodeMCU-Tool)

## Preparando o Ubuntu (WSL)

### Porta Serial no Ubuntu (WSL)

Para a porta USB-Serial funcionar no Ubuntu, é necessário instalar o programa usbipd no Windows
e no Ubuntu que serve para compartilhar periféricos USB.

_ref.: [Connecting USB devices to WSL](https://devblogs.microsoft.com/commandline/connecting-usb-devices-to-wsl/)

1. Instale o último release do [usbipd-win](https://github.com/dorssel/usbipd-win) no Windows.
   Trata-se de baixar um `.msi` e instalar ele ou executar o comando abaixo num CMD com 
   privilégios administrativos:


    C:\Windows\system32>winget show usbipd
    ...
    C:\Windows\system32>winget install usbipd
    Encontrado usbipd-win [dorssel.usbipd-win] Versão 5.1.0
    Este aplicativo é licenciado para você pelo proprietário.
    A Microsoft não é responsável por, nem concede licenças a pacotes de terceiros.
    Baixando https://github.com/dorssel/usbipd-win/releases/download/v5.1.0/usbipd-win_5.1.0_x64.msi
    ██████████████████████████████  4.15 MB / 4.15 MB
    Hash do instalador verificado com êxito
    Iniciando a instalação do pacote...
    Instalado com êxito

2. Instale o `usbipd` no Ubuntu:

_se a versao linux-tools-6.8.0-60-generic não existir, procure outra com `apt-cache search linux-tools`._

    $ sudo apt install linux-tools-6.8.0-60-generic hwdata
    $ sudo update-alternatives --install /usr/local/bin/usbip usbip /usr/lib/linux-tools/6.8.0-60-generic/usbip 20
    $ 


3. Reinicie o comand prompt do windows e liste os dispositivos USB:


    $ C:\Users\smarc>usbipd list
    Connected:
    BUSID  VID:PID    DEVICE                                                        STATE
    3-4    10c4:ea60  Silicon Labs CP210x USB to UART Bridge (COM8)                 Not shared
    3-9    413c:a503  Dell AC511 USB SoundBar, Dispositivo de Entrada USB           Not shared
    3-13   8087:0032  Intel(R) Wireless Bluetooth(R)                                Not shared
    5-1    1bcf:28c4  FHD Camera, FHD Camera Microphone                             Not shared
    5-3    258a:0090  Dispositivo de Entrada USB                                    Not shared
    5-4    258a:1007  Dispositivo de Entrada USB                                    Not shared
    
    Persisted:
    GUID                                  DEVICE
    
    usbipd: warning: USB filter 'USBPcap' is known to be incompatible with this software; 'bind --force' will be required.
    
    C:\Users\smarc>


4. Sabendo o BUSID, podemos compartilhar a porta serial com o Ubuntu:

_Esta operação exige um command prompt com privilégios administrativos._ 

    C:\Windows\system32>usbipd bind --busid=3-4
    C:\Windows\system32>usbipd list
    Connected:
    BUSID  VID:PID    DEVICE                                                        STATE
    3-4    10c4:ea60  Silicon Labs CP210x USB to UART Bridge (COM8)                 Shared
    3-9    413c:a503  Dell AC511 USB SoundBar, Dispositivo de Entrada USB           Not shared
    3-13   8087:0032  Intel(R) Wireless Bluetooth(R)                                Not shared
    5-1    1bcf:28c4  FHD Camera, FHD Camera Microphone                             Not shared
    5-3    258a:0090  Dispositivo de Entrada USB                                    Not shared
    5-4    258a:1007  Dispositivo de Entrada USB                                    Not shared

Sharing a device is persistent; it survives reboots.

5. Agora que o dispositivo USB está compartilhado, podemos ligá-lo no Ubuntu (WSL):
 

    C:\Users\smarc>usbipd attach --wsl --busid=3-4
    usbipd: info: Using WSL distribution 'Ubuntu' to attach; the device will be available in all WSL 2 distributions.
    usbipd: info: Loading vhci_hcd module.
    usbipd: info: Detected networking mode 'nat'.
    usbipd: info: Using IP address 172.29.32.1 to reach the host.

    C:\Users\smarc>

Se tiver problemas com firewall, libere a porta 3240 para incoming connections no TCP. 

6. Para conferir se o USB está conectado no Ubuntu, use o `lsusb`


    $ sudo apt install usbutils
    $ lsusb
    Bus 001 Device 001: ID 1d6b:0002 Linux Foundation 2.0 root hub
    Bus 001 Device 002: ID 10c4:ea60 Silicon Labs CP210x UART Bridge
    Bus 002 Device 001: ID 1d6b:0003 Linux Foundation 3.0 root hub

### Instalação do `node.js` (para obter o `npm`):

_ref.: [Install Node.js on Windows Subsystem for Linux (WSL2)](https://learn.microsoft.com/en-us/windows/dev-environment/javascript/nodejs-on-wsl)_

1. Instalação do compilador C++

_obs.: necessário para instalar o nodemcu-tool_

    $ sudo apt-get update
    $ sudo apt-get install build-essential

2. Instalação do `nvm`:
 

    $ sudo apt-get install curl 
    $ curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh | bash

Reinicie o terminal e teste o `nvm` com:

    $ comand -v nvm
    nvm 
    $ nvm ls
    (o node não deve estar instalado...)

3. Instalação do `node.js` com `nvm`:


    $ nvm install --lts
    $ nvm ls
    (agora o node.js deve aparecer)
    $ node -v
    $ npm -v

4. Instalação do `nodemcu-tool`:
 

    $ npm install nodemcu-tool -g
    $ nodemcu-tool --version
    3.2.1

5. Teste o acesso a porta serial:

_Conecte o ESP8266, veja a porta serial COM\<n\> atribuída a ele_

    $ nodemcu-tool devices
    sergio@XeonLing:~$ nodemcu-tool devices
    [device]      ~ Device filter is active - only known NodeMCU devices (USB vendor-id) will be listed.
    [device]      ~ Connected Devices | Total: 1
    [device]      ~ - /dev/ttyUSB0 (Silicon Labs, usb-Silicon_Labs_CP2102_USB_to_UART_Bridge_Controller_0001-if00-port0)
    

O ESP8266 foi encontrado em `/dev/ttyUSB0`. Podemos tentar acessar o terminal lua:

    $ nodemcu-tool --port=/dev/ttyUSB0 terminal

## Clonar repositório:

$ git clone https://github.com/smarcelobr/relogioBPICM.git

## NODEMCU Firmware

- Código fonte (release) do firmware nodemcu para ESP8266:
      https://github.com/nodemcu/nodemcu-firmware/tree/release

- Documentação do nodemcu: 
      https://nodemcu.readthedocs.io

### Building a firmware

Documentação com opções para construir o firmware:
   https://nodemcu.readthedocs.io/en/release/build/

Usando **Cloud Build Service**

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

### Writing the firmware

Para gravar o firmware:

Ferramenta:  https://github.com/espressif/esptool

comando:

    esptool.py --port <serial-port-of-ESP8266> write_flash -fm <flash-mode> 0x00000 <nodemcu-firmware>.bin

exemplo: (Powershell NATALENE)

    cd .\home\sergio\IdeaProjects\LedMatrixPanel\firmware\
    esptool.py --port COM3 write_flash -fm dio 0x00000 nodemcu-release-16-modules-2021-04-01-00-52-53-integer.bin

## Construindo os artefatos LUA:

Execute o script build.sh no Ubuntu.

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


## Uploading para ESP8266

Execute o script 'upload.ps1' no powershell, ou:

    cd /mnt/c/Users/smarc/CLionProjects/LedMatrixPanel/LedMatrix/
    cd out
    nodemcu-tool upload --port=/dev/ttyUSB0 lfs.img *.lua ok.flag


## executando o código novo:

Execute o script 'run.ps1' no powershell, ou:

    nodemcu-tool --port=/dev/ttyUSB0 run reload_LFS.lua
    nodemcu-tool --port=/dev/ttyUSB0 terminal


