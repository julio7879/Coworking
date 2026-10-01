/*
Proyecto: Gestión de Coworking

Grupo: 06

Integrante Responsable: Julio Ernesto Castaño Palacios

Módulo: Consultas - Módulo 1: Usuarios y Membresías (1-20)
Archivo: 01_usuarios_membresias.sql

Descripción:
Consultas de análisis de usuarios, membresías y comportamiento de clientes.
*/

USE coworking;

-- 01: Usuarios con información básica (tipo_usuario, empresa_id, rol_id)

SELECT
    u.id,
    CONCAT(u.nombre, ' ', u.apellidos) AS nombre_completo,
    u.email,
    u.telefono,
    u.tipo_usuario,
    u.empresa_id,
    u.rol_id,
    r.nombre AS rol_nombre,
    u.activo,
    u.fecha_registro
FROM usuarios u
JOIN roles r ON u.rol_id = r.id
ORDER BY u.fecha_registro ASC;

-- 02: Usuarios con membresía activa 

SELECT
    u.id,
    CONCAT(u.nombre, ' ', u.apellidos) AS nombre_completo,
    u.email,
    tm.nombre AS tipo_membresia,
    m.fecha_inicio,
    m.fecha_fin,
    m.estado
FROM usuarios u
JOIN membresias m ON m.usuario_id = u.id
JOIN tipos_membresia tm ON m.tipo_id = tm.id
WHERE m.estado = 'Activa'
  AND m.id = (
      SELECT m2.id FROM membresias m2
      WHERE m2.usuario_id = u.id
        AND m2.fecha_inicio <= NOW()
      ORDER BY m2.fecha_inicio DESC
      LIMIT 1
  )
ORDER BY u.nombre;

-- 03: Usuarios con membresía vencida

SELECT
    u.id,
    CONCAT(u.nombre, ' ', u.apellidos) AS nombre_completo,
    u.email,
    tm.nombre AS tipo_membresia,
    m.fecha_fin,
    DATEDIFF(CURRENT_DATE, m.fecha_fin) AS dias_vencida
FROM usuarios u
JOIN membresias m ON m.usuario_id = u.id
JOIN tipos_membresia tm ON m.tipo_id = tm.id
WHERE m.estado = 'Vencida'
  AND m.id = (
      SELECT m2.id FROM membresias m2
      WHERE m2.usuario_id = u.id
      ORDER BY m2.fecha_inicio DESC
      LIMIT 1
  )
ORDER BY dias_vencida DESC;

-- 04: Usuarios con membresía suspendida

SELECT
    u.id,
    CONCAT(u.nombre, ' ', u.apellidos) AS nombre_completo,
    u.email,
    tm.nombre AS tipo_membresia,
    m.estado,
    m.fecha_fin,
    DATEDIFF(CURRENT_DATE, m.fecha_fin) AS dias_desde_vencimiento
FROM usuarios u
JOIN membresias m ON m.usuario_id = u.id
JOIN tipos_membresia tm ON m.tipo_id = tm.id
WHERE m.estado = 'Suspendida'
  AND m.id = (
      SELECT m2.id FROM membresias m2
      WHERE m2.usuario_id = u.id
      ORDER BY m2.fecha_inicio DESC
      LIMIT 1
  )
ORDER BY u.nombre;

-- 05: Usuarios agrupados por tipo de membresía de referencia

SELECT
    tm.nombre AS tipo_membresia,
    COUNT(DISTINCT u.id) AS total_usuarios
FROM usuarios u
JOIN membresias m ON m.usuario_id = u.id
JOIN tipos_membresia tm ON m.tipo_id = tm.id
WHERE m.id = (
    SELECT m2.id FROM membresias m2
    WHERE m2.usuario_id = u.id
      AND m2.fecha_inicio <= NOW()
    ORDER BY m2.fecha_inicio DESC
    LIMIT 1
)
GROUP BY tm.nombre
ORDER BY total_usuarios DESC;

-- 06: Top 10 usuarios más antiguos 

SELECT
    u.id,
    CONCAT(u.nombre, ' ', u.apellidos) AS nombre_completo,
    u.email,
    u.fecha_registro,
    TIMESTAMPDIFF(MONTH, u.fecha_registro, CURRENT_DATE) AS meses_en_coworking
