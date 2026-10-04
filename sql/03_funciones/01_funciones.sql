/*
Módulo: Funciones Almacenadas
Archivo: 01_funciones.sql

Descripción:
- 5 funciones de membresías
- 5 funciones de reservas
- 5 funciones de pagos y finanzas
- 5 funciones de asistencias y accesos

Requisitos:
Ejecutar previamente 01_estructura.sql y 01_datos_iniciales.sql.
*/

USE coworking;

DELIMITER $$

-- SECCIÓN 1: FUNCIONES DE MEMBRESÍAS (1 - 5)
-- Integrante responsables: Julio Ernesto Castaño Palacios (1-4)


-- 1. fn_membresia_activa

DROP FUNCTION IF EXISTS fn_membresia_activa$$
CREATE FUNCTION fn_membresia_activa(p_usuario_id INT)
RETURNS BOOLEAN
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_activa BOOLEAN DEFAULT FALSE;
    SELECT EXISTS (
        SELECT 1 FROM membresias
        WHERE usuario_id = p_usuario_id
          AND estado = 'Activa'
          AND NOW() BETWEEN fecha_inicio AND fecha_fin
    ) INTO v_activa;
    RETURN v_activa;
END$$

-- 2. fn_estado_membresia

DROP FUNCTION IF EXISTS fn_estado_membresia$$
CREATE FUNCTION fn_estado_membresia(p_usuario_id INT)
RETURNS VARCHAR(20)
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_estado VARCHAR(20);
    
    -- Busca membresía vigente en curso
    SELECT 
        CASE 
            WHEN estado = 'Pendiente' THEN 'Suspendida'
            ELSE estado 
        END INTO v_estado
    FROM membresias
    WHERE usuario_id = p_usuario_id
      AND NOW() BETWEEN fecha_inicio AND fecha_fin
    ORDER BY fecha_inicio DESC
    LIMIT 1;

    -- Si no hay vigente, busca la más reciente histórica
    IF v_estado IS NULL THEN
        SELECT 
            CASE 
                WHEN estado = 'Pendiente' THEN 'Suspendida'
                ELSE estado 
            END INTO v_estado
        FROM membresias
        WHERE usuario_id = p_usuario_id
        ORDER BY fecha_inicio DESC
        LIMIT 1;
    END IF;

    RETURN COALESCE(v_estado, 'Vencida');
END$$

-- 3. fn_tipo_membresia

DROP FUNCTION IF EXISTS fn_tipo_membresia$$
CREATE FUNCTION fn_tipo_membresia(p_usuario_id INT)
RETURNS VARCHAR(50)
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_nombre VARCHAR(50);
    SELECT tm.nombre INTO v_nombre
    FROM membresias m
    JOIN tipos_membresia tm ON m.tipo_id = tm.id
    WHERE m.usuario_id = p_usuario_id
      AND m.fecha_inicio <= NOW()
    ORDER BY m.fecha_inicio DESC
    LIMIT 1;

    RETURN v_nombre;
END$$

-- 4. fn_dias_restantes_membresia

DROP FUNCTION IF EXISTS fn_dias_restantes_membresia$$
CREATE FUNCTION fn_dias_restantes_membresia(p_usuario_id INT)
RETURNS INT
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_dias INT DEFAULT 0;
    SELECT GREATEST(DATEDIFF(fecha_fin, CURRENT_DATE), 0) INTO v_dias
    FROM membresias
    WHERE usuario_id = p_usuario_id
      AND NOW() BETWEEN fecha_inicio AND fecha_fin
    ORDER BY fecha_inicio DESC
    LIMIT 1;

    RETURN COALESCE(v_dias, 0);
END$$

-- Integrante responsables: Sofia Salazar Hernandez(5-8)

-- 5. fn_renovaciones_membresia

DROP FUNCTION IF EXISTS fn_renovaciones_membresia$$
CREATE FUNCTION fn_renovaciones_membresia(p_usuario_id INT)
RETURNS INT
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_count INT DEFAULT 0;
    SELECT GREATEST(COUNT(*) - 1, 0) INTO v_count
    FROM membresias
    WHERE usuario_id = p_usuario_id;

    RETURN COALESCE(v_count, 0);
END$$



-- SECCIÓN 2: FUNCIONES DE RESERVAS (6 - 10)
-- Integrante responsables: Sofia Salazar Hernandez (5-8)


-- 6. fn_total_reservas

DROP FUNCTION IF EXISTS fn_total_reservas$$
CREATE FUNCTION fn_total_reservas(p_usuario_id INT)
RETURNS INT
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_total INT DEFAULT 0;
    SELECT COUNT(*) INTO v_total
    FROM reservas
    WHERE usuario_id = p_usuario_id;
    RETURN COALESCE(v_total, 0);
END$$

-- 7. fn_horas_reservadas

