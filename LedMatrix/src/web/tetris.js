let ws; // variável para armazenar a conexão WebSocket

const pecas = ['t', 'i', 'j', 'l', 's', 'z', 'o'];

async function carregarSVG(tipo) {
    try {
        const resposta = await fetch(`/pecas/peca-${tipo}.svg`);
        if (!resposta.ok) {
            throw new Error(`Erro ao carregar SVG: ${resposta.status}`);
        }
        const svgText = await resposta.text();
        return svgText;
    } catch (erro) {
        console.error(`Erro ao carregar peça ${tipo}:`, erro);
        return null;
    }
}

// Função para exibir uma peça no elemento next-piece-img
async function mostrarProximaPeca(tipo) {
    const nextPieceElement = document.getElementById('next-piece-img');
    const svgContent = await carregarSVG(tipo);
    if (svgContent) {
        nextPieceElement.innerHTML = svgContent;
    }
}

function atualizarScore(score) {
    document.querySelector('.score').textContent = `Score: ${score}`;
}

function iniciarWebSocket() {
    // Criar conexão WebSocket na mesma origem
    const protocolo = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
    const host = window.location.host;
    ws = new WebSocket(`${protocolo}//${host}/game`);

    ws.onopen = () => {
        console.log('Conexão WebSocket estabelecida');
    };

    ws.onmessage = (event) => {
        // Processar mensagens recebidas do servidor
        const data = JSON.parse(event.data);
        if (data.proximaPeca) {
            mostrarProximaPeca(data.proximaPeca);
        }
        if (data.score !== undefined) {
            atualizarScore(data.score);
        }
    };

    ws.onclose = () => {
        console.log('Conexão WebSocket fechada');
        // Tentar reconectar após 5 segundos
        setTimeout(iniciarWebSocket, 5000);
    };

    ws.onerror = (error) => {
        console.error('Erro na conexão WebSocket:', error);
    };
}

function enviarAcao(acao) {
    if (ws && ws.readyState === WebSocket.OPEN) {
        ws.send(acao);
    }
}

document.addEventListener('DOMContentLoaded', () => {
    // Iniciar conexão WebSocket
    iniciarWebSocket();

    // Configurar listeners para os botões
    const botoes = document.querySelectorAll('.directional-pad .round-button');
    botoes.forEach(botao => {
        botao.addEventListener('click', (e) => {
            const direcao = e.currentTarget.querySelector('path').getAttribute('d');
            
            // Identificar a ação baseada no path do SVG
            let acao;
            switch (direcao) {
                case 'M7 14l5-5 5 5z':
                    acao = 'up';
                    break;
                case 'M7 10l5 5 5-5z':
                    acao = 'down';
                    break;
                case 'M15 19l-5-5 5-5z':
                    acao = 'left';
                    break;
                case 'M9 19l5-5-5-5z':
                    acao = 'right';
                    break;
            }

            if (acao) {
                enviarAcao(acao);
            }
        });
    });

    // Configurar listener para o botão de rotação
    const botaoRotacao = document.querySelector('.float-end .round-button');
    botaoRotacao.addEventListener('click', () => {
        enviarAcao('rotate');
    });
});