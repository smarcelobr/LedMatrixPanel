# Terminal do NODEMCU

### Remove o arquivo ok.flag:

    if file.exists("ok.flag") then if file.exists("not_ok.flag") then file.remove("not_ok.flag") end file.rename("ok.flag","not_ok.flag") end

### Lista os arquivos do SPIFFS

    l = file.list()
    for k,v in pairs(l) do
      print("name:"..k..",".."size:"..v)
    end

Versão comprimida:

    l = file.list() for k,v in pairs(l) do print("name:"..k..",".."size:"..v) end

Resultado:

    name:init.lua,size:2032
    name:lfs.img,size:17380
    name:reload_LFS.lua,size:113
    name:ok.flag,size:3
    name:config.json,size:86
    name:teste.lua,size:637

### Consulta o tamanho do SPIFFS e do LFS:

    do
        local s,p={},node.getpartitiontable()
        for _,k in ipairs{'lfs_addr','lfs_size','spiffs_addr','spiffs_size'} do
            s[#s+1] ='%s = 0x%06x' % {k, p[k]}
        end
        print ('{ %s }' % table.concat(s,', '))
    end
    
Resultado esperado:

    { lfs_addr = 0x09e000, lfs_size = 0x010000, spiffs_addr = 0x0ae000, spiffs_size = 0x04f000 }