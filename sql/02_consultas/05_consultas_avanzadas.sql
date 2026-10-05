/*
Proyecto: Gestión de Coworking
Grupo: 06

Integrante Responsable: Brenda Nico Carrillo Gonzalez

Módulo: Consultas - Módulo 5: Consultas Avanzadas (81-100)
Archivo: 05_avanzadas.sql

Descripción:
Consultas complejas con subconsultas correlacionadas, funciones de ventana (window functions),
múltiples JOINs y cálculos de ocupación real desde asistencias tipo Sala.

Técnicas empleadas:
- Subconsultas escalares y correlacionadas
- CTEs implícitas con subconsultas FROM
- Funciones de ventana: SUM() OVER, ROW_NUMBER() OVER
- GREATEST/LEAST para acotamiento de intervalos solapados
- HAVING con subconsultas
*/

USE coworking;

-- 81: Usuario con mayor gasto acumulado total

SELECT
    u.id,
    CONCAT(u.nombre, ' ', u.apellidos) AS nombre_completo,
    u.email,
    SUM(p.monto) AS gasto_acumulado_total
FROM usuarios u
JOIN facturas f ON f.usuario_id = u.id
JOIN pagos p ON p.factura_id = f.id AND p.estado = 'Aplicado'
GROUP BY u.id, u.nombre, u.apellidos
ORDER BY gasto_acumulado_total DESC
LIMIT 1;

-- 82: Espacios más ocupados en uso real

SELECT
    e.id AS espacio_id,
    e.nombre AS espacio,
    te.nombre AS tipo,
    COUNT(DISTINCT r.id) AS reservas_con_uso_real,
    ROUND(SUM(
        TIMESTAMPDIFF(MINUTE,
            GREATEST(a.fecha_entrada, r.fecha_inicio),
            LEAST(
                COALESCE(a.fecha_salida, NOW()),
                r.fecha_fin
            )
        ) / 60.0
    ), 2) AS horas_uso_real
FROM asistencias a
JOIN reservas r ON a.reserva_id = r.id
JOIN espacios e ON r.espacio_id = e.id
JOIN tipos_espacio te ON e.tipo_id = te.id
WHERE a.tipo = 'Sala'
  AND GREATEST(a.fecha_entrada, r.fecha_inicio) <
      LEAST(COALESCE(a.fecha_salida, NOW()), r.fecha_fin)
GROUP BY e.id, e.nombre, te.nombre
ORDER BY horas_uso_real DESC;

-- 83: Ingreso promedio por usuario 

SELECT
    u.id,
    CONCAT(u.nombre, ' ', u.apellidos) AS nombre_completo,
    u.email,
    (
        SELECT COALESCE(SUM(p2.monto), 0.00)
        FROM pagos p2
        JOIN facturas f2 ON p2.factura_id = f2.id
        WHERE f2.usuario_id = u.id AND p2.estado = 'Aplicado'
    ) AS gasto_individual,
    (
        SELECT ROUND(AVG(sub.tot), 2)
        FROM (
            SELECT SUM(p3.monto) AS tot
            FROM pagos p3
            JOIN facturas f3 ON p3.factura_id = f3.id
            WHERE p3.estado = 'Aplicado' AND f3.usuario_id IS NOT NULL
            GROUP BY f3.usuario_id
        ) AS sub
    ) AS promedio_general
FROM usuarios u
ORDER BY gasto_individual DESC;

-- 84: Reservas activas junto a sus facturas pendientes

SELECT
    r.id AS reserva_id,
    CONCAT(u.nombre, ' ', u.apellidos) AS usuario,
    e.nombre AS espacio,
    r.fecha_inicio,
    r.fecha_fin,
    r.estado AS estado_reserva,
    f.id AS factura_id,
    f.monto_total,
    f.saldo_pendiente,
    f.estado AS estado_factura
FROM reservas r
JOIN usuarios u ON r.usuario_id = u.id
JOIN espacios e ON r.espacio_id = e.id
JOIN facturas f ON f.reserva_id = r.id
WHERE r.estado IN ('Pendiente', 'Confirmada')
  AND r.fecha_fin > NOW()
  AND f.estado = 'Pendiente'
  AND f.saldo_pendiente > 0
ORDER BY r.fecha_inicio;

-- 85: Empresas cuyos empleados generan más del 20% de los ingresos totales

SELECT
    e.id AS empresa_id,
    e.nombre AS empresa,
    fn_ingresos_por_empresa(e.id) AS ingresos_empresa,
    (
        SELECT COALESCE(SUM(p.monto), 0.00)
        FROM pagos p WHERE p.estado = 'Aplicado'
    ) AS ingresos_totales,
    ROUND(fn_ingresos_por_empresa(e.id) * 100.0 /
        NULLIF((SELECT COALESCE(SUM(p2.monto), 0.00) FROM pagos p2 WHERE p2.estado = 'Aplicado'), 0),
    2) AS pct_del_total
