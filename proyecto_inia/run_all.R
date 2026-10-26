# Ejecuta el proyecto completo desde los datos originales hasta el informe.
# Uso (desde la carpeta raiz del proyecto):
#   Rscript run_all.R
# o, en RGui, con el directorio de trabajo en la raiz del proyecto:
#   source("run_all.R")

scripts <- c(
  "scripts/00_paquetes.R",
  "scripts/01_preparar_datos.R",
  "scripts/02_base_relacional.R",
  "scripts/03_analisis_temporal.R",
  "scripts/04_tendencias.R"
)

# Cada script se ejecuta en un entorno nuevo: no depende de objetos que haya
# dejado otro script, solo de los archivos que este escribio en disco.
for (script in scripts) {
  cat("\n==============================\n", script, "\n==============================\n")
  source(script, local = new.env(), echo = FALSE)
}

# --- Informe Quarto ------------------------------------------------------------
.libPaths(c(normalizePath("r_packages"), .libPaths()))

# Quarto ejecuta el informe en un proceso de R aparte: R_LIBS le indica que
# tambien busque paquetes en la libreria local del proyecto.
Sys.setenv(R_LIBS = paste(c(normalizePath("r_packages"), Sys.getenv("R_LIBS")),
                          collapse = .Platform$path.sep))

# Si R se abrio antes de instalar Quarto, el PATH de la sesion no lo incluye.
# En ese caso se busca en las ubicaciones habituales y se informa via QUARTO_PATH.
if (Sys.which("quarto") == "" && Sys.getenv("QUARTO_PATH") == "") {
  candidatos <- c(
    file.path(Sys.getenv("LOCALAPPDATA"), "Programs", "Quarto", "bin", "quarto.exe"),
    file.path(Sys.getenv("ProgramFiles"), "Quarto", "bin", "quarto.exe"),
    "/usr/local/bin/quarto",
    "/Applications/quarto/bin/quarto"
  )
  encontrado <- candidatos[file.exists(candidatos)]
  if (length(encontrado) > 0) Sys.setenv(QUARTO_PATH = encontrado[1])
}

if (quarto::quarto_available()) {
  quarto::quarto_render("report/informe.qmd")
  cat("\nInforme generado: report/informe.html\n")
} else {
  warning(
    "No se encontro Quarto. Instalarlo desde https://quarto.org/docs/get-started/ ",
    "y volver a ejecutar run_all.R para generar report/informe.html.",
    call. = FALSE
  )
}

writeLines(capture.output(sessionInfo()), "outputs/sessionInfo.txt")
cat("\nPipeline finalizado.\n")
