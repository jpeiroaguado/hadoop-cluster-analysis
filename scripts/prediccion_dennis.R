# ================================
# Predicción Dennis - R + ggplot2
# ================================
setwd("C:/Users/Dennis/proyecto-bigdata/hadoop-cluster-analysis")

# Instalar paquetes si no existen
paquetes <- c("readr", "dplyr", "ggplot2")

for (p in paquetes) {
  if (!require(p, character.only = TRUE)) {
    install.packages(p)
    library(p, character.only = TRUE)
  }
}

# Crear carpeta de salida si no existe
if (!dir.exists("outputs")) {
  dir.create("outputs")
}

# Cargar CSV del proyecto
datos <- read_csv("datos_electricidad_bueno.csv")

# Revisar nombres de columnas
print(names(datos))

# Limpiar datos
datos_limpios <- datos %>%
  filter(!is.na(consumo), !is.na(hora_dia)) %>%
  mutate(
    consumo = as.numeric(consumo),
    hora_dia = as.numeric(hora_dia)
  )

# Agrupar por hora para reducir ruido
datos_hora <- datos_limpios %>%
  group_by(hora_dia) %>%
  summarise(
    consumo_medio = mean(consumo, na.rm = TRUE),
    generacion_media = mean(generacion, na.rm = TRUE),
    registros = n()
  ) %>%
  ungroup()

# Modelo de regresión lineal
modelo <- lm(consumo_medio ~ hora_dia, data = datos_hora)

# Mostrar resumen del modelo
print(summary(modelo))

# Generar predicciones con intervalo de confianza
predicciones <- predict(modelo, interval = "confidence")

datos_pred <- cbind(datos_hora, predicciones)

# Guardar predicciones en CSV
write_csv(datos_pred, "outputs/predicciones_dennis.csv")

# Gráfico con ggplot2
grafico <- ggplot(datos_pred, aes(x = hora_dia, y = consumo_medio)) +
  geom_point(size = 2) +
  geom_line() +
  geom_smooth(method = "lm", se = TRUE) +
  labs(
    title = "Predicción del consumo medio por hora",
    subtitle = "Modelo de regresión lineal con intervalo de confianza",
    x = "Hora del día",
    y = "Consumo medio"
  ) +
  theme_minimal()

# Mostrar gráfico
print(grafico)

# Guardar gráfico
ggsave(
  filename = "outputs/prediccion_consumo_hora.png",
  plot = grafico,
  width = 10,
  height = 6
)

cat("Predicción finalizada correctamente.\n")
cat("Archivos generados:\n")
cat("- outputs/predicciones_dennis.csv\n")
cat("- outputs/prediccion_consumo_hora.png\n")