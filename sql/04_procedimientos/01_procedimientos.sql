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

-- SECCIÓN 3: PROCEDIMIENTOS DE PAGOS Y FACTURACIÓN (10 - 13)
-- Integrante responsable: Valeria Lizcano Arena


-- 10. sp_generar_factura_por_consumo

DROP PROCEDURE IF EXISTS sp_generar_factura_por_consumo$$
CREATE PROCEDURE sp_generar_factura_por_consumo(
    IN  p_tipo            VARCHAR(20),
    IN  p_usuario_id      INT,
    IN  p_monto           DECIMAL(12,2),
    IN  p_concepto        VARCHAR(200),
    IN  p_referencia_tipo VARCHAR(30),
    IN  p_referencia_id   INT,
    OUT p_factura_id      INT
)
BEGIN
    DECLARE v_dias_venc INT DEFAULT 15;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    SELECT CAST(COALESCE(MAX(valor), '15') AS UNSIGNED) INTO v_dias_venc
    FROM configuracion_sistema WHERE clave = 'dias_vencimiento_factura';

    INSERT INTO facturas (usuario_id, tipo, monto_base, recargo_acumulado, saldo_pendiente, estado, fecha_emision, fecha_vencimiento)
    VALUES (p_usuario_id, p_tipo, p_monto, 0.00, p_monto, 'Pendiente', CURRENT_DATE, DATE_ADD(CURRENT_DATE, INTERVAL v_dias_venc DAY));

    SET p_factura_id = LAST_INSERT_ID();

    INSERT INTO factura_detalle (factura_id, concepto, referencia_tipo, referencia_id, monto)
    VALUES (p_factura_id, p_concepto, p_referencia_tipo, p_referencia_id, p_monto);

    COMMIT;
END$$

-- 11. sp_generar_factura_consolidada_empresa

DROP PROCEDURE IF EXISTS sp_generar_factura_consolidada_empresa$$
CREATE PROCEDURE sp_generar_factura_consolidada_empresa(
    IN  p_empresa_id   INT,
    IN  p_mes          INT,
    IN  p_anio         INT,
    OUT p_factura_id   INT
)
BEGIN
    DECLARE v_total DECIMAL(12,2) DEFAULT 0.00;
    DECLARE v_precio_corp DECIMAL(12,2);
    DECLARE v_dias_venc INT DEFAULT 15;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    SELECT precio INTO v_precio_corp
    FROM tipos_membresia
    WHERE id = 3; -- Corporativa

    SELECT COUNT(*) * v_precio_corp INTO v_total
    FROM usuarios u
    JOIN membresias m ON m.usuario_id = u.id AND m.tipo_id = 3 AND m.estado = 'Activa'
    WHERE u.empresa_id = p_empresa_id
      AND u.activo = TRUE;

    IF v_total > 0 THEN
        SELECT CAST(COALESCE(MAX(valor), '15') AS UNSIGNED) INTO v_dias_venc
        FROM configuracion_sistema WHERE clave = 'dias_vencimiento_factura';

        INSERT INTO facturas (empresa_id, usuario_id, tipo, monto_base, recargo_acumulado, saldo_pendiente, estado, fecha_emision, fecha_vencimiento)
        VALUES (p_empresa_id, NULL, 'Consolidada', v_total, 0.00, v_total, 'Pendiente', CURRENT_DATE, DATE_ADD(CURRENT_DATE, INTERVAL v_dias_venc DAY));

        SET p_factura_id = LAST_INSERT_ID();

        INSERT INTO factura_detalle (factura_id, concepto, referencia_tipo, referencia_id, monto)
        SELECT 
            p_factura_id,
            CONCAT('Membresía Corporativa Mes ', p_mes, '/', p_anio, ' - ', u.nombre, ' ', u.apellidos),
            'Membresia',
            m.id,
            v_precio_corp
        FROM usuarios u
        JOIN membresias m ON m.usuario_id = u.id AND m.tipo_id = 3 AND m.estado = 'Activa'
        WHERE u.empresa_id = p_empresa_id AND u.activo = TRUE;
    END IF;

    COMMIT;
END$$

-- 12. sp_aplicar_recargos_facturas_vencidas

