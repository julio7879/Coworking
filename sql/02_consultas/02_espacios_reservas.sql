/*
Proyecto: Gestión de Coworking
Grupo: 06

Integrante Responsable: Sofia Salazar Hernandez

Módulo: Consultas - Módulo 2: Espacios y Reservas (21-40)
Archivo: 02_espacios_reservas.sql

Descripción:
Consultas de análisis de espacios físicos, ocupación, reservas y patrones de uso.
*/

USE coworking;

-- 21: Espacios disponibles con su capacidad y tarifas

SELECT
    e.id,
    e.nombre,
    te.nombre AS tipo,
    te.modo_ocupacion,
    e.ubicacion_fisica,
    e.capacidad_maxima,
    e.tarifa_hora,
    e.tarifa_mes,
    e.estado
FROM espacios e
JOIN tipos_espacio te ON e.tipo_id = te.id
WHERE e.estado = 'Disponible'
ORDER BY te.nombre, e.nombre;

-- 22: Reservas activas hoy 

SELECT
    r.id AS reserva_id,
    CONCAT(u.nombre, ' ', u.apellidos) AS usuario,
    e.nombre AS espacio,
    r.modalidad,
    r.fecha_inicio,
    r.fecha_fin,
    r.num_personas,
    r.estado
FROM reservas r
JOIN usuarios u ON r.usuario_id = u.id
JOIN espacios e ON r.espacio_id = e.id
WHERE r.estado IN ('Pendiente', 'Confirmada')
  AND r.fecha_fin > NOW()
  AND DATE(r.fecha_inicio) = CURDATE()
ORDER BY r.fecha_inicio;

-- 23: Reservas canceladas en el último mes

SELECT
    r.id AS reserva_id,
    CONCAT(u.nombre, ' ', u.apellidos) AS usuario,
    e.nombre AS espacio,
    r.modalidad,
    r.fecha_inicio,
    r.fecha_fin,
    r.costo_total
FROM reservas r
JOIN usuarios u ON r.usuario_id = u.id
JOIN espacios e ON r.espacio_id = e.id
WHERE r.estado = 'Cancelada'
  AND r.fecha_inicio >= DATE_SUB(NOW(), INTERVAL 1 MONTH)
ORDER BY r.fecha_inicio DESC;



-- 24: Reservas de Salas de Reuniones en hora pico 9-11

SELECT
    r.id AS reserva_id,
    CONCAT(u.nombre, ' ', u.apellidos) AS usuario,
    e.nombre AS sala,
    r.fecha_inicio,
    r.fecha_fin,
    r.num_personas,
    r.estado
FROM reservas r
JOIN usuarios u ON r.usuario_id = u.id
JOIN espacios e ON r.espacio_id = e.id
JOIN tipos_espacio te ON e.tipo_id = te.id AND te.nombre = 'Sala de Reuniones'
WHERE HOUR(r.fecha_inicio) BETWEEN 9 AND 11
  AND r.estado NOT IN ('Cancelada')
ORDER BY r.fecha_inicio DESC;

-- 25: Reservas agrupadas por tipo de espacio

SELECT
    te.nombre AS tipo_espacio,
    te.modo_ocupacion,
    COUNT(r.id) AS total_reservas,
    COUNT(CASE WHEN r.estado = 'Completada' THEN 1 END) AS completadas,
    COUNT(CASE WHEN r.estado = 'Cancelada'  THEN 1 END) AS canceladas,
    COUNT(CASE WHEN r.estado = 'No_Show'    THEN 1 END) AS no_shows
FROM reservas r
JOIN espacios e ON r.espacio_id = e.id
JOIN tipos_espacio te ON e.tipo_id = te.id
GROUP BY te.id, te.nombre, te.modo_ocupacion
ORDER BY total_reservas DESC;



-- 26: Espacio más reservado en el último mes 

SELECT
    e.id AS espacio_id,
    e.nombre AS espacio,
    te.nombre AS tipo,
    COUNT(r.id) AS total_reservas
FROM reservas r
JOIN espacios e ON r.espacio_id = e.id
JOIN tipos_espacio te ON e.tipo_id = te.id
WHERE r.estado <> 'Cancelada'
  AND r.fecha_inicio >= DATE_SUB(NOW(), INTERVAL 1 MONTH)
