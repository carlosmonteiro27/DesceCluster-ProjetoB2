###############################################################
# DesceCluster | TRA-48 | Projeto B2
# 00_funcoes.R: funções compartilhadas pelos scripts 03, 04 e 05
#   - métricas (RMSE, MAE, MAPE)
#   - conjuntos de variáveis e matrizes de entrada
#   - definição de cada modelo no formato "treina e prevê"
###############################################################

suppressPackageStartupMessages({
  library(data.table); library(rpart); library(caret); library(e1071)
  library(nnet); library(ranger); library(xgboost); library(lightgbm)
})

# ------------------------------------------------------------
# Métricas
# ------------------------------------------------------------
rmse <- function(y, p) sqrt(mean((y - p)^2))
mae  <- function(y, p) mean(abs(y - p))
mape <- function(y, p) 100 * mean(abs(y - p) / y)

# ------------------------------------------------------------
# Variáveis de entrada
# ------------------------------------------------------------
FEATS <- c("runway", "wtc", "cia", "acft", "destino", "regiao", "dia_semana",
           "domestico", "nactive", "hora", "hora_sin", "hora_cos",
           "wind_speed", "wind_direction", "vento_proa", "vento_cruzado", "wx",
           "push_10", "push_20", "push_30", "push_60", "gap_push")

# KNN: subconjunto reduzido (a distância euclidiana se dilui com muitas dummies)
FEATS_KNN <- c("runway", "wtc", "domestico", "nactive", "hora_sin", "hora_cos",
               "wx", "push_20", "cia", "regiao")

# Árvore e random forest: todas as variáveis
FORM_ARV <- as.formula(paste("taxitime ~", paste(FEATS, collapse = " + ")))

# Regressão linear: efeitos principais + interações com a cabeceira
FORM_LM <- taxitime ~ wtc + cia + acft + destino + regiao + dia_semana + domestico +
  wind_speed + vento_proa + vento_cruzado + wx + push_10 + push_30 + push_60 + gap_push +
  runway * (nactive + I(nactive^2) + hora_sin + hora_cos + sin(4 * pi * hora / 24) +
            cos(4 * pi * hora / 24) + cia + wtc + push_20) +
  wx:nactive + domestico:cia + nactive:(hora_sin + hora_cos)

# ------------------------------------------------------------
# Estrutura de dados usada pelos modelos
#   d  = data.table com as variáveis (modelos com fórmula)
#   X  = matriz one-hot de FEATS (SVM, rede neural, XGBoost, LightGBM)
#   XK = matriz one-hot de FEATS_KNN (KNN)
#   y  = taxitime (só no treino)
# ------------------------------------------------------------
prepara <- function(train, test) {
  dd <- rbind(train, test, fill = TRUE)
  X  <- model.matrix(~ . - 1, dd[, ..FEATS])
  XK <- model.matrix(~ . - 1, dd[, ..FEATS_KNN])
  i_tr <- seq_len(nrow(train)); i_te <- nrow(train) + seq_len(nrow(test))
  keep <- apply(X[i_tr, ], 2, sd) > 0
  list(tr = list(d = train, X = X[i_tr, keep], XK = XK[i_tr, ], y = train$taxitime),
       te = list(d = test,  X = X[i_te, keep], XK = XK[i_te, ]))
}
parte <- function(b, idx) list(d = b$d[idx], X = b$X[idx, , drop = FALSE],
                               XK = b$XK[idx, , drop = FALSE], y = b$y[idx])

# padroniza com média/desvio do treino, ignorando colunas constantes no treino
padroniza <- function(Xtr, Xnovo) {
  keep <- apply(Xtr, 2, sd) > 0
  pp <- preProcess(Xtr[, keep, drop = FALSE], method = c("center", "scale"))
  list(tr = predict(pp, Xtr[, keep, drop = FALSE]), novo = predict(pp, Xnovo[, keep, drop = FALSE]))
}

