# Terminal do NODEMCU

Remove o arquivo ok.flag:

    file.remove("ok.flag")

Lista os arquivos do SPIFFS

    l = file.list();
    for k,v in pairs(l) do
      print("name:"..k..",".."size:"..v)
    end