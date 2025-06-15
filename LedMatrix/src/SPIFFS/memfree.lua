-- Reinicia o nodemcu com mais memória
if file.exists("ok.flag") then
  if file.exists("not_ok.flag") then file.remove("not_ok.flag") end
  file.rename("ok.flag","not_ok.flag")
end

node.restart()