DROP FUNCTION IF EXISTS fn_horas_reservadas$$
CREATE FUNCTION fn_horas_reservadas(p_usuario_id INT, p_mes INT, p_anio INT)
RETURNS DECIMAL(10,2)
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_horas DECIMAL(10,2) DEFAULT 0.00;
    SELECT COALESCE(SUM(TIMESTAMPDIFF(MINUTE, fecha_inicio, fecha_fin) / 60.0), 0.00)
    INTO v_horas
    FROM reservas
    WHERE usuario_id = p_usuario_id
      AND MONTH(fecha_inicio) = p_mes
      AND YEAR(fecha_inicio) = p_anio
      AND estado <> 'Cancelada';
    RETURN v_horas;
END$$

-- 8. fn_espacio_mas_reservado

DROP FUNCTION IF EXISTS fn_espacio_mas_reservado$$
CREATE FUNCTION fn_espacio_mas_reservado()
RETURNS INT
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_espacio_id INT;
    SELECT espacio_id INTO v_espacio_id
    FROM reservas
    WHERE estado <> 'Cancelada'
    GROUP BY espacio_id
    ORDER BY COUNT(*) DESC, espacio_id ASC
    LIMIT 1;
    RETURN v_espacio_id;
END$$

-- Integrante responsable: Valeria Lizcano Arena 


-- 9. fn_reservas_activas

DROP FUNCTION IF EXISTS fn_reservas_activas$$
CREATE FUNCTION fn_reservas_activas(p_usuario_id INT)
RETURNS INT
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_activas INT DEFAULT 0;
    SELECT COUNT(*) INTO v_activas
    FROM reservas
    WHERE usuario_id = p_usuario_id
      AND estado IN ('Pendiente', 'Confirmada')
      AND fecha_fin > NOW();
    RETURN COALESCE(v_activas, 0);
END$$

-- 10. fn_duracion_promedio_reservas

_duracion_promedio_reservas$$
CREATE FUNCTION fn_duracion_promedio_reservas(p_espacio_id INT)
RETURNS DECIMAL(10,2)
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_prom DECIMAL(10,2) DEFAULT 0.00;
    SELECT COALESCE(AVG(TIMESTAMPDIFF(MINUTE, fecha_inicio, fecha_fin) / 60.0), 0.00)
    INTO v_prom
    FROM reservas
    WHERE espacio_id = p_espacio_id
      AND estado <> 'Cancelada';
    RETURN v_prom;
END$$


-- SECCIÓN 3: FUNCIONES DE PAGOS Y FACTURACIÓN (11 - 15)
-- Integrante responsable: Valeria Lizcano Arena

-- 11. fn_total_pagado

DROP FUNCTION IF EXISTS fn_total_pagado$$
CREATE FUNCTION fn_total_pagado(p_usuario_id INT)
RETURNS DECIMAL(12,2)
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_total DECIMAL(12,2) DEFAULT 0.00;
    SELECT COALESCE(SUM(p.monto), 0.00) INTO v_total
    FROM pagos p
    JOIN facturas f ON p.factura_id = f.id
    WHERE f.usuario_id = p_usuario_id
      AND p.estado = 'Aplicado';
    RETURN v_total;
END$$

-- 12. fn_ingresos_por_mes

DROP FUNCTION IF EXISTS fn_ingresos_por_mes$$
CREATE FUNCTION fn_ingresos_por_mes(p_mes INT, p_anio INT)
RETURNS DECIMAL(12,2)
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_ingresos DECIMAL(12,2) DEFAULT 0.00;
    SELECT COALESCE(SUM(monto), 0.00) INTO v_ingresos
    FROM pagos
    WHERE estado = 'Aplicado'
      AND MONTH(fecha_pago) = p_mes
      AND YEAR(fecha_pago) = p_anio;
    RETURN v_ingresos;
END$$

-- Integrante Responsable: Zlatan Ricardo Villamizar 

-- 13. fn_ingresos_por_membresia
DROP FUNCTION IF EXISTS fn_ingresos_por_membresia$$
CREATE FUNCTION fn_ingresos_por_membresia(p_tipo_id INT)
RETURNS DECIMAL(12,2)
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_total DECIMAL(12,2) DEFAULT 0.00;
    
    SELECT COALESCE(SUM(p.monto), 0.00) INTO v_total
    FROM pagos p
    JOIN facturas f ON p.factura_id = f.id
    JOIN membresias m ON f.membresia_id = m.id
    WHERE m.tipo_id = p_tipo_id
      AND p.estado = 'Aplicado';

    IF p_tipo_id = 3 THEN
        SELECT v_total + COALESCE(SUM(p.monto), 0.00) INTO v_total
        FROM pagos p
        JOIN facturas f ON p.factura_id = f.id
        WHERE f.tipo = 'Consolidada'
          AND p.estado = 'Aplicado';
    END IF;

    RETURN v_total;
END$$

-- 14. fn_ingresos_por_reservas

DROP FUNCTION IF EXISTS fn_ingresos_por_reservas$$
CREATE FUNCTION fn_ingresos_por_reservas(p_mes INT, p_anio INT)
RETURNS DECIMAL(12,2)
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_total DECIMAL(12,2) DEFAULT 0.00;
    SELECT COALESCE(SUM(p.monto), 0.00) INTO v_total
    FROM pagos p
    JOIN facturas f ON p.factura_id = f.id
    WHERE f.tipo = 'Reserva'
      AND p.estado = 'Aplicado'
      AND MONTH(p.fecha_pago) = p_mes
      AND YEAR(p.fecha_pago) = p_anio;
    RETURN v_total;