DROP PROCEDURE IF EXISTS sp_aplicar_recargos_facturas_vencidas$$
CREATE PROCEDURE sp_aplicar_recargos_facturas_vencidas()
BEGIN
    DECLARE v_porc_diario DECIMAL(5,2) DEFAULT 0.50;
    DECLARE v_dias_recargo INT DEFAULT 16;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    SELECT CAST(COALESCE(MAX(valor), '0.5') AS DECIMAL(5,2)) INTO v_porc_diario
    FROM configuracion_sistema WHERE clave = 'porcentaje_mora_diaria';

    SELECT CAST(COALESCE(MAX(valor), '16') AS UNSIGNED) INTO v_dias_recargo
    FROM configuracion_sistema WHERE clave = 'dias_recargo';

    -- Aplica solo si no se ha aplicado hoy 
    UPDATE facturas f
    LEFT JOIN (
        SELECT factura_id, COALESCE(SUM(monto), 0.00) AS total_pagado
        FROM pagos
        WHERE estado = 'Aplicado' AND monto > 0
        GROUP BY factura_id
    ) p ON p.factura_id = f.id
    SET 
        f.recargo_acumulado = f.recargo_acumulado + ((v_porc_diario / 100.0) * (f.monto_base - COALESCE(p.total_pagado, 0.00))),
        f.ultimo_recargo = CURRENT_DATE,
        f.saldo_pendiente = (f.monto_base + f.recargo_acumulado + ((v_porc_diario / 100.0) * (f.monto_base - COALESCE(p.total_pagado, 0.00)))) - COALESCE(p.total_pagado, 0.00)
    WHERE f.saldo_pendiente > 0
      AND f.estado = 'Pendiente'
      AND DATEDIFF(CURRENT_DATE, f.fecha_vencimiento) >= v_dias_recargo
      AND (f.ultimo_recargo IS NULL OR f.ultimo_recargo < CURRENT_DATE);

    COMMIT;
END$$

-- 13. sp_registrar_pago