GROUP BY e.id, e.nombre, te.nombre
ORDER BY total_reservas DESC
LIMIT 1;

-- 27: Quién más reserva Oficinas Privadas 

SELECT
    u.id AS usuario_id,
    CONCAT(u.nombre, ' ', u.apellidos) AS nombre_completo,
    u.email,
    COUNT(r.id) AS total_reservas_oficinas
FROM reservas r
JOIN usuarios u ON r.usuario_id = u.id
JOIN espacios e ON r.espacio_id = e.id
JOIN tipos_espacio te ON e.tipo_id = te.id AND te.nombre = 'Oficina Privada'
WHERE r.estado <> 'Cancelada'
GROUP BY u.id, u.nombre, u.apellidos
ORDER BY total_reservas_oficinas DESC;

-- 28: AUDITORÍA - Reservas que exceden la capacidad del espacio

SELECT
    r.id AS reserva_id,
    CONCAT(u.nombre, ' ', u.apellidos) AS usuario,
    e.nombre AS espacio,
    e.capacidad_maxima,
    r.num_personas,
    r.num_personas - e.capacidad_maxima AS excedente,
    r.fecha_inicio,
    r.fecha_fin
FROM reservas r
JOIN usuarios u ON r.usuario_id = u.id
JOIN espacios e ON r.espacio_id = e.id
WHERE r.num_personas > e.capacidad_maxima;

-- 29: Espacios sin ninguna reserva en la última semana

SELECT
    e.id,
    e.nombre,
    te.nombre AS tipo,
    e.estado
FROM espacios e
JOIN tipos_espacio te ON e.tipo_id = te.id
WHERE NOT EXISTS (
    SELECT 1 FROM reservas r
    WHERE r.espacio_id = e.id
      AND r.fecha_inicio >= DATE_SUB(NOW(), INTERVAL 7 DAY)
)
ORDER BY te.nombre, e.nombre;

-- 30: Porcentaje de ocupación promedio por espacio

SELECT
    e.id AS espacio_id,
    e.nombre AS espacio,
    te.nombre AS tipo,
    COALESCE(SUM(TIMESTAMPDIFF(MINUTE, r.fecha_inicio, r.fecha_fin) / 60.0), 0.00) AS horas_reservadas,
    (
        SELECT COALESCE(SUM(TIME_TO_SEC(TIMEDIFF(hd.hora_cierre, hd.hora_apertura)) / 3600.0), 0)
        FROM horarios_disponibilidad hd
        WHERE (hd.espacio_id = e.id OR hd.espacio_id IS NULL)
        GROUP BY hd.espacio_id
        ORDER BY (hd.espacio_id = e.id) DESC
        LIMIT 1
    ) * DAY(LAST_DAY(NOW())) AS horas_disponibles_mes,
    ROUND(
        COALESCE(SUM(TIMESTAMPDIFF(MINUTE, r.fecha_inicio, r.fecha_fin) / 60.0), 0.00) /
        NULLIF(
            (
                SELECT COALESCE(SUM(TIME_TO_SEC(TIMEDIFF(hd.hora_cierre, hd.hora_apertura)) / 3600.0), 0)
                FROM horarios_disponibilidad hd
                WHERE (hd.espacio_id = e.id OR hd.espacio_id IS NULL)
                LIMIT 1
            ) * DAY(LAST_DAY(NOW())),
        0) * 100,
    2) AS pct_ocupacion
FROM espacios e
JOIN tipos_espacio te ON e.tipo_id = te.id
LEFT JOIN reservas r ON r.espacio_id = e.id
    AND r.estado NOT IN ('Cancelada')
    AND YEAR(r.fecha_inicio) = YEAR(NOW())
    AND MONTH(r.fecha_inicio) = MONTH(NOW())
GROUP BY e.id, e.nombre, te.nombre
ORDER BY pct_ocupacion DESC;

-- 31: Reservas con duración mayor a 8 horas

SELECT
    r.id AS reserva_id,
    CONCAT(u.nombre, ' ', u.apellidos) AS usuario,
    e.nombre AS espacio,
    r.fecha_inicio,
    r.fecha_fin,
    ROUND(TIMESTAMPDIFF(MINUTE, r.fecha_inicio, r.fecha_fin) / 60.0, 2) AS horas_total,
    r.costo_total,
    r.estado
