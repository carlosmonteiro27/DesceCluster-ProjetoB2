// Relatório do Projeto B2 — TRA-48 — Grupo DesceCluster
// Compilar: typst compile relatorio.typ Relatorio_ProjetoB2_DesceCluster.pdf

#set document(
  title: "Previsão do tempo de táxi na partida no Aeroporto Internacional de São Paulo/Guarulhos",
  author: ("Carlos Alberto Monteiro da Cunha", "Matheus do Nascimento Lima dos Santos", "Guilherme Rodrigues Gomes"),
)
#set text(font: "New Computer Modern", size: 12pt, lang: "pt", region: "br")
#set par(justify: true, leading: 0.72em, first-line-indent: 1.25em)
#show par: set block(spacing: 0.9em)
#set page(paper: "a4", margin: (top: 3cm, bottom: 2.5cm, x: 2.5cm))
#set heading(numbering: "1.1")
#show heading: set block(above: 1.5em, below: 0.9em)
#show heading.where(level: 1): set text(size: 14pt)
#show heading.where(level: 2): set text(size: 12pt)
#set math.equation(numbering: "(1)")
#set figure(gap: 0.8em)
#set figure.caption(separator: [ -- ])
#show figure.caption: set text(size: 10.5pt)
#show figure.where(kind: table): set figure.caption(position: top)
#set table(stroke: none, inset: (x: 6pt, y: 4.5pt))
#show table: set text(size: 10.5pt, hyphenate: false)
#show table: set par(justify: false)
#show raw: set text(size: 10.5pt)

#let azul = rgb("#0F2747")

// ---------------------------------------------------------------- capa
#page(numbering: none, margin: 2.5cm)[
  #set align(center)
  #set par(first-line-indent: 0pt, justify: false)
  #image("logo_ita.png", width: 23%)
  #v(1.0cm)
  #text(size: 16pt)[Instituto Tecnológico de Aeronáutica]
  #v(0.2cm)
  #text(size: 13pt)[Curso de Graduação em Engenharia Civil-Aeronáutica]
  #v(1.6cm)
  #text(size: 14pt)[TRA-48 -- Inteligência Analítica: Dados, Modelos e Decisões]
  #v(0.25cm)
  #text(size: 12pt)[Relatório do Projeto B2]
  #v(0.9cm)
  #line(length: 35%, stroke: 0.8pt + azul)
  #v(0.5cm)
  #text(size: 19pt, weight: "bold")[Previsão do tempo de táxi na partida no Aeroporto Internacional de São Paulo/Guarulhos com aprendizado de máquina supervisionado]
  #v(0.5cm)
  #line(length: 35%, stroke: 0.8pt + azul)
  #v(1fr)
  #set align(left)
  #grid(
    columns: (auto, 1fr),
    column-gutter: 0.6em,
    row-gutter: 0.75em,
    [*Grupo:*], [DesceCluster (INFRA 27)],
    [*Alunos:*], [Carlos Alberto Monteiro da Cunha \ Matheus do Nascimento Lima dos Santos \ Guilherme Rodrigues Gomes],
    [*Professora:*], [Maj. Mayara Condé Rocha Murça],
    [*Data:*], [2 de dezembro de 2026],
  )
  #v(1.4cm)
  #align(center)[São José dos Campos \ 2026]
]

// ---------------------------------------------------------------- páginas pré-textuais
#set page(
  numbering: "i",
  header: [
    #set text(size: 9pt, fill: luma(90))
    #grid(
      columns: (auto, 1fr),
      align: (left + horizon, right + horizon),
      image("logo_ita.png", height: 0.7cm),
      [TRA-48 · Projeto B2 · Grupo DesceCluster],
    )
    #v(-0.45em)
    #line(length: 100%, stroke: 0.4pt + luma(170))
  ],
)
#counter(page).update(1)

#heading(numbering: none, outlined: false)[Resumo]

