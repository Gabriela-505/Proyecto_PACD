# 04 - Tendencia lineal del balance anual por estacion
# Entrada: outputs/tables/balance_anual.csv (generado por 03).
# Salida: coeficientes y metricas de un modelo por estacion, y su grafico.
# La regresion se usa como herramienta descriptiva de tendencia, no como
# prediccion: con ~10 anios por estacion la incertidumbre es grande.

source("R/configuracion.R")
source("R/funciones.R")

anual <- read_csv(file.path(rutas$tablas, "balance_anual.csv"), show_col_types = FALSE) %>%
  filter(anio_completo)

# Un modelo por estacion: group_nest + map. La version segura devuelve NULL
# en lugar de detener el proceso, y la columna estado registra que paso.
modelos <- anual %>%
  group_nest(estacion, departamento) %>%
  mutate(
    anios_usados = map_int(data, nrow),
    modelo = map(data, ajustar_tendencia_segura,
                 anios_minimos = parametros$anios_minimos_tendencia),
    estado = map_chr(modelo, ~ if (is.null(.x)) "sin_modelo" else "ok")
  )

estado_modelos <- modelos %>% select(estacion, departamento, anios_usados, estado)
exportar_tabla(estado_modelos, file.path(rutas$tablas, "estado_modelos_tendencia.csv"))
print(estado_modelos)

modelos_ok <- modelos %>% filter(estado == "ok")

# broom::tidy y broom::glance convierten cada modelo en tablas comparables.
coeficientes <- modelos_ok %>%
  mutate(resultado = map(modelo, tidy, conf.int = TRUE)) %>%
  select(estacion, departamento, anios_usados, resultado) %>%
  unnest(resultado)

metricas <- modelos_ok %>%
  mutate(resultado = map(modelo, glance)) %>%
  select(estacion, departamento, anios_usados, resultado) %>%
  unnest(resultado) %>%
  select(estacion, departamento, anios_usados, r.squared, adj.r.squared, sigma, p.value, nobs)

# Tabla resumen: pendiente en mm por anio con su intervalo de confianza del 95%.
tendencias <- coeficientes %>%
  filter(term == "anio") %>%
  transmute(
    estacion, departamento, anios_usados,
    pendiente_mm_por_anio = estimate,
    ic_inferior = conf.low,
    ic_superior = conf.high,
    valor_p = p.value,
    interpretacion = if_else(
      ic_inferior > 0 | ic_superior < 0,
      "tendencia distinta de cero",
      "sin evidencia de tendencia lineal"
    )
  ) %>%
  arrange(pendiente_mm_por_anio)

exportar_tabla(coeficientes, file.path(rutas$tablas, "tendencias_coeficientes.csv"))
exportar_tabla(metricas, file.path(rutas$tablas, "tendencias_metricas.csv"))
exportar_tabla(tendencias, file.path(rutas$tablas, "tendencias_lm.csv"))
print(tendencias, width = Inf)

grafico_tendencias <- ggplot(anual, aes(x = anio, y = balance_anual)) +
  geom_hline(yintercept = 0, linetype = 2, color = colores$secundario) +
  geom_smooth(method = "lm", formula = y ~ x, se = TRUE,
              color = colores$excedente, fill = colores$excedente, alpha = 0.15) +
  geom_line(color = colores$secundario, alpha = 0.5) +
  geom_point(aes(color = balance_anual < 0), size = 2.2, show.legend = FALSE) +
  scale_color_manual(values = c(`TRUE` = colores$deficit, `FALSE` = colores$excedente)) +
  facet_wrap(~ estacion, ncol = 3) +
  scale_x_continuous(breaks = seq(2016, 2025, 2)) +
  labs(title = "Tendencia lineal del balance hídrico anual",
       subtitle = "Recta de regresión con banda de confianza del 95 %. Solo años completos.",
       x = NULL, y = "Balance anual (mm)")
guardar_figura(grafico_tendencias, "tendencias_balance_anual.png", rutas$figuras,
               ancho = 12, alto = 7)

cat("\nModelos ajustados:", nrow(modelos_ok), "de", nrow(modelos), "estaciones.\n")
