###############################################################
# DesceCluster | TRA-48 | Projeto B2
# 05_previsao.R: treina o modelo final com TODA a base de treino
# e gera o arquivo de submissão com as previsões de taxitime.
#
# Entrada: resultados/modelo_final.rds (gerado pelo 04_modelos.R)
# Saída:   submissao/data_project_test_grupoDesceCluster.Rda
#          (objeto data_test original com a coluna taxitime preenchida)
###############################################################

if (basename(getwd()) == "scripts") setwd("..")
source("scripts/00_funcoes.R")

load("dados/data_features.Rda")                   # train, test (features)
orig <- new.env(); load("dados/data_project.Rda", envir = orig)
final <- readRDS("resultados/modelo_final.rds")   # modelo_final, pesos, hp

B <- prepara(train, test)
usados <- names(final$pesos)[final$pesos > 0]
cat("Modelo final:", final$modelo_final, "| componentes:", paste(usados, collapse = ", "), "\n")

# previsões de cada componente, treinado com os 6.426 voos de treino
P <- sapply(usados, function(m) {
  cat("  treinando", m, "\n")
  MODELOS[[m]](final$hp[[m]], B$tr, B$te)
})
P <- matrix(P, ncol = length(usados), dimnames = list(NULL, usados))
pred <- as.numeric(P %*% final$pesos[usados])
pred <- pmin(pmax(pred, min(B$tr$y)), max(B$tr$y))     # limita à faixa observada no treino

# monta a submissão no formato original (mesmas linhas, colunas e ordem de id)
data_test <- copy(as.data.table(orig$data_test))
stopifnot(identical(data_test$id, test$id))
data_test[, taxitime := pred]
stopifnot(nrow(data_test) == 1607, !anyNA(data_test$taxitime),
          identical(names(data_test), names(orig$data_test)))

dir.create("submissao", showWarnings = FALSE)
arquivo <- "submissao/data_project_test_grupoDesceCluster.Rda"
save(data_test, file = arquivo)
fwrite(data.table(id = data_test$id, taxitime = round(pred, 3), round(P, 3)), "resultados/previsoes_teste.csv")

cat("Arquivo salvo:", arquivo, "\n")
print(summary(data_test$taxitime))