DROP PROCEDURE IF EXISTS sp_registrar_pago$$
CREATE PROCEDURE sp_registrar_pago(
    IN  p_factura_id     INT,
    IN  p_monto          DECIMAL(12,2),
    IN  p_metodo_pago_id INT,
    IN  p_referencia     VARCHAR(100),
    OUT p_pago_id        INT
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    INSERT INTO pagos (factura_id, monto, fecha_pago, metodo_pago_id, referencia, estado)
    VALUES (p_factura_id, p_monto, NOW(), p_metodo_pago_id, p_referencia, 'Aplicado');

    SET p_pago_id = LAST_INSERT_ID();

    COMMIT;
END$$


-- SECCIÓN 4: PROCEDIMIENTOS DE ACCESOS Y ASISTENCIAS (14 - 17)
-- Integrante Responsable: Zlatan Ricardo Villamizar 

-- 14. sp_registrar_acceso

DROP PROCEDURE IF EXISTS sp_registrar_acceso$$
CREATE PROCEDURE sp_registrar_acceso(
    IN  p_usuario_id INT,
    IN  p_metodo     VARCHAR(10),
    IN  p_reserva_id INT,
    OUT p_acceso_id  BIGINT,
    OUT p_resultado  VARCHAR(20)
)
BEGIN
    DECLARE v_fecha_entrada DATETIME;
    DECLARE v_tipo_sesion VARCHAR(10);
    DECLARE v_acceso_previo_id BIGINT;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    SET v_fecha_entrada = NOW();

    INSERT INTO accesos (usuario_id, reserva_id, fecha_hora_entrada, metodo_acceso, estado_intento)
    VALUES (p_usuario_id, p_reserva_id, v_fecha_entrada, p_metodo, 'Rechazado');

    SET p_acceso_id = LAST_INSERT_ID();

    SELECT estado_intento INTO p_resultado
    FROM accesos
    WHERE id = p_acceso_id;

    IF p_resultado = 'Permitido' THEN
        SET v_tipo_sesion = IF(p_reserva_id IS NOT NULL, 'Sala', 'Edificio');

        SELECT a.id INTO v_acceso_previo_id
        FROM accesos a
        JOIN asistencias asi ON asi.acceso_id = a.id
        WHERE a.usuario_id = p_usuario_id
          AND a.id <> p_acceso_id
          AND asi.tipo = v_tipo_sesion
          AND a.fecha_hora_salida IS NULL
        ORDER BY a.fecha_hora_entrada DESC
        LIMIT 1;

        IF v_acceso_previo_id IS NOT NULL THEN
            UPDATE accesos
            SET fecha_hora_salida = DATE_SUB(v_fecha_entrada, INTERVAL 1 MINUTE)
            WHERE id = v_acceso_previo_id;
        END IF;
    END IF;

    COMMIT;
END$$

-- 15. sp_registrar_salida

DROP PROCEDURE IF EXISTS sp_registrar_salida$$
CREATE PROCEDURE sp_registrar_salida(IN p_usuario_id INT)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    UPDATE accesos
    SET fecha_hora_salida = NOW()
    WHERE usuario_id = p_usuario_id
      AND estado_intento = 'Permitido'
      AND fecha_hora_salida IS NULL;

    COMMIT;
END$$

-- 16. sp_generar_reporte_diario_asistencias

DROP PROCEDURE IF EXISTS sp_generar_reporte_diario_asistencias$$
CREATE PROCEDURE sp_generar_reporte_diario_asistencias(IN p_fecha DATE)
BEGIN
    DECLARE v_reporte_json JSON;

    SELECT JSON_OBJECT(
        'fecha', p_fecha,
        'total_accesos', COUNT(*),
        'permitidos', SUM(CASE WHEN estado_intento = 'Permitido' THEN 1 ELSE 0 END),
        'rechazados', SUM(CASE WHEN estado_intento = 'Rechazado' THEN 1 ELSE 0 END),
        'asistencias_edificio', (
            SELECT COUNT(*) FROM asistencias 
            WHERE tipo = 'Edificio' AND DATE(fecha_entrada) = p_fecha
        ),
        'asistencias_sala', (
            SELECT COUNT(*) FROM asistencias 
            WHERE tipo = 'Sala' AND DATE(fecha_entrada) = p_fecha
        )
    ) INTO v_reporte_json
    FROM accesos
    WHERE DATE(fecha_hora_entrada) = p_fecha;

    INSERT INTO reportes_generados (tipo, datos, fecha_generacion)
    VALUES ('Reporte_Diario_Asistencias', v_reporte_json, NOW());
END$$

-- 17. sp_marcar_no_show_y_penalizar

DROP PROCEDURE IF EXISTS sp_marcar_no_show_y_penalizar$$
CREATE PROCEDURE sp_marcar_no_show_y_penalizar(IN p_reserva_id INT)
BEGIN
    DECLARE v_costo_total DECIMAL(12,2);
    DECLARE v_usuario_id INT;
    DECLARE v_porc_pen DECIMAL(5,2) DEFAULT 0.50;
    DECLARE v_penalizacion DECIMAL(12,2);
    DECLARE v_pagado DECIMAL(12,2) DEFAULT 0.00;
    DECLARE v_factura_id INT;
    DECLARE v_diferencia DECIMAL(12,2);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    SELECT CAST(COALESCE(MAX(valor), '0.5') AS DECIMAL(5,2)) INTO v_porc_pen
    FROM configuracion_sistema WHERE clave = 'penalizacion_no_show';

    SELECT costo_total, usuario_id INTO v_costo_total, v_usuario_id
    FROM reservas
    WHERE id = p_reserva_id;

    SET v_penalizacion = v_costo_total * v_porc_pen;

    SELECT COALESCE(SUM(p.monto), 0.00) INTO v_pagado
    FROM pagos p
    JOIN facturas f ON p.factura_id = f.id
    WHERE f.reserva_id = p_reserva_id AND p.estado = 'Aplicado';
    
    UPDATE reservas
    SET estado = 'No_Show'
    WHERE id = p_reserva_id;

    IF v_pagado < v_penalizacion THEN
        SET v_diferencia = v_penalizacion - v_pagado;
        INSERT INTO facturas (usuario_id, reserva_id, tipo, monto_base, recargo_acumulado, saldo_pendiente, estado, fecha_emision, fecha_vencimiento)
        VALUES (v_usuario_id, p_reserva_id, 'Penalizacion', v_diferencia, 0.00, v_diferencia, 'Pendiente', CURRENT_DATE, DATE_ADD(CURRENT_DATE, INTERVAL 15 DAY));

        INSERT INTO factura_detalle (factura_id, concepto, referencia_tipo, referencia_id, monto)
        VALUES (LAST_INSERT_ID(), CONCAT('Penalización por No Show en Reserva ID ', p_reserva_id), 'Reserva', p_reserva_id, v_diferencia);
    ELSEIF v_pagado > v_penalizacion THEN
        -- Reembolsar el exceso como pago negativo
        SET v_diferencia = v_pagado - v_penalizacion;
        SELECT id INTO v_factura_id FROM facturas WHERE reserva_id = p_reserva_id LIMIT 1;

        IF v_factura_id IS NOT NULL THEN
            INSERT INTO pagos (factura_id, monto, metodo_pago_id, referencia, estado)
            VALUES (v_factura_id, -v_diferencia, 1, CONCAT('Reembolso por exceso tras penalización No Show reserva ', p_reserva_id), 'Aplicado');
        END IF;
    END IF;

    COMMIT;
END$$

-- SECCIÓN 5: PROCEDIMIENTOS CORPORATIVOS Y DE REPORTES (18 - 20)
-- Integrante Responsable: Brenda Nico Carrillo Gonzalez

-- 18. sp_registrar_lote_empleados


DROP PROCEDURE IF EXISTS sp_registrar_lote_empleados$$
CREATE PROCEDURE sp_registrar_lote_empleados(
    IN p_empresa_id INT,
    IN p_empleados  JSON
)
BEGIN
    DECLARE i INT DEFAULT 0;
    DECLARE v_count INT;
    DECLARE v_nombre VARCHAR(80);
    DECLARE v_apellidos VARCHAR(100);
    DECLARE v_email VARCHAR(150);
    DECLARE v_telefono VARCHAR(30);
    DECLARE v_uid INT;
    DECLARE v_mid INT;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    SET v_count = JSON_LENGTH(p_empleados);

    WHILE i < v_count DO
        SET v_nombre    = JSON_UNQUOTE(JSON_EXTRACT(p_empleados, CONCAT('$[', i, '].nombre')));
        SET v_apellidos = JSON_UNQUOTE(JSON_EXTRACT(p_empleados, CONCAT('$[', i, '].apellidos')));
        SET v_email     = JSON_UNQUOTE(JSON_EXTRACT(p_empleados, CONCAT('$[', i, '].email')));
        SET v_telefono  = JSON_UNQUOTE(JSON_EXTRACT(p_empleados, CONCAT('$[', i, '].telefono')));

        INSERT INTO usuarios (nombre, apellidos, email, telefono, empresa_id, rol_id, tipo_usuario, fecha_registro)
        VALUES (v_nombre, v_apellidos, v_email, v_telefono, p_empresa_id, 3, 'Cliente', CURRENT_DATE);

        SET v_uid = LAST_INSERT_ID();

        -- Membresía corporativa inicia hoy y vence fin de mes
        CALL sp_registrar_membresia(v_uid, 3, NOW(), v_mid);

        SET i = i + 1;
    END WHILE;

    COMMIT;
END$$

-- 19. sp_cancelar_reservas_futuras_usuario

DROP PROCEDURE IF EXISTS sp_cancelar_reservas_futuras_usuario$$
CREATE PROCEDURE sp_cancelar_reservas_futuras_usuario(
    IN p_usuario_id INT,
    IN p_motivo     VARCHAR(255)
)
BEGIN
    DECLARE v_done INT DEFAULT FALSE;
    DECLARE v_rid INT;
    DECLARE cur_reservas CURSOR FOR
        SELECT id FROM reservas
        WHERE usuario_id = p_usuario_id
          AND estado IN ('Pendiente', 'Confirmada')
          AND fecha_inicio > NOW();

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = TRUE;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    OPEN cur_reservas;
    canc_loop: LOOP
        FETCH cur_reservas INTO v_rid;
        IF v_done THEN
            LEAVE canc_loop;
        END IF;

        CALL sp_cancelar_reserva(v_rid, TRUE);
    END LOOP;
    CLOSE cur_reservas;

    COMMIT;
END$$

-- 20. sp_generar_reporte_ingresos_mensuales


DROP PROCEDURE IF EXISTS sp_generar_reporte_ingresos_mensuales$$
CREATE PROCEDURE sp_generar_reporte_ingresos_mensuales(IN p_anio INT)
BEGIN
    DECLARE v_reporte JSON;

    SELECT JSON_ARRAYAGG(
        JSON_OBJECT(
            'mes', mes,
            'ingresos_membresias', ingresos_membresias,
            'ingresos_reservas', ingresos_reservas,
            'ingresos_servicios', ingresos_servicios,
            'total_neto', total_neto
        )
    ) INTO v_reporte
    FROM (
        SELECT 
            MONTH(p.fecha_pago) AS mes,
            SUM(CASE WHEN f.tipo IN ('Membresia', 'Consolidada') THEN p.monto ELSE 0 END) AS ingresos_membresias,
            SUM(CASE WHEN f.tipo = 'Reserva' THEN p.monto ELSE 0 END) AS ingresos_reservas,
            SUM(CASE WHEN f.tipo = 'Servicio' THEN p.monto ELSE 0 END) AS ingresos_servicios,
            SUM(p.monto) AS total_neto
        FROM pagos p
        JOIN facturas f ON p.factura_id = f.id
        WHERE p.estado = 'Aplicado'
          AND YEAR(p.fecha_pago) = p_anio
        GROUP BY MONTH(p.fecha_pago)
        ORDER BY mes ASC
    ) AS resumen;

    INSERT INTO reportes_generados (tipo, datos, fecha_generacion)
    VALUES (CONCAT('Reporte_Ingresos_Anual_', p_anio), v_reporte, NOW());
END$$

DELIMITER ;