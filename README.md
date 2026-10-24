# Projeto Terror

Jogo de terror em primeira pessoa feito no **Godot 4** (4.4 ou mais novo).
Sem combate: você só pode fugir, se esconder e torcer.

Visual estilo PS1/VHS (baixa resolução, dithering, neblina, granulação),
porque o que você não enxerga direito assusta mais.

## Como abrir

1. Abra o Godot.
2. Clique em **Importar** e escolha o arquivo `project.godot` desta pasta.
3. Espere ele importar os assets (só na primeira vez).
4. Aperte **F5** pra jogar.

## Controles

| Tecla | Ação |
|---|---|
| W A S D | Andar |
| Shift | Correr (gasta fôlego) |
| Ctrl / C | Agachar |
| E / clique esquerdo | Interagir (portas, itens) |
| F / clique direito | Lanterna |
| Esc | Pausar (volume e sensibilidade do mouse ficam aqui) |
| - / + | Abaixar / aumentar volume |
| F11 | Tela cheia |

## Estrutura

```
assets/audio/      sons (provisórios, sintetizados por tools/gen_assets.py)
assets/textures/   texturas (provisórias, geradas por tools/gen_assets.py)
scenes/player/     jogador (câmera, lanterna, HUD, pós-processamento)
scenes/world/      porta, a Coisa (monstro)
scenes/levels/     fases
scripts/           código de tudo acima
shaders/           visual PS1 (mundo e pós-processamento)
tools/             scripts Python que geram assets e a fase de teste
```

## Fase de teste (`test_house`)

Quarto → corredor → cozinha. Serve pra calibrar o medo:

1. Batidas atrás de uma porta trancada no corredor.
2. A Coisa aparece no fim do corredor, as lâmpadas estouram e ela surge na sua cara.
3. A porta do quarto bate sozinha atrás de você.
4. Depois disso, sons aleatórios começam a tocar **atrás** de você.

## Sistemas prontos

- Movimento com fôlego, agachar, balanço de câmera, passos com som
- Lanterna com bateria, piscando quando fraca, seguindo a câmera com atraso
- Sistema de **medo** (0–1): coração, respiração, visão de túnel, tremor, vinheta pulsando
- Portas que abrem pro lado certo, rangem, trancam e **batem** sozinhas
- Lâmpadas que piscam, chiam e estouram
- Gatilhos de susto, glitch de VHS na tela, legendas de pensamento
- "Diretor de ambiente" que toca sons atrás do jogador

## Próximos passos

- IA da Coisa: patrulha, ouve passos, caça o jogador
- Esconderijos (armário, debaixo da cama)
- Menu principal, opções (sensibilidade, volume), save
- Trocar sons/texturas provisórios por assets reais
