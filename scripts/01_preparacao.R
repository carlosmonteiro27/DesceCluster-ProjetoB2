###############################################################
# DesceCluster | TRA-48 | Projeto B2
# 01_preparacao.R: pré-processamento e construção das features
#
# Regra adotada: toda feature usa somente informação disponível
# no instante do pushback (cpush). O horário de decolagem (crwy)
# não é usado, pois só é conhecido depois do táxi.
#
# Entrada: dados/data_project.Rda (data_train, data_test)
# Saída:   dados/data_features.Rda (train, test, feats)
###############################################################

if (basename(getwd()) == "scripts") setwd("..")
suppressPackageStartupMessages(library(data.table))

load("dados/data_project.Rda")
tr  <- copy(as.data.table(data_train))[, base := "treino"]
te  <- copy(as.data.table(data_test))[,  base := "teste"]
all <- rbind(tr, te)
setorder(all, cpush)
t <- as.numeric(all$cpush)

# nº de elementos de v (ordenado) estritamente menores que x
n_antes <- function(x, v) findInterval(x, v, left.open = TRUE)

# ------------------------------------------------------------
# 1) Tempo (hora local de São Paulo, UTC-3)
# ------------------------------------------------------------
loc <- as.POSIXlt(all$cpush, tz = "America/Sao_Paulo")
all[, hora        := loc$hour + loc$min / 60 + loc$sec / 3600]
all[, hora_sin    := sin(2 * pi * hora / 24)]
all[, hora_cos    := cos(2 * pi * hora / 24)]
all[, dia_semana  := factor(loc$wday, levels = 0:6,
                            labels = c("dom", "seg", "ter", "qua", "qui", "sex", "sab"))]

# ------------------------------------------------------------
# 2) Destino, companhia e aeronave
# ------------------------------------------------------------
pref <- substr(as.character(all$ades), 1, 2)
all[, domestico := as.integer(pref %in% c("SB", "SD"))]
all[, regiao := factor(fcase(
  pref %in% c("SB", "SD"),                    "Brasil",
  substr(pref, 1, 1) == "S",                  "AmSul",
  substr(pref, 1, 1) %in% c("K", "C", "M", "T"), "AmNorte",
  substr(pref, 1, 1) %in% c("E", "L"),        "Europa",
  default =                                   "Outros"))]

# níveis raros (frequência no treino abaixo do mínimo) viram "OUTROS"
agrupa <- function(x, n_min) {
  x <- as.character(x)
  f <- table(x[all$base == "treino"])
  x[!(x %in% names(f)[f >= n_min])] <- "OUTROS"
  factor(x)
}
all[, acft    := agrupa(acfttype, 20)]
all[, destino := agrupa(ades, 40)]
all[, cia     := agrupa(airline, 30)]

# ------------------------------------------------------------
# 3) Vento decomposto em relação à cabeceira (10L ~ 095°, 28R ~ 275°)
# ------------------------------------------------------------
rumo <- ifelse(all$runway == "10L", 95, 275)
ang  <- (all$wind_direction - rumo) * pi / 180
all[, vento_proa    := wind_speed * cos(ang)]
all[, vento_cruzado := abs(wind_speed * sin(ang))]
all[wind_speed == 0, c("vento_proa", "vento_cruzado") := 0]

# ------------------------------------------------------------
# 4) Demanda: pushbacks anteriores (todos os voos, só o passado)
# ------------------------------------------------------------
for (W in c(10, 20, 30, 60))
  all[, paste0("push_", W) := n_antes(t, t) - n_antes(t - W * 60, t)]
all[, gap_push := pmin(c(3600, diff(t)), 3600)]   # s desde o pushback anterior

# ------------------------------------------------------------
# 5) Separação treino/teste (teste na ordem original de id)
# ------------------------------------------------------------
feats <- c("runway", "wtc", "cia", "acft", "destino", "regiao", "dia_semana",
           "domestico", "nactive", "hora", "hora_sin", "hora_cos",
           "wind_speed", "wind_direction", "vento_proa", "vento_cruzado", "wx",
           "push_10", "push_20", "push_30", "push_60", "gap_push")

train <- all[base == "treino"]
test  <- all[base == "teste"][match(data_test$id, id)]
stopifnot(identical(test$id, data_test$id), !anyNA(train[, ..feats]), !anyNA(test[, ..feats]))

save(train, test, feats, file = "dados/data_features.Rda")
cat("01_preparacao: treino", nrow(train), "| teste", nrow(test), "|", length(feats), "features\n")