Este relatório apresenta o desenvolvimento de um modelo preditivo do tempo de táxi na partida de voos regulares no Aeroporto Internacional de São Paulo/Guarulhos (SBGR), a partir de 6.426 voos de janeiro de 2026. A previsão é feita no instante do pushback, usando apenas informações disponíveis naquele momento. A partir dos dados brutos foram construídas 22 variáveis explicativas, que descrevem o horário, o voo, a cabeceira, as condições meteorológicas e o tráfego no solo. A análise exploratória mostrou que o número de aeronaves taxiando no pushback é o fator mais associado ao tempo de táxi (correlação de 0,68) e que a cabeceira 28R, aeronaves pesadas, voos internacionais e a ocorrência de chuva ou baixa visibilidade elevam esse tempo. Oito métodos de aprendizado supervisionado foram comparados por validação cruzada 5-fold com partições idênticas: regressão linear, árvore de regressão, KNN, SVM, rede neural, random forest, XGBoost e LightGBM. O modelo final é uma média ponderada de LightGBM, XGBoost, random forest e rede neural, com RMSE de 118,6 s, MAE de 95,4 s e MAPE de 11,5%, o que corresponde a um erro típico de cerca de 2 minutos para um tempo de táxi médio de 14,5 minutos e a uma redução de 56% do RMSE em relação a prever a média. O modelo foi aplicado aos 1.607 voos da base de teste.

#v(0.6em)
#par(first-line-indent: 0pt)[*Palavras-chave:* tempo de táxi; aprendizado de máquina; regressão; validação cruzada; gradient boosting; aeroporto de Guarulhos.]

#pagebreak()
#outline(title: [Sumário], indent: auto, depth: 2)

// ---------------------------------------------------------------- texto
#pagebreak()
#set page(numbering: "1")
#counter(page).update(1)

= Introdução

O tempo de táxi na partida é o intervalo entre o pushback, quando a aeronave deixa a posição de estacionamento, e a decolagem. Em aeroportos movimentados, esse intervalo varia bastante ao longo do dia e depende do congestionamento das pistas de táxi, da cabeceira em uso, do tipo de aeronave e das condições meteorológicas. Conhecê-lo com antecedência permite sequenciar melhor as decolagens, reduzir filas na cabeceira, diminuir o tempo com motores ligados, e portanto o consumo de combustível e as emissões, e oferecer informação mais confiável a companhias aéreas, controle de tráfego e passageiros.

O objetivo deste trabalho é desenvolver um modelo de aprendizado de máquina supervisionado que preveja, no instante do pushback, o tempo de táxi de voos regulares no Aeroporto Internacional de São Paulo/Guarulhos (SBGR). O desempenho é avaliado pelo erro quadrático médio (RMSE), que também é o critério do desafio de dados da disciplina, além do erro absoluto médio (MAE) e do erro percentual absoluto médio (MAPE).

O relatório está organizado da seguinte forma: a @sec:dados descreve a base de dados; a @sec:prep, o pré-processamento e a construção de variáveis; a @sec:eda, a análise exploratória; a @sec:metodos, os métodos e o processo de treinamento; a @sec:resultados, os resultados e o modelo final; e a @sec:conclusoes, as conclusões.

= Base de dados <sec:dados>

As bases fornecidas contêm voos regulares partindo de SBGR em janeiro de 2026. A base de treino tem 6.426 voos, com o tempo de táxi conhecido, e a base de teste tem 1.607 voos, cujo tempo de táxi deve ser previsto. Cada voo é descrito por 14 colunas, resumidas na @tab:variaveis.

