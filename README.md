# simpleGasSystem
Este é um re-upload de um sistema feito em junho de 2018.

Foi um sistema feito para estudar algumas funções e algumas lógicas de programação.

É um sistema de Gasolina e Postos de Gasolina para servidores SA-MP, possui uma forma fácil para alterar os valores do litro da gasolina, de posto para posto.

Lembrando que: Não existe um sistema de salvamento, como eu havia dito, é um sistema simples, pode ser utilizado como base.

[Link do vídeo de funcionamento do sistema](https://www.youtube.com/watch?v=cx3YMe4IGUE&t=20s&ab_channel=vTn)

## Depêndencias

Este filterscript utilizam duas includes básicas: a_samp e zcmd.

## Comandos

* /postos - Exibe as caixas de diálogo dos postos de gasolina.
* /preco - (Apenas administradores) Caixa de diálogo para alteração do valor da gasolina.
* /abastecer - Abastece o veículo.

## Adicionando novos postos de Gasolina.

Para adicionar um novo posto de gasolina é muito simples:

1. Altere a variável *gasStationsMax* na linha **61** para a nova quantia máxima de postos de gasolina.
2. Adicione mais uma linha na matriz *gasStations* na linha **120**.

Devo lembrar que dentro da matriz funciona da seguinte forma:

Nome do Posto de Gasolina, Valor da Gasolina, Posição X, Posição Y, Posição Z

### Contato

Contato via Discord: Vitor Santos#0001 