FROM empresas e
HAVING pct_del_total > 20
ORDER BY pct_del_total DESC;

-- 86: Top 5 usuarios en gasto de servicios adicionales

SELECT
    u.id,
    CONCAT(u.nombre, ' ', u.apellidos) AS nombre_completo,
    u.email,
    COUNT(sc.id) AS servicios_contratados,
    SUM(sc.cantidad * sc.precio_unitario) AS gasto_total_servicios
FROM servicios_contratados sc
JOIN usuarios u ON sc.usuario_id = u.id
GROUP BY u.id, u.nombre, u.apellidos
ORDER BY gasto_total_servicios DESC
LIMIT 5;

-- 87: Reservas cuya factura supera el promedio de todas las facturas

SELECT
    r.id AS reserva_id,
    CONCAT(u.nombre, ' ', u.apellidos) AS usuario,
    e.nombre AS espacio,
    r.fecha_inicio,
    f.id AS factura_id,
    f.monto_total,
    (SELECT AVG(f2.monto_total) FROM facturas f2 WHERE f2.tipo = 'Reserva') AS promedio_facturas_reserva
FROM reservas r
JOIN usuarios u ON r.usuario_id = u.id
JOIN espacios e ON r.espacio_id = e.id
JOIN facturas f ON f.reserva_id = r.id
WHERE f.tipo = 'Reserva'
  AND f.monto_total > (
      SELECT AVG(f3.monto_total) FROM facturas f3 WHERE f3.tipo = 'Reserva'
  )
ORDER BY f.monto_total DESC;

-- 88: Porcentaje de ocupación global por mes

WITH meses AS (
    SELECT
        YEAR(a.fecha_entrada) AS anio,
        MONTH(a.fecha_entrada) AS mes,
        DAY(LAST_DAY(a.fecha_entrada)) AS dias_mes
    FROM asistencias a
    WHERE a.tipo = 'Sala'
    GROUP BY
        YEAR(a.fecha_entrada),
        MONTH(a.fecha_entrada),
        DAY(LAST_DAY(a.fecha_entrada))
),

uso_mensual AS (
    SELECT
        YEAR(a.fecha_entrada) AS anio,
        MONTH(a.fecha_entrada) AS mes,

        ROUND(
            SUM(
                TIMESTAMPDIFF(
                    MINUTE,
                    GREATEST(
                        a.fecha_entrada,
                        r.fecha_inicio
                    ),
                    LEAST(
                        COALESCE(a.fecha_salida, NOW()),
                        r.fecha_fin
                    )
                )
            ),
            0
        ) AS minutos_uso_real

    FROM asistencias a

    JOIN reservas r
        ON a.reserva_id = r.id

    WHERE a.tipo = 'Sala'

    GROUP BY
        YEAR(a.fecha_entrada),
        MONTH(a.fecha_entrada)
),

capacidad AS (
    SELECT
        COUNT(DISTINCT e.id) AS cantidad_espacios,

        SUM(
            TIME_TO_SEC(
                TIMEDIFF(
                    hd.hora_cierre,
                    hd.hora_apertura
                )
            ) / 60.0
        ) AS minutos_horario_diario

    FROM espacios e

    CROSS JOIN horarios_disponibilidad hd

    WHERE hd.espacio_id IS NULL
)

SELECT
    u.anio,
    u.mes,

    u.minutos_uso_real,

    ROUND(
        c.cantidad_espacios
        * c.minutos_horario_diario
        * m.dias_mes,
        0
    ) AS minutos_disponibles_estimado,

    ROUND(
        u.minutos_uso_real * 100.0
        /
        NULLIF(
            c.cantidad_espacios
            * c.minutos_horario_diario
            * m.dias_mes,
            0
        ),
        2
    ) AS pct_ocupacion_global

FROM uso_mensual u

JOIN meses m
    ON m.anio = u.anio
    AND m.mes = u.mes

CROSS JOIN capacidad c

ORDER BY
    u.anio DESC,
    u.mes DESC;

-- 89: Usuarios que han reservado más horas que el promedio del coworking

SELECT
    u.id,
    CONCAT(u.nombre, ' ', u.apellidos) AS nombre_completo,
    u.email,
    SUM(TIMESTAMPDIFF(MINUTE, r.fecha_inicio, r.fecha_fin) / 60.0) AS horas_reservadas,
    (
        SELECT AVG(horas_usuario)
        FROM (
            SELECT SUM(TIMESTAMPDIFF(MINUTE, r2.fecha_inicio, r2.fecha_fin) / 60.0) AS horas_usuario
            FROM reservas r2
            WHERE r2.estado <> 'Cancelada'
            GROUP BY r2.usuario_id
        ) AS sub_avg
    ) AS promedio_horas_coworking
