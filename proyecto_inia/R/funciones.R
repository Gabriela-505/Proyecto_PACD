# Funciones reutilizables del proyecto.
# Los scripts describen el flujo; aqui se encapsulan las tareas que se repiten.

# -----------------------------------------------------------------------------
# Validaciones
# -----------------------------------------------------------------------------

# Validacion de estructura: detiene el pipeline si falta alguna columna necesaria.
# Devuelve TRUE invisible para poder encadenarla sin imprimir nada.
validar_columnas <- function(datos, columnas, nombre_tabla) {
  faltantes <- setdiff(columnas, names(datos))
  if (length(faltantes) > 0) {
    stop("Tabla ", nombre_tabla, ": faltan columnas: ",
         paste(faltantes, collapse = ", "), call. = FALSE)
  }
  invisible(TRUE)
}

# Validacion de calidad para una estacion. Recibe la tabla diaria de una sola
# estacion (sin limpiar) y devuelve una fila con el conteo de cada problema.
diagnosticar_estacion <- function(tabla) {
  tibble(
    estacion = first(tabla$estacion),
    departamento = first(tabla$departamento),
    registros = nrow(tabla),
    fecha_inicio = min(tabla$fecha),
    fecha_fin = max(tabla$fecha),
    dias_esperados = as.integer(max(tabla$fecha) - min(tabla$fecha)) + 1L,
    dias_ausentes = dias_esperados - n_distinct(tabla$fecha),
    fechas_duplicadas = sum(duplicated(tabla$fecha)),
    # Temperatura y humedad en 0 a la vez no es fisicamente plausible:
    # es la forma en que la fuente registra un dato faltante.
    ceros_como_faltante = sum(tabla$temp_media == 0 & tabla$hr_media == 0, na.rm = TRUE),
    hr_fuera_rango = sum(tabla$hr_media < 0 | tabla$hr_media > 100, na.rm = TRUE),
    precipitacion_negativa = sum(tabla$precipitacion < 0, na.rm = TRUE),
    eto_negativa = sum(tabla$eto < 0, na.rm = TRUE),
    tmax_menor_tmin = sum(tabla$temp_max < tabla$temp_min, na.rm = TRUE),
    llovio_inconsistente = sum((tabla$precipitacion > 0) != (tabla$llovio == 1), na.rm = TRUE),
    faltantes_precipitacion = sum(is.na(tabla$precipitacion)),
    faltantes_eto = sum(is.na(tabla$eto))
  )
}

# -----------------------------------------------------------------------------
# Limpieza
# -----------------------------------------------------------------------------

# Aplica las reglas de limpieza documentadas en el informe. No elimina filas:
# los valores invalidos pasan a NA para que la cobertura los cuente como ausentes.
limpiar_inia <- function(datos) {
  datos %>%
    mutate(
      cero_como_faltante = temp_media == 0 & hr_media == 0,
      temp_media = if_else(cero_como_faltante, NA_real_, temp_media),
      hr_media = if_else(cero_como_faltante | hr_media < 0 | hr_media > 100,
                         NA_real_, hr_media),
      eto = if_else(eto < 0, NA_real_, eto),
      balance = precipitacion - eto
    ) %>%
    select(-cero_como_faltante)
}

# -----------------------------------------------------------------------------
# Agregacion temporal
# -----------------------------------------------------------------------------

# sum(..., na.rm = TRUE) devuelve 0 si todo es NA. Esta version conserva la
# ausencia total de informacion como NA (clase de analisis temporal, 16.6).
sumar_si_hay_datos <- function(x) {
  if (all(is.na(x))) return(NA_real_)
  sum(x, na.rm = TRUE)
}

media_si_hay_datos <- function(x) {
  if (all(is.na(x))) return(NA_real_)
  mean(x, na.rm = TRUE)
}

# Resumen mensual de una estacion. Recibe la tabla diaria de una estacion y
# devuelve una fila por mes, incluyendo los meses sin ningun registro
# (complete), con su cobertura y una marca de validez.
resumir_mensual <- function(tabla, cobertura_minima = 0.80) {
  tabla %>%
    mutate(mes = floor_date(fecha, "month")) %>%
    group_by(mes) %>%
    summarise(
      dias_registrados = n(),
      dias_con_balance = sum(!is.na(balance)),
      # summarise calcula en orden: los conteos diarios van antes de que
      # precipitacion pase a ser la suma del mes.
      dias_lluvia = sum(precipitacion > 0, na.rm = TRUE),
      precipitacion = sumar_si_hay_datos(precipitacion),
      eto = sumar_si_hay_datos(eto),
      balance = sumar_si_hay_datos(balance),
      temp_media = media_si_hay_datos(temp_media),
      .groups = "drop"
    ) %>%
    complete(
      mes = seq(min(mes), max(mes), by = "month"),
      fill = list(dias_registrados = 0L, dias_con_balance = 0L, dias_lluvia = 0L)
    ) %>%
    mutate(
      anio = year(mes),
      numero_mes = month(mes),
      dias_esperados = days_in_month(mes),
      cobertura = dias_con_balance / dias_esperados,
      mes_valido = cobertura >= cobertura_minima
    )
}

