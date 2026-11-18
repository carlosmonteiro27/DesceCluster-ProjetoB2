###############################################################
# DesceCluster | TRA-48 | Projeto B2
# 04_modelos.R: comparação dos modelos por validação cruzada
#
# Todos os modelos usam as MESMAS 5 partições da base de treino.
# Modelos da disciplina (hiperparâmetros escolhidos aqui por grade):
#   LM (regressão linear), ARVORE (CART), KNN, SVM, RN (rede neural)
# Modelos de ensemble de árvores (hiperparâmetros vindos do script 03):
#   RF (random forest), XGB (XGBoost), LGB (LightGBM)
# ENSEMBLE: combinação linear das previsões com pesos >= 0 (soma 1)
#
# Saídas: resultados/metricas_cv.csv, resultados/grade_modelos_disciplina.csv,
#         resultados/previsoes_oof.rds, resultados/modelo_final.rds, figuras
###############################################################

if (basename(getwd()) == "scripts") setwd("..")
source("scripts/00_funcoes.R")
suppressPackageStartupMessages(library(parallel))
t_inicio <- Sys.time()

load("dados/data_features.Rda")
B <- prepara(train, test)
y <- B$tr$y; n <- length(y)

# partições 5-fold fixas
set.seed(48); f <- sample(rep(1:5, length.out = n))
folds <- lapply(1:5, function(k) which(f == k))

# ------------------------------------------------------------
# Execução: dobras em paralelo (modelos da disciplina) ou em
# sequência com vários threads (RF, XGBoost, LightGBM)
# ------------------------------------------------------------
NUCLEOS <- max(1, min(15, detectCores() - 2))
THREADS <- max(1, min(16, detectCores() - 2))
cl <- makeCluster(NUCLEOS)
invisible(clusterCall(cl, function(dir) { setwd(dir); source("scripts/00_funcoes.R"); NULL }, getwd()))
clusterExport(cl, c("B", "folds"))

roda_tarefa <- function(t, nome) MODELOS[[nome]](t$hp, parte(B$tr, -folds[[t$k]]), parte(B$tr, folds[[t$k]]))

cv_grade <- function(nome, grade) {
  tarefas <- unlist(lapply(seq_len(nrow(grade)), function(i) lapply(seq_along(folds), function(k)
    list(i = i, k = k, hp = as.list(grade[i, , drop = FALSE])))), recursive = FALSE)
  res <- parLapplyLB(cl, tarefas, roda_tarefa, nome = nome)
  oof <- matrix(NA_real_, n, nrow(grade))
  for (j in seq_along(tarefas)) oof[folds[[tarefas[[j]]$k]], tarefas[[j]]$i] <- res[[j]]
  oof
}
cv_seq <- function(nome, hp) {
  oof <- numeric(n)
  for (k in seq_along(folds)) oof[folds[[k]]] <- MODELOS[[nome]](hp, parte(B$tr, -folds[[k]]), parte(B$tr, folds[[k]]))
  oof
}

# ------------------------------------------------------------
# 1) Modelos da disciplina: grade de hiperparâmetros
# ------------------------------------------------------------
grades <- list(
  LM     = data.frame(sem_hp = 1),
  ARVORE = data.frame(minsplit = c(10, 20, 40)),
  KNN    = data.frame(k = c(5, 10, 15, 20, 30)),
  SVM    = expand.grid(cost = c(1, 4, 16), gamma_rel = c(0.25, 0.5, 1), epsilon = 0.1),
  RN     = expand.grid(size = c(3, 6, 10), decay = c(0.3, 1, 3), maxit = 400, seeds = 3)
)

oof <- list(); hp_final <- list(); tabela_grade <- list()
for (nome in names(grades)) {
  cat(sprintf("[%s] %s: %d configuração(ões) x 5 dobras\n", format(Sys.time(), "%H:%M"), nome, nrow(grades[[nome]])))
  O <- cv_grade(nome, grades[[nome]])
  r <- apply(O, 2, rmse, y = y)
  best <- which.min(r)
  tabela_grade[[nome]] <- data.table(modelo = nome, config = apply(grades[[nome]], 1, function(z)
    paste(names(z), z, sep = "=", collapse = " ")), rmse_cv = round(r, 2))
  oof[[nome]] <- O[, best]
  hp_final[[nome]] <- as.list(grades[[nome]][best, , drop = FALSE])
}
stopCluster(cl)

# ------------------------------------------------------------
# 2) RF, XGBoost e LightGBM: melhores configurações do script 03
# ------------------------------------------------------------
tun <- rbindlist(lapply(list.files("resultados/tuning", pattern = "\\.csv$", full.names = TRUE), fread), fill = TRUE)
melhor <- function(m) as.list(tun[metodo == m][which.min(rmse_cv)])

b <- melhor("rf")
hp_final$RF  <- list(num.trees = 1000, mtry = b$mtry, min.node.size = b$min.node.size, threads = THREADS)
b <- melhor("xgb")
hp_final$XGB <- list(eta = 0.02, max_depth = b$max_depth, min_child_weight = b$min_child_weight, subsample = 0.8,
                     colsample_bytree = b$colsample_bytree, nrounds = b$best_iter, seeds = 5, threads = THREADS)
b <- melhor("lgb")
hp_final$LGB <- list(learning_rate = 0.02, num_leaves = b$num_leaves, min_data_in_leaf = b$min_data_in_leaf,
                     feature_fraction = b$feature_fraction, lambda_l2 = b$lambda_l2, nrounds = b$best_iter,
                     seeds = 5, threads = THREADS)
