let ws; // variável para armazenar a conexão WebSocket

const pecas = ['t', 'i', 'j', 'l', 's', 'z', 'o'];

async function carregarSVG(tipo) {
    try {
        const resposta = await fetch(`/peca-${tipo}.svg`);
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

function apagarProximaPeca() {
    const nextPieceElement = document.getElementById('next-piece-img');
    nextPieceElement.innerHTML = '';
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
        if (data.next_piece) {
            mostrarProximaPeca(data.next_piece);
        } else {
            apagarProximaPeca();
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
    const botoes = document.querySelectorAll('.controls button');
    botoes.forEach(botao => {
        botao.addEventListener('click', (e) => {
            const acao = e.currentTarget.id;

            // Validar se a ação é válida
            if (['up', 'down', 'left', 'right', 'start'].includes(acao)) {
                enviarAcao(acao);
            }
        });
    });

});