# Agrega anomalias, variacion mensual y balance acumulado movil a la serie
# mensual de una estacion. Los meses no validos no participan en ningun calculo.
calcular_indicadores <- function(mensual, ventana = 12) {
  mensual %>%
    arrange(mes) %>%
    mutate(balance_valido = if_else(mes_valido, balance, NA_real_)) %>%
    group_by(numero_mes) %>%
    mutate(balance_normal = mean(balance_valido, na.rm = TRUE)) %>%
    ungroup() %>%
    arrange(mes) %>%
    mutate(
      anomalia = balance_valido - balance_normal,
      variacion_mes_anterior = balance_valido - lag(balance_valido),
      # sum() sin na.rm: si algun mes de la ventana falta, el acumulado queda NA.
      balance_acumulado = slide_dbl(balance_valido, sum,
                                    .before = ventana - 1, .complete = TRUE)
    )
}

# -----------------------------------------------------------------------------
# Modelos
# -----------------------------------------------------------------------------

# Tendencia lineal descriptiva del balance anual. Devuelve NULL si no hay
# suficientes anios: possibly() y la columna estado registran ese caso.
ajustar_tendencia <- function(tabla, anios_minimos = 5) {
  datos_modelo <- tabla %>% filter(!is.na(balance_anual))
  if (nrow(datos_modelo) < anios_minimos) return(NULL)
  lm(balance_anual ~ anio, data = datos_modelo)
}

ajustar_tendencia_segura <- possibly(ajustar_tendencia, otherwise = NULL)

# -----------------------------------------------------------------------------
# Graficos y archivos
# -----------------------------------------------------------------------------

# Exporta una tabla redondeando los numeros decimales. Evita que en los CSV
# aparezcan restos de punto flotante como -874.8000000000001. Se usan 6
# decimales para que el informe, que vuelve a redondear (por ejemplo un valor p
# a 3 decimales), no sufra un doble redondeo (0.917506 -> 0.9175 -> 0.917).
exportar_tabla <- function(tabla, archivo, digitos = 6) {
  tabla %>%
    mutate(across(where(is.double), ~ round(.x, digitos))) %>%
    write_csv(archivo)
  invisible(archivo)
}

normalizar_nombre_archivo <- function(texto) {
  texto %>%
    iconv(from = "UTF-8", to = "ASCII//TRANSLIT") %>%
    str_to_lower() %>%
    str_replace_all("[^a-z0-9]+", "_") %>%
    str_remove_all("^_|_$")
}

guardar_figura <- function(grafico, nombre, carpeta, ancho = 10, alto = 6) {
  archivo <- file.path(carpeta, nombre)
  ggsave(archivo, grafico, width = ancho, height = alto, dpi = 200, bg = "white")
  invisible(archivo)
}

# Grafico de una estacion: barras del balance mensual y linea del acumulado movil.
graficar_balance_estacion <- function(mensual, nombre_estacion) {
  datos_estacion <- mensual %>% filter(estacion == nombre_estacion)

  ggplot(datos_estacion, aes(x = mes)) +
    geom_col(aes(y = balance_valido, fill = balance_valido < 0), width = 25, na.rm = TRUE) +
    geom_line(aes(y = balance_acumulado / 12, color = "Acumulado de 12 meses (promedio mensual)"),
              linewidth = 0.9, na.rm = TRUE) +
    geom_hline(yintercept = 0, color = colores$secundario) +
    scale_fill_manual(values = c(`TRUE` = colores$deficit, `FALSE` = colores$excedente),
                      labels = c(`TRUE` = "Déficit", `FALSE` = "Excedente"),
                      na.translate = FALSE) +
    scale_color_manual(values = colores$texto) +
    scale_x_date(date_breaks = "1 year", date_labels = "%Y") +
    labs(
      title = paste("Balance hídrico mensual –", nombre_estacion),
      subtitle = "Precipitación − evapotranspiración Penman. Se omiten los meses con cobertura menor al 80 %.",
      x = NULL, y = "mm", fill = NULL, color = NULL
    ) +
    theme(panel.grid.major.x = element_blank())
}
