-- recebe caracteres por um socket e converte em ações do tetris
do
    local srv

    function tetris_session(socket)

        socket:on("receive", function(sck, dataRX)
            local map = {
                [string.byte('a')] = tetris.KEY.LEFT,
                [string.byte('d')] = tetris.KEY.RIGHT,
                [string.byte('w')] = tetris.KEY.UP,
                [string.byte('s')] = tetris.KEY.DOWN,
                [tetris.KEY.LEFT] = tetris.KEY.LEFT,
                [tetris.KEY.RIGHT] = tetris.KEY.RIGHT,
                [tetris.KEY.UP] = tetris.KEY.UP,
                [tetris.KEY.DOWN] = tetris.KEY.DOWN,
                [tetris.KEY.PLUS] = tetris.KEY.PLUS,
                [tetris.KEY.MINUS] = tetris.KEY.MINUS,
                [tetris.KEY.ESC] = tetris.KEY.ESC
            }
            local num = string.byte(string.lower(dataRX))
            if map[num] then
                tetris.doAction(map[num])
            else
                if num == tetris.KEY.SPACE then
                    tetris.start()
                end
            end
        end)

        socket:send("TETRIS!\r\n")
    end

    function ledMatrix_session(sck, dataRX)

    end

    -- TCP e timeout de 10 minutos (600 seg) para desconectar o cliente se inativo.
    srv = net.createServer(net.TCP, 600)
    srv:listen(12010, tetris_session)
    --srv:listen(12011, ledMatrix_session)

end
