---
--- Baseado no código em https://codeincomplete.com/articles/javascript-tetris/
---
---
ws2812.init(ws2812.MODE_SINGLE)
-- create a buffer, 60 LEDs with 3 color bytes
tetris = {}

do
    --- CONSTANTES
    local KEY = { ESC = 27, SPACE = 32, LEFT = 37, UP = 38, RIGHT = 39, DOWN = 40,
         PLUS= string.byte('+'),
         MINUS= string.byte('-')
    }
    local DIR = { UP = 1, RIGHT = 2, DOWN = 3, LEFT = 4, MIN = 1, MAX = 4 }
    local speed = { start = 600, decrement = 5, min = 100 } -- milliseconds until current piece drops 1 row
    local nx = 10 -- width of tetris court (in blocks)
    local ny = 20 -- height of tetris court (in blocks)

    --- CORES
    local cyan = { 0, 255, 255 }
    local blue = { 0, 0, 255 }
    local orange = { 255, 131, 0 }
    local yellow = { 255, 255, 0 }
    local green = { 0, 80, 0 }
    local purple = { 128, 0, 128 }
    local red = { 255, 0, 0 }

    -- peças e suas rotações
    local i = {name='i', blocks = { 0x0F00, 0x2222, 0x00F0, 0x4444 }, color = cyan };
    local j = {name='j', blocks = { 0x44C0, 0x8E00, 0x6440, 0x0E20 }, color = blue };
    local l = {name='l', blocks = { 0x4460, 0x0E80, 0xC440, 0x2E00 }, color = orange };
    local o = {name='o', blocks = { 0xCC00, 0xCC00, 0xCC00, 0xCC00 }, color = yellow };
    local s = {name='s', blocks = { 0x06C0, 0x8C40, 0x6C00, 0x4620 }, color = green };
    local t = {name='t', blocks = { 0x0E40, 0x4C40, 0x4E00, 0x4640 }, color = purple };
    local z = {name='z', blocks = { 0x0C60, 0x4C80, 0xC600, 0x2640 }, color = red };

    --- VARIAVEIS
    local next -- the next piece
    local rows = 0 -- number of completed rows in the current game
    local current = nil -- the current piece
    local dt = 0 -- time since starting this game
    local playing = false -- true|false - game is in progress
    local step = 1000 -- how long (ms) before current piece drops by 1 row
    local score = 0 -- the current score
    local actions = (require "fifo").new() -- queue of user actions (inputs)
    local blocks = {} -- 2 dimensional array (nx*ny) representing tetris court - either empty block or occupied by a 'piece'
    local brilho = {current= 10, max=10, min=1}

    local invalidate = false -- indica se o desenho da tela precisa ser feito

    function initStage()
        -- inicia a matrix que representa o que está em cada bloco da área do jogo
        for i=1,nx do
            blocks[i] = {}     -- create a new row
            for j=1,ny do
                blocks[i][j] = nil -- indica que não tem bloco nessa posicao
            end
        end
        invalidate = true -- precisa atualizar a tela.
    end

    local strip_buffer = ws2812.newBuffer(200, 3)

    --[[
    We can then provide a helper method that given:

    one of the pieces above
    a rotation direction (0-3)
    a location on the tetris grid
    … will iterate over all of the cells in the tetris grid that the piece will occupy:
    --]]
    function eachblock(type, x, y, dir, fn)
        local result, row, col, blcks = nil, 0, 0, type.blocks[dir]
        local b

        local b = 0x8000
        while b > 0 do

            if bit.band(blcks, b) > 0 then
                fn(x + col, y + row)
            end
            col = col + 1
            if (col == 4) then
                col = 0
                row = row + 1
            end

            b = bit.rshift(b, 1)
        end

    end

    function calcStripIndex(x, y)
        local index
        if (x % 2)==0 then
            index = ((x-1)*20)-(y-21)
        else
            index = ((x-1)*20)+y
        end
        return index
    end

    function drawBlock(x, y, color)
        strip_buffer:set(calcStripIndex(x,y), color);
    end

    function drawPiece(type, x, y, dir)
        eachblock(type, x, y, dir, function(x, y)
            drawBlock(x, y, type.color)
        end)
    end

    function draw()
        -- apaga tudo:
        strip_buffer:fill(0, 0, 0)
        if (playing and current) then
            drawPiece(current.type, current.x, current.y, current.dir)
        end
        local x, y, block
        for y = 1,ny do
            for x = 1,nx do
                block = getBlock(x, y)
                if block then
                    drawBlock(x, y, block.color)
                end
            end
        end

        strip_buffer:fade((brilho.max+1) - brilho.current)
        ws2812.write(strip_buffer)
    end

    function setScore(n)
        score = n
        --invalidateScore()
    end

    function addScore(n)
        score = score + n
    end

    function setRows(n)
        rows = n

        step = math.max(speed.min, speed.start - (speed.decrement * rows))
        --invalidateRows()
    end

    function addRows(n)
        setRows(rows + n)
    end

    function getBlock(x, y)
        if blocks and blocks[x] then
            return blocks[x][y]
        else
            return nil
        end
    end

    function setBlock(x, y, type)
        blocks[x] = blocks[x] or {};
        blocks[x][y] = type;
        invalidate = true
    end

    function setCurrentPiece(piece)
        current = piece or randomPiece();
        invalidate = true
    end

    function setNextPiece(piece)
        next = piece or randomPiece();
        --invalidateNext()
    end

    --[[
    Valid Piece Positioning
    We need to be careful about our bounds checking when
    sliding a piece left and right, or dropping it down a row.
    We can build on our eachblock helper to provide an
    occupied method that returns true if any of the blocks
    required to place a piece at a position on the tetris grid,
    with a particular rotation direction, would be occupied
    or out of bounds:
    --]]
    function occupied(type, x, y, dir)
        local result = false
        eachblock(type, x, y, dir, function(x, y)
            if ((x <= 0) or (x > nx) or (y <= 0) or (y > ny) or getBlock(x, y)) then
                result = true;
            end
        end)
        return result;
    end

    function unoccupied(type, x, y, dir)
        return not occupied(type, x, y, dir);
    end

    local pieces = {};
    function randomPiece()
        if (#pieces == 0) then
            pieces = { i, i, i, i, j, j, j, j, l, l, l, l, o, o, o, o, s, s, s, s, t, t, t, t, z, z, z, z }
        end
        local idx = math.random(#pieces)
        local type = table.remove(pieces, idx) -- remove a single piece
        return { type = type, dir = DIR.UP, x = 3, y = 1 };
    end

    function dropPiece()
        if current then
            eachblock(current.type, current.x, current.y, current.dir, function(x, y)
                setBlock(x, y, current.type)
            end)
        end
    end

    function removeLines()
       local complete, n = true, 0
       local y = ny
       while y >= 1 do
          complete = true
          for x = 1,nx do
            if not getBlock(x, y) then
               complete = false
               break
            end
          end -- for da coluna
          if complete then
             removeLine(y)
             y = y + 1 -- recheck same line
             n = n + 1
          end
          y = y - 1
       end -- while da linha
       if n > 0 then
         addRows(n)
         addScore( 100 * 2^(n-1) ) -- 1: 100, 2: 200, 3: 400, 4: 800
       end
    end

    function removeLine(n)
       for y = n, 1, -1 do
          for x = 1, nx do
             if y == 1 then
                setBlock(x, y, nil)
             else
                setBlock(x, y, getBlock(x, y-1) )
             end
          end
       end
    end

    function move(dir)
        if not current then
           return false
        end
        local x, y = current.x, current.y
        local switch = {
            [DIR.RIGHT] = function()
                x = x + 1
            end,
            [DIR.LEFT] = function()
                x = x - 1
            end,
            [DIR.DOWN] = function()
                y = y + 1
            end
        }
        switch[dir]()

        if (unoccupied(current.type, x, y, current.dir)) then
            current.x = x
            current.y = y
            invalidate = true
            return true
        else
            return false
        end
    end

    function rotate(dir)
        local newdir = current.dir + 1
        if current.dir == DIR.MAX then
            newdir = DIR.MIN
        end
        if (unoccupied(current.type, current.x, current.y, newdir)) then
            current.dir = newdir
            invalidate = true
        end
    end

    function lose()
        print('perdeu!');
        playing = false
    end

    function drop()
        if (not move(DIR.DOWN)) then
            addScore(10)
            dropPiece()
            removeLines()
            setCurrentPiece(next)
            setNextPiece(randomPiece())
            if (occupied(current.type, current.x, current.y, current.dir)) then
                lose()
            end
        end
    end

    function tetris.start()
        rows = 0
        next = nil
        current = nil -- the current piece
        dt = 0 -- time since starting this game
        playing = false -- true|false - game is in progress
        step = speed.start -- how long (ms) before current piece drops by 1 row
        score = 0
        initStage()
        last = (tmr.now() / 1000) -- em milliseconds
        playing = true
    end

    function tetris.stop()
        playing = false
    end

    -- callback do fifo:dequeue
    function handle(action)
        local switch = {
            [KEY.LEFT] = function()
                move(DIR.LEFT)
            end,
            [KEY.RIGHT] = function()
                move(DIR.RIGHT)
            end,
            [KEY.UP] = function()
                rotate()
            end,
            [KEY.DOWN] = function()
                drop()
            end,
            [KEY.ESC] = function()
                lose()
            end,
            [KEY.SPACE] = function()
                tetris.start()
            end,
            [KEY.MINUS] = function ()
                brilho.current = math.max(brilho.min, brilho.current - 1)
            end,
            [KEY.PLUS] = function ()
                brilho.current = math.min(brilho.max, brilho.current + 1)
            end,
        }

        switch[action]()

        return nil, false
    end

    -- chamado no GAME LOOP
    function update(idt)
        if (playing) then
            actions:dequeue(handle)
            dt = dt + idt
            if (dt > step) then
                dt = dt - step
                node.task.post(node.task.MEDIUM_PRIORITY, function() chamar(drop()) end )
            end
        end
    end

    -- GAME LOOP
    local now
    local last = (tmr.now() / 1000)

    function frame(loopTimer)
        now = (tmr.now() / 1000)
        chamar( update(now - last), function() loopTimer:stop() end)

        if invalidate then
           invalidate = false
           node.task.post(node.task.MEDIUM_PRIORITY,
              function()
                chamar(draw(), function() loopTimer:stop() end)
              end )
        end
        last = now
    end

    function tetris.printBuffer()
        local linha, r, g, b
        print('----------')
        for y=1,ny do
          linha = ""
          for x=1,nx do
             r,g,b = strip_buffer:get(calcStripIndex(x,y))
             if r>0 or g>0 or b>0 then
                linha = linha .. 'X'
             else
                linha = linha .. ' '
             end
          end
          print (linha)
        end
        print('==========')
    end

    function tetris.printStage()
        local linha, block
        print('----------')
        for y=1,ny do
          linha = ""
          for x=1,nx do
              block = getBlock(x, y)
              if block and (block.color[1]>0 or block.color[2]>0 or block.color[3]>0) then
                   linha = linha .. 'X'
              else
                   linha = linha .. ' '
              end
          end
          print (linha)
        end
        print('==========')
    end

    function tetris.debug()
       if playing then
          print('playing')
       else
          print('not playing')
       end
       if (current) then
          print('current',current.x, current.y, current.dir, current.type.name)
       end
       if next then
          print('next',next.x, next.y, next.dir, next.type.name)
       end
       local rndPiece = randomPiece()
       if rndPiece then
          print('rnd',rndPiece.x, rndPiece.y, rndPiece.dir, rndPiece.type.name)
       end
    end

    --[[
    @param action DIR.LEFT, DIR.RIGHT, DIR.UP, DIR.DOWN
    --]]
    tetris.doAction = function (action)
       actions:queue(action)
    end

    if not tmr.create():alarm(90, tmr.ALARM_AUTO, frame) then
        print("deu ruim!")
    end

    tetris.KEY = KEY

    require("input_server")
end

tetris.start()

-- shorthands
function l()
  tetris.doAction(tetris.KEY.LEFT)
end

function r()
  tetris.doAction(tetris.KEY.RIGHT)
end

function u()
  tetris.doAction(tetris.KEY.UP)
end

function d()
  tetris.doAction(tetris.KEY.DOWN)
end
