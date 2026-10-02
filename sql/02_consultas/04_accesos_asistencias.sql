/*
Proyecto: Gestión de Coworking
Grupo: 06

Integrante Responsable: Zlatan Ricardo Villamizar 

Módulo: Consultas - Módulo 4: Accesos y Asistencias (61-80)
Archivo: 04_accesos_asistencias.sql

Descripción:
Consultas de control de accesos físicos, asistencias reales y patrones temporales.
*/

USE coworking;

-- 61: Todos los accesos de hoy 

SELECT
    a.id AS acceso_id,
    CONCAT(u.nombre, ' ', u.apellidos) AS usuario,
    a.fecha_hora_entrada,
    a.fecha_hora_salida,
    a.metodo_acceso,
    a.estado_intento,
    COALESCE(a.motivo_rechazo, '-') AS motivo_rechazo,
    COALESCE(r.id, '-') AS reserva_vinculada
FROM accesos a
JOIN usuarios u ON a.usuario_id = u.id
LEFT JOIN reservas r ON a.reserva_id = r.id
WHERE DATE(a.fecha_hora_entrada) = CURDATE()
ORDER BY a.fecha_hora_entrada DESC;

-- 62: Usuarios con más de 20 asistencias al edificio en el mes actual

SELECT
    u.id,
    CONCAT(u.nombre, ' ', u.apellidos) AS nombre_completo,
    u.email,
    COUNT(a.id) AS asistencias_edificio
FROM asistencias a
JOIN usuarios u ON a.usuario_id = u.id
WHERE a.tipo = 'Edificio'
  AND YEAR(a.fecha_entrada)  = YEAR(NOW())
  AND MONTH(a.fecha_entrada) = MONTH(NOW())
GROUP BY u.id, u.nombre, u.apellidos
HAVING COUNT(a.id) > 20
ORDER BY asistencias_edificio DESC;

-- 63: Usuarios que no han asistido en la última semana

SELECT
    u.id,
    CONCAT(u.nombre, ' ', u.apellidos) AS nombre_completo,
    u.email,
    u.ultimo_acceso,
    COALESCE(DATEDIFF(NOW(), u.ultimo_acceso), 999) AS dias_sin_acceso
FROM usuarios u
WHERE u.activo = TRUE
  AND NOT EXISTS (
      SELECT 1 FROM asistencias a
      WHERE a.usuario_id = u.id
        AND a.tipo = 'Edificio'
        AND a.fecha_entrada >= DATE_SUB(NOW(), INTERVAL 7 DAY)
  )
ORDER BY dias_sin_acceso DESC;

-- 64: Asistencia promedio al edificio por día de la semana

SELECT
    DAYOFWEEK(a.fecha_entrada) AS numero_dia,
    DAYNAME(a.fecha_entrada)   AS dia_semana,
    COUNT(a.id)                AS total_asistencias,
    ROUND(COUNT(a.id) / COUNT(DISTINCT DATE(a.fecha_entrada)), 2) AS promedio_por_dia
FROM asistencias a
WHERE a.tipo = 'Edificio'
GROUP BY DAYOFWEEK(a.fecha_entrada), DAYNAME(a.fecha_entrada)
ORDER BY numero_dia;

-- 65: Top 10 usuarios más constantes

SELECT
    u.id,
    CONCAT(u.nombre, ' ', u.apellidos) AS nombre_completo,
    u.email,
    COUNT(a.id) AS total_asistencias_edificio,
    MIN(DATE(a.fecha_entrada)) AS primera_visita,
    MAX(DATE(a.fecha_entrada)) AS ultima_visita
FROM asistencias a
JOIN usuarios u ON a.usuario_id = u.id
WHERE a.tipo = 'Edificio'
GROUP BY u.id, u.nombre, u.apellidos
ORDER BY total_asistencias_edificio DESC
LIMIT 10;

-- 66: Accesos fuera del horario de disponibilidad del coworking

SELECT
    ac.id AS acceso_id,
    CONCAT(u.nombre, ' ', u.apellidos) AS usuario,
    ac.fecha_hora_entrada,
    ac.estado_intento,
    ac.metodo_acceso,
    TIME(ac.fecha_hora_entrada) AS hora_ingreso,
    hd.hora_apertura,
    hd.hora_cierre
FROM accesos ac
JOIN usuarios u ON ac.usuario_id = u.id
LEFT JOIN horarios_disponibilidad hd ON hd.espacio_id IS NULL
    AND hd.dia_semana = DAYOFWEEK(ac.fecha_hora_entrada)
WHERE hd.hora_apertura IS NOT NULL
  AND (TIME(ac.fecha_hora_entrada) < hd.hora_apertura
    OR TIME(ac.fecha_hora_entrada) > hd.hora_cierre)
ORDER BY ac.fecha_hora_entrada DESC;

-- 67: Accesos permitidos sin membresía vigente pero con reserva Confirmada

