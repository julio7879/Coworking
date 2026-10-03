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

-- =====================================================================
-- SECCIÓN 1: FUNCIONES DE MEMBRESÍAS (1 - 5)
-- Integrante responsables: Julio Ernesto Castaño Palacios (1-4)
-- =====================================================================

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

