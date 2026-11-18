###############################################################
# DesceCluster | TRA-48 | Projeto B2
# 03_tuning_boosting.R: busca de hiperparâmetros (grade + CV 5-fold)
# para random forest (ranger), XGBoost e LightGBM.
#
# Para XGBoost e LightGBM o nº de árvores é escolhido por parada
# antecipada (early stopping) na própria validação cruzada.
#
# Uso:  Rscript scripts/03_tuning_boosting.R               (tudo, em sequência)
#       Rscript scripts/03_tuning_boosting.R lgb 1 3 4     (bloco 1 de 3 da grade do LightGBM, 4 threads)
# Saída: resultados/tuning/tuning_<metodo>_<bloco>.csv
# OBS: demorado (~25 min com 6 processos em paralelo). Os resultados já
#      estão salvos em resultados/tuning/ e são lidos pelo 04_modelos.R.
###############################################################

if (basename(getwd()) == "scripts") setwd("..")
source("scripts/00_funcoes.R")

args    <- commandArgs(TRUE)
metodos <- if (length(args) >= 1) args[1] else c("rf", "xgb", "lgb")
bloco   <- if (length(args) >= 2) as.integer(args[2]) else 1L
nblocos <- if (length(args) >= 3) as.integer(args[3]) else 1L
threads <- if (length(args) >= 4) as.integer(args[4]) else 8L

load("dados/data_features.Rda")
B <- prepara(train, test)
X <- B$tr$X; y <- B$tr$y; n <- length(y)
set.seed(48); f <- sample(rep(1:5, length.out = n))
folds <- lapply(1:5, function(k) which(f == k))

grades <- list(
  rf  = expand.grid(mtry = c(6, 8, 10, 12), min.node.size = c(1, 3, 5)),
  xgb = expand.grid(max_depth = c(6, 7, 8, 10), min_child_weight = c(1, 3, 5), colsample_bytree = c(0.5, 0.8)),
  lgb = expand.grid(num_leaves = c(31, 63, 127), min_data_in_leaf = c(5, 10, 20), feature_fraction = c(0.5, 0.8), lambda_l2 = 1)
)

dir.create("resultados/tuning", recursive = TRUE, showWarnings = FALSE)
for (metodo in metodos) {
  grade <- grades[[metodo]]
  arq <- sprintf("resultados/tuning/tuning_%s_%d.csv", metodo, bloco)
  if (file.exists(arq)) file.remove(arq)
  for (i in which((seq_len(nrow(grade)) - 1) %% nblocos == (bloco - 1))) {
    g <- as.list(grade[i, , drop = FALSE]); t0 <- Sys.time()
    if (metodo == "rf") {
      oof <- numeric(n)
      for (k in 1:5) oof[folds[[k]]] <- MODELOS$RF(c(g, num.trees = 500, threads = threads),
                                                    parte(B$tr, -folds[[k]]), parte(B$tr, folds[[k]]))
      best_iter <- 500; score <- rmse(y, oof)
    } else if (metodo == "xgb") {
      p <- c(list(objective = "reg:squarederror", eta = 0.02, subsample = 0.8, nthread = threads, seed = 1), g)
      cv <- xgb.cv(params = p, data = xgb.DMatrix(X, label = y), nrounds = 6000, folds = folds,
                   early_stopping_rounds = 300, verbose = 0)
      best_iter <- if (!is.null(cv$early_stop$best_iteration)) cv$early_stop$best_iteration else cv$best_iteration
      score <- min(cv$evaluation_log$test_rmse_mean)
    } else {
      p <- c(list(objective = "regression", metric = "rmse", learning_rate = 0.02, bagging_fraction = 0.8,
                  bagging_freq = 1, seed = 1, verbose = -1, num_threads = threads), g)
      cv <- lgb.cv(params = p, data = lgb.Dataset(X, label = y), nrounds = 6000, folds = folds,
                   early_stopping_rounds = 300, verbose = -1)
      best_iter <- cv$best_iter; score <- cv$best_score
    }
    linha <- data.frame(metodo = metodo, grade[i, , drop = FALSE], best_iter = best_iter,
                        rmse_cv = round(score, 3), segundos = round(as.numeric(difftime(Sys.time(), t0, units = "secs"))))
    fwrite(linha, arq, append = file.exists(arq))
    cat(sprintf("%s %s -> RMSE %.2f (%d árvores)\n", metodo, paste(names(g), g, sep = "=", collapse = " "), score, best_iter))
  }
}