#figure(
  table(
    columns: (auto, 1fr),
    align: (left, left),
    table.hline(),
    [*Variável*], [*Descrição*],
    table.hline(stroke: 0.5pt),
    [`id`], [Identificador único do voo],
    [`adep`, `ades`], [Aeroportos de origem (sempre SBGR) e de destino, em código ICAO],
    [`cpush`, `crwy`], [Horários de pushback e de decolagem (UTC)],
    [`airline`], [Companhia aérea (código ICAO)],
    [`acfttype`, `wtc`], [Tipo de aeronave e categoria de esteira de turbulência (M ou H na base)],
    [`runway`], [Cabeceira usada na decolagem: 10L ou 28R],
    [`nactive`], [Número de aeronaves taxiando no momento do pushback],
    [`wind_direction`, `wind_speed`], [Direção (graus) e velocidade (nós) do vento],
    [`wx`], [Presença de chuva e/ou baixa visibilidade (binária)],
    [`taxitime`], [Tempo de táxi, em segundos (variável-alvo)],
    table.hline(),
  ),
  caption: [Variáveis das bases de dados.],
) <tab:variaveis>

A base de treino reúne 10 companhias aéreas, 21 tipos de aeronave e 96 destinos. As companhias TAM e GLO respondem por 82% dos voos. A cabeceira 10L foi usada em 4.562 voos (71%) e a 28R, em 1.864. Apenas 595 voos (9%) são de aeronaves pesadas e 141 (2,2%) ocorreram com chuva ou baixa visibilidade. Não há valores faltantes.

= Pré-processamento e construção de variáveis <sec:prep>

== Informação disponível no pushback

A regra adotada em todo o trabalho foi usar como entrada apenas informações conhecidas no instante do pushback, já que é nesse momento que a previsão tem utilidade operacional. Essa regra tem uma consequência importante: o horário de decolagem (`crwy`) não pode ser usado. Na base de treino, o tempo de táxi é exatamente a diferença entre `crwy` e `cpush` em todos os voos, e `crwy` também está presente na base de teste. Usá-lo daria erro nulo sem nenhum aprendizado, mas não tem sentido prático, pois a decolagem só é conhecida depois do táxi. Por isso `crwy` foi excluído, assim como `id` e `adep`, que é constante.

== Variáveis construídas

A partir dos dados brutos foram construídas 22 variáveis explicativas, organizadas em quatro grupos (@tab:features).

#figure(
  table(
    columns: (auto, 1fr),
    align: (left, left),
    table.hline(),
    [*Grupo*], [*Variáveis*],
    table.hline(stroke: 0.5pt),
    [Tempo], [Hora local (UTC−3) contínua e em codificação cíclica (seno e cosseno); dia da semana],
    [Voo], [Companhia (menos de 30 voos agrupadas); tipo de aeronave (menos de 20 voos agrupados); esteira de turbulência; destino (menos de 40 voos agrupados); região do destino (Brasil, América do Sul, América do Norte, Europa e outros); voo doméstico ou internacional],
    [Pista e meteorologia], [Cabeceira; direção e velocidade do vento; componentes de proa e de través em relação à cabeceira; chuva ou baixa visibilidade],
    [Tráfego], [`nactive`; número de pushbacks nos 10, 20, 30 e 60 minutos anteriores; tempo desde o pushback anterior],
    table.hline(),
  ),
  caption: [Variáveis explicativas usadas pelos modelos.],
) <tab:features>

A hora foi convertida para o horário local e também representada de forma cíclica, para que 23 h e 0 h fiquem próximas:

$ h_"sen" = sin(2 pi h \/ 24), quad h_"cos" = cos(2 pi h \/ 24). $

O vento foi decomposto em relação ao rumo da cabeceira em uso, $psi = 95 degree$ para a 10L e $psi = 275 degree$ para a 28R, com $theta$ a direção de onde sopra o vento e $v$ a sua velocidade:

$ v_"proa" = v cos(theta - psi), quad v_"través" = abs(v sin(theta - psi)). $

