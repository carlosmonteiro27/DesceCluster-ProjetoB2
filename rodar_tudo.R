###############################################################
# DesceCluster | TRA-48 | Projeto B2
# Executa o pipeline completo a partir da pasta raiz do projeto:
#   Rscript rodar_tudo.R
#
# 01_preparacao.R      features (dados/data_features.Rda)
# 02_exploracao.R      estatísticas e gráficos exploratórios
# 03_tuning_boosting.R busca de hiperparâmetros de RF/XGBoost/LightGBM
#                      (demorada; só roda se resultados/tuning/ estiver vazio)
# 04_modelos.R         comparação dos modelos por validação cruzada 5-fold
# 05_previsao.R        modelo final e arquivo de submissão
###############################################################

pacotes <- c("data.table", "rpart", "caret", "e1071", "nnet", "ranger", "xgboost", "lightgbm", "quadprog", "corrplot")
faltando <- pacotes[!vapply(pacotes, requireNamespace, logical(1), quietly = TRUE)]
if (length(faltando)) install.packages(faltando, repos = "https://cloud.r-project.org")

rodar <- function(s) {
  cat("\n==========", s, "==========\n")
  status <- system2(file.path(R.home("bin"), "Rscript"), file.path("scripts", s))
  if (status != 0) stop("falha em ", s)
}

rodar("01_preparacao.R")
rodar("02_exploracao.R")
if (!length(list.files("resultados/tuning", pattern = "\\.csv$"))) rodar("03_tuning_boosting.R")
rodar("04_modelos.R")
rodar("05_previsao.R")
cat("\nPipeline concluído. Submissão em submissao/data_project_test_grupoDesceCluster.Rda\n")