END$$

-- 15. fn_ingresos_por_empresa

DROP FUNCTION IF EXISTS fn_ingresos_por_empresa$$
CREATE FUNCTION fn_ingresos_por_empresa(p_empresa_id INT)
RETURNS DECIMAL(12,2)
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_empresa DECIMAL(12,2) DEFAULT 0.00;
    DECLARE v_empleados DECIMAL(12,2) DEFAULT 0.00;

    SELECT COALESCE(SUM(p.monto), 0.00) INTO v_empresa
    FROM pagos p
    JOIN facturas f ON p.factura_id = f.id
    WHERE f.empresa_id = p_empresa_id
      AND p.estado = 'Aplicado';

    SELECT COALESCE(SUM(p.monto), 0.00) INTO v_empleados
    FROM pagos p
    JOIN facturas f ON p.factura_id = f.id
    JOIN usuarios u ON f.usuario_id = u.id
    WHERE u.empresa_id = p_empresa_id
      AND p.estado = 'Aplicado';

    RETURN (v_empresa + v_empleados);
END$$.
DROP FUNCTION IF EXISTS fn_ingresos_por_reservas$$
CREATE FUNCTION fn_ingresos_por_reservas(p_mes INT, p_anio INT)
RETURNS DECIMAL(12,2)
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_total DECIMAL(12,2) DEFAULT 0.00;
    SELECT COALESCE(SUM(p.monto), 0.00) INTO v_total
    FROM pagos p
    JOIN facturas f ON p.factura_id = f.id
    WHERE f.tipo = 'Reserva'
      AND p.estado = 'Aplicado'
      AND MONTH(p.fecha_pago) = p_mes
      AND YEAR(p.fecha_pago) = p_anio;
    RETURN v_total;
END$$

-- SECCIÓN 4: FUNCIONES DE ASISTENCIAS Y ACCESOS (16 - 20)
-- Integrante Responsable: Brenda Nico Carrillo Gonzalez

-- 16. fn_total_asistencias

DROP FUNCTION IF EXISTS fn_total_asistencias$$
CREATE FUNCTION fn_total_asistencias(p_usuario_id INT)
RETURNS INT
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_total INT DEFAULT 0;
    SELECT COUNT(*) INTO v_total
    FROM asistencias
    WHERE usuario_id = p_usuario_id
      AND tipo = 'Edificio';
    RETURN COALESCE(v_total, 0);
END$$

-- 17. fn_asistencias_mes

DROP FUNCTION IF EXISTS fn_asistencias_mes$$
CREATE FUNCTION fn_asistencias_mes(p_usuario_id INT, p_mes INT, p_anio INT)
RETURNS INT
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_total INT DEFAULT 0;
    SELECT COUNT(*) INTO v_total
    FROM asistencias
    WHERE usuario_id = p_usuario_id
      AND tipo = 'Edificio'
      AND MONTH(fecha_entrada) = p_mes
      AND YEAR(fecha_entrada) = p_anio;
    RETURN COALESCE(v_total, 0);
END$$

-- 18. fn_ultima_asistencia

DROP FUNCTION IF EXISTS fn_ultima_asistencia$$
CREATE FUNCTION fn_ultima_asistencia(p_usuario_id INT)
RETURNS DATETIME
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_fecha DATETIME;
    SELECT fecha_entrada INTO v_fecha
    FROM asistencias
    WHERE usuario_id = p_usuario_id
      AND tipo = 'Edificio'
    ORDER BY fecha_entrada DESC
    LIMIT 1;
    RETURN v_fecha;
END$$

-- 19. fn_top_usuario_asistencias

DROP FUNCTION IF EXISTS fn_top_usuario_asistencias$$
CREATE FUNCTION fn_top_usuario_asistencias()
RETURNS INT
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_usuario_id INT;
    SELECT usuario_id INTO v_usuario_id
    FROM asistencias
    WHERE tipo = 'Edificio'
    GROUP BY usuario_id
    ORDER BY COUNT(*) DESC, usuario_id ASC
    LIMIT 1;
    RETURN v_usuario_id;
END$$

-- 20. fn_promedio_asistencias

DROP FUNCTION IF EXISTS fn_promedio_asistencias$$
CREATE FUNCTION fn_promedio_asistencias()
RETURNS DECIMAL(10,2)
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_prom DECIMAL(10,2) DEFAULT 0.00;
    SELECT COALESCE(AVG(asist_count), 0.00) INTO v_prom
    FROM (
        SELECT COUNT(a.id) AS asist_count
        FROM usuarios u
        JOIN membresias m ON m.usuario_id = u.id
            AND m.estado = 'Activa'
            AND NOW() BETWEEN m.fecha_inicio AND m.fecha_fin
        LEFT JOIN asistencias a ON a.usuario_id = u.id AND a.tipo = 'Edificio'
        GROUP BY u.id
    ) AS sub;
    RETURN v_prom;
END$$

DELIMITER ;