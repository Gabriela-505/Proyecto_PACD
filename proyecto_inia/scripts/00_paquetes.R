# 00 - Verificacion e instalacion de paquetes
# Los paquetes se instalan en la carpeta local r_packages/ del proyecto, igual que
# en las actividades del curso. Asi el proyecto no depende de la libreria global.

dir.create("r_packages", showWarnings = FALSE)
.libPaths(c(normalizePath("r_packages"), .libPaths()))

paquetes <- c(
  "dplyr", "readr", "tidyr", "lubridate", "purrr", "tibble", "stringr",
  "ggplot2", "slider", "broom", "DBI", "RSQLite",
  "quarto", "rmarkdown", "knitr"
)

# vapply recorre los nombres y devuelve TRUE si el paquete ya esta disponible.
faltan <- paquetes[!vapply(paquetes, requireNamespace, logical(1), quietly = TRUE)]

if (length(faltan) > 0) {
  cat("Instalando:", paste(faltan, collapse = ", "), "\n")
  install.packages(
    faltan,
    lib = normalizePath("r_packages"),
    repos = "https://cloud.r-project.org",
    type = "binary"
  )
}

faltan <- paquetes[!vapply(paquetes, requireNamespace, logical(1), quietly = TRUE)]
if (length(faltan) > 0) {
  stop("No se pudieron instalar: ", paste(faltan, collapse = ", "), call. = FALSE)
}

cat("Todos los paquetes estan disponibles.\n")
