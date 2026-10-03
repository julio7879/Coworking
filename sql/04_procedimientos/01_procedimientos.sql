/*
Módulo: Procedimientos Almacenados
Archivo: 01_procedimientos.sql

Descripción:
20 procedimientos almacenados transaccionales con prefijo obligatorio 'sp_':

Requisitos:
Ejecutar previamente 01_estructura.sql, 01_datos_iniciales.sql y 01_funciones.sql.
*/

USE coworking;

DELIMITER $$

-- =====================================================================
-- SECCIÓN 1: PROCEDIMIENTOS DE MEMBRESÍAS (1 - 4)
-- Integrante rsponsable: Julio Ernesto Castaño palacios
-- =====================================================================

-- 1. sp_registrar_membresia

DROP PROCEDURE IF EXISTS sp_registrar_membresia$$
CREATE PROCEDURE sp_registrar_membresia(
    IN  p_usuario_id   INT,
    IN  p_tipo_id      INT,
    IN  p_fecha_inicio DATETIME,
    OUT p_membresia_id INT
)
BEGIN
    DECLARE v_nombre_tipo VARCHAR(50);
    DECLARE v_precio DECIMAL(12,2);
    DECLARE v_duracion INT;
    DECLARE v_fecha_fin DATETIME;
    DECLARE v_estado VARCHAR(20);
    DECLARE v_dias_venc INT DEFAULT 15;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    SELECT nombre, precio, duracion_dias
    INTO v_nombre_tipo, v_precio, v_duracion
    FROM tipos_membresia
    WHERE id = p_tipo_id;

    IF v_nombre_tipo IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Tipo de membresía no válido';
    END IF;

    IF v_nombre_tipo = 'Diaria' THEN
        SET v_fecha_fin = STR_TO_DATE(CONCAT(DATE(p_fecha_inicio), ' 23:59:59'), '%Y-%m-%d %H:%i:%s');
    ELSEIF v_nombre_tipo = 'Corporativa' THEN
        SET v_fecha_fin = STR_TO_DATE(CONCAT(LAST_DAY(p_fecha_inicio), ' 23:59:59'), '%Y-%m-%d %H:%i:%s');
    ELSE
        SET v_fecha_fin = DATE_ADD(p_fecha_inicio, INTERVAL COALESCE(v_duracion, 30) DAY);
    END IF;

    IF v_nombre_tipo = 'Corporativa' THEN
        SET v_estado = 'Activa';
    ELSE
        SET v_estado = 'Pendiente';
    END IF;

    INSERT INTO membresias (usuario_id, tipo_id, fecha_inicio, fecha_fin, estado, renovaciones)
    VALUES (p_usuario_id, p_tipo_id, p_fecha_inicio, v_fecha_fin, v_estado, 0);

    SET p_membresia_id = LAST_INSERT_ID();

    IF v_nombre_tipo <> 'Corporativa' THEN
        SELECT CAST(COALESCE(MAX(valor), '15') AS UNSIGNED) INTO v_dias_venc
        FROM configuracion_sistema WHERE clave = 'dias_vencimiento_factura';

        INSERT INTO facturas (usuario_id, membresia_id, tipo, monto_base, recargo_acumulado, saldo_pendiente, estado, fecha_emision, fecha_vencimiento)
        VALUES (p_usuario_id, p_membresia_id, 'Membresia', v_precio, 0.00, v_precio, 'Pendiente', CURRENT_DATE, DATE_ADD(CURRENT_DATE, INTERVAL v_dias_venc DAY));

        INSERT INTO factura_detalle (factura_id, concepto, referencia_tipo, referencia_id, monto)
        VALUES (LAST_INSERT_ID(), CONCAT('Membresía ', v_nombre_tipo, ' - Usuario ID ', p_usuario_id), 'Membresia', p_membresia_id, v_precio);
    END IF;

    COMMIT;
END$$

-- 2. sp_renovar_membresia

DROP PROCEDURE IF EXISTS sp_renovar_membresia$$
CREATE PROCEDURE sp_renovar_membresia(
    IN  p_usuario_id           INT,
    IN  p_tipo_id              INT,
    OUT p_nueva_membresia_id   INT
)
BEGIN
    DECLARE v_ultima_fin DATETIME;
    DECLARE v_fecha_inicio DATETIME;
    DECLARE v_renovaciones INT DEFAULT 0;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    SELECT fecha_fin, renovaciones INTO v_ultima_fin, v_renovaciones
    FROM membresias
    WHERE usuario_id = p_usuario_id
    ORDER BY fecha_fin DESC
    LIMIT 1;

    IF v_ultima_fin IS NOT NULL AND v_ultima_fin > NOW() THEN
        SET v_fecha_inicio = DATE_ADD(v_ultima_fin, INTERVAL 1 SECOND);
    ELSE
        SET v_fecha_inicio = NOW();
    END IF;

    CALL sp_registrar_membresia(p_usuario_id, p_tipo_id, v_fecha_inicio, p_nueva_membresia_id);

    UPDATE membresias
    SET renovaciones = v_renovaciones + 1
    WHERE id = p_nueva_membresia_id;

    COMMIT;
END$$

-- 3. sp_actualizar_membresias_vencidas

DROP PROCEDURE IF EXISTS sp_actualizar_membresias_vencidas$$
CREATE PROCEDURE sp_actualizar_membresias_vencidas()
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    UPDATE membresias m
    SET m.estado = 'Suspendida'
    WHERE m.estado = 'Activa'
      AND m.fecha_fin < NOW()
      AND EXISTS (
          SELECT 1 FROM facturas f
          WHERE f.usuario_id = m.usuario_id
            AND f.saldo_pendiente > 0
            AND f.fecha_vencimiento < CURRENT_DATE
      );

    UPDATE membresias m
    SET m.estado = 'Vencida'
    WHERE m.estado = 'Activa'
      AND m.fecha_fin < NOW();

    UPDATE membresias m
    SET m.estado = 'Vencida'
    WHERE m.estado = 'Suspendida'
      AND m.fecha_fin < NOW()
      AND NOT EXISTS (
          SELECT 1 FROM facturas f
          WHERE f.usuario_id = m.usuario_id
            AND f.saldo_pendiente > 0
      );

    COMMIT;
END$$

-- 4. sp_suspender_membresias_impagas

DROP PROCEDURE IF EXISTS sp_suspender_membresias_impagas$$
CREATE PROCEDURE sp_suspender_membresias_impagas(IN p_dias_mora INT)
BEGIN
    DECLARE v_done INT DEFAULT FALSE;
    DECLARE v_uid INT;
    DECLARE cur_usuarios CURSOR FOR
        SELECT DISTINCT u.id
        FROM usuarios u
        JOIN facturas f ON (f.usuario_id = u.id OR f.empresa_id = u.empresa_id)
        WHERE f.saldo_pendiente > 0
          AND f.estado IN ('Pendiente', 'Incobrable')
          AND DATEDIFF(CURRENT_DATE, f.fecha_vencimiento) > p_dias_mora;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = TRUE;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    OPEN cur_usuarios;
    read_loop: LOOP
        FETCH cur_usuarios INTO v_uid;
        IF v_done THEN
            LEAVE read_loop;
        END IF;

        UPDATE membresias
        SET estado = 'Suspendida'
        WHERE usuario_id = v_uid AND estado = 'Activa';

        CALL sp_cancelar_reservas_futuras_usuario(v_uid, 'Suspensión por falta de pago prolongada');
    END LOOP;
    CLOSE cur_usuarios;

    COMMIT;
END$$