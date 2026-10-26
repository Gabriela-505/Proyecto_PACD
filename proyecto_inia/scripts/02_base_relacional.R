# 02 - Base relacional y consultas SQL
# Entrada: data/processed/inia_mensual.csv y los catalogos de data/raw/.
# Salida: data/processed/inia.sqlite y los resultados de sql/consultas.sql
#         en outputs/tables/sql_<nombre>.csv

source("R/configuracion.R")
source("R/funciones.R")

mensual <- read_csv(file.path(rutas$processed, "inia_mensual.csv"), show_col_types = FALSE)

# Los catalogos se normalizan igual que en 01 para que la clave coincida.
estaciones <- read_csv(file.path(rutas$raw, "EstacionAgr.csv"), show_col_types = FALSE) %>%
  transmute(
    estacion = recode(stringi::stri_trans_nfc(EstacionAgr), !!!correcciones_nombre),
    DepartamentoCodigo
  )
departamentos <- read_delim(file.path(rutas$raw, "Departamentos.csv"),
                            delim = ";", show_col_types = FALSE)

# SQLite no tiene tipo fecha ni logico: se guardan como texto y entero.
mensual_sql <- mensual %>%
  transmute(
    estacion, mes = format(mes), anio, numero_mes,
    precipitacion, eto, balance, cobertura,
    mes_valido = as.integer(mes_valido)
  )

# La base se reconstruye en cada ejecucion: nunca se edita a mano.
if (file.exists(rutas$sqlite)) file.remove(rutas$sqlite)
con <- dbConnect(RSQLite::SQLite(), rutas$sqlite)

dbWriteTable(con, "departamentos", departamentos)
dbWriteTable(con, "estaciones", estaciones)
dbWriteTable(con, "mensual", mensual_sql)

# Validacion de la estructura relacional: toda fila mensual debe encontrar su
# estacion y su departamento. Un LEFT JOIN con NULL indicaria una clave rota.
huerfanas <- dbGetQuery(con, "
  SELECT COUNT(*) AS n
  FROM mensual AS m
  LEFT JOIN estaciones AS e ON e.estacion = m.estacion
  LEFT JOIN departamentos AS d ON d.DepartamentoCodigo = e.DepartamentoCodigo
  WHERE d.DepartamentoCodigo IS NULL
")
if (huerfanas$n > 0) {
  dbDisconnect(con)
  stop(huerfanas$n, " filas mensuales sin estacion o departamento en la base SQL.",
       call. = FALSE)
}

# Separa el archivo .sql en consultas usando las lineas "-- name: <nombre>".
leer_consultas_sql <- function(archivo) {
  lineas <- readLines(archivo, encoding = "UTF-8")
  inicios <- grep("^-- name:", lineas)
  nombres <- str_trim(str_remove(lineas[inicios], "^-- name:"))
  finales <- c(inicios[-1] - 1, length(lineas))
  consultas <- map2_chr(inicios, finales, ~ paste(lineas[(.x + 1):.y], collapse = "\n"))
  set_names(consultas, nombres)
}

consultas <- leer_consultas_sql(rutas$consultas)

# map ejecuta cada consulta; walk2 guarda cada resultado con su nombre.
resultados_sql <- map(consultas, ~ dbGetQuery(con, .x))
walk2(resultados_sql, names(resultados_sql),
      ~ exportar_tabla(.x, file.path(rutas$tablas, paste0("sql_", .y, ".csv"))))

dbDisconnect(con)

print(resultados_sql$meses_mas_secos)
print(resultados_sql$sequia_2022_2023)
cat("\nBase relacional creada en", rutas$sqlite, "con",
    length(resultados_sql), "consultas exportadas.\n")