SELECT
    ac.id AS acceso_id,
    CONCAT(u.nombre, ' ', u.apellidos) AS usuario,
    ac.fecha_hora_entrada,
    ac.estado_intento,
    r.id AS reserva_id,
    e.nombre AS espacio,
    r.fecha_inicio,
    r.fecha_fin,
    fn_estado_membresia(u.id) AS estado_membresia_actual
FROM accesos ac
JOIN usuarios u ON ac.usuario_id = u.id
JOIN reservas r ON ac.reserva_id = r.id
JOIN espacios e ON r.espacio_id = e.id
WHERE ac.estado_intento = 'Permitido'
  AND ac.reserva_id IS NOT NULL
  AND NOT fn_membresia_activa(u.id)
ORDER BY ac.fecha_hora_entrada DESC;

-- 68: Usuarios que SOLO asisten en fines de semana

SELECT
    u.id,
    CONCAT(u.nombre, ' ', u.apellidos) AS nombre_completo,
    u.email,
    COUNT(a.id) AS total_asistencias_fds
FROM usuarios u
JOIN asistencias a ON a.usuario_id = u.id AND a.tipo = 'Edificio'
GROUP BY u.id, u.nombre, u.apellidos
HAVING COUNT(a.id) > 0
   AND COUNT(a.id) = SUM(CASE WHEN DAYOFWEEK(a.fecha_entrada) IN (1, 7) THEN 1 ELSE 0 END)
ORDER BY total_asistencias_fds DESC;

-- 69: Usuarios con más de 2 asistencias al edificio en el mismo día

SELECT
    u.id,
    CONCAT(u.nombre, ' ', u.apellidos) AS nombre_completo,
    u.email,
    DATE(a.fecha_entrada) AS fecha,
    COUNT(a.id) AS asistencias_ese_dia
FROM asistencias a
JOIN usuarios u ON a.usuario_id = u.id
WHERE a.tipo = 'Edificio'
GROUP BY u.id, u.nombre, u.apellidos, DATE(a.fecha_entrada)
HAVING COUNT(a.id) > 2
ORDER BY asistencias_ese_dia DESC;

-- 70: Número de accesos diarios en el último mes

SELECT
    DATE(a.fecha_hora_entrada) AS fecha,
    COUNT(*) AS total_accesos,
    SUM(CASE WHEN a.estado_intento = 'Permitido'  THEN 1 ELSE 0 END) AS permitidos,
    SUM(CASE WHEN a.estado_intento = 'Rechazado'  THEN 1 ELSE 0 END) AS rechazados
FROM accesos a
WHERE a.fecha_hora_entrada >= DATE_SUB(NOW(), INTERVAL 30 DAY)
GROUP BY DATE(a.fecha_hora_entrada)
ORDER BY fecha DESC;

-- 71: Usuarios que accedieron al edificio sin tener ninguna reserva

SELECT DISTINCT
    u.id,
    CONCAT(u.nombre, ' ', u.apellidos) AS nombre_completo,
    u.email,
    COUNT(ac.id) AS accesos_sin_reserva
FROM accesos ac
JOIN usuarios u ON ac.usuario_id = u.id
LEFT JOIN reservas r ON ac.reserva_id = r.id
WHERE r.id IS NULL
  AND ac.estado_intento = 'Permitido'
GROUP BY u.id, u.nombre, u.apellidos
ORDER BY accesos_sin_reserva DESC;

-- 72: Días con más concurrencia al coworking 

SELECT
    DATE(a.fecha_entrada)  AS fecha,
    DAYNAME(a.fecha_entrada) AS dia_semana,
    COUNT(a.id)              AS total_asistencias_edificio
FROM asistencias a
WHERE a.tipo = 'Edificio'
GROUP BY DATE(a.fecha_entrada), DAYNAME(a.fecha_entrada)
ORDER BY total_asistencias_edificio DESC
LIMIT 10;

-- 73: Accesos sin registrar salida 

SELECT
    ac.id AS acceso_id,
    CONCAT(u.nombre, ' ', u.apellidos) AS usuario,
    u.email,
    ac.fecha_hora_entrada,
    TIMESTAMPDIFF(MINUTE, ac.fecha_hora_entrada, NOW()) AS minutos_en_local,
    ac.metodo_acceso,
    COALESCE(r.id, '-') AS reserva_vinculada
FROM accesos ac
JOIN usuarios u ON ac.usuario_id = u.id
LEFT JOIN reservas r ON ac.reserva_id = r.id
WHERE ac.estado_intento = 'Permitido'
  AND ac.fecha_hora_salida IS NULL
ORDER BY ac.fecha_hora_entrada ASC;

-- 74: Accesos con membresía vencida y con reserva vinculada

