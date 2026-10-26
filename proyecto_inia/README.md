# Balance hídrico en estaciones INIA (2016–2025)

Proyecto reproducible de ciencia de datos – Programación Avanzada para Ciencias de Datos.

**Docente:** Marcelo Danessi

**Autores:** Alejandra Ramírez, Alvaro Barreto, Katerin Gonzalez y Gabriela Flores.

## Objetivo

Estudiar cómo se comportó el **balance hídrico climático** (precipitación − evapotranspiración Penman) en las estaciones agroclimáticas de INIA, qué tan intensa fue la sequía de 2022–2023 y si afectó por igual al sur y al norte del país.

## Datos

| Archivo (`data/raw/`) | Contenido |
|---|---|
| `INIA.csv` | Registros meteorológicos diarios de 6 estaciones (2016-01-01 a 2026-03-17) |
| `EstacionAgr.csv` | Catálogo estación → código de departamento |
| `Departamentos.csv` | Catálogo código → nombre de departamento (separado por `;`) |
| `Metadatos INIA.txt` | Definición de cada variable |

Los archivos de `data/raw/` no se modifican. Todo lo derivado lo genera el código.

## Estructura

```
proyecto_inia/
├── data/
│   ├── raw/                 datos originales
│   └── processed/           inia_diario_limpio.csv, inia_mensual.csv, inia.sqlite (generados)
├── R/
│   ├── configuracion.R      paquetes, caminos y parámetros comunes
│   └── funciones.R          funciones propias (validación, limpieza, agregación, modelos, gráficos)
├── scripts/
│   ├── 00_paquetes.R        instala los paquetes en r_packages/
│   ├── 01_preparar_datos.R  lectura, joins, validaciones, limpieza, bases procesadas
│   ├── 02_base_relacional.R base SQLite y consultas de sql/consultas.sql
│   ├── 03_analisis_temporal.R anomalías, acumulado móvil, agregación anual, gráficos
│   └── 04_tendencias.R      regresión lineal de tendencia por estación (map + broom)
├── sql/consultas.sql        consultas SQL con JOIN y GROUP BY
├── outputs/
│   ├── tables/              tablas de resultados (CSV)
│   └── figures/             gráficos (PNG); por_estacion/ con uno por estación
├── report/
│   ├── informe.qmd          informe Quarto (run_all.R genera informe.html)
│   ├── informe_rediseno.html versión con diseño alternativo del informe
│   ├── estilos.css          estilos del informe
│   └── img/encabezado.jpg   imagen del encabezado
├── r_packages/              librería local de paquetes (se crea sola)
└── run_all.R                ejecuta todo en orden
```

## Requisitos

- R (probado con R 4.6.1 en Windows). Las versiones exactas de R y de los paquetes de cada ejecución quedan en `outputs/sessionInfo.txt`.
- [Quarto](https://quarto.org/docs/get-started/), instalado en el sistema operativo. Solo hace falta para generar el informe.
- Paquetes de R: `dplyr`, `readr`, `tidyr`, `lubridate`, `purrr`, `tibble`, `stringr`, `ggplot2`, `slider`, `broom`, `DBI`, `RSQLite`, `quarto`, `rmarkdown`, `knitr`. `scripts/00_paquetes.R` los instala automáticamente en `r_packages/`.

## Ejecución

Desde la carpeta raíz del proyecto:

```
Rscript run_all.R
```

o desde RGui / RStudio, con el directorio de trabajo en la raíz del proyecto:

```r
source("run_all.R")
```

`run_all.R` ejecuta los scripts `00` a `04` en orden y genera `report/informe.html`. Cada script también puede ejecutarse por separado, siempre que antes se hayan ejecutado los anteriores.

**Prueba de reproducibilidad:** borrar `data/processed/` y `outputs/` y volver a ejecutar `run_all.R`. Se regenera todo a partir de `data/raw/`.

## Decisiones principales

- Los nombres de estación se normalizan a Unicode NFC. La errata "Tacuaremnó" se corrige a "Tacuarembó" después del join.
- Los días con temperatura media y humedad relativa iguales a 0 al mismo tiempo se tratan como faltantes (226 de los 227 casos son de Glencore).
- La humedad fuera de 0–100 % y la evapotranspiración negativa pasan a `NA`.
- Un mes es válido con ≥ 80 % de días con balance. Un año es comparable con sus 12 meses válidos. Esto excluye 2026 y los huecos de Glencore.
- Los parámetros de estas reglas están en `R/configuracion.R`.

## Resultados principales

- Hubo dos períodos de déficit generalizado: 2020–2021 y 2022–2023 (el más intenso).
- En 2022–2023 La Estanzuela (Colonia) acumuló cerca de −990 mm de balance, mientras La Magnolia (Tacuarembó) tuvo un excedente de cerca de +990 mm. La sequía fue sobre todo del sur; en el norte también hubo déficit a mediados de 2023, pero las lluvias de fin de año lo compensaron.
- Los meses de mayor déficit son diciembre y enero, pero la sequía se explica por la persistencia del déficit durante muchos meses.
- Las dos estaciones de Tacuarembó difieren mucho: Glencore registra sistemáticamente menos lluvia que La Magnolia.
- Con 10 años de datos no se detecta una tendencia lineal del balance anual en ninguna estación.

## Limitaciones

Serie corta (10 años); balance climático simplificado (sin suelo ni escurrimiento); la evapotranspiración es un valor calculado; cada estación es un punto; la estación Glencore tiene huecos y en 2017 una evapotranspiración atípica. Ver detalles en el informe.