FROM reservas r
JOIN usuarios u ON r.usuario_id = u.id
WHERE r.estado <> 'Cancelada'
GROUP BY u.id, u.nombre, u.apellidos
HAVING horas_reservadas > (
    SELECT AVG(horas_usuario)
    FROM (
        SELECT SUM(TIMESTAMPDIFF(MINUTE, r3.fecha_inicio, r3.fecha_fin) / 60.0) AS horas_usuario
        FROM reservas r3
        WHERE r3.estado <> 'Cancelada'
        GROUP BY r3.usuario_id
    ) AS sub_avg2
)
ORDER BY horas_reservadas DESC;



-- 90: Top 3 salas más usadas en el último trimestre 

SELECT
    e.id AS espacio_id,
    e.nombre AS espacio,
    te.nombre AS tipo,
    COUNT(DISTINCT r.id) AS reservas_con_asistencia,
    ROUND(SUM(COALESCE(a.minutos, 0)) / 60.0, 2) AS horas_reales_uso
FROM asistencias a
JOIN reservas r ON a.reserva_id = r.id
JOIN espacios e ON r.espacio_id = e.id
JOIN tipos_espacio te ON e.tipo_id = te.id
WHERE a.tipo = 'Sala'
  AND a.fecha_entrada >= DATE_SUB(NOW(), INTERVAL 3 MONTH)
GROUP BY e.id, e.nombre, te.nombre
ORDER BY horas_reales_uso DESC
LIMIT 3;

-- 91: Ingreso promedio generado por tipo de membresía

SELECT
    tm.nombre AS tipo_membresia,
    COUNT(DISTINCT m.id) AS total_membresias,
    COALESCE(SUM(p.monto), 0.00) AS ingresos_totales,
    ROUND(COALESCE(SUM(p.monto), 0.00) / NULLIF(COUNT(DISTINCT m.id), 0), 2) AS ingreso_promedio
FROM tipos_membresia tm
LEFT JOIN membresias m ON m.tipo_id = tm.id
LEFT JOIN facturas f ON f.membresia_id = m.id
LEFT JOIN pagos p ON p.factura_id = f.id AND p.estado = 'Aplicado'
GROUP BY tm.id, tm.nombre
ORDER BY ingreso_promedio DESC;

-- 92: Usuarios que pagan exclusivamente con un solo método de pago

SELECT
    u.id,
    CONCAT(u.nombre, ' ', u.apellidos) AS nombre_completo,
    u.email,
    mp.nombre AS unico_metodo_pago,
    COUNT(p.id) AS total_pagos
FROM usuarios u
JOIN facturas f ON f.usuario_id = u.id
JOIN pagos p ON p.factura_id = f.id AND p.estado = 'Aplicado'
JOIN metodos_pago mp ON p.metodo_pago_id = mp.id
GROUP BY u.id, u.nombre, u.apellidos, mp.id, mp.nombre
HAVING COUNT(DISTINCT p.metodo_pago_id) = 1
ORDER BY total_pagos DESC;

-- 93: Reservas canceladas de usuarios que nunca asistieron al coworking

SELECT
    r.id AS reserva_id,
    CONCAT(u.nombre, ' ', u.apellidos) AS usuario,
    u.email,
    e.nombre AS espacio,
    r.fecha_inicio,
    r.fecha_fin,
    r.estado
FROM reservas r
JOIN usuarios u ON r.usuario_id = u.id
JOIN espacios e ON r.espacio_id = e.id
WHERE r.estado = 'Cancelada'
  AND NOT EXISTS (
      SELECT 1 FROM asistencias a
      WHERE a.usuario_id = u.id
  )
ORDER BY r.fecha_inicio DESC;

-- 94: Facturas con pagos parciales

SELECT
    f.id AS factura_id,
    COALESCE(CONCAT(u.nombre, ' ', u.apellidos), 'Empresa') AS titular,
    f.tipo,
    f.monto_total,
    COALESCE(SUM(CASE WHEN p.monto > 0 THEN p.monto ELSE 0 END), 0.00) AS total_cobrado,
    f.saldo_pendiente,
    f.estado,
    f.fecha_vencimiento
FROM facturas f
LEFT JOIN usuarios u ON f.usuario_id = u.id
LEFT JOIN pagos p ON p.factura_id = f.id AND p.estado = 'Aplicado'
GROUP BY f.id, u.nombre, u.apellidos, f.tipo, f.monto_total, f.saldo_pendiente, f.estado, f.fecha_vencimiento
HAVING SUM(CASE WHEN p.monto > 0 THEN p.monto ELSE 0 END) > 0
   AND f.saldo_pendiente > 0
