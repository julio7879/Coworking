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

-- SECCIÓN 1: PROCEDIMIENTOS DE MEMBRESÍAS (1 - 4)
-- Integrante rsponsable: Julio Ernesto Castaño palacios

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

-- SECCIÓN 2: PROCEDIMIENTOS DE RESERVAS (5 - 9)
-- Integrante responsable: Sofia Salazar Hernandez

-- 5. sp_verificar_disponibilidad

DROP PROCEDURE IF EXISTS sp_verificar_disponibilidad$$
CREATE PROCEDURE sp_verificar_disponibilidad(
    IN  p_espacio_id   INT,
    IN  p_modalidad    VARCHAR(10),
    IN  p_fecha_inicio DATETIME,
    IN  p_fecha_fin    DATETIME,
    IN  p_num_personas INT,
    OUT p_disponible   BOOLEAN,
    OUT p_motivo       VARCHAR(255)
)
BEGIN
    DECLARE v_estado VARCHAR(20);
    DECLARE v_modo VARCHAR(20);
    DECLARE v_capacidad INT;
    DECLARE v_perm_hora BOOLEAN;
    DECLARE v_perm_mes  BOOLEAN;
    DECLARE v_dia_semana TINYINT;
    DECLARE v_hora_ini TIME;
    DECLARE v_hora_fin TIME;
    DECLARE v_apertura TIME;
    DECLARE v_cierre TIME;
    DECLARE v_solapados INT DEFAULT 0;

    SET p_disponible = TRUE;
    SET p_motivo = 'Espacio disponible';

    IF p_fecha_fin <= p_fecha_inicio THEN
        SET p_disponible = FALSE;
        SET p_motivo = 'La fecha de fin debe ser posterior a la de inicio';
        RETURN;
    END IF;

    SELECT e.estado, te.modo_ocupacion, e.capacidad_maxima, te.permite_reserva_hora, te.permite_reserva_mes
    INTO v_estado, v_modo, v_capacidad, v_perm_hora, v_perm_mes
    FROM espacios e
    JOIN tipos_espacio te ON e.tipo_id = te.id
    WHERE e.id = p_espacio_id;

    IF v_estado IS NULL THEN
        SET p_disponible = FALSE;
        SET p_motivo = 'Espacio no existe';
        RETURN;
    ELSEIF v_estado <> 'Disponible' THEN
        SET p_disponible = FALSE;
        SET p_motivo = CONCAT('El espacio se encuentra en estado: ', v_estado);
        RETURN;
    END IF;

    IF p_modalidad = 'Hora' AND NOT v_perm_hora THEN
        SET p_disponible = FALSE;
        SET p_motivo = 'Este tipo de espacio no permite reservas por hora';
        RETURN;
    ELSEIF p_modalidad = 'Mes' AND NOT v_perm_mes THEN
        SET p_disponible = FALSE;
        SET p_motivo = 'Este tipo de espacio no permite reservas mensuales';
        RETURN;
    END IF;

    IF p_num_personas > v_capacidad THEN
        SET p_disponible = FALSE;
        SET p_motivo = CONCAT('El número de personas (', p_num_personas, ') supera la capacidad máxima (', v_capacidad, ')');
        RETURN;
    END IF;

    IF p_modalidad = 'Hora' THEN
        SET v_dia_semana = DAYOFWEEK(p_fecha_inicio);
        SET v_hora_ini = TIME(p_fecha_inicio);
        SET v_hora_fin = TIME(p_fecha_fin);

        SELECT hora_apertura, hora_cierre INTO v_apertura, v_cierre
        FROM horarios_disponibilidad
        WHERE (espacio_id = p_espacio_id OR espacio_id IS NULL)
          AND dia_semana = v_dia_semana
        ORDER BY espacio_id DESC
        LIMIT 1;

        IF v_apertura IS NULL OR v_hora_ini < v_apertura OR v_hora_fin > v_cierre THEN
            SET p_disponible = FALSE;
            SET p_motivo = 'La reserva está fuera del horario de disponibilidad del espacio';
            RETURN;
        END IF;
    END IF;

    IF v_modo = 'Exclusivo' THEN
        SELECT COUNT(*) INTO v_solapados
        FROM reservas
        WHERE espacio_id = p_espacio_id
          AND estado IN ('Pendiente', 'Confirmada')
          AND p_fecha_inicio < fecha_fin
          AND p_fecha_fin > fecha_inicio;

        IF v_solapados > 0 THEN
            SET p_disponible = FALSE;
            SET p_motivo = 'El espacio exclusivo ya cuenta con una reserva en el horario solicitado';
            RETURN;
        END IF;
    ELSE

        SELECT COALESCE(SUM(num_personas), 0) INTO v_solapados
        FROM reservas
        WHERE espacio_id = p_espacio_id
          AND estado IN ('Pendiente', 'Confirmada')
          AND p_fecha_inicio < fecha_fin
          AND p_fecha_fin > fecha_inicio;

        IF (v_solapados + p_num_personas) > v_capacidad THEN
            SET p_disponible = FALSE;
            SET p_motivo = CONCAT('Capacidad compartida excedida. Ocupadas: ', v_solapados, ', Solicitadas: ', p_num_personas, ', Capacidad: ', v_capacidad);
            RETURN;
        END IF;
    END IF;
