/*
Proyecto: Gestión de Coworking

Grupo: 01

Integrante Responsable: Valeria Lizcano Arena

Módulo: Consultas - Módulo 3: Pagos y Facturación (41-60)
Archivo: 03_pagos_facturacion.sql

Descripción:
Consultas de análisis financiero, flujo de caja, mora, ingresos por período y métodos de pago.
*/
USE coworking;

-- 41: Pagos realizados con tarjeta de crédito/débito 

SELECT
    p.id AS pago_id,
    CONCAT(u.nombre, ' ', u.apellidos) AS usuario,
    mp.nombre AS metodo_pago,
    p.monto,
    p.fecha_pago,
    f.tipo AS tipo_factura,
    p.referencia,
    p.estado
FROM pagos p
JOIN facturas f ON p.factura_id = f.id
LEFT JOIN usuarios u ON f.usuario_id = u.id
JOIN metodos_pago mp ON p.metodo_pago_id = mp.id
WHERE mp.nombre LIKE '%Tarjeta%'
  AND p.monto > 0
  AND p.estado = 'Aplicado'
ORDER BY p.fecha_pago DESC;


-- 42: Facturas pendientes de usuarios con saldo mayor a cero

SELECT
    f.id AS factura_id,
    CONCAT(u.nombre, ' ', u.apellidos) AS usuario,
    u.email,
    f.tipo,
    f.monto_base,
    f.recargo_acumulado,
    f.monto_total,
    f.saldo_pendiente,
    f.fecha_vencimiento,
    DATEDIFF(CURRENT_DATE, f.fecha_vencimiento) AS dias_mora
FROM facturas f
JOIN usuarios u ON f.usuario_id = u.id
WHERE f.estado = 'Pendiente'
  AND f.saldo_pendiente > 0
ORDER BY dias_mora DESC, f.saldo_pendiente DESC;


-- 43: Pagos cancelados en los últimos 3 meses

SELECT
    p.id AS pago_id,
    CONCAT(u.nombre, ' ', u.apellidos) AS usuario,
    mp.nombre AS metodo_pago,
    p.monto,
    p.fecha_pago,
    f.tipo AS tipo_factura,
    p.estado
FROM pagos p
JOIN facturas f ON p.factura_id = f.id
LEFT JOIN usuarios u ON f.usuario_id = u.id
JOIN metodos_pago mp ON p.metodo_pago_id = mp.id
WHERE p.estado = 'Cancelado'
  AND p.fecha_pago >= DATE_SUB(NOW(), INTERVAL 3 MONTH)
ORDER BY p.fecha_pago DESC;

-- 44: Facturas de membresías 

SELECT
    f.id AS factura_id,
    COALESCE(CONCAT(u.nombre, ' ', u.apellidos), 'N/A (Corporativa)') AS usuario_o_empresa,
    COALESCE(e.nombre, '-') AS empresa,
    f.tipo,
    f.monto_base,
    f.recargo_acumulado,
    f.monto_total,
    f.saldo_pendiente,
    f.estado,
    f.fecha_emision,
    f.fecha_vencimiento
FROM facturas f
LEFT JOIN usuarios u ON f.usuario_id = u.id
LEFT JOIN empresas e ON f.empresa_id = e.id
WHERE f.tipo IN ('Membresia', 'Consolidada')
ORDER BY f.fecha_emision DESC;


-- 45: Facturas de reservas 

SELECT
    f.id AS factura_id,
    CONCAT(u.nombre, ' ', u.apellidos) AS usuario,
    f.reserva_id,
    esp.nombre AS espacio,
    f.monto_base,
    f.monto_total,
    f.saldo_pendiente,
    f.estado,
    f.fecha_emision,
    f.fecha_vencimiento
FROM facturas f
JOIN usuarios u ON f.usuario_id = u.id
LEFT JOIN reservas r ON f.reserva_id = r.id
LEFT JOIN espacios esp ON r.espacio_id = esp.id
WHERE f.tipo = 'Reserva'
ORDER BY f.fecha_emision DESC;


-- 46: Ingresos por membresías en el mes anterior 

SELECT
    YEAR(p.fecha_pago)  AS anio,
    MONTH(p.fecha_pago) AS mes,
    f.tipo,
    SUM(p.monto) AS ingresos_netos