ORDER BY f.saldo_pendiente DESC;

-- 95: Facturación neta por empresa 

SELECT
    e.id AS empresa_id,
    e.nombre AS empresa,
    e.industria,
    COUNT(DISTINCT f.id) AS total_facturas,
    SUM(f.monto_total) AS facturacion_neta
FROM empresas e
JOIN facturas f ON f.empresa_id = e.id
WHERE f.estado NOT IN ('Anulada', 'Cancelada')
GROUP BY e.id, e.nombre, e.industria
ORDER BY facturacion_neta DESC;

-- 96: Usuarios que superan el promedio de reservas de su empresa

SELECT
    u.id,
    CONCAT(u.nombre, ' ', u.apellidos) AS nombre_completo,
    u.email,
    e.nombre AS empresa,
    COUNT(r.id) AS reservas_usuario,
    promedios.promedio_empresa

FROM usuarios u

JOIN empresas e
    ON u.empresa_id = e.id

LEFT JOIN reservas r
    ON r.usuario_id = u.id

JOIN (
    SELECT
        u2.empresa_id,
        AVG(reservas_usuario.total_r) AS promedio_empresa

    FROM usuarios u2

    LEFT JOIN (
        SELECT
            usuario_id,
            COUNT(id) AS total_r
        FROM reservas
        GROUP BY usuario_id
    ) AS reservas_usuario
        ON reservas_usuario.usuario_id = u2.id

    GROUP BY u2.empresa_id

) AS promedios
    ON promedios.empresa_id = u.empresa_id

GROUP BY
    u.id,
    u.nombre,
    u.apellidos,
    u.email,
    e.id,
    e.nombre,
    promedios.promedio_empresa

HAVING COUNT(r.id) > promedios.promedio_empresa

ORDER BY
    reservas_usuario DESC;

-- 97: Top 3 empresas con más empleados con membresía activa

SELECT
    e.id AS empresa_id,
    e.nombre AS empresa,
    e.industria,
    COUNT(DISTINCT m.usuario_id) AS empleados_activos
FROM empresas e
JOIN usuarios u ON u.empresa_id = e.id
JOIN membresias m ON m.usuario_id = u.id
    AND m.estado = 'Activa'
    AND NOW() BETWEEN m.fecha_inicio AND m.fecha_fin
GROUP BY e.id, e.nombre, e.industria
ORDER BY empleados_activos DESC
LIMIT 3;

-- 98: Porcentaje de usuarios activos vs total de usuarios registrados

SELECT
    COUNT(*) AS total_usuarios,
    SUM(CASE WHEN activo = TRUE  THEN 1 ELSE 0 END) AS usuarios_activos,
    SUM(CASE WHEN activo = FALSE THEN 1 ELSE 0 END) AS usuarios_inactivos,
    ROUND(SUM(CASE WHEN activo = TRUE THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS pct_activos
FROM usuarios;

-- 99: Ingresos acumulados por mes (función de ventana acumulativa)

SELECT
    YEAR(p.fecha_pago)  AS anio,
    MONTH(p.fecha_pago) AS mes,
    SUM(p.monto) AS ingresos_mes,
    SUM(SUM(p.monto)) OVER (
        ORDER BY YEAR(p.fecha_pago), MONTH(p.fecha_pago)
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS ingresos_acumulados
FROM pagos p
WHERE p.estado = 'Aplicado'
GROUP BY YEAR(p.fecha_pago), MONTH(p.fecha_pago)
ORDER BY anio, mes;

-- 100: Usuarios con más de 10 reservas, más de $500 en pagos Y membresía activa

SELECT
    u.id,
    CONCAT(u.nombre, ' ', u.apellidos) AS nombre_completo,
    u.email,
    tm.nombre AS tipo_membresia,
    COUNT(DISTINCT r.id) AS total_reservas,
    COALESCE(SUM(p.monto), 0.00) AS total_pagado
FROM usuarios u
JOIN membresias m ON m.usuario_id = u.id
    AND m.estado = 'Activa'
    AND NOW() BETWEEN m.fecha_inicio AND m.fecha_fin
JOIN tipos_membresia tm ON m.tipo_id = tm.id
LEFT JOIN reservas r ON r.usuario_id = u.id
LEFT JOIN facturas f ON f.usuario_id = u.id
LEFT JOIN pagos p ON p.factura_id = f.id AND p.estado = 'Aplicado'
GROUP BY u.id, u.nombre, u.apellidos, tm.nombre
HAVING COUNT(DISTINCT r.id) > 10
   AND COALESCE(SUM(p.monto), 0.00) > 500
ORDER BY total_pagado DESC;