END$$

-- 6. sp_crear_reserva

DROP PROCEDURE IF EXISTS sp_crear_reserva$$
CREATE PROCEDURE sp_crear_reserva(
    IN  p_usuario_id     INT,
    IN  p_espacio_id     INT,
    IN  p_modalidad      VARCHAR(10),
    IN  p_fecha_inicio   DATETIME,
    IN  p_fecha_fin      DATETIME,
    IN  p_num_personas   INT,
    IN  p_usar_creditos  BOOLEAN,
    OUT p_reserva_id     INT
)
BEGIN
    DECLARE v_disponible BOOLEAN;
    DECLARE v_motivo VARCHAR(255);
    DECLARE v_bloqueado BOOLEAN DEFAULT FALSE;
    DECLARE v_max_simultaneas INT DEFAULT 1;
    DECLARE v_activas_actuales INT DEFAULT 0;
    DECLARE v_tarifa_hora DECIMAL(12,2);
    DECLARE v_tarifa_mes DECIMAL(12,2);
    DECLARE v_usa_creditos BOOLEAN;
    DECLARE v_modo_ocupacion VARCHAR(20);
    DECLARE v_horas DECIMAL(10,2);
    DECLARE v_costo_total DECIMAL(12,2);
    DECLARE v_creditos_usados DECIMAL(6,2) DEFAULT 0.00;
    DECLARE v_monto_facturable DECIMAL(12,2);
    DECLARE v_saldo_creditos DECIMAL(6,2) DEFAULT 0.00;
    DECLARE v_empresa_id INT;
    DECLARE v_membresia_id INT;
    DECLARE v_factura_id INT;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    SELECT e.tarifa_hora, e.tarifa_mes, te.usa_creditos, te.modo_ocupacion
    INTO v_tarifa_hora, v_tarifa_mes, v_usa_creditos, v_modo_ocupacion
    FROM espacios e
    JOIN tipos_espacio te ON e.tipo_id = te.id
    WHERE e.id = p_espacio_id
    FOR UPDATE;

    SELECT EXISTS (
        SELECT 1 FROM v_usuarios_bloqueados WHERE usuario_id = p_usuario_id
    ) INTO v_bloqueado;

    IF v_bloqueado THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Usuario bloqueado para nuevas reservas por facturas vencidas en mora';
    END IF;

    SELECT tm.max_reservas_simultaneas, m.id, u.empresa_id
    INTO v_max_simultaneas, v_membresia_id, v_empresa_id
    FROM usuarios u
    LEFT JOIN membresias m ON m.usuario_id = u.id AND m.estado = 'Activa' AND NOW() BETWEEN m.fecha_inicio AND m.fecha_fin
    LEFT JOIN tipos_membresia tm ON m.tipo_id = tm.id
    WHERE u.id = p_usuario_id
    LIMIT 1;

    SET v_activas_actuales = fn_reservas_activas(p_usuario_id);
    IF v_activas_actuales >= COALESCE(v_max_simultaneas, 1) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Se ha alcanzado el límite máximo de reservas simultáneas permitidas para su plan';
    END IF;

    CALL sp_verificar_disponibilidad(p_espacio_id, p_modalidad, p_fecha_inicio, p_fecha_fin, p_num_personas, v_disponible, v_motivo);
    IF NOT v_disponible THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_motivo;
    END IF;

    IF p_modalidad = 'Mes' THEN
        SET v_costo_total = v_tarifa_mes;
        SET v_monto_facturable = v_costo_total;
    ELSE
        SET v_horas = TIMESTAMPDIFF(MINUTE, p_fecha_inicio, p_fecha_fin) / 60.0;
        IF v_modo_ocupacion = 'Compartido' THEN
            SET v_costo_total = v_horas * v_tarifa_hora * p_num_personas;
        ELSE
            SET v_costo_total = v_horas * v_tarifa_hora;
        END IF;
        SET v_monto_facturable = v_costo_total;

        IF p_usar_creditos AND v_usa_creditos THEN
            IF v_empresa_id IS NOT NULL THEN
                SELECT COALESCE(saldo_creditos, 0.00) INTO v_saldo_creditos
                FROM v_creditos_saldo WHERE origen = 'Empresa' AND empresa_id = v_empresa_id;
            ELSE
                SELECT COALESCE(saldo_creditos, 0.00) INTO v_saldo_creditos
                FROM v_creditos_saldo WHERE origen = 'Membresia' AND origen_id = v_membresia_id;
            END IF;

            IF v_saldo_creditos > 0 THEN
                SET v_creditos_usados = LEAST(v_horas, v_saldo_creditos);
                SET v_monto_facturable = GREATEST(0.00, v_costo_total - (v_creditos_usados * v_tarifa_hora));
            END IF;
        END IF;
    END IF;

    INSERT INTO reservas (usuario_id, espacio_id, modalidad, fecha_inicio, fecha_fin, num_personas, costo_total, creditos_usados, monto_facturable)
    VALUES (p_usuario_id, p_espacio_id, p_modalidad, p_fecha_inicio, p_fecha_fin, p_num_personas, v_costo_total, v_creditos_usados, v_monto_facturable);

    SET p_reserva_id = LAST_INSERT_ID();

    IF v_creditos_usados > 0 THEN
        INSERT INTO movimientos_credito (usuario_id, membresia_id, empresa_id, reserva_id, creditos, tipo, fecha)
        VALUES (p_usuario_id, v_membresia_id, v_empresa_id, p_reserva_id, -v_creditos_usados, 'Consumo', NOW());
    END IF;

    IF v_monto_facturable > 0 THEN
        INSERT INTO facturas (usuario_id, reserva_id, tipo, monto_base, recargo_acumulado, saldo_pendiente, estado, fecha_emision, fecha_vencimiento)
        VALUES (p_usuario_id, p_reserva_id, 'Reserva', v_monto_facturable, 0.00, v_monto_facturable, 'Pendiente', CURRENT_DATE, DATE_ADD(CURRENT_DATE, INTERVAL 3 DAY));

        SET v_factura_id = LAST_INSERT_ID();

        INSERT INTO factura_detalle (factura_id, concepto, referencia_tipo, referencia_id, monto)
        VALUES (v_factura_id, CONCAT('Reserva ID ', p_reserva_id, ' en Espacio ID ', p_espacio_id), 'Reserva', p_reserva_id, v_monto_facturable);
    END IF;

    COMMIT;
