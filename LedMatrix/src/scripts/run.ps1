Write-Host "Executando no ESP8266..."

# Set-Location -Path //wsl$/Ubuntu/home/sergio/IdeaProjects/LedMatrixPanel/LedMatrix/out

nodemcu-tool --port=COM3 run reload_LFS.lua
nodemcu-tool --port=COM3 terminal