FROM usuarios u
ORDER BY u.fecha_registro ASC
LIMIT 10;

-- 07: Usuarios de una empresa específica 

SELECT
    u.id,
    CONCAT(u.nombre, ' ', u.apellidos) AS nombre_completo,
    u.email,
    u.tipo_usuario,
    u.activo,
    u.fecha_registro
FROM usuarios u
WHERE u.empresa_id = 1
ORDER BY u.nombre;

-- 08: Cantidad de usuarios agrupados por empresa

SELECT
    COALESCE(e.nombre, '(Sin Empresa / Independiente)') AS empresa,
    COUNT(u.id) AS total_usuarios
FROM usuarios u
LEFT JOIN empresas e ON u.empresa_id = e.id
GROUP BY u.empresa_id, e.nombre
ORDER BY total_usuarios DESC;

-- 09: Usuarios que nunca han realizado una reserva

SELECT
    u.id,
    CONCAT(u.nombre, ' ', u.apellidos) AS nombre_completo,
    u.email,
    u.tipo_usuario,
    u.fecha_registro
FROM usuarios u
LEFT JOIN reservas r ON r.usuario_id = u.id
WHERE r.id IS NULL
ORDER BY u.fecha_registro DESC;

-- 10: Usuarios con más de 5 reservas en el mes actual

SELECT
    u.id,
    CONCAT(u.nombre, ' ', u.apellidos) AS nombre_completo,
    COUNT(r.id) AS reservas_en_el_mes
FROM usuarios u
JOIN reservas r ON r.usuario_id = u.id
WHERE r.estado IN ('Pendiente', 'Confirmada')
  AND YEAR(r.fecha_inicio)  = YEAR(NOW())
  AND MONTH(r.fecha_inicio) = MONTH(NOW())
GROUP BY u.id, u.nombre, u.apellidos
HAVING COUNT(r.id) > 5
ORDER BY reservas_en_el_mes DESC;

-- 11: Edad promedio de todos los usuarios con fecha de nacimiento registrada

SELECT
    AVG(TIMESTAMPDIFF(YEAR, fecha_nac, CURRENT_DATE)) AS edad_promedio,
    MIN(TIMESTAMPDIFF(YEAR, fecha_nac, CURRENT_DATE)) AS edad_minima,
    MAX(TIMESTAMPDIFF(YEAR, fecha_nac, CURRENT_DATE)) AS edad_maxima
FROM usuarios
WHERE fecha_nac IS NOT NULL;

-- 12: Usuarios que han cambiado de tipo de membresía más de 2 veces

SELECT
    u.id,
    CONCAT(u.nombre, ' ', u.apellidos) AS nombre_completo,
    u.email,
    COUNT(hm.id) AS cambios_de_membresia
FROM usuarios u
JOIN historial_membresias hm ON hm.usuario_id = u.id
GROUP BY u.id, u.nombre, u.apellidos
HAVING COUNT(hm.id) > 2
ORDER BY cambios_de_membresia DESC;

-- 13: Usuarios que han gastado más de $500 en reservas

SELECT
    u.id,
    CONCAT(u.nombre, ' ', u.apellidos) AS nombre_completo,
    u.email,
    SUM(p.monto) AS gasto_total_reservas
FROM usuarios u
JOIN facturas f ON f.usuario_id = u.id AND f.tipo = 'Reserva'
JOIN pagos p ON p.factura_id = f.id AND p.estado = 'Aplicado'
GROUP BY u.id, u.nombre, u.apellidos
HAVING SUM(p.monto) > 500
ORDER BY gasto_total_reservas DESC;

-- 14: Usuarios que tienen membresía activa Y han contratado servicios adicionales

SELECT DISTINCT
    u.id,
    CONCAT(u.nombre, ' ', u.apellidos) AS nombre_completo,
    u.email,
    tm.nombre AS tipo_membresia,
    COUNT(sc.id) AS servicios_contratados
FROM usuarios u
JOIN membresias m ON m.usuario_id = u.id AND m.estado = 'Activa' AND NOW() BETWEEN m.fecha_inicio AND m.fecha_fin
JOIN tipos_membresia tm ON m.tipo_id = tm.id
JOIN servicios_contratados sc ON sc.usuario_id = u.id
GROUP BY u.id, u.nombre, u.apellidos, tm.nombre
ORDER BY servicios_contratados DESC;

