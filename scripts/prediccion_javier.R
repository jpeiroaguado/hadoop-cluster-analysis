# prediccion_javier.R
# Regresion lineal: cpu_usage ~ timestamp por nodo
# Autor: Javier Peiro | Practica 8.1 - IA i Big Data

library(ggplot2)

csv_path <- Sys.getenv("INPUT_CSV",  "/outputs/metricas_cluster.csv")
out_csv  <- Sys.getenv("OUTPUT_CSV", "/outputs/predicciones_javier.csv")
out_png  <- Sys.getenv("OUTPUT_PNG", "/outputs/prediccion_cpu_nodo.png")

cat("[INFO] Leyendo datos desde:", csv_path, "\n")
df <- read.csv(csv_path, stringsAsFactors = FALSE)
cat("[INFO] Filas cargadas:", nrow(df), "\n")

df$contenedor <- gsub('"', '', df$contenedor)

df$timestamp_raw <- as.POSIXct(paste(df$fecha, df$hora),
                                format = "%Y-%m-%d %H:%M:%S", tz = "UTC")
t0       <- min(df$timestamp_raw)
df$t_sec <- as.numeric(difftime(df$timestamp_raw, t0, units = "secs"))

nodos      <- unique(df$contenedor)
resultados <- list()

for (nodo in nodos) {
  sub    <- df[df$contenedor == nodo, ]
  modelo <- lm(cpu_usage ~ t_sec, data = sub)
  s      <- summary(modelo)

  cat("\n===", nodo, "===\n")
  print(s)

  pred       <- predict(modelo, newdata = sub, interval = "confidence", level = 0.95)
  sub$fit    <- pred[, "fit"]
  sub$lwr    <- pred[, "lwr"]
  sub$upr    <- pred[, "upr"]

  resultados[[nodo]] <- data.frame(
    contenedor = nodo,
    t_sec      = sub$t_sec,
    cpu_real   = sub$cpu_usage,
    fit        = sub$fit,
    lwr        = sub$lwr,
    upr        = sub$upr,
    intercept  = round(coef(modelo)[1], 4),
    pendiente  = round(coef(modelo)[2], 6),
    r_squared  = round(s$r.squared, 4),
    p_valor    = round(coef(s)[2, 4], 6)
  )
}

predicciones <- do.call(rbind, resultados)
write.csv(predicciones, out_csv, row.names = FALSE)
cat("\n[DONE] Predicciones guardadas en:", out_csv, "\n")

p <- ggplot(predicciones, aes(x = t_sec / 60, y = cpu_real, color = contenedor)) +
  geom_point(alpha = 0.35, size = 1.0) +
  geom_line(aes(y = fit), linewidth = 1.1) +
  geom_ribbon(aes(ymin = lwr, ymax = upr, fill = contenedor), alpha = 0.12, color = NA) +
  labs(
    title    = "Prediccion de uso de CPU por nodo (Regresion Lineal)",
    subtitle = "Datos reales + linea de regresion con intervalo de confianza al 95%",
    x        = "Tiempo desde inicio (minutos)",
    y        = "CPU GC (ms/s)",
    color    = "Nodo",
    fill     = "Nodo"
  ) +
  theme_minimal(base_size = 12) +
  theme(legend.position = "bottom")

ggsave(out_png, plot = p, width = 10, height = 6, dpi = 150)
cat("[DONE] Grafico guardado en:", out_png, "\n")
