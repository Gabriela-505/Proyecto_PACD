# 03 - Analisis temporal del balance hidrico
# Entrada: data/processed/inia_mensual.csv
# Salida: tablas de indicadores mensuales y anuales, y graficos en outputs/.

source("R/configuracion.R")
source("R/funciones.R")

mensual <- read_csv(file.path(rutas$processed, "inia_mensual.csv"), show_col_types = FALSE)

# --- 1. Indicadores mensuales por estacion (automatizado con map) -------------
# Cada estacion tiene su propio "mes normal", por eso las anomalias y el
# acumulado movil se calculan dentro de cada tabla anidada.
indicadores <- mensual %>%
  group_nest(estacion, departamento) %>%
  mutate(data = map(data, calcular_indicadores,
                    ventana = parametros$ventana_acumulado)) %>%
  unnest(data)

exportar_tabla(indicadores, file.path(rutas$tablas, "indicadores_mensuales.csv"))

# --- 2. Agregacion anual -------------------------------------------------------
# Un anio solo se compara si sus 12 meses son validos; asi 2026 (incompleto) y
# los anios con huecos de Glencore quedan fuera por regla y no a mano.
anual <- indicadores %>%
  group_by(estacion, departamento, anio) %>%
  summarise(
    meses_validos = sum(mes_valido),
    precipitacion_anual = sum(if_else(mes_valido, precipitacion, NA_real_)),
    eto_anual = sum(if_else(mes_valido, eto, NA_real_)),
    balance_anual = sum(balance_valido),
    dias_lluvia = sum(if_else(mes_valido, as.numeric(dias_lluvia), NA_real_)),
    .groups = "drop"
  ) %>%
  mutate(
    anio_completo = meses_validos >= parametros$meses_minimos_anio,
    across(c(precipitacion_anual, eto_anual, balance_anual, dias_lluvia),
           ~ if_else(anio_completo, .x, NA_real_))
  )

exportar_tabla(anual, file.path(rutas$tablas, "balance_anual.csv"))

# --- 3. Indicadores de sequia por estacion -------------------------------------
indicadores_sequia <- indicadores %>%
  group_by(estacion, departamento) %>%
  summarise(
    balance_acumulado_minimo = min(balance_acumulado, na.rm = TRUE),
    mes_del_minimo = mes[which.min(balance_acumulado)],
    meses_con_deficit_pct = mean(balance_valido < 0, na.rm = TRUE),
    anomalia_2022_2023 = sum(anomalia[anio %in% 2022:2023], na.rm = TRUE),
    .groups = "drop"
  ) %>%
  arrange(balance_acumulado_minimo)

exportar_tabla(indicadores_sequia, file.path(rutas$tablas, "indicadores_sequia.csv"))
print(indicadores_sequia, width = Inf)

# --- 4. Visualizaciones --------------------------------------------------------

# 4.1 Cobertura de datos: muestra donde la regla de calidad excluye meses.
# Se completa la grilla con todos los meses del periodo para cada estacion. Asi se
# distingue "la estacion existia pero no registro datos" (cobertura 0) de "la serie
# de esa estacion todavia no habia comenzado" (cobertura NA tras complete).
meses_periodo <- seq(min(indicadores$mes), max(indicadores$mes), by = "month")
niveles_estado <- c("Completo (80 % o más)", "Parcial (excluido)",
                    "Sin datos", "Antes del inicio de la serie")

datos_cobertura <- indicadores %>%
  select(estacion, mes, cobertura) %>%
  complete(estacion, mes = meses_periodo) %>%
  mutate(
    estado = case_when(
      is.na(cobertura) ~ niveles_estado[4],
      cobertura == 0 ~ niveles_estado[3],
      cobertura < parametros$cobertura_minima_mes ~ niveles_estado[2],
      TRUE ~ niveles_estado[1]
    ),
    estado = factor(estado, levels = niveles_estado),
    estacion = factor(estacion, levels = rev(sort(unique(estacion))))
  )

grafico_cobertura <- ggplot(datos_cobertura, aes(x = mes, y = estacion, fill = estado)) +
  # width = 31 dias: cubre meses de distinto largo sin dejar lineas blancas.
  geom_tile(height = 0.72, width = 31) +
  scale_fill_manual(
    values = setNames(c("#b9d7c0", "#e9a03b", colores$deficit, "#dcdcdc"), niveles_estado),
    drop = FALSE
  ) +
  scale_x_date(date_breaks = "1 year", date_labels = "%Y", expand = c(0, 0)) +
  labs(
    title = "Cobertura mensual de datos por estación",
    subtitle = "Un mes entra al análisis solo si al menos el 80 % de sus días tiene balance hídrico disponible",
    caption = paste0(
      "Glencore comienza en noviembre de 2016; sus meses parciales (oct. 2018, jul. 2020, feb. 2026) tienen parte de los días sin registro.\n",
      "Marzo de 2026 figura como parcial en todas las estaciones porque la base termina a mitad de ese mes."
    ),
    x = NULL, y = NULL, fill = NULL
  ) +
  theme(panel.grid = element_blank())