FROM pagos p
JOIN facturas f ON p.factura_id = f.id
WHERE p.estado = 'Aplicado'
  AND f.tipo IN ('Membresia', 'Consolidada')
  AND YEAR(p.fecha_pago)  = YEAR(DATE_SUB(NOW(), INTERVAL 1 MONTH))
  AND MONTH(p.fecha_pago) = MONTH(DATE_SUB(NOW(), INTERVAL 1 MONTH))
GROUP BY YEAR(p.fecha_pago), MONTH(p.fecha_pago), f.tipo
ORDER BY mes;



-- 47: Ingresos por reservas en el mes anterior

SELECT
    YEAR(p.fecha_pago)  AS anio,
    MONTH(p.fecha_pago) AS mes,
    SUM(p.monto)        AS ingresos_netos_reservas
FROM pagos p
JOIN facturas f ON p.factura_id = f.id
WHERE p.estado = 'Aplicado'
  AND f.tipo = 'Reserva'
  AND YEAR(p.fecha_pago)  = YEAR(DATE_SUB(NOW(), INTERVAL 1 MONTH))
  AND MONTH(p.fecha_pago) = MONTH(DATE_SUB(NOW(), INTERVAL 1 MONTH))
GROUP BY YEAR(p.fecha_pago), MONTH(p.fecha_pago);



-- 48: Ingresos por servicios adicionales

SELECT
    YEAR(p.fecha_pago)  AS anio,
    MONTH(p.fecha_pago) AS mes,
    SUM(p.monto)        AS ingresos_servicios
FROM pagos p
JOIN facturas f ON p.factura_id = f.id
WHERE p.estado = 'Aplicado'
  AND f.tipo = 'Servicio'
GROUP BY YEAR(p.fecha_pago), MONTH(p.fecha_pago)
ORDER BY anio DESC, mes DESC;



-- 49: Usuarios que nunca han pagado con PayPal 

SELECT
    u.id,
    CONCAT(u.nombre, ' ', u.apellidos) AS nombre_completo,
    u.email
FROM usuarios u
WHERE NOT EXISTS (
    SELECT 1
    FROM facturas f
    JOIN pagos p ON p.factura_id = f.id
    JOIN metodos_pago mp ON p.metodo_pago_id = mp.id
    WHERE f.usuario_id = u.id
      AND mp.nombre = 'PayPal'
      AND p.estado = 'Aplicado'
)
ORDER BY u.nombre;



-- 50: Gasto promedio por usuario 

SELECT
    ROUND(AVG(gasto_usuario), 2) AS gasto_promedio_por_usuario
FROM (
    SELECT
        f.usuario_id,
        SUM(p.monto) AS gasto_usuario
    FROM pagos p
    JOIN facturas f ON p.factura_id = f.id
    WHERE p.estado = 'Aplicado'
      AND f.usuario_id IS NOT NULL
    GROUP BY f.usuario_id
) AS sub_gastos;



-- 51: Top 5 usuarios que más pagan 

SELECT
    u.id,
    CONCAT(u.nombre, ' ', u.apellidos) AS nombre_completo,
    u.email,
    SUM(p.monto) AS total_pagado
FROM usuarios u
JOIN facturas f ON f.usuario_id = u.id AND f.tipo <> 'Consolidada'
JOIN pagos p ON p.factura_id = f.id AND p.estado = 'Aplicado'
GROUP BY u.id, u.nombre, u.apellidos
ORDER BY total_pagado DESC
LIMIT 5;



-- 52: Facturas con monto_total mayor a $1000

SELECT
    f.id AS factura_id,
    COALESCE(CONCAT(u.nombre, ' ', u.apellidos), 'Empresa Corporativa') AS titular,
    COALESCE(e.nombre, '-') AS empresa,
    f.tipo,
    f.monto_base,
    f.recargo_acumulado,
    f.monto_total,
    f.saldo_pendiente,
    f.estado,
    f.fecha_emision
FROM facturas f
LEFT JOIN usuarios u ON f.usuario_id = u.id
LEFT JOIN empresas e ON f.empresa_id = e.id
WHERE f.monto_total > 1000
ORDER BY f.monto_total DESC;



-- 53: Pagos realizados después de la fecha de vencimiento de la factura

SELECT
    p.id AS pago_id,
    CONCAT(u.nombre, ' ', u.apellidos) AS usuario,
    p.monto,
    p.fecha_pago,
    f.fecha_vencimiento,
    DATEDIFF(DATE(p.fecha_pago), f.fecha_vencimiento) AS dias_despues_vencimiento,
    f.tipo AS tipo_factura
