###############################################################
# DesceCluster | TRA-48 | Projeto B2
# 02_exploracao.R: análise exploratória (estatísticas e gráficos)
#
# Saídas: resultados/estatisticas_descritivas.txt
#         resultados/figuras/01_ ... 09_*.png
###############################################################

if (basename(getwd()) == "scripts") setwd("..")
suppressPackageStartupMessages({ library(data.table); library(corrplot) })

load("dados/data_features.Rda")
d <- copy(train)
d[, taxi_min := taxitime / 60]
d[, hora_int := floor(hora)]
d[, destino_tipo := factor(ifelse(domestico == 1, "Doméstico", "Internacional"))]
dir.create("resultados/figuras", recursive = TRUE, showWarnings = FALSE)
fig <- function(nome, w = 1000, h = 600) png(file.path("resultados/figuras", nome), width = w, height = h, res = 115)

# ------------------------------------------------------------
# Estatísticas descritivas
# ------------------------------------------------------------
resumo <- function(by) d[, .(N = .N, media_s = round(mean(taxitime), 1), mediana_s = round(median(taxitime), 1),
                             dp_s = round(sd(taxitime), 1)), by = by][order(-N)]
num <- c("taxitime", "nactive", "push_10", "push_20", "push_30", "push_60", "gap_push",
         "wind_speed", "vento_proa", "vento_cruzado", "wx", "hora_sin", "hora_cos", "domestico")
sink("resultados/estatisticas_descritivas.txt")
cat("BASE DE TREINO:", nrow(d), "voos | BASE DE TESTE:", nrow(test), "voos\n\n")
cat("=== taxitime (s) ===\n"); print(summary(d$taxitime)); cat("desvio padrão:", round(sd(d$taxitime), 1), "\n\n")
cat("=== por cabeceira ===\n");            print(resumo("runway"))
cat("\n=== por categoria de esteira ===\n"); print(resumo("wtc"))
cat("\n=== doméstico x internacional ===\n"); print(resumo("destino_tipo"))
cat("\n=== por companhia aérea ===\n");    print(resumo("airline"))
cat("\n=== por tipo de aeronave ===\n");   print(resumo("acft"))
cat("\n=== por fenômeno meteorológico (wx) ===\n"); print(resumo("wx"))
cat("\n=== por dia da semana ===\n");      print(resumo("dia_semana"))
cat("\n=== variáveis numéricas ===\n");    print(summary(d[, ..num]))
cat("\n=== correlação de Pearson com o taxitime ===\n")
print(round(sort(cor(d[, ..num])[-1, 1], decreasing = TRUE), 3))
sink()

# ------------------------------------------------------------
# 01 Histograma e boxplot da variável resposta
# ------------------------------------------------------------
fig("01_histograma_taxitime.png", 1200, 550)
par(mfrow = c(1, 2))
hist(d$taxi_min, breaks = 50, col = "steelblue", border = "white",
     main = "Distribuição do tempo de táxi (treino)", xlab = "Tempo de táxi (min)", ylab = "Frequência")
abline(v = median(d$taxi_min), col = "red", lwd = 2, lty = 2)
boxplot(d$taxi_min, col = "steelblue", horizontal = TRUE, main = "Boxplot do tempo de táxi", xlab = "Tempo de táxi (min)")
dev.off()

# ------------------------------------------------------------
# 02-05 Boxplots por categorias
# ------------------------------------------------------------
fig("02_boxplot_cabeceira_esteira_destino.png", 1300, 520)
par(mfrow = c(1, 4))
boxplot(taxi_min ~ runway, d, col = c("#4C9BE8", "#E8954C"), main = "Cabeceira", xlab = "", ylab = "Tempo de táxi (min)")
boxplot(taxi_min ~ wtc, d, col = c("#9B59B6", "#2ECC71"), main = "Esteira de turbulência", xlab = "", ylab = "")
boxplot(taxi_min ~ destino_tipo, d, col = c("#F1C40F", "#E74C3C"), main = "Destino", xlab = "", ylab = "")
boxplot(taxi_min ~ wx, d, col = c("grey80", "#5D6D7E"), names = c("Sem", "Com"), main = "Chuva / baixa visib. (wx)", xlab = "", ylab = "")
dev.off()

