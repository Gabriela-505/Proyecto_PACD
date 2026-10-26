# 01 - Preparacion de datos
# Entrada: data/raw/ (INIA.csv y los catalogos de estaciones y departamentos).
# Salida: data/processed/inia_diario_limpio.csv, data/processed/inia_mensual.csv
#         y outputs/tables/control_calidad_por_estacion.csv

source("R/configuracion.R")
source("R/funciones.R")

# --- 1. Lectura de las fuentes originales ------------------------------------
inia <- read_csv(file.path(rutas$raw, "INIA.csv"), show_col_types = FALSE)
estaciones <- read_csv(file.path(rutas$raw, "EstacionAgr.csv"), show_col_types = FALSE)
departamentos <- read_delim(file.path(rutas$raw, "Departamentos.csv"),
                            delim = ";", show_col_types = FALSE)

# --- 2. Validacion de estructura ---------------------------------------------
columnas_inia <- c("Anio", "Mes", "Dia", "EstacionAgr", "PrecipAcum",
                   "EvapotranspPenman", "TempAireMedia", "TempAireMax",
                   "TempAireMin", "HRMed", "Llovio")
validar_columnas(inia, columnas_inia, "INIA")
validar_columnas(estaciones, c("EstacionAgr", "DepartamentoCodigo"), "EstacionAgr")
validar_columnas(departamentos, c("DepartamentoCodigo", "DepartamentoDescripcion"),
                 "Departamentos")

# Los nombres vienen con tildes en forma Unicode descompuesta (o + acento
# combinado). Se normalizan a la forma compuesta (NFC) en ambas tablas para que
# las comparaciones de texto y la correccion de nombres funcionen.
inia <- inia %>% mutate(EstacionAgr = stringi::stri_trans_nfc(EstacionAgr))
estaciones <- estaciones %>% mutate(EstacionAgr = stringi::stri_trans_nfc(EstacionAgr))

# Toda estacion de INIA debe existir en el catalogo; si no, el join dejaria NA.
sin_catalogo <- setdiff(unique(inia$EstacionAgr), estaciones$EstacionAgr)
if (length(sin_catalogo) > 0) {
  stop("Estaciones sin catalogo: ", paste(sin_catalogo, collapse = ", "), call. = FALSE)
}

# --- 3. Integracion y seleccion de variables ---------------------------------
diario <- inia %>%
  left_join(estaciones, by = "EstacionAgr") %>%
  left_join(departamentos, by = "DepartamentoCodigo") %>%
  transmute(
    fecha = make_date(Anio, Mes, Dia),
    estacion = recode(EstacionAgr, !!!correcciones_nombre),
    departamento = DepartamentoDescripcion,
    precipitacion = PrecipAcum,
    eto = EvapotranspPenman,
    temp_media = TempAireMedia,
    temp_max = TempAireMax,
    temp_min = TempAireMin,
    hr_media = HRMed,
    llovio = Llovio
  )

control_join <- diario %>%
  summarise(
    registros = n(),
    fechas_invalidas = sum(is.na(fecha)),
    sin_departamento = sum(is.na(departamento))
  )
if (control_join$fechas_invalidas > 0 || control_join$sin_departamento > 0) {
  stop("El join o la construccion de fechas produjo valores faltantes.", call. = FALSE)
}

# --- 4. Validacion de calidad por estacion (automatizada con map) ------------
# group_split separa la base en una tabla por estacion; map_dfr aplica el
# diagnostico a cada una y une las filas resultantes.
control_calidad <- diario %>%
  group_split(estacion) %>%
  map_dfr(diagnosticar_estacion)

exportar_tabla(control_calidad, file.path(rutas$tablas, "control_calidad_por_estacion.csv"))
print(control_calidad, width = Inf)

# Problemas fatales: invalidan el calculo del balance y detienen el pipeline.
if (sum(control_calidad$fechas_duplicadas) > 0) {
  stop("Hay fechas duplicadas dentro de una estacion.", call. = FALSE)
}
if (sum(control_calidad$precipitacion_negativa) > 0) {
  stop("Hay precipitaciones negativas.", call. = FALSE)
}

# --- 5. Limpieza y base diaria procesada -------------------------------------
diario_limpio <- limpiar_inia(diario)
exportar_tabla(diario_limpio, file.path(rutas$processed, "inia_diario_limpio.csv"))

# --- 6. Base mensual (automatizada por estacion) -----------------------------
# group_nest guarda la tabla de cada estacion en una columna de listas;
# map aplica resumir_mensual a cada tabla y unnest las vuelve a unir.
mensual <- diario_limpio %>%
  group_nest(estacion, departamento) %>%
  mutate(mensual = map(data, resumir_mensual,
                       cobertura_minima = parametros$cobertura_minima_mes)) %>%
  select(estacion, departamento, mensual) %>%
  unnest(mensual)

exportar_tabla(mensual, file.path(rutas$processed, "inia_mensual.csv"))

cobertura <- mensual %>%
  group_by(estacion) %>%
  summarise(
    meses_totales = n(),
    meses_validos = sum(mes_valido),
    meses_excluidos = sum(!mes_valido),
    cobertura_media = mean(cobertura),
    .groups = "drop"
  )
exportar_tabla(cobertura, file.path(rutas$tablas, "cobertura_por_estacion.csv"))

cat("\nPreparacion finalizada:", nrow(diario_limpio), "dias y",
    nrow(mensual), "meses-estacion.\n")