guardar_figura(grafico_cobertura, "cobertura_datos.png", rutas$figuras, ancho = 11, alto = 4.5)

# 4.2 Mapa de calor de anomalias: hace visibles los periodos secos y humedos.
grafico_anomalias <- indicadores %>%
  filter(mes_valido) %>%
  ggplot(aes(x = factor(numero_mes, levels = 1:12, labels = meses_abrev),
             y = factor(anio), fill = anomalia)) +
  geom_tile(color = "white", linewidth = 0.4) +
  facet_wrap(~ estacion, ncol = 3) +
  scale_fill_gradient2(low = colores$deficit, mid = colores$neutro, high = colores$excedente,
                       midpoint = 0, limits = c(-200, 200), oob = scales::squish,
                       breaks = c(-200, -100, 0, 100, 200),
                       labels = c("≤ −200", "−100", "0", "100", "≥ 200")) +
  guides(fill = guide_colorbar(barwidth = unit(18, "lines"), barheight = unit(0.6, "lines"),
                               title.position = "top")) +
  labs(title = "Anomalía del balance hídrico mensual",
       subtitle = "Diferencia respecto del promedio de ese mes en cada estación. Rojo: más seco que lo normal; azul: más húmedo.",
       x = NULL, y = NULL, fill = "Anomalía (mm)") +
  theme(panel.grid = element_blank(),
        axis.text.x = element_text(size = rel(0.75)))
guardar_figura(grafico_anomalias, "anomalias_balance_mensual.png", rutas$figuras,
               ancho = 12, alto = 8)

# 4.3 Balance acumulado de 12 meses: suaviza la serie y muestra sequias prolongadas.
# No se filtran los NA: asi geom_line corta la linea en los huecos (Glencore)
# en lugar de unir con una recta periodos sin informacion.
# Un panel por estacion: las areas roja y azul separan deficit y excedente.
grafico_acumulado <- indicadores %>%
  mutate(negativo = pmin(balance_acumulado, 0),
         positivo = pmax(balance_acumulado, 0)) %>%
  ggplot(aes(x = mes)) +
  annotate("rect", xmin = as.Date("2022-01-01"), xmax = as.Date("2023-12-31"),
           ymin = -Inf, ymax = Inf, fill = "grey85", alpha = 0.5) +
  geom_ribbon(aes(ymin = negativo, ymax = 0), fill = colores$deficit, alpha = 0.85, na.rm = TRUE) +
  geom_ribbon(aes(ymin = 0, ymax = positivo), fill = colores$excedente, alpha = 0.85, na.rm = TRUE) +
  geom_line(aes(y = balance_acumulado), color = colores$texto, linewidth = 0.35, na.rm = TRUE) +
  geom_hline(yintercept = 0, color = colores$texto, linewidth = 0.3) +
  facet_wrap(~ estacion, ncol = 2) +
  scale_x_date(date_breaks = "2 years", date_labels = "%Y") +
  labs(title = "Balance hídrico acumulado de los últimos 12 meses",
       subtitle = "Rojo: en el último año la evapotranspiración superó a la lluvia. Franja gris: 2022–2023.",
       caption = "Los cortes en la línea corresponden a meses excluidos por baja cobertura.",
       x = NULL, y = "mm")
guardar_figura(grafico_acumulado, "balance_acumulado_12m.png", rutas$figuras, ancho = 11, alto = 8)

# 4.4 Balance anual por estacion (solo anios completos).
grafico_anual <- anual %>%
  filter(anio_completo) %>%
  ggplot(aes(x = anio, y = balance_anual, fill = balance_anual < 0)) +
  geom_col(width = 0.75) +
  geom_hline(yintercept = 0, color = colores$texto, linewidth = 0.3) +
  facet_wrap(~ estacion, ncol = 3) +
  scale_fill_manual(values = c(`TRUE` = colores$deficit, `FALSE` = colores$excedente),
                    labels = c(`TRUE` = "Déficit", `FALSE` = "Excedente")) +
  scale_x_continuous(breaks = 2016:2025, labels = function(x) paste0("'", substr(x, 3, 4))) +
  labs(title = "Balance hídrico anual por estación",
       subtitle = "Solo años con sus 12 meses válidos",
       x = NULL, y = "mm", fill = NULL) +
  theme(panel.grid.major.x = element_blank())
guardar_figura(grafico_anual, "balance_anual.png", rutas$figuras, ancho = 12, alto = 7)

# 4.5 Un grafico por estacion: walk ejecuta la accion de guardar para cada una.
estaciones <- sort(unique(indicadores$estacion))
walk(estaciones, function(nombre) {
  guardar_figura(
    graficar_balance_estacion(indicadores, nombre),
    paste0("balance_", normalizar_nombre_archivo(nombre), ".png"),
    rutas$figuras_estacion, ancho = 11, alto = 5
  )
})

cat("\nAnalisis temporal finalizado:", length(estaciones), "estaciones.\n")