As variáveis de tráfego contam os pushbacks anteriores de todos os voos, das bases de treino e de teste, olhando apenas para o passado de cada voo. Os destinos foram classificados como domésticos pelos prefixos ICAO SB e SD. Para os modelos que operam sobre matrizes numéricas (SVM, rede neural, XGBoost e LightGBM), as variáveis categóricas foram codificadas em variáveis indicadoras (one-hot). Para KNN, SVM e rede neural, as variáveis foram padronizadas com a média e o desvio padrão da parte usada no treino.

= Análise exploratória <sec:eda>

== Distribuição do tempo de táxi

O tempo de táxi varia de 7,2 a 36,1 minutos, com média de 14,5 minutos, mediana de 13,8 minutos e desvio padrão de 4,5 minutos. Metade dos voos taxia entre 11,3 e 16,7 minutos (1º e 3º quartis). A distribuição é assimétrica à direita (@fig:dist): poucos voos têm tempos muito longos, e são esses os casos mais difíceis de prever.

#figure(
  placement: auto,
  image("figuras/c1_distribuicao.png", width: 88%),
  caption: [Histograma do tempo de táxi na base de treino (6.426 voos). A linha tracejada marca a mediana.],
) <fig:dist>

== Tráfego no solo

A variável mais associada ao tempo de táxi é `nactive`, o número de aeronaves taxiando no momento do pushback, com correlação de Pearson de 0,68. A relação é aproximadamente linear e diferente para cada cabeceira (@fig:nactive): pelas retas ajustadas, cada aeronave a mais taxiando acrescenta cerca de 0,71 minuto na cabeceira 10L e 0,95 minuto na 28R. Com até 2 aeronaves taxiando, o tempo médio é de 11,8 minutos; com 12 ou mais, chega a 23,7 minutos. Essa interação entre cabeceira e tráfego foi incluída explicitamente na regressão linear.

#figure(
  placement: auto,
  image("figuras/c2_nactive_cabeceira.png", width: 85%),
  caption: [Tempo de táxi em função do número de aeronaves taxiando no pushback, por cabeceira, com as retas de mínimos quadrados.],
) <fig:nactive>

== Fatores operacionais e meteorológicos

A @fig:fatores e a @tab:grupos comparam o tempo de táxi entre grupos de voos. A cabeceira 28R é, em média, 4,8 minutos mais lenta que a 10L. Aeronaves pesadas taxiam 4,0 minutos a mais que as médias, e voos internacionais, 2,1 minutos a mais que os domésticos. Com chuva ou baixa visibilidade, o tempo médio sobe 4,2 minutos e a variabilidade também aumenta.

#figure(
  placement: auto,
  image("figuras/c3_fatores.png", width: 80%),
  caption: [Boxplots do tempo de táxi por cabeceira, categoria de esteira, tipo de destino e condição meteorológica.],
) <fig:fatores>

#figure(
  table(
    columns: (auto, auto, auto, auto, auto),
    align: (left, left, right, right, right),
    table.hline(),
    [*Fator*], [*Grupo*], [*Voos*], [*Média (min)*], [*Mediana (min)*],
    table.hline(stroke: 0.5pt),
    [Cabeceira], [10L], [4.562], [13,1], [12,5],
    [], [28R], [1.864], [17,9], [16,4],
    [Esteira], [Média (M)], [5.831], [14,2], [13,4],
    [], [Pesada (H)], [595], [18,2], [17,7],
    [Destino], [Doméstico], [5.097], [14,1], [13,3],
    [], [Internacional], [1.329], [16,2], [15,5],
    [Meteorologia], [Sem fenômeno], [6.285], [14,4], [13,7],
    [], [Chuva ou baixa visibilidade], [141], [18,7], [16,8],
    table.hline(),
  ),
  caption: [Tempo de táxi por grupo de voos na base de treino.],
) <tab:grupos>

Entre as companhias, as norte-americanas AAL e UAL, que operam aeronaves de grande porte, têm os maiores tempos médios (18,6 e 18,1 minutos), e a ARG, o menor (12,6 minutos). Entre os tipos de aeronave, B77W e B789 passam de 18 minutos em média, enquanto o E295 fica em 13,3 minutos. A sexta-feira é o dia com maior tempo médio (15,5 minutos) e o domingo, o de menor (13,7 minutos).

