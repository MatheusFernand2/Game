# Ecos

Jogo de terror em primeira pessoa feito no **Godot 4** (4.4 ou mais novo).
Sem combate e sem morte: você só pode fugir, se esconder e torcer.

Visual estilo PS1/VHS (baixa resolução, dithering, neblina, granulação),
porque o que você não enxerga direito assusta mais.

O roteiro completo está no documento "Roteiro — Ecos".

## Como abrir

1. Abra o Godot.
2. Clique em **Importar** e escolha o arquivo `project.godot` desta pasta.
3. Espere ele importar os assets (só na primeira vez).
4. Aperte **F5**. Abre o menu: **Novo jogo** (Ato 1) ou **Casa de teste**.

A floresta é gerada quando a fase carrega, então o Ato 1 leva alguns segundos pra abrir.

## Controles

| Tecla | Ação |
|---|---|
| W A S D | Andar |
| Shift | Correr (gasta fôlego) |
| Ctrl / C | Agachar |
| E / clique esquerdo | Interagir (portas, itens) |
| F / clique direito | Lanterna |
| T | Olhar o relógio |
| Esc | Pausar (volume, sensibilidade, voltar ao menu) |
| - / + | Abaixar / aumentar volume |
| F11 | Tela cheia |

## O que já dá pra jogar

### Ato 1 — A Trilha (`scenes/levels/act1_trilha.tscn`)

1. O sítio, à noite. O Paçoca late pro mato e foge pelo portão.
2. A trilha. Alguma coisa anda no mato do seu lado e para quando você para.
3. A casa de ferramentas: rastro de sangue e a coruja.
4. O primeiro Eco, parado entre as árvores. Some se você apagar a lanterna.
5. A perseguição. A Coisa Funda vem atrás; a luz da lanterna segura ela. Siga o latido.
6. A queda no barranco.
7. O despertar: lanterna falhando, perna doendo, relógio parado em 03:17.

### Casa de teste (`scenes/levels/test_house.tscn`)

Quarto, corredor e cozinha, pra testar sustos. Na cozinha está o **Eco sentado**:
mão no rosto, do lado das pilhas. Você tem que passar do lado dele. Ele nunca reage.

## Estrutura

```
assets/audio/        sons (provisórios, sintetizados pelos scripts em tools/)
assets/textures/     texturas (provisórias, idem)
scenes/menu/         menu principal
scenes/player/       jogador (câmera, lanterna, HUD, pós-processamento)
scenes/world/        porta, Eco sentado, Paçoca, Coisa Funda...
scenes/levels/       fases
scripts/systems/     trombada do Eco, barulho que te acompanha no mato
scripts/world/       terreno, floresta, corpo dos Ecos, cachorro, monstro...
shaders/             visual PS1 (mundo, terreno e pós-processamento)
tools/               scripts Python que geram assets e as fases
```

## Sistemas prontos

- Movimento com fôlego, agachar, passos com som (madeira e terra)
- Lanterna com bateria, piscando quando fraca
- Sistema de **medo**: coração, respiração, visão de túnel, tremor, vinheta pulsando
- Medo por proximidade (chegar perto de um Eco já acelera o coração)
- Terreno e floresta gerados por código (trilha, clareiras, barranco, ~1400 árvores, mato)
- Corpo dos Ecos montado por código, com poses (em pé, sentado, correndo, de quatro)
- Paçoca: corre na frente, espera você, late chamando
- Coisa Funda: persegue pelo seu rastro, recua na luz, te derruba sem matar
- Trombada do Eco (no máximo 2 vezes no jogo): você vira pra trás correndo e ele te atropela
- Relógio de pulso que para na hora da queda
- Portas, lâmpadas que piscam/estouram, gatilhos de susto, coruja, legendas
- Menu principal e menu de pausa com volume e sensibilidade

## Regerando as coisas

```
python tools/gen_assets.py          # sons e texturas da casa
python tools/gen_forest_assets.py   # sons e texturas da floresta
python tools/gen_level.py           # casa de teste
python tools/gen_act1.py            # Ato 1
```

Precisa de Python com `numpy`, `scipy`, `pillow`. Regerar uma fase apaga o que for
mudado nela à mão no editor, então depois de começar a editar no Godot, edite lá.

## Próximos passos

- Esconder e prender a respiração
- Ato 2 — A Floresta (as 4 áreas)
- Save automático
- Trocar sons/texturas provisórios por assets reais