-- 15: Usuarios Premium con reservas activas

SELECT
    u.id,
    CONCAT(u.nombre, ' ', u.apellidos) AS nombre_completo,
    u.email,
    m.fecha_fin AS vigencia_premium,
    COUNT(r.id) AS reservas_activas
FROM usuarios u
JOIN membresias m ON m.usuario_id = u.id
JOIN tipos_membresia tm ON m.tipo_id = tm.id AND tm.nombre = 'Premium'
JOIN reservas r ON r.usuario_id = u.id
  AND r.estado IN ('Pendiente', 'Confirmada')
  AND r.fecha_fin > NOW()
WHERE m.id = (
    SELECT m2.id FROM membresias m2
    WHERE m2.usuario_id = u.id AND m2.fecha_inicio <= NOW()
    ORDER BY m2.fecha_inicio DESC LIMIT 1
)
GROUP BY u.id, u.nombre, u.apellidos, m.fecha_fin
ORDER BY reservas_activas DESC;

-- 16: Usuarios con membresía Corporativa activa y su empresa asociada

SELECT
    u.id AS usuario_id,
    CONCAT(u.nombre, ' ', u.apellidos) AS nombre_empleado,
    u.email,
    e.nombre AS empresa,
    e.industria,
    m.fecha_inicio,
    m.fecha_fin,
    m.estado
FROM usuarios u
JOIN membresias m ON m.usuario_id = u.id
JOIN tipos_membresia tm ON m.tipo_id = tm.id AND tm.nombre = 'Corporativa'
JOIN empresas e ON u.empresa_id = e.id
WHERE m.id = (
    SELECT m2.id FROM membresias m2
    WHERE m2.usuario_id = u.id AND m2.fecha_inicio <= NOW()
    ORDER BY m2.fecha_inicio DESC LIMIT 1
)
  AND m.estado = 'Activa'
ORDER BY e.nombre, u.apellidos;

-- 17: Usuarios con membresía Diaria renovada más de 10 veces

SELECT
    u.id,
    CONCAT(u.nombre, ' ', u.apellidos) AS nombre_completo,
    u.email,
    COUNT(m.id) AS total_membresias_diarias
FROM usuarios u
JOIN membresias m ON m.usuario_id = u.id
JOIN tipos_membresia tm ON m.tipo_id = tm.id AND tm.nombre = 'Diaria'
GROUP BY u.id, u.nombre, u.apellidos
HAVING COUNT(m.id) > 10
ORDER BY total_membresias_diarias DESC;

-- 18: Usuarios con membresía que vence en los próximos 7 días

SELECT
    u.id,
    CONCAT(u.nombre, ' ', u.apellidos) AS nombre_completo,
    u.email,
    u.telefono,
    tm.nombre AS tipo_membresia,
    m.fecha_fin,
    DATEDIFF(m.fecha_fin, NOW()) AS dias_para_vencer
FROM usuarios u
JOIN membresias m ON m.usuario_id = u.id
JOIN tipos_membresia tm ON m.tipo_id = tm.id
WHERE m.estado = 'Activa'
  AND m.fecha_fin BETWEEN NOW() AND DATE_ADD(NOW(), INTERVAL 7 DAY)
ORDER BY m.fecha_fin ASC;

-- 19: Usuarios registrados en el último mes

SELECT
    u.id,
    CONCAT(u.nombre, ' ', u.apellidos) AS nombre_completo,
    u.email,
    u.tipo_usuario,
    e.nombre AS empresa,
    u.fecha_registro
FROM usuarios u
LEFT JOIN empresas e ON u.empresa_id = e.id
WHERE u.fecha_registro >= DATE_SUB(CURRENT_DATE, INTERVAL 1 MONTH)
ORDER BY u.fecha_registro DESC;

-- 20: Usuarios que nunca han asistido al coworking 

SELECT
    u.id,
    CONCAT(u.nombre, ' ', u.apellidos) AS nombre_completo,
    u.email,
    u.tipo_usuario,
    u.fecha_registro
FROM usuarios u
WHERE NOT EXISTS (
    SELECT 1 FROM asistencias a
    WHERE a.usuario_id = u.id AND a.tipo = 'Edificio'
)
ORDER BY u.fecha_registro DESC;