SELECT
    ac.id AS acceso_id,
    CONCAT(u.nombre, ' ', u.apellidos) AS usuario,
    ac.fecha_hora_entrada,
    ac.estado_intento,
    r.id AS reserva_id,
    e.nombre AS espacio,
    r.estado AS estado_reserva,
    fn_estado_membresia(u.id) AS estado_membresia
FROM accesos ac
JOIN usuarios u ON ac.usuario_id = u.id
JOIN reservas r ON ac.reserva_id = r.id
JOIN espacios e ON r.espacio_id = e.id
WHERE ac.estado_intento = 'Permitido'
  AND ac.reserva_id IS NOT NULL
  AND NOT EXISTS (
      SELECT 1 FROM membresias m2
      WHERE m2.usuario_id = u.id
        AND m2.estado = 'Activa'
        AND ac.fecha_hora_entrada BETWEEN m2.fecha_inicio AND m2.fecha_fin
  )
ORDER BY ac.fecha_hora_entrada DESC;

-- 75: Accesos corporativos agrupados por empresa

SELECT
    e.id AS empresa_id,
    e.nombre AS empresa,
    COUNT(ac.id) AS total_accesos_corporativos,
    SUM(CASE WHEN ac.estado_intento = 'Permitido' THEN 1 ELSE 0 END) AS permitidos,
    SUM(CASE WHEN ac.estado_intento = 'Rechazado' THEN 1 ELSE 0 END) AS rechazados
FROM accesos ac
JOIN usuarios u ON ac.usuario_id = u.id
JOIN empresas e ON u.empresa_id = e.id
GROUP BY e.id, e.nombre
ORDER BY total_accesos_corporativos DESC;

-- 76: Usuarios que pagaron su membresía pero nunca asistieron al coworking

SELECT
    u.id,
    CONCAT(u.nombre, ' ', u.apellidos) AS nombre_completo,
    u.email,
    tm.nombre AS tipo_membresia,
    m.estado,
    m.fecha_inicio
FROM usuarios u
JOIN membresias m ON m.usuario_id = u.id AND m.estado = 'Activa' AND NOW() BETWEEN m.fecha_inicio AND m.fecha_fin
JOIN tipos_membresia tm ON m.tipo_id = tm.id
WHERE NOT EXISTS (
    SELECT 1 FROM asistencias a
    WHERE a.usuario_id = u.id
)
ORDER BY m.fecha_inicio;

-- 77: Rechazos por código QR inválido o expirado

SELECT
    ac.id AS acceso_id,
    CONCAT(u.nombre, ' ', u.apellidos) AS usuario,
    u.email,
    ac.fecha_hora_entrada,
    ac.metodo_acceso,
    ac.motivo_rechazo
FROM accesos ac
JOIN usuarios u ON ac.usuario_id = u.id
WHERE ac.estado_intento = 'Rechazado'
  AND ac.motivo_rechazo LIKE '%QR%'
ORDER BY ac.fecha_hora_entrada DESC;

-- 78: Promedio de asistencias al edificio por usuario registrado

SELECT
    ROUND(AVG(asistencias_usuario), 2) AS promedio_asistencias_por_usuario
FROM (
    SELECT u.id, COUNT(a.id) AS asistencias_usuario
    FROM usuarios u
    LEFT JOIN asistencias a ON a.usuario_id = u.id AND a.tipo = 'Edificio'
    GROUP BY u.id
) AS sub;

-- 79: Usuarios que asisten predominantemente por la mañana (06:00-11:59)

SELECT
    u.id,
    CONCAT(u.nombre, ' ', u.apellidos) AS nombre_completo,
    u.email,
    COUNT(a.id) AS asistencias_manana,
    ROUND(COUNT(a.id) * 100.0 / (
        SELECT COUNT(*) FROM asistencias a2
        WHERE a2.usuario_id = u.id AND a2.tipo = 'Edificio'
    ), 1) AS pct_manana
FROM asistencias a
JOIN usuarios u ON a.usuario_id = u.id
WHERE a.tipo = 'Edificio'
  AND HOUR(a.fecha_entrada) BETWEEN 6 AND 11
GROUP BY u.id, u.nombre, u.apellidos
ORDER BY asistencias_manana DESC;

-- 80: Usuarios que asisten predominantemente por la noche (18:00-23:00)

SELECT
    u.id,
    CONCAT(u.nombre, ' ', u.apellidos) AS nombre_completo,
    u.email,
    COUNT(a.id) AS asistencias_noche,
    ROUND(COUNT(a.id) * 100.0 / (
        SELECT COUNT(*) FROM asistencias a2
        WHERE a2.usuario_id = u.id AND a2.tipo = 'Edificio'
    ), 1) AS pct_noche
FROM asistencias a
JOIN usuarios u ON a.usuario_id = u.id
WHERE a.tipo = 'Edificio'
  AND HOUR(a.fecha_entrada) BETWEEN 18 AND 23
GROUP BY u.id, u.nombre, u.apellidos
ORDER BY asistencias_noche DESC;