END$$

-- 7. sp_confirmar_reserva_con_pago


DROP PROCEDURE IF EXISTS sp_confirmar_reserva_con_pago$$
CREATE PROCEDURE sp_confirmar_reserva_con_pago(
    IN p_reserva_id      INT,
    IN p_metodo_pago_id  INT,
    IN p_referencia      VARCHAR(100)
)
BEGIN
    DECLARE v_factura_id INT;
    DECLARE v_saldo DECIMAL(12,2);
    DECLARE v_pago_id INT;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    SELECT id, saldo_pendiente INTO v_factura_id, v_saldo
    FROM facturas
    WHERE reserva_id = p_reserva_id
      AND estado = 'Pendiente'
    LIMIT 1;

    IF v_factura_id IS NOT NULL AND v_saldo > 0 THEN
        CALL sp_registrar_pago(v_factura_id, v_saldo, p_metodo_pago_id, p_referencia, v_pago_id);
    END IF;

    COMMIT;
END$$

-- 8. sp_cancelar_reserva

DROP PROCEDURE IF EXISTS sp_cancelar_reserva$$
CREATE PROCEDURE sp_cancelar_reserva(
    IN p_reserva_id INT,
    IN p_reembolso  BOOLEAN
)
BEGIN
    DECLARE v_factura_id INT;
    DECLARE v_pagado DECIMAL(12,2) DEFAULT 0.00;
    DECLARE v_metodo INT DEFAULT 1;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    UPDATE reservas
    SET estado = 'Cancelada'
    WHERE id = p_reserva_id;

    SELECT id INTO v_factura_id
    FROM facturas
    WHERE reserva_id = p_reserva_id;

    IF v_factura_id IS NOT NULL THEN
        SELECT COALESCE(SUM(monto), 0.00), COALESCE(MAX(metodo_pago_id), 1)
        INTO v_pagado, v_metodo
        FROM pagos
        WHERE factura_id = v_factura_id AND estado = 'Aplicado';

        IF v_pagado = 0 THEN
            UPDATE facturas
            SET estado = 'Anulada', motivo_anulacion = 'Cancelación de reserva'
            WHERE id = v_factura_id;
        ELSEIF p_reembolso THEN
            INSERT INTO pagos (factura_id, monto, metodo_pago_id, referencia, estado)
            VALUES (v_factura_id, -v_pagado, v_metodo, 'Reembolso por cancelación de reserva', 'Aplicado');

            UPDATE facturas
            SET estado = 'Cancelada'
            WHERE id = v_factura_id;
        END IF;
    END IF;

    COMMIT;
END$$


-- 9. sp_liberar_reservas_no_confirmadas

DROP PROCEDURE IF EXISTS sp_liberar_reservas_no_confirmadas$$
CREATE PROCEDURE sp_liberar_reservas_no_confirmadas(IN p_horas_limite INT)
BEGIN
    DECLARE v_done INT DEFAULT FALSE;
    DECLARE v_rid INT;
    DECLARE cur_pendientes CURSOR FOR
        SELECT id FROM reservas
        WHERE estado = 'Pendiente'
          AND (fecha_inicio <= NOW() OR fecha_inicio <= DATE_ADD(NOW(), INTERVAL p_horas_limite HOUR));

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = TRUE;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    OPEN cur_pendientes;
    liberar_loop: LOOP
        FETCH cur_pendientes INTO v_rid;
        IF v_done THEN
            LEAVE liberar_loop;
        END IF;

        CALL sp_cancelar_reserva(v_rid, FALSE);
    END LOOP;
    CLOSE cur_pendientes;

    COMMIT;
END$$
