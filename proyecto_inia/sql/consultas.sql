-- Consultas del proyecto. Cada consulta comienza con una linea "-- name: <nombre>",
-- que scripts/02_base_relacional.R usa para separarlas y nombrar su resultado.
-- Tablas: departamentos(DepartamentoCodigo, DepartamentoDescripcion)
--         estaciones(estacion, DepartamentoCodigo)
--         mensual(estacion, mes, anio, numero_mes, precipitacion, eto, balance,
--                 cobertura, mes_valido)

-- name: meses_mas_secos
-- Los 10 meses con mayor deficit hidrico (balance mas negativo) entre todas las
-- estaciones, con el departamento obtenido mediante los catalogos.
SELECT d.DepartamentoDescripcion AS departamento,
       m.estacion,
       m.mes,
       ROUND(m.precipitacion, 1) AS precipitacion_mm,
       ROUND(m.eto, 1) AS eto_mm,
       ROUND(m.balance, 1) AS balance_mm
FROM mensual AS m
JOIN estaciones AS e ON e.estacion = m.estacion
JOIN departamentos AS d ON d.DepartamentoCodigo = e.DepartamentoCodigo
WHERE m.mes_valido = 1
ORDER BY m.balance ASC
LIMIT 10;

-- name: balance_anual_sql
-- Balance anual por estacion y departamento, solo para anios con los 12 meses
-- validos (HAVING filtra los grupos incompletos).
SELECT d.DepartamentoDescripcion AS departamento,
       m.estacion,
       m.anio,
       COUNT(*) AS meses_validos,
       ROUND(SUM(m.precipitacion), 1) AS precipitacion_mm,
       ROUND(SUM(m.eto), 1) AS eto_mm,
       ROUND(SUM(m.balance), 1) AS balance_mm
FROM mensual AS m
JOIN estaciones AS e ON e.estacion = m.estacion
JOIN departamentos AS d ON d.DepartamentoCodigo = e.DepartamentoCodigo
WHERE m.mes_valido = 1
GROUP BY d.DepartamentoDescripcion, m.estacion, m.anio
HAVING COUNT(*) = 12
ORDER BY m.estacion, m.anio;

-- name: sequia_2022_2023
-- Deficit acumulado y cantidad de meses con deficit durante 2022-2023.
SELECT d.DepartamentoDescripcion AS departamento,
       m.estacion,
       COUNT(*) AS meses_validos,
       SUM(CASE WHEN m.balance < 0 THEN 1 ELSE 0 END) AS meses_con_deficit,
       ROUND(SUM(m.balance), 1) AS balance_2022_2023_mm
FROM mensual AS m
JOIN estaciones AS e ON e.estacion = m.estacion
JOIN departamentos AS d ON d.DepartamentoCodigo = e.DepartamentoCodigo
WHERE m.mes_valido = 1 AND m.anio IN (2022, 2023)
GROUP BY d.DepartamentoDescripcion, m.estacion
ORDER BY balance_2022_2023_mm ASC;
