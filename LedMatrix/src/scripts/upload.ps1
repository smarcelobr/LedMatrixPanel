Write-Host "Carregando arquivos para o ESP8266..."

Set-Location -Path //wsl$/Ubuntu/home/sergio/IdeaProjects/LedMatrixPanel/LedMatrix/out

nodemcu-tool upload --port=COM3 lfs.img *.lua ok.flag

Set-Location -Path //wsl$/Ubuntu/home/sergio/IdeaProjects/LedMatrixPanel/LedMatrix/src/scripts