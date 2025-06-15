-- Módulo que serve requisições HTTP.
 --
 -- Árvore de dependências
 -- httpserver.lua (Lua Module)
 --     net (C module)
 --     fifosock.lua (Lua Module)
 --         fifo.lua (Lua Module)
 --
 -- * Connection: close *
 -- Todas as respostas devem conter no header
 -- Connection: close
 -- que indica um Short-lived Connection, ou seja, avisa ao browser para serializar
 -- as chamadas, afinal, o ESP-12 não tem memória suficiente para lidar com múltiplas
 -- conexões simultâneas.
 -- ref.: https://developer.mozilla.org/en-US/docs/Web/HTTP/Guides/Connection_management_in_HTTP_1.x#short-lived_connections
 --
local contentTypeMap = {
      html = "text/html",
      css = "text/css",
      js = "application/javascript",
--      png = "image/png",
--      jpg = "image/jpeg",
--      jpeg = "image/jpeg",
--      gif = "image/gif",
--      ico = "image/x-icon",
      json = "application/json",
      svg = "image/svg+xml"
}

require("httpserver").createServer(80, function(req, res)
  -- analyse method and url
  print("+R", req.method, req.url, node.heap())

  if req.url=="/" then
    req.filename = "index.html"
  else
    req.filename = string.sub(req.url, 2) -- elimina a '/' inicial
  end
  req.fileext = string.match(req.filename, "%.([^%.]+)$") or nil
  req.accept_enc_gzip = false
  req.accept_json = false
  req.websocket = false

  -- setup handler of headers, if any
  req.onheader = function(self, name, value) -- luacheck: ignore
    print("+H", name, value)

    if name == "accept" then
      if string.find(value, "application/json") then
        req.accept_json = true
      end
    elseif name == "accept-encoding" then
        if string.find(value, "gzip") then
            req.accept_enc_gzip = true
        end
    elseif name == "upgrade" and value == "websocket" then
        req.websocket = true
    end

    req.ondata = resolverOndata()
  end

  function resolverOndata()
      if req.method == 'GET' then
          if req.accept_enc_gzip and file.exists(req.filename..".gz") then
            return req.get_gzip_file
          end
      elseif req.accept_json then
          return req.helloword
      elseif req.url == '/game' and req.websocket then
          return req.websocket_game
      end
      return req.not_found
  end

  -- setup handler do helloword

  req.helloword = function(self, chunk) -- luacheck: ignore
    print("+B", chunk and #chunk, node.heap())
    if not chunk then
      -- reply
      res:send(nil, 200)
      res:send_header("Connection", "close")
      res:send_header("Content-Type", "application/json")
      res:send("{\"msg\":\"Hello, world!\"}\n")
      res:finish()
    end
  end

  req.get_gzip_file = function(self, chunk)

      res.step_cancela_envio = function()
          node.task.post(node.task.MEDIUM_PRIORITY, function()
              chamar(res.step_finaliza)
          end)
      end

      res.step_envia_cabecalho = function()
         res:send(nil, 200)
         res:send_header("Connection", "close")
         res:send_header("Content-Type", contentTypeMap[req.fileext] or "application/octet-stream")
         res:send_header("Content-Encoding", "gzip")
         node.task.post(node.task.MEDIUM_PRIORITY, function()
             chamar(res.step_envia_conteudo, res.step_cancela_envio)
         end)
      end

      res.step_envia_conteudo = function()
         local buf = res.fd:read() -- lê até 1KB por vez (FILE_READ_CHUNK=1024)
         if buf then
            res:send(buf) -- envia um chunk
            node.task.post(node.task.MEDIUM_PRIORITY, function()
              chamar(res.step_envia_conteudo, res.step_cancela_envio)
            end)
         else
            node.task.post(node.task.MEDIUM_PRIORITY, function()
              chamar(res.step_finaliza)
            end)
         end -- se nil, é EOF.
      end

      res.step_finaliza = function()
          if res.fd then
             res.fd:close()
          end
          res:finish()
      end

      if not chunk then
        res.fd = file.open(req.filename..".gz", "r")

        if res.fd then
            -- divide o envio do arquivo em várias chamadas
            node.task.post(node.task.MEDIUM_PRIORITY, function()
                  chamar(res.step_envia_cabecalho, res.step_cancela_envio)
            end)
        else
            res:send(nil, 500)
            res:send_header("Connection", "close")
            res:send_header("Content-Type", "text/plain")
            res:send("Erro ao abrir arquivo "..req.filename)
            res:finish()
        end

      end
  end

  req.not_found = function(self, chunk)
      if not chunk then
          res:send(nil, 404)
          res:send_header("Connection", "close")
          res:send_header("Content-Type", "text/html")
          res:send("<html><head><title>tetris</title></head><body><p>Nao encontrado.</p></body></html>\n")
          res:finish()
      end
  end

  req.websocket_game = function(self, chunk)

  end
end)