fig("03_boxplot_companhia.png", 1100, 550)
ord <- d[, .(m = median(taxitime)), by = airline][order(m), airline]
boxplot(taxi_min ~ factor(airline, levels = ord), d, col = "lightblue", las = 2,
        main = "Tempo de táxi por companhia aérea", xlab = "", ylab = "Tempo de táxi (min)")
dev.off()

fig("04_boxplot_hora.png", 1200, 550)
boxplot(taxi_min ~ hora_int, d, col = "lightgreen", main = "Tempo de táxi por hora local do pushback",
        xlab = "Hora local (UTC-3)", ylab = "Tempo de táxi (min)")
dev.off()

fig("05_boxplot_nactive.png", 1200, 550)
boxplot(taxi_min ~ pmin(nactive, 16), d, col = "orange",
        main = "Tempo de táxi x aeronaves taxiando no pushback (nactive; 16 = 16 ou mais)",
        xlab = "nactive", ylab = "Tempo de táxi (min)")
dev.off()

# ------------------------------------------------------------
# 06-07 Scatterplots
# ------------------------------------------------------------
fig("06_scatter_nactive_push.png", 1300, 560)
par(mfrow = c(1, 2))
cor_rwy <- ifelse(d$runway == "10L", "#E74C3C", "#27AE60")
plot(jitter(d$nactive), d$taxi_min, pch = 16, cex = 0.4, col = adjustcolor(cor_rwy, 0.4),
     xlab = "nactive", ylab = "Tempo de táxi (min)", main = "Tempo de táxi x nactive, por cabeceira")
for (r in c("10L", "28R")) abline(lm(taxi_min ~ nactive, d[runway == r]), lwd = 2, col = ifelse(r == "10L", "#E74C3C", "#27AE60"))
legend("topleft", legend = c("10L", "28R"), col = c("#E74C3C", "#27AE60"), pch = 16, lwd = 2, title = "Cabeceira")
plot(jitter(d$push_20), d$taxi_min, pch = 16, cex = 0.4, col = adjustcolor("steelblue", 0.4),
     xlab = "Pushbacks nos 20 min anteriores", ylab = "Tempo de táxi (min)", main = "Tempo de táxi x pushbacks recentes")
abline(lm(taxi_min ~ push_20, d), col = "red", lwd = 2)
dev.off()

fig("07_scatterplot_matriz.png", 950, 950)
pairs(~ taxi_min + nactive + push_20 + push_60 + wind_speed, d, pch = 16, cex = 0.3,
      col = adjustcolor("steelblue", 0.3), labels = c("taxitime (min)", "nactive", "push_20", "push_60", "wind_speed"))
dev.off()

# ------------------------------------------------------------
# 08 Correlograma
# ------------------------------------------------------------
fig("08_correlograma.png", 900, 900)
corrplot(cor(d[, ..num]), method = "color", type = "upper", addCoef.col = "black",
         number.cex = 0.65, tl.col = "black", tl.cex = 0.8)
dev.off()

# ------------------------------------------------------------
# 09 Tipo de aeronave
# ------------------------------------------------------------
fig("09_boxplot_aeronave.png", 1200, 550)
ord <- d[, .(m = median(taxitime)), by = acft][order(m), acft]
boxplot(taxi_min ~ factor(acft, levels = ord), d, col = "#D7BDE2", las = 2,
        main = "Tempo de táxi por tipo de aeronave (tipos raros agrupados)", xlab = "", ylab = "Tempo de táxi (min)")
dev.off()

cat("02_exploracao: estatísticas e 9 figuras salvas em resultados/\n")