FROM reservas r
JOIN usuarios u ON r.usuario_id = u.id
JOIN espacios e ON r.espacio_id = e.id
WHERE TIMESTAMPDIFF(HOUR, r.fecha_inicio, r.fecha_fin) > 8
ORDER BY horas_total DESC;

-- 32: Usuarios con más de 20 reservas en total

SELECT
    u.id,
    CONCAT(u.nombre, ' ', u.apellidos) AS nombre_completo,
    u.email,
    COUNT(r.id) AS total_reservas
FROM usuarios u
JOIN reservas r ON r.usuario_id = u.id
GROUP BY u.id, u.nombre, u.apellidos
HAVING COUNT(r.id) > 20
ORDER BY total_reservas DESC;

-- 33: Reservas de empresas con más de 10 empleados activos

SELECT
    r.id AS reserva_id,
    CONCAT(u.nombre, ' ', u.apellidos) AS usuario,
    e_emp.nombre AS empresa,
    esp.nombre AS espacio,
    r.fecha_inicio,
    r.fecha_fin,
    r.estado
FROM reservas r
JOIN usuarios u ON r.usuario_id = u.id
JOIN empresas e_emp ON u.empresa_id = e_emp.id
JOIN espacios esp ON r.espacio_id = esp.id
WHERE (
    SELECT COUNT(*) FROM usuarios u2
    WHERE u2.empresa_id = u.empresa_id AND u2.activo = TRUE
) > 10
ORDER BY e_emp.nombre, r.fecha_inicio DESC;

-- 34: AUDITORÍA - Solapamientos en espacios Exclusivos

SELECT
    r1.id AS reserva_1,
    r2.id AS reserva_2,
    e.nombre AS espacio,
    te.modo_ocupacion,
    r1.fecha_inicio AS inicio_1, r1.fecha_fin AS fin_1,
    r2.fecha_inicio AS inicio_2, r2.fecha_fin AS fin_2,
    CONCAT(u1.nombre, ' ', u1.apellidos) AS usuario_1,
    CONCAT(u2.nombre, ' ', u2.apellidos) AS usuario_2
FROM reservas r1
JOIN reservas r2 ON r1.espacio_id = r2.espacio_id
    AND r1.id < r2.id
    AND r1.fecha_inicio < r2.fecha_fin
    AND r1.fecha_fin > r2.fecha_inicio
JOIN espacios e ON r1.espacio_id = e.id
JOIN tipos_espacio te ON e.tipo_id = te.id AND te.modo_ocupacion = 'Exclusivo'
JOIN usuarios u1 ON r1.usuario_id = u1.id
JOIN usuarios u2 ON r2.usuario_id = u2.id
WHERE r1.estado IN ('Pendiente', 'Confirmada')
  AND r2.estado IN ('Pendiente', 'Confirmada')
ORDER BY e.nombre, r1.fecha_inicio;

-- 35: Reservas de fin de semana 

SELECT
    r.id AS reserva_id,
    DAYNAME(r.fecha_inicio) AS dia_semana,
    CONCAT(u.nombre, ' ', u.apellidos) AS usuario,
    e.nombre AS espacio,
    r.fecha_inicio,
    r.fecha_fin,
    r.num_personas,
    r.estado
FROM reservas r
JOIN usuarios u ON r.usuario_id = u.id
JOIN espacios e ON r.espacio_id = e.id
WHERE DAYOFWEEK(r.fecha_inicio) IN (1, 7)
ORDER BY r.fecha_inicio DESC;

-- 36: Porcentaje de ocupación total por TIPO de espacio

SELECT
    te.nombre AS tipo_espacio,
    te.modo_ocupacion,
    COUNT(DISTINCT e.id) AS cantidad_espacios,
    COALESCE(SUM(TIMESTAMPDIFF(MINUTE, r.fecha_inicio, r.fecha_fin) / 60.0), 0.00) AS total_horas_reservadas,
    ROUND(
        COALESCE(SUM(TIMESTAMPDIFF(MINUTE, r.fecha_inicio, r.fecha_fin) / 60.0), 0.00) /
        NULLIF(COUNT(DISTINCT e.id) * 220.0, 0) * 100,
    2) AS pct_ocupacion_estimado