for (nome in c("RF", "XGB", "LGB")) {
  cat(sprintf("[%s] %s\n", format(Sys.time(), "%H:%M"), nome))
  oof[[nome]] <- cv_seq(nome, hp_final[[nome]])
}

# ------------------------------------------------------------
# 3) Ensemble (pesos >= 0, soma 1) com avaliação honesta:
#    pesos estimados sem a dobra k e aplicados na dobra k
# ------------------------------------------------------------
P <- do.call(cbind, oof)
ens <- numeric(n)
for (k in seq_along(folds)) {
  w_k <- pesos_ensemble(P[-folds[[k]], ], y[-folds[[k]]])
  ens[folds[[k]]] <- P[folds[[k]], ] %*% w_k
}
pesos <- pesos_ensemble(P, y)
P <- cbind(P, ENSEMBLE = ens)

# ------------------------------------------------------------
# 4) Tabela de métricas e escolha do modelo final
# ------------------------------------------------------------
metricas <- data.table(modelo = c("MEDIA (referência)", colnames(P)),
                       RMSE = c(rmse(y, mean(y)), apply(P, 2, rmse, y = y)),
                       MAE  = c(mae(y, mean(y)),  apply(P, 2, mae,  y = y)),
                       MAPE = c(mape(y, mean(y)), apply(P, 2, mape, y = y)))
setorder(metricas, RMSE)
final <- metricas[modelo != "MEDIA (referência)"][1, modelo]
if (final != "ENSEMBLE") pesos <- setNames(1, final)

dir.create("resultados/figuras", recursive = TRUE, showWarnings = FALSE)
fwrite(metricas[, .(modelo, RMSE = round(RMSE, 2), MAE = round(MAE, 2), MAPE = round(MAPE, 2))], "resultados/metricas_cv.csv")
fwrite(rbindlist(tabela_grade), "resultados/grade_modelos_disciplina.csv")
saveRDS(list(oof = P, y = y, folds = folds), "resultados/previsoes_oof.rds")
saveRDS(list(modelo_final = final, pesos = pesos, hp = hp_final), "resultados/modelo_final.rds")

cat("\n=== Validação cruzada 5-fold (RMSE e MAE em s, MAPE em %) ===\n")
print(metricas, digits = 4)
cat("\nModelo final:", final, "\nPesos:\n"); print(round(pesos, 3))

# ------------------------------------------------------------
# 5) Figuras
# ------------------------------------------------------------
cols <- colnames(P)
png("resultados/figuras/10_histograma_erros.png", width = 1500, height = 1100, res = 115)
par(mfrow = c(3, 3))
for (m in cols) {
  e <- (P[, m] - y) / 60
  hist(e, breaks = seq(floor(min(e)) - 1, ceiling(max(e)) + 1, by = 0.5), col = ifelse(m == final, "darkorange", "steelblue"),
       border = "white", xlim = c(-12, 12), main = sprintf("%s | RMSE = %.1f s", m, rmse(y, P[, m])),
       xlab = "Erro de previsão (min)", ylab = "Frequência")
  abline(v = 0, col = "red", lwd = 2)
}
dev.off()

png("resultados/figuras/11_previsto_vs_real.png", width = 1500, height = 1100, res = 115)
par(mfrow = c(3, 3))
for (m in cols) {
  plot(y / 60, P[, m] / 60, pch = 16, cex = 0.3, col = adjustcolor("steelblue", 0.35), xlim = c(5, 37), ylim = c(5, 37),
       xlab = "Real (min)", ylab = "Previsto (min)", main = m)
  abline(0, 1, col = "red", lwd = 2)
}
dev.off()

png("resultados/figuras/12_comparacao_metricas.png", width = 1500, height = 550, res = 115)
par(mfrow = c(1, 3), mar = c(9, 4, 3, 1))
r <- metricas[modelo != "MEDIA (referência)"]
cor_b <- ifelse(r$modelo == final, "darkorange", "grey55")
barplot(r$RMSE, names.arg = r$modelo, las = 2, col = cor_b, main = "RMSE (s)", ylim = c(0, max(r$RMSE) * 1.1))
barplot(r$MAE,  names.arg = r$modelo, las = 2, col = cor_b, main = "MAE (s)",  ylim = c(0, max(r$MAE) * 1.1))
barplot(r$MAPE, names.arg = r$modelo, las = 2, col = cor_b, main = "MAPE (%)", ylim = c(0, max(r$MAPE) * 1.1))
dev.off()

png("resultados/figuras/13_grades_disciplina.png", width = 1500, height = 500, res = 115)
par(mfrow = c(1, 3), mar = c(10, 4, 3, 1))
g <- tabela_grade$KNN; plot(grades$KNN$k, g$rmse_cv, type = "b", pch = 16, xlab = "k", ylab = "RMSE CV (s)", main = "KNN")
for (m in c("SVM", "RN")) { g <- tabela_grade[[m]]
  barplot(g$rmse_cv, names.arg = g$config, las = 2, cex.names = 0.55, col = "steelblue", main = m,
          ylim = c(min(g$rmse_cv) * 0.97, max(g$rmse_cv) * 1.01), xpd = FALSE, ylab = "RMSE CV (s)") }
dev.off()

cat(sprintf("\n04_modelos concluído em %.1f min\n", as.numeric(difftime(Sys.time(), t_inicio, units = "mins"))))
