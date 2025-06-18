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
      svg = "image/svg+xml"
--      png = "image/png",
--      jpg = "image/jpeg",
--      jpeg = "image/jpeg",
--      gif = "image/gif",
--      ico = "image/x-icon",
--      json = "application/json",
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
  req.websocket = false

  -- setup handler of headers, if any
  req.onheader = function(self, name, value) -- luacheck: ignore
    print("+H", name, value)

    if name == "accept-encoding" then
        if string.find(value, "gzip") then
            req.accept_enc_gzip = true
        end
    elseif name == "upgrade" and value == "websocket" then
        req.websocket = true
    elseif name == "sec-websocket-key" then
        req.websocket_key = value
    end

    req.ondata = resolverOndata()
  end

  function resolverOndata()
      if req.method == 'GET' then
          if req.accept_enc_gzip and file.exists(req.filename..".gz") then
            return req.get_gzip_file
          elseif req.url == '/game' and req.websocket then
              print("ws")
              return req.game_websocket_handshake_response
          end
      end
      return req.not_found
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

  req.bad_request = function(self, chunk)
      if not chunk then
          res:send(nil, 400)
          res:send_header("Connection", "close")
          res:send_header("Content-Type", "text/html")
          res:send("<html><head><title>tetris</title></head><body><h2>Requisicao invalida</h2><p>"..req.bad_request_msg.."</p></body></html>\n")
          res:finish()
      end
  end

  req.game_websocket_handshake_response = function(self, chunk)

      if not req.websocket_key then
          print("ws:e:1")
        req.bad_request_msg = "sec-websocket-key não informado."
        req.bad_request(self, chunk)
        return
      end

      res.step_encerra_conn = function()
          -- encerra a conexao
          print("ws:f")
          res.cfini()
      end

      res.send_handshake_response = function()
          --print("ws:h")
        res.csend("HTTP/1.1 101 Switching Protocols\r\n")
        res.csend("Connection: Upgrade\r\n")
        res.csend("Upgrade: websocket\r\n")
        res.csend("Sec-Websocket-Accept: "..
               encoder.toBase64(crypto.hash("sha1",req.websocket_key.."258EAFA5-E914-47DA-95CA-C5AB0DC85B11")) ..
               "\r\n\r\n")
        res.send_handshake_response = nil -- para não enviar o handshake novamente.
      end

      if res.send_handshake_response then
          print("ws:hs")
          -- responde o handshake
          node.task.post(node.task.MEDIUM_PRIORITY, function()
                            chamar(res.send_handshake_response, res.step_encerra_conn)
                      end)
          -- as próximas chamadas deve ser para decodificar as mensagens
          req.ondata = req.game_decode_message
          tetris.setStateConsumer(req.send_game_state)
          req.ondisconnect = function (self)
                 tetris.setStateConsumer(nil)
                 print("ws:discon")
              end
      end
  end

  req.game_text_message_handler = function(message)
        -- Quando o opcode é 0x1 (text) o payload contem o nome da acao que será passada para o tetris.doAction() da seguinte forma
        -- "up" -> tetris.doAction(tetris.KEY.UP)
        -- "down" -> tetris.doAction(tetris.KEY.DOWN)
        -- "left" -> tetris.doAction(tetris.KEY.LEFT)
        -- "right" -> tetris.doAction(tetris.KEY.RIGHT)
        -- Se a ação não for encontrada, ela é ignorada.

        local actions = {
          up = tetris.KEY.UP,
          down = tetris.KEY.DOWN,
          left = tetris.KEY.LEFT,
          right = tetris.KEY.RIGHT,
          start = tetris.KEY.SPACE
        }

        if actions[message] then
          tetris.doAction(actions[message])
        else
          print('ws:anf') -- action not found
        end
  end

  req.game_close_message_handler = function(message)
      print("ws:close!")
      -- envia um close como resposta ao cliente e fecha a conexão com res.cfini
    res.csend(string.char(0x88))  -- FIN=1, opcode=0x8 (close)
    res.csend(string.char(#message))  -- payload length  
    res.csend(message) -- echo back original payload
    res.cfini() -- close connection
  end

  req.game_ping_message_handler = function(message)
      print("ws:ping!")
      -- responde com o pong (0xA) para o client usando res.csend passando
      -- o 'message' que foi recebido no ping.
      res.csend(string.char(0x8A))  -- FIN=1, opcode=0xA (pong)
      res.csend(string.char(#message))  -- payload length
      res.csend(message) -- echo back original payload
  end
  
  req.game_pong_message_handler = function(message)
      -- quando receber um pong (0xA) do client apenas ignora.
      print("ws:pong!")
  end

  req.game_decode_message = function(self, chunk)
      if not chunk or #chunk==0 then
         return
      end
    -- o handshake já foi respondido. Esta é uma mensagem a ser decodificada.
    -- este implementação aceita apenas mensagens de até 125 caracteres

    -- 0                   1                   2                   3
    --  0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
    -- +-+-+-+-+-------+-+-------------+-------------------------------+
    -- |F|R|R|R| opcode|M| Payload len |          Masking-key          |
    -- |I|S|S|S|  (4)  |A|     (7)     |             (32)              |
    -- |N|V|V|V|       |S|             |                               |
    -- | |1|2|3|       |K|             |                               |
    -- +-+-+-+-+-------+-+-------------+-------------------------------+
    -- |    Masking-key (continued)    |          Payload Data         |
    -- +-------------------------------- - - - - - - - - - - - - - - - +
    -- :                     Payload Data continued ...                :
    -- + - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - +
    -- |                     Payload Data continued ...                |
    -- +---------------------------------------------------------------+

    -- no primeiro byte, espera-se que o bit FIN seja 1.
    -- ignoro os bits RSV1 a RSV3.
    -- no segundo byte, o bit MASK deve ser 1. O payload deve ser menor que 125 caracteres
    -- Os quatro bytes seguintes são o masking-key
    -- Quando o opcode é 0x1 (text), uma ação é enviada para o tetris
    -- Quando o opcode é 0x9 (ping), um pong deve ser respondido
    -- Quando o opcode é 0x8 (Connect Close Frame), a conexão é encerrada.
    
    local byte1 = string.byte(chunk, 1)
    local byte2 = string.byte(chunk, 2)
    
    local fin = bit.rshift(bit.band(byte1, 0x80), 7) == 1
    local opcode = bit.band(byte1, 0x0F)
    local mask = bit.rshift(bit.band(byte2, 0x80), 7) == 1 
    local payload_len = bit.band(byte2, 0x7F)

    if not (fin and mask and payload_len < 125) then
      print("ws:inv.")
      return
    end
    
    local masking_key = {
      string.byte(chunk, 3),
      string.byte(chunk, 4), 
      string.byte(chunk, 5),
      string.byte(chunk, 6)
    }
    
    local decoded = ""
    for i = 1, payload_len do
      local j = (i-1) % 4 + 1
      local encoded_byte = string.byte(chunk, i + 6)
      local decoded_byte = bit.bxor(encoded_byte, masking_key[j])
      decoded = decoded .. string.char(decoded_byte)
    end

    chamar(function() 
        print('opcode=',opcode,' decoded=',decoded)
        if opcode == 0x1 then
            req.game_text_message_handler(decoded)
        elseif opcode == 0x8 then
            req.game_close_message_handler(decoded)
        elseif opcode == 0x9 then
            req.game_ping_message_handler(decoded)
        elseif opcode == 0xA then
            req.game_pong_message_handler(decoded)
        end
    end)

  end

  req.send_game_state = function(state)
        local message = '{'
        local first = true
        for chave, valor in pairs(state) do
          if not first then
              message = message .. ','
          else
              first = false
          end
          message = message .. "\"" .. chave .."\":"
          if type(valor) == "boolean" then
             message = message .. (valor and "true" or "false")
          elseif type(valor) == "number" then
             message = message .. tostring(valor)
          elseif type(valor) == "string" then
             message = message .. "\"" .. valor .. "\""
          else
             message = message .. "null"
          end
        end
        message = message .. "}"

        print(message)

        res.csend(string.char(0x81))  -- FIN=1, opcode=0x1 (text)
        res.csend(string.char(#message))  -- payload length
        res.csend(message) -- echo back original payload
  end

end)