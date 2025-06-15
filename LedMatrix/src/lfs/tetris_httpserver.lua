-- Módulo que serve requisições HTTP
-- Árvore de dependências
 -- httpserver.lua (Lua Module)
 --     net (C module)
 --     fifosock.lua (Lua Module)
 --         fifo.lua (Lua Module)
require("httpserver").createServer(80, function(req, res)
  -- analyse method and url
  print("+R", req.method, req.url, node.heap())

  if req.url=="/" then
    req.filename = "index"
  else
    req.filename = string.sub(req.url, 2) -- elimina a '/' inicial
  end
  req.file_exists = file.exists(req.filename..".html.gz")
  req.accept_text_html = false
  req.accept_enc_gzip = false
  req.accept_json = false

  -- setup handler of headers, if any
  req.onheader = function(self, name, value) -- luacheck: ignore
    print("+H", name, value)

    if name == "accept" then
      if string.find(value, "*/*") or string.find(value, "text/html") then
        req.accept_text_html = true
      end
      if string.find(value, "application/json") then
        req.accept_text_json = true
      end
    elseif name == "accept-encoding" then
        if string.find(value, "gzip") then
            req.accept_enc_gzip = true
        end
    end

    req.ondata = resolverOndata()

    -- E.g. look for "content-type" header,
    --   setup body parser to particular format
    -- if name == "content-type" then
    --   if value == "application/json" then
    --     req.ondata = function(self, chunk) ... end
    --   elseif value == "application/x-www-form-urlencoded" then
    --     req.ondata = function(self, chunk) ... end
    --   end
    -- end
  end

  function resolverOndata()
      if req.accept_text_html and req.method == 'GET' then
          if req.file_exists then
            return req.get_html_file
          end
      elseif req.accept_json then
          return req.helloword
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

  req.get_html_file = function(self, chunk)
      if not chunk then
        res:send(nil, 200)
        res:send_header("Connection", "close")
        res:send_header("Content-Type", "text/html")
        res:send_header("Content-Encoding", "gzip")
        file.open(req.filename..".html.gz", "r")
        local buf = file.read()
        file.close()
        res:send(buf)
        res:finish()
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

  -- or just do something not waiting till body (if any) comes
  --res:finish("Hello, world!")
  --res:finish("Salut, monde!")
end)