# Configuracion comun: la cargan todos los scripts al comenzar.
# Centraliza paquetes, caminos y parametros para que no se repitan en cada archivo.

if (!file.exists("run_all.R")) {
  stop("Ejecutar desde la carpeta raiz del proyecto (donde esta run_all.R).", call. = FALSE)
}

# Primero se busca en la libreria local del proyecto (ver scripts/00_paquetes.R).
if (dir.exists("r_packages")) .libPaths(c(normalizePath("r_packages"), .libPaths()))

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(tidyr)
  library(lubridate)
  library(purrr)
  library(tibble)
  library(stringr)
  library(ggplot2)
  library(slider)
  library(broom)
  library(DBI)
  library(RSQLite)
})

# Caminos relativos: describen donde esta cada archivo dentro del proyecto.
rutas <- list(
  raw = "data/raw",
  processed = "data/processed",
  tablas = "outputs/tables",
  figuras = "outputs/figures",
  figuras_estacion = "outputs/figures/por_estacion",
  sqlite = "data/processed/inia.sqlite",
  consultas = "sql/consultas.sql"
)
walk(rutas[c("processed", "tablas", "figuras", "figuras_estacion")],
     dir.create, recursive = TRUE, showWarnings = FALSE)

# Parametros de las reglas de calidad. Cambiarlos aqui modifica todo el pipeline.
parametros <- list(
  cobertura_minima_mes = 0.80,   # un mes se usa si tiene al menos 80% de dias con balance
  meses_minimos_anio = 12,       # un anio se compara solo si sus 12 meses son validos
  anios_minimos_tendencia = 5,   # minimo de anios para ajustar una tendencia lineal
  ventana_acumulado = 12         # meses del balance acumulado movil
)

# Correccion de nombre: el catalogo y INIA.csv escriben "Tacuaremnó" (errata).
# La clave original se usa para el join y despues se corrige la etiqueta.
correcciones_nombre <- c("Tacuaremnó Glencore" = "Tacuarembó Glencore")

# Estilo comun de todos los graficos: mismo tema y misma paleta en todo el informe.
colores <- list(
  deficit = "#c2483b",
  excedente = "#2f6f9f",
  neutro = "#f7f7f7",
  texto = "#2b2b2b",
  secundario = "#6b6b6b"
)

theme_informe <- function(base_size = 12) {
  theme_minimal(base_size = base_size) +
    theme(
      plot.title = element_text(face = "bold", size = rel(1.2), color = colores$texto),
      plot.subtitle = element_text(color = colores$secundario, margin = margin(b = 10)),
      plot.caption = element_text(color = colores$secundario, size = rel(0.8), hjust = 0),
      plot.title.position = "plot",
      plot.caption.position = "plot",
      strip.text = element_text(face = "bold", hjust = 0, size = rel(0.95)),
      panel.grid.minor = element_blank(),
      legend.position = "bottom",
      legend.title = element_text(size = rel(0.9)),
      plot.margin = margin(12, 16, 12, 12)
    )
}
theme_set(theme_informe())

# Etiquetas cortas de meses en espanol, independientes del idioma del sistema.
meses_abrev <- c("Ene", "Feb", "Mar", "Abr", "May", "Jun",
                 "Jul", "Ago", "Sep", "Oct", "Nov", "Dic")