FROM tipos_espacio te
JOIN espacios e ON e.tipo_id = te.id
LEFT JOIN reservas r ON r.espacio_id = e.id AND r.estado <> 'Cancelada'
GROUP BY te.id, te.nombre, te.modo_ocupacion
ORDER BY pct_ocupacion_estimado DESC;

-- 37: Duración promedio de reservas por tipo de espacio 

SELECT
    te.nombre AS tipo_espacio,
    COUNT(r.id) AS total_reservas,
    ROUND(AVG(TIMESTAMPDIFF(MINUTE, r.fecha_inicio, r.fecha_fin) / 60.0), 2) AS duracion_promedio_horas,
    ROUND(MIN(TIMESTAMPDIFF(MINUTE, r.fecha_inicio, r.fecha_fin) / 60.0), 2) AS duracion_minima_horas,
    ROUND(MAX(TIMESTAMPDIFF(MINUTE, r.fecha_inicio, r.fecha_fin) / 60.0), 2) AS duracion_maxima_horas
FROM reservas r
JOIN espacios e ON r.espacio_id = e.id
JOIN tipos_espacio te ON e.tipo_id = te.id
WHERE r.estado <> 'Cancelada'
GROUP BY te.id, te.nombre
ORDER BY duracion_promedio_horas DESC;

-- 38: Reservas que incluyen al menos un servicio adicional contratado

SELECT
    r.id AS reserva_id,
    CONCAT(u.nombre, ' ', u.apellidos) AS usuario,
    e.nombre AS espacio,
    r.fecha_inicio,
    r.fecha_fin,
    r.estado,
    COUNT(sc.id) AS servicios_adicionales,
    SUM(sc.cantidad * sc.precio_unitario) AS costo_servicios
FROM reservas r
JOIN usuarios u ON r.usuario_id = u.id
JOIN espacios e ON r.espacio_id = e.id
JOIN servicios_contratados sc ON sc.reserva_id = r.id
GROUP BY r.id, u.nombre, u.apellidos, e.nombre, r.fecha_inicio, r.fecha_fin, r.estado
ORDER BY servicios_adicionales DESC;

-- 39: Usuarios que han reservado la Sala de Eventos en los últimos 6 meses

SELECT DISTINCT
    u.id,
    CONCAT(u.nombre, ' ', u.apellidos) AS nombre_completo,
    u.email,
    COUNT(r.id) AS veces_reservo,
    MAX(r.fecha_inicio) AS ultima_reserva
FROM reservas r
JOIN usuarios u ON r.usuario_id = u.id
JOIN espacios e ON r.espacio_id = e.id
JOIN tipos_espacio te ON e.tipo_id = te.id AND te.nombre = 'Sala de Eventos'
WHERE r.fecha_inicio >= DATE_SUB(NOW(), INTERVAL 6 MONTH)
  AND r.estado <> 'Cancelada'
GROUP BY u.id, u.nombre, u.apellidos, u.email
ORDER BY veces_reservo DESC;

-- 40: Reservas con estado No_Show 

SELECT
    r.id AS reserva_id,
    CONCAT(u.nombre, ' ', u.apellidos) AS usuario,
    u.email,
    e.nombre AS espacio,
    r.modalidad,
    r.fecha_inicio,
    r.fecha_fin,
    r.costo_total,
    r.creditos_usados,
    COALESCE(SUM(p.monto), 0.00) AS pagado_real,
    r.costo_total * 0.5 AS penalizacion_calculada
FROM reservas r
JOIN usuarios u ON r.usuario_id = u.id
JOIN espacios e ON r.espacio_id = e.id
LEFT JOIN facturas f ON f.reserva_id = r.id
LEFT JOIN pagos p ON p.factura_id = f.id AND p.estado = 'Aplicado'
WHERE r.estado = 'No_Show'
GROUP BY r.id, u.nombre, u.apellidos, u.email, e.nombre, r.modalidad, r.fecha_inicio, r.fecha_fin, r.costo_total, r.creditos_usados
ORDER BY r.fecha_inicio DESC;