# ------------------------------------------------------------
# Modelos: cada função treina com "tr" e devolve a previsão para "novo"
# hp = lista de hiperparâmetros
# ------------------------------------------------------------
MODELOS <- list(

  # 1) Regressão linear múltipla
  LM = function(hp, tr, novo) {
    m <- lm(FORM_LM, data = tr$d)
    suppressWarnings(predict(m, novo$d))
  },

  # 2) Árvore de regressão (CART), podada pelo menor erro de validação cruzada interna
  ARVORE = function(hp, tr, novo) {
    set.seed(48)
    m <- rpart(FORM_ARV, data = tr$d, method = "anova",
               control = rpart.control(cp = 0, minsplit = hp$minsplit, xval = 10))
    cp <- m$cptable[which.min(m$cptable[, "xerror"]), "CP"]
    predict(prune(m, cp = cp), novo$d)
  },

  # 3) K-vizinhos mais próximos (média do taxitime dos k vizinhos)
  KNN = function(hp, tr, novo) {
    z <- padroniza(tr$XK, novo$XK)
    predict(knnreg(z$tr, tr$y, k = hp$k), z$novo)
  },

  # 4) Máquina de vetores de suporte para regressão (epsilon-SVR, kernel radial)
  SVM = function(hp, tr, novo) {
    z <- padroniza(tr$X, novo$X); mu <- mean(tr$y); s <- sd(tr$y)
    m <- svm(z$tr, (tr$y - mu) / s, type = "eps-regression", kernel = "radial",
             cost = hp$cost, gamma = hp$gamma_rel / ncol(z$tr), epsilon = hp$epsilon, scale = FALSE)
    as.numeric(predict(m, z$novo)) * s + mu
  },

  # 5) Rede neural artificial (1 camada escondida), média de várias inicializações
  RN = function(hp, tr, novo) {
    z <- padroniza(tr$X, novo$X); mu <- mean(tr$y); s <- sd(tr$y)
    rowMeans(sapply(seq_len(hp$seeds), function(r) {
      set.seed(r)
      m <- nnet(z$tr, (tr$y - mu) / s, size = hp$size, decay = hp$decay, linout = TRUE,
                maxit = hp$maxit, trace = FALSE, MaxNWts = 20000)
      as.numeric(predict(m, z$novo)) * s + mu
    }))
  },

  # 6) Random forest (ranger)
  RF = function(hp, tr, novo) {
    m <- ranger(FORM_ARV, data = tr$d, num.trees = hp$num.trees, mtry = hp$mtry,
                min.node.size = hp$min.node.size, num.threads = hp$threads, seed = 48)
    predict(m, novo$d, num.threads = hp$threads)$predictions
  },

  # 7) Gradient boosting: XGBoost (média de várias sementes)
  XGB = function(hp, tr, novo) {
    dtr <- xgb.DMatrix(tr$X, label = tr$y); dnv <- xgb.DMatrix(novo$X)
    rowMeans(sapply(seq_len(hp$seeds), function(s) {
      p <- list(objective = "reg:squarederror", eta = hp$eta, max_depth = hp$max_depth,
                min_child_weight = hp$min_child_weight, subsample = hp$subsample,
                colsample_bytree = hp$colsample_bytree, nthread = hp$threads, seed = s)
      m <- xgb.train(params = p, data = dtr, nrounds = hp$nrounds, verbose = 0)
      predict(m, dnv)
    }))
  },

  # 8) Gradient boosting: LightGBM (média de várias sementes)
  LGB = function(hp, tr, novo) {
    rowMeans(sapply(seq_len(hp$seeds), function(s) {
      p <- list(objective = "regression", learning_rate = hp$learning_rate, num_leaves = hp$num_leaves,
                min_data_in_leaf = hp$min_data_in_leaf, feature_fraction = hp$feature_fraction,
                bagging_fraction = 0.8, bagging_freq = 1, lambda_l2 = hp$lambda_l2, seed = s,
                deterministic = TRUE, force_row_wise = TRUE, verbose = -1, num_threads = hp$threads)
      m <- lgb.train(params = p, data = lgb.Dataset(tr$X, label = tr$y), nrounds = hp$nrounds, verbose = -1)
      predict(m, novo$X)
    }))
  }
)

# ------------------------------------------------------------
# Ensemble: pesos w >= 0 com soma 1 que minimizam ||y - P w||^2
# (programação quadrática resolvida com quadprog::solve.QP)
# ------------------------------------------------------------
pesos_ensemble <- function(P, y) {
  k <- ncol(P); Ps <- P / 1000; ys <- y / 1000           # escala só melhora o condicionamento
  D <- crossprod(Ps) / nrow(Ps); D <- D + diag(1e-10 * mean(diag(D)), k)
  d <- as.numeric(crossprod(Ps, ys) / nrow(Ps))
  sol <- quadprog::solve.QP(Dmat = D, dvec = d, Amat = cbind(rep(1, k), diag(k)),
                            bvec = c(1, rep(0, k)), meq = 1)$solution
  w <- pmax(sol, 0); w[w < 1e-3] <- 0; w <- w / sum(w)
  setNames(w, colnames(P))
}