== Hora do dia

O tempo de táxi acompanha os picos de movimento do aeroporto (@fig:hora). As maiores medianas ocorrem às 18 h (16,1 minutos), às 23 h e às 0 h e às 9 h (15,5 a 15,6 minutos). As menores ocorrem às 20 h (11,0 minutos) e no início da manhã, às 5 h e às 6 h (11,3 minutos).

#figure(
  placement: auto,
  image("figuras/c5_hora.png", width: 92%),
  caption: [Tempo de táxi por hora local do pushback.],
) <fig:hora>

== Correlações

O correlograma da @fig:correl resume as correlações entre as variáveis numéricas. O `nactive` se destaca. Os pushbacks recentes são correlacionados entre si (até 0,57 entre as janelas de 10 e 60 minutos), mas pouco com o tempo de táxi quando vistos isoladamente (entre 0,15 e 0,17), pois medem a demanda e não a fila efetiva. O vento tem correlação fraca. A chuva tem correlação de apenas 0,14 porque é rara, mas, quando ocorre, o efeito é grande (@tab:grupos). Correlação baixa, portanto, não implica variável irrelevante, e todas as variáveis foram mantidas, deixando aos modelos a seleção do que é útil.

#figure(
  placement: auto,
  image("figuras/c4_correlograma.png", width: 85%),
  caption: [Correlograma (Pearson) de variáveis numéricas selecionadas. Azul indica correlação positiva e laranja, negativa.],
) <fig:correl>

= Métodos e treinamento <sec:metodos>

== Validação e métricas

Todos os modelos foram avaliados por validação cruzada 5-fold na base de treino. Os 6.426 voos foram divididos aleatoriamente em 5 partes fixas (semente 48), e as mesmas partições foram usadas para todos os modelos, o que torna a comparação justa. Em cada rodada, o modelo é treinado com 4 partes e prevê a parte restante, de modo que todas as métricas são calculadas sobre previsões fora da amostra. Sendo $y_i$ o tempo real e $hat(y)_i$ o previsto, as métricas são:

$ "RMSE" = sqrt(1/n sum_(i=1)^n (y_i - hat(y)_i)^2), quad quad "MAE" = 1/n sum_(i=1)^n abs(y_i - hat(y)_i), $

$ "MAPE" = 100/n sum_(i=1)^n abs(y_i - hat(y)_i)/y_i. $

Os hiperparâmetros foram escolhidos pelo menor RMSE da validação cruzada, por busca em grade.

== Métodos vistos na disciplina

- *Regressão linear múltipla:* efeitos principais de todas as variáveis e interações da cabeceira com `nactive` (inclusive o termo quadrático), com a hora (harmônicos de 24 h e 12 h), com a companhia, com a esteira e com os pushbacks em 20 minutos.
- *Árvore de regressão (CART):* árvore crescida sem restrição de complexidade e podada pelo parâmetro de complexidade com menor erro na validação cruzada interna de 10 partes. O tamanho mínimo para divisão foi escolhido entre 10, 20 e 40 voos.
- *K-vizinhos mais próximos (KNN):* média do tempo de táxi dos $k$ voos mais próximos, com $k in {5, 10, 15, 20, 30}$. Usou-se um subconjunto de 10 variáveis (cabeceira, esteira, tipo de destino, `nactive`, hora cíclica, chuva, pushbacks em 20 minutos, companhia e região), pois a distância euclidiana perde poder de discriminação com muitas variáveis indicadoras.
- *Máquina de vetores de suporte (SVM):* regressão $epsilon$-SVR com kernel radial, custo $C in {1, 4, 16}$, $gamma$ igual a 0,25, 0,5 ou 1 dividido pelo número de variáveis e $epsilon = 0,1$.
- *Rede neural artificial:* uma camada escondida com 3, 6 ou 10 neurônios e penalização dos pesos (_decay_) de 0,3, 1 ou 3. A previsão é a média de 3 inicializações aleatórias.

