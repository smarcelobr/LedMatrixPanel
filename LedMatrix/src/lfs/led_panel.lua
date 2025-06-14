local ledPanel = {}

do
    ws2812.init(ws2812.MODE_SINGLE)
    local strip_buffer = ws2812.newBuffer(200, 3)

    function startEffects()
        -- init the effects module, set color to red and start blinking
        ws2812_effects.init(strip_buffer)
        ws2812_effects.set_speed(100)
        ws2812_effects.set_brightness(50)
        ws2812_effects.set_color(0,255,0)
        ws2812_effects.set_mode("circus_combustus")
        ws2812_effects.start()
    end

    function stopEffects()
        ws2812_effects.stop()
        apaga()
    end

    -- Converte uma posicao (x,y) pelo número do LED na fita.
    -- Intervalos permitidos: 1<=x<=nx e 1<=y<=ny
    --
    -- (x,y) -> número do LED
    -- (1,1) -> 0 + 1 = 1
    -- (1,20) -> 0 + 20 = 20
    -- (2,20) -> 20 -(20-21) = 20 -(-1) = 20+1 = 21
    -- (2,1) -> 20 -(1-21) = 20 -(-20) = 20+20 = 40
    function calcStripIndex(x, y)
        local index
        if (x % 2)==0 then
            index = ((x-1)*20)-(y-21)
        else
            index = ((x-1)*20)+y
        end
        return index
    end

    -- Altera a cor de um pixel, apenas no buffer.
    -- Sem desenha na tela.
    function ledPanel.setPixel(x, y, color)
        strip_buffer:set(calcStripIndex(x, y), color);
    end

    -- Apaga o buffer para fazer uma imagem
    -- esta função não atualiza a cor do led no panel
    function ledPanel.apagaBuffer()
        strip_buffer:fill(0, 0, 0)
    end

    -- pega toda a informação do buffer e manda para o painel de LEDs
    function ledPanel.draw()
        ws2812.write(strip_buffer)
    end

    -- apaga o painel imediatamente.
    function ledPanel.apaga()
        apagaBuffer()
        ws2812.write(strip_buffer)
    end

    function ledPanel.setBrilho(brilho)
        strip_buffer:fade(brilho)
    end


    function ledPanel.printBuffer()
        local linha, r, g, b
        print('----------')
        for y = 1, ny do
            linha = ""
            for x = 1, nx do
                r, g, b = strip_buffer:get(calcStripIndex(x, y))
                if r > 0 or g > 0 or b > 0 then
                    linha = linha .. 'X'
                else
                    linha = linha .. ' '
                end
            end
            print(linha)
        end
        print('==========')
    end

end

return ledPanel;