FROM pagos p
JOIN facturas f ON p.factura_id = f.id
LEFT JOIN usuarios u ON f.usuario_id = u.id
WHERE p.monto > 0
  AND p.estado = 'Aplicado'
  AND DATE(p.fecha_pago) > f.fecha_vencimiento
ORDER BY dias_despues_vencimiento DESC;



-- 54: Total recaudado en el año actual

SELECT
    YEAR(p.fecha_pago) AS anio,
    SUM(p.monto)       AS total_recaudado_neto
FROM pagos p
WHERE p.estado = 'Aplicado'
  AND YEAR(p.fecha_pago) = YEAR(NOW())
GROUP BY YEAR(p.fecha_pago);



-- 55: Facturas anuladas y su motivo de anulación

SELECT
    f.id AS factura_id,
    COALESCE(CONCAT(u.nombre, ' ', u.apellidos), 'N/A') AS usuario,
    f.tipo,
    f.monto_base,
    f.estado,
    f.fecha_emision,
    f.motivo_anulacion
FROM facturas f
LEFT JOIN usuarios u ON f.usuario_id = u.id
WHERE f.estado = 'Anulada'
ORDER BY f.fecha_emision DESC;



-- 56: Usuarios con saldo pendiente acumulado mayor a $200

SELECT
    u.id,
    CONCAT(u.nombre, ' ', u.apellidos) AS nombre_completo,
    u.email,
    SUM(f.saldo_pendiente) AS saldo_total_pendiente
FROM usuarios u
JOIN facturas f ON f.usuario_id = u.id
WHERE f.saldo_pendiente > 0
  AND f.estado IN ('Pendiente', 'Incobrable')
GROUP BY u.id, u.nombre, u.apellidos
HAVING SUM(f.saldo_pendiente) > 200
ORDER BY saldo_total_pendiente DESC;



-- 57: Usuarios que contrataron el mismo servicio adicional más de 1 vez

SELECT
    u.id AS usuario_id,
    CONCAT(u.nombre, ' ', u.apellidos) AS nombre_completo,
    sa.nombre AS servicio,
    COUNT(sc.id) AS veces_contratado,
    SUM(sc.cantidad * sc.precio_unitario) AS gasto_total_en_servicio
FROM servicios_contratados sc
JOIN usuarios u ON sc.usuario_id = u.id
JOIN servicios_adicionales sa ON sc.servicio_id = sa.id
GROUP BY u.id, u.nombre, u.apellidos, sa.id, sa.nombre
HAVING COUNT(sc.id) > 1
ORDER BY veces_contratado DESC;



-- 58: Ingresos totales agrupados por método de pago

SELECT
    mp.nombre AS metodo_pago,
    COUNT(p.id) AS numero_transacciones,
    SUM(p.monto) AS ingresos_netos
FROM pagos p
JOIN metodos_pago mp ON p.metodo_pago_id = mp.id
WHERE p.estado = 'Aplicado'
GROUP BY mp.id, mp.nombre
ORDER BY ingresos_netos DESC;



-- 59: Facturación bruta por empresa

SELECT
    e.id AS empresa_id,
    e.nombre AS empresa,
    e.industria,
    COUNT(f.id) AS total_facturas,
    SUM(f.monto_total) AS facturacion_bruta
FROM empresas e
JOIN facturas f ON f.empresa_id = e.id
GROUP BY e.id, e.nombre, e.industria
ORDER BY facturacion_bruta DESC;



-- 60: Ingresos netos por mes en el último año 

SELECT
    YEAR(p.fecha_pago)  AS anio,
    MONTH(p.fecha_pago) AS mes,
    COUNT(CASE WHEN p.monto > 0 THEN 1 END) AS cobros,
    COUNT(CASE WHEN p.monto < 0 THEN 1 END) AS reembolsos,
    SUM(CASE WHEN p.monto > 0 THEN p.monto ELSE 0 END)  AS total_cobrado,
    SUM(CASE WHEN p.monto < 0 THEN p.monto ELSE 0 END)  AS total_reembolsado,
    SUM(p.monto) AS ingreso_neto
FROM pagos p
WHERE p.estado = 'Aplicado'
  AND p.fecha_pago >= DATE_SUB(NOW(), INTERVAL 12 MONTH)
GROUP BY YEAR(p.fecha_pago), MONTH(p.fecha_pago)
ORDER BY anio DESC, mes DESC;