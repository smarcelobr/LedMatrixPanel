---
--- Baseado no código em https://codeincomplete.com/articles/javascript-tetris/
---
---
local ledPanel = require("led_panel")

tetris = {}

do
    --- CONSTANTES
    local KEY = {
        ESC = 27,
        SPACE = 32,
        LEFT = 37,
        UP = 38,
        RIGHT = 39,
        DOWN = 40,
        PLUS = string.byte('+'),
        MINUS = string.byte('-')
    }

    local DIR = { UP = 1, RIGHT = 2, DOWN = 3, LEFT = 4, MIN = 1, MAX = 4 }
    local speed = { start = 600, decrement = 5, min = 100 } -- milliseconds until current piece drops 1 row
    local nx = 10 -- width of tetris court (in blocks)
    local ny = 20 -- height of tetris court (in blocks)
    local eachCONTINUE = 1
    local eachBREAK = 2

    --- CORES
    local cyan = { 0, 255, 255 }
    local blue = { 0, 0, 255 }
    local orange = { 255, 131, 0 }
    local yellow = { 255, 255, 0 }
    local green = { 0, 80, 0 }
    local purple = { 128, 0, 128 }
    local red = { 255, 0, 0 }

    -- peças e suas rotações
    --[[ Cada ponto da peça/direção é definida com um número de 16 bits (4 colunas x 4 linhas)
         peça I
           UP     RIGHT   DOWN    LEFT
          0000    0010    0000    0100
          1111    0010    0000    0100
          0000    0010    1111    0100
          0000    0010    0000    0100
         ======= ======= ======= =======
         0x0f00  0x2222  0x00f0  0x4444

         peça J
           UP     RIGHT   DOWN    LEFT
          0100    1000    0110    0000
          0100    1110    0010    1110
          1100    0000    0010    0010
          0000    0000    0000    0000
         ======= ======= ======= =======
         0x44C0  0x8E00  0x6440  0x0E20
    --]]
    local i = { name = 'i', blocks = { 0x0F00, 0x2222, 0x00F0, 0x4444 }, color = cyan };
    local j = { name = 'j', blocks = { 0x44C0, 0x8E00, 0x6440, 0x0E20 }, color = blue };
    local l = { name = 'l', blocks = { 0x4460, 0x0E80, 0xC440, 0x2E00 }, color = orange };
    local o = { name = 'o', blocks = { 0xCC00, 0xCC00, 0xCC00, 0xCC00 }, color = yellow };
    local s = { name = 's', blocks = { 0x06C0, 0x8C40, 0x6C00, 0x4620 }, color = green };
    local t = { name = 't', blocks = { 0x0E40, 0x4C40, 0x4E00, 0x4640 }, color = purple };
    local z = { name = 'z', blocks = { 0x0C60, 0x4C80, 0xC600, 0x2640 }, color = red };

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
    local brilho = { current = 10, max = 10, min = 1 }

    local invalidate = false -- indica se o desenho da tela precisa ser feito

    -- Mapa de teclas e ações
    local actionMap = {
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
        [KEY.MINUS] = function()
            brilho.current = math.max(brilho.min, brilho.current - 1)
        end,
        [KEY.PLUS] = function()
            brilho.current = math.min(brilho.max, brilho.current + 1)
        end,
    }

    function initStage()
        -- inicia a matrix que representa o que está em cada bloco da área do jogo
        for i = 1, nx do
            blocks[i] = {}     -- create a new row
            for j = 1, ny do
                blocks[i][j] = nil -- indica que não tem bloco nessa posicao
            end
        end
        invalidate = true -- precisa atualizar a tela.
    end

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
                if fn(x + col, y + row) == eachBREAK then
                    break
                end
            end
            col = col + 1
            if (col == 4) then
                col = 0
                row = row + 1
            end

            b = bit.rshift(b, 1)
        end

    end

    function drawPiece(type, x, y, dir)
        eachblock(type, x, y, dir, function(x, y)
            ledPanel.setPixel(x, y, type.color)
            return eachCONTINUE
        end)
    end

    function draw()
        ledPanel.apagaBuffer();
        if (playing and current) then
            drawPiece(current.type, current.x, current.y, current.dir)
        end
        local x, y, block
        for y = 1, ny do
            for x = 1, nx do
                block = getBlock(x, y)
                if block then
                    ledPanel.setPixel(x, y, block.color)
                end
            end
        end

        ledPanel.setBrilho((brilho.max + 1) - brilho.current)
        ledPanel.draw()
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

    function occupiedBlock(x, y)
        return (x <= 0) or (x > nx) or (y <= 0) or (y > ny) or getBlock(x, y)
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
            if occupiedBlock(x,y) then
                result = true
                return eachBREAK
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
        -- Para evitar que algumas peças apareçam apenas na segunda linha do tetris,
        -- testo se a primeira linha da peça não é vazia para começar da linha 1 senão 0.
        return { type = type, dir = DIR.UP, x = 3, y = (bit.band(0xf000,type.blocks[DIR.UP])>0) and 1 or 0 };
    end

    function dropPiece()
        if current then
            eachblock(current.type, current.x, current.y, current.dir, function(x, y)
                setBlock(x, y, current.type)
                return eachCONTINUE
            end)
        end
    end

    -- ocupa o que der da peça nas partes não ocupadas.
    function dropPartOfPiece()
        if current then
            eachblock(current.type, current.x, current.y, current.dir, function(x, y)
                if not occupiedBlock(x, y) then
                   setBlock(x, y, current.type)
                end
                return eachCONTINUE
            end)
        end
    end

    function removeLines()
        local complete, n = true, 0
        local y = ny
        while y >= 1 do
            complete = true
            for x = 1, nx do
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
            addScore(100 * 2 ^ (n - 1)) -- 1: 100, 2: 200, 3: 400, 4: 800
        end
    end

    function removeLine(n)
        for y = n, 1, -1 do
            for x = 1, nx do
                if y == 1 then
                    -- primeira linha fica vazia.
                    setBlock(x, y, nil)
                else
                    -- copia os blocos da linha anterior para a linha eliminada
                    setBlock(x, y, getBlock(x, y - 1))
                end
            end
        end
    end

    -- posiciona a peça corrente uma linha/coluna para a direção especificada.
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
        if not current then
            return false
        end

        local newdir = current.dir + 1
        if current.dir == DIR.MAX then
            newdir = DIR.MIN
        end

        if (unoccupied(current.type, current.x, current.y, newdir)) then
            current.dir = newdir
            invalidate = true
            return true
        else
            return false
        end
    end

    function lose()
        print('perdeu!')
        tetris.stop()
    end

    -- desce a peça corrente uma posição e
    -- se não conseguir descer,
    -- ocupa o lugar definitivo da peça no tetris.
    function drop()
        if (not move(DIR.DOWN)) then -- a peça atual não desce mais?
            addScore(10) -- ganha 10 pontos
            dropPiece() -- ocupa a peça no seu lugar definitivo
            removeLines() -- remove as linhas completas
            setCurrentPiece(next) -- a próxima peça vira a corrente
            setNextPiece(randomPiece()) -- sorteia uma próxima peça.
            if (occupied(current.type, current.x, current.y, current.dir)) then
                -- Se não houver espaço para a nova peça corrente, perdeu!
                -- ocupa parte dela no tetris para mostrar que não há espaço
                dropPartOfPiece()
                -- perdeu!
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
        current = nil
        playing = false
    end

    -- callback do fifo:dequeue
    function handle(action)
        actionMap[action]()

        return nil, false
    end

    --[[
    @param action KEY.*
    --]]
    tetris.doAction = function(action)
        actions:queue(action)
    end

    -- chamado no GAME LOOP
    -- idt são os milisegundos que passou desde a ultima chamada
    -- dt acumula os milisegundos decorridos e o step é quando a
    -- tela precisa ser atualizada em milisegundos.
    function update(idt)
        actions:dequeue(handle)
        if (playing) then
            dt = dt + idt
            if (dt > step) then
                dt = dt - step
                node.task.post(node.task.MEDIUM_PRIORITY, function()
                    chamar(drop())
                end)
            end
        end
    end

    -- GAME LOOP
    local now
    local last = (tmr.now() / 1000)

    function frame(loopTimer)
        -- tmr.now() retorna um contador em microsegundos (reset após 31 bits).
        now = (tmr.now() / 1000)
        chamar(update(now - last), function()
            loopTimer:stop()
        end)

        if invalidate then
            invalidate = false
            node.task.post(node.task.MEDIUM_PRIORITY,
                    function()
                        chamar(draw(), function()
                            loopTimer:stop()
                        end)
                    end)
        end
        last = now
    end

    -- executa a atualização do frame a cada 90 milisegundos
    if not tmr.create():alarm(90, tmr.ALARM_AUTO, frame) then
        print("deu ruim!")
    end

    -- expõe as KEYs para o tetris_server.
    tetris.KEY = KEY
    require("tetris_server")

    function tetris.printStage()
        local linha, block
        print('----------')
        for y = 1, ny do
            linha = ""
            for x = 1, nx do
                block = getBlock(x, y)
                if block and (block.color[1] > 0 or block.color[2] > 0 or block.color[3] > 0) then
                    linha = linha .. 'X'
                else
                    linha = linha .. ' '
                end
            end
            print(linha)
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
            print('current', current.x, current.y, current.dir, current.type.name)
        end
        if next then
            print('next', next.x, next.y, next.dir, next.type.name)
        end
        local rndPiece = randomPiece()
        if rndPiece then
            print('rnd', rndPiece.x, rndPiece.y, rndPiece.dir, rndPiece.type.name)
        end
    end
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
