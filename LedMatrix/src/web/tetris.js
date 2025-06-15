function mostrarProximaPeca(tipo) {
    const template = document.getElementById(`peca-${tipo}`);
    const proximaPeca = document.querySelector('#next-piece-img');
    const clone = template.content.cloneNode(true);
    // Limpar SVG anterior
    const svgAntigo = proximaPeca.querySelector('svg');
    if (svgAntigo) svgAntigo.remove();
    // Adicionar nova peça
    proximaPeca.insertBefore(clone, proximaPeca.firstChild);
}

document.addEventListener('DOMContentLoaded', () => {
    mostrarProximaPeca('t');
});