== Comitês de árvores

- *Random forest:* 1.000 árvores, com o número de variáveis sorteadas em cada divisão ($m_"try" in {6, 8, 10, 12}$) e o tamanho mínimo dos nós (1, 3 ou 5) escolhidos por grade.
- *XGBoost:* gradient boosting de árvores com taxa de aprendizado 0,02 e subamostragem de 80% dos voos, com busca em grade da profundidade máxima (6, 7, 8 ou 10), do peso mínimo por folha (1, 3 ou 5) e da fração de variáveis por árvore (0,5 ou 0,8).
- *LightGBM:* gradient boosting com crescimento das árvores por folha, taxa de aprendizado 0,02, com busca em grade do número de folhas (31, 63 ou 127), do mínimo de voos por folha (5, 10 ou 20) e da fração de variáveis (0,5 ou 0,8).

No XGBoost e no LightGBM, o número de árvores foi definido por parada antecipada na própria validação cruzada (interrupção após 300 iterações sem melhora). Para reduzir a variância, a previsão final de cada um é a média de 5 sementes.

== Combinação dos modelos (ensemble)

Como modelos diferentes erram de formas diferentes, foi testada uma média ponderada das previsões. Sendo $P$ a matriz com as previsões fora da amostra dos oito modelos e $bold(y)$ o vetor de tempos reais, os pesos $bold(w)$ resolvem o problema de programação quadrática

$ min_(bold(w)) norm(bold(y) - P bold(w))^2 quad "sujeito a" quad w_j >= 0, quad sum_j w_j = 1, $ <eq:ens>

e a previsão do ensemble é $hat(y) = sum_j w_j hat(y)_j$. Para que o desempenho reportado fosse honesto, na validação cruzada os pesos aplicados em cada parte foram estimados sem usar essa parte. Os pesos finais foram estimados com todas as previsões fora da amostra.

== Implementação

Todo o trabalho foi feito em R 4.4, com os pacotes `data.table`, `rpart`, `caret`, `e1071`, `nnet`, `ranger`, `xgboost`, `lightgbm` e `quadprog`. O código está organizado em scripts numerados (preparação, exploração, busca de hiperparâmetros, comparação dos modelos e previsão), executados em sequência por um script único, e as previsões são reproduzidas exatamente quando o processo é refeito do início.

= Resultados <sec:resultados>

== Comparação dos modelos

A @tab:metricas mostra o desempenho de cada modelo na validação cruzada, com a melhor configuração de cada um. Como referência, prever sempre a média do treino resulta em RMSE de 271,2 s.

#figure(
  table(
    columns: (1fr, auto, auto, auto),
    align: (left, right, right, right),
    table.hline(),
    [*Modelo*], [*RMSE (s)*], [*MAE (s)*], [*MAPE (%)*],
    table.hline(stroke: 0.5pt),
    [*Ensemble (modelo final)*], [*118,6*], [*95,4*], [*11,5*],
    [LightGBM], [118,8], [95,5], [11,6],
    [XGBoost], [119,1], [95,7], [11,6],
    [Random forest], [120,9], [96,7], [11,7],
    [Rede neural (3 neurônios, _decay_ 1)], [132,6], [104,1], [12,4],
    [Regressão linear], [134,4], [105,4], [12,5],
    [SVM ($C = 4$, $gamma$ = 0,25/p)], [138,0], [108,0], [12,8],
    [Árvore de regressão (mín. 20 voos)], [143,6], [111,5], [13,2],
    [KNN ($k = 10$)], [146,3], [111,6], [13,1],
    table.hline(stroke: 0.5pt),
    [Referência: média do treino], [271,2], [206,2], [25,0],
    table.hline(),
  ),
  caption: [Desempenho na validação cruzada 5-fold (previsões fora da amostra, 6.426 voos).],
) <tab:metricas>

Todos os modelos reduzem o erro da referência pela metade ou mais. Os comitês de árvores foram claramente superiores aos métodos vistos na disciplina, com RMSE entre 118,8 s e 120,9 s, contra 132,6 s da melhor alternativa clássica, a rede neural. A vantagem vem da capacidade de capturar não linearidades e interações, como a dependência da inclinação de `nactive` em relação à cabeceira, sem que elas precisem ser especificadas manualmente. Entre os métodos clássicos, a regressão linear com interações ficou próxima da rede neural, o que mostra que boa parte da estrutura do problema é aproximadamente linear quando as interações corretas são incluídas. A árvore única e o KNN tiveram os maiores erros: a árvore produz previsões em degraus, e o KNN sofre com a alta dimensão das variáveis categóricas. As três métricas ordenam os modelos praticamente da mesma forma.

== Histogramas de erro

A @fig:erros mostra a distribuição do erro de previsão de cada modelo. Todos os histogramas são centrados em zero, ou seja, os modelos não tendem sistematicamente a superestimar ou subestimar o tempo de táxi. Nos comitês de árvores e no ensemble, os histogramas são mais estreitos e as caudas mais curtas, com menos erros grandes. No ensemble, 69% dos voos têm erro absoluto de até 2 minutos, 88% de até 3 minutos e 99% de até 5 minutos. Há uma leve cauda à esquerda em todos os modelos, que corresponde aos táxis muito longos, subestimados pelas variáveis disponíveis no pushback.

#figure(
  placement: auto,
  image("figuras/c6_histogramas_erro.png", width: 100%),
  caption: [Histogramas do erro de previsão (previsto menos real) na validação cruzada. Em laranja, o modelo final.],
) <fig:erros>

== Modelo final

O modelo final escolhido é o ensemble, que teve o menor RMSE, o menor MAE e o menor MAPE. A otimização da @eq:ens atribuiu peso zero à regressão linear, à árvore, ao KNN e ao SVM, e manteve quatro componentes (@tab:final).

#figure(
  table(
    columns: (auto, auto, 1fr),
    align: (left, right, left),
    table.hline(),
    [*Componente*], [*Peso*], [*Hiperparâmetros*],
    table.hline(stroke: 0.5pt),
    [LightGBM], [53,1%], [63 folhas; mínimo de 5 voos por folha; 50% das variáveis por árvore; 583 árvores; média de 5 sementes],
    [XGBoost], [23,2%], [profundidade 10; peso mínimo por folha 5; 50% das variáveis por árvore; 514 árvores; média de 5 sementes],
    [Random forest], [20,5%], [1.000 árvores; $m_"try" = 8$; tamanho mínimo do nó 1],
    [Rede neural], [3,2%], [1 camada com 3 neurônios; _decay_ 1; média de 3 inicializações],
    table.hline(),
  ),
  caption: [Componentes do modelo final.],
) <tab:final>

O RMSE de 118,6 s corresponde a cerca de 2 minutos, para um tempo de táxi médio de 14,5 minutos, e representa uma redução de 56% em relação à referência. O coeficiente de determinação das previsões fora da amostra é $R^2$ = 0,81. A @fig:prevreal mostra que as previsões se concentram em torno da diagonal; a dispersão cresce para os táxis mais longos, que tendem a ser subestimados.

#figure(
  placement: auto,
  image("figuras/c7_previsto_real.png", width: 55%),
  caption: [Tempo de táxi previsto pelo modelo final em função do tempo real (validação cruzada). Cada ponto é um voo.],
) <fig:prevreal>

Para a previsão da base de teste, os quatro componentes foram treinados novamente com os 6.426 voos e combinados com os pesos da @tab:final. As previsões foram limitadas à faixa observada no treino (434 s a 2.168 s). Os 1.607 voos de teste receberam previsões entre 519 s e 2.063 s, com média de 870 s, próxima da média do treino (871 s). O arquivo de submissão mantém as colunas e a ordem dos voos da base original, com a coluna `taxitime` preenchida.

== Alternativas testadas e descartadas

Algumas alternativas foram avaliadas com as mesmas partições e não reduziram o RMSE da validação cruzada, por isso não fazem parte do modelo final: modelar o logaritmo do tempo de táxi; usar o tratamento nativo de variáveis categóricas do LightGBM em vez da codificação one-hot; incluir o dia do mês; incluir medidas do desempenho recente do aeroporto, como o tempo de táxi médio das últimas decolagens; e incluir contagens de pushbacks recentes da mesma companhia, do mesmo tipo de destino ou de aeronaves pesadas.

= Conclusões <sec:conclusoes>

Este trabalho desenvolveu um modelo para prever, no instante do pushback, o tempo de táxi na partida em Guarulhos. As principais conclusões são:

+ O congestionamento no solo é o principal determinante do tempo de táxi: cada aeronave a mais taxiando acrescenta de 0,7 a 1,0 minuto, conforme a cabeceira.
+ A cabeceira 28R, aeronaves pesadas, voos internacionais, os horários de pico e a ocorrência de chuva ou baixa visibilidade também aumentam o tempo de táxi.
+ Os comitês de árvores (random forest, XGBoost e LightGBM) superaram os métodos clássicos, por capturarem não linearidades e interações sem especificação manual.
+ A combinação ponderada dos modelos produziu o menor erro: RMSE de 118,6 s, MAE de 95,4 s e MAPE de 11,5%, cerca de 2 minutos de erro típico e 56% menos que a referência.

O cuidado de usar apenas informação disponível no pushback, em especial a exclusão do horário de decolagem, garante que o modelo possa ser usado na prática. Entre as limitações, destacam-se o período curto da base, apenas um mês, e a ausência de informações sobre a posição de estacionamento e a rota de táxi, que explicariam parte dos tempos longos ainda subestimados. Como trabalhos futuros, sugere-se ampliar a base para vários meses, de forma a captar efeitos sazonais, e incorporar a distância entre o estacionamento e a cabeceira e a sequência de decolagens prevista.

#heading(numbering: none)[Referências]

#set par(first-line-indent: 0pt, justify: false, hanging-indent: 1.25em)

BREIMAN, L. Stacked regressions. *Machine Learning*, v. 24, n. 1, p. 49–64, 1996.

BREIMAN, L. Random forests. *Machine Learning*, v. 45, n. 1, p. 5–32, 2001.

CHEN, T.; GUESTRIN, C. XGBoost: a scalable tree boosting system. In: ACM SIGKDD INTERNATIONAL CONFERENCE ON KNOWLEDGE DISCOVERY AND DATA MINING, 22., 2016, São Francisco. *Proceedings* [...]. Nova York: ACM, 2016. p. 785–794.

FRIEDMAN, J. H. Greedy function approximation: a gradient boosting machine. *The Annals of Statistics*, v. 29, n. 5, p. 1189–1232, 2001.

JAMES, G.; WITTEN, D.; HASTIE, T.; TIBSHIRANI, R. *An introduction to statistical learning*: with applications in R. Nova York: Springer, 2013.

KE, G. et al. LightGBM: a highly efficient gradient boosting decision tree. In: ADVANCES IN NEURAL INFORMATION PROCESSING SYSTEMS, 30., 2017, Long Beach. *Proceedings* [...]. Red Hook: Curran Associates, 2017. p. 3146–3154.

R CORE TEAM. *R*: a language and environment for statistical computing. Viena: R Foundation for Statistical Computing, 2024.

TAN, P.-N.; STEINBACH, M.; KARPATNE, A.; KUMAR, V. *Introduction to data mining*. 2. ed. Londres: Pearson Education, 2018.
