/*

Módulo: Triggers de Base de Datos
Archivo: 01_triggers.sql

Descripción:
20 triggers de integridad, seguridad y automatización con prefijo 'trg_':
Requisitos:
Ejecutar DESPUÉS de 01_datos_iniciales.sql y 01_procedimientos.sql.
*/

USE coworking;

DELIMITER $$

-- =====================================================================
-- SECCIÓN 1: TRIGGERS DE MEMBRESÍAS (T1 - T5)
-- Integrante Responsable: Julio Ernesto Castaño Palacios
-- =====================================================================

-- T1. trg_bi_membresias_vigencia_solapamiento

DROP TRIGGER IF EXISTS trg_bi_membresias_vigencia_solapamiento$$
CREATE TRIGGER trg_bi_membresias_vigencia_solapamiento
BEFORE INSERT ON membresias
FOR EACH ROW
BEGIN
    DECLARE v_nombre_tipo VARCHAR(50);
    DECLARE v_duracion INT;
    DECLARE v_solapados INT DEFAULT 0;

    SELECT nombre, duracion_dias INTO v_nombre_tipo, v_duracion
    FROM tipos_membresia
    WHERE id = NEW.tipo_id;

    IF NEW.fecha_fin IS NULL OR NEW.fecha_fin <= NEW.fecha_inicio THEN
        IF v_nombre_tipo = 'Diaria' THEN
            SET NEW.fecha_fin = STR_TO_DATE(CONCAT(DATE(NEW.fecha_inicio), ' 23:59:59'), '%Y-%m-%d %H:%i:%s');
        ELSEIF v_nombre_tipo = 'Corporativa' THEN
            SET NEW.fecha_fin = STR_TO_DATE(CONCAT(LAST_DAY(NEW.fecha_inicio), ' 23:59:59'), '%Y-%m-%d %H:%i:%s');
        ELSE
            SET NEW.fecha_fin = DATE_ADD(NEW.fecha_inicio, INTERVAL COALESCE(v_duracion, 30) DAY);
        END IF;
    END IF;

    IF v_nombre_tipo = 'Corporativa' THEN
        SET NEW.estado = 'Activa';
    ELSEIF NEW.estado IS NULL THEN
        SET NEW.estado = 'Pendiente';
    END IF;

    SELECT COUNT(*) INTO v_solapados
    FROM membresias
    WHERE usuario_id = NEW.usuario_id
      AND estado IN ('Activa', 'Pendiente', 'Suspendida')
      AND NEW.fecha_inicio < fecha_fin
      AND NEW.fecha_fin > fecha_inicio;

    IF v_solapados > 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'El usuario ya cuenta con una membresía en estado Activa/Pendiente/Suspendida con período solapado';
    END IF;
END$$

-- T2. trg_au_facturas_activar_membresia

DROP TRIGGER IF EXISTS trg_au_facturas_activar_membresia$$
CREATE TRIGGER trg_au_facturas_activar_membresia
AFTER UPDATE ON facturas
FOR EACH ROW
BEGIN
    DECLARE v_cred_incluidos INT DEFAULT 0;
    DECLARE v_deuda_restante INT DEFAULT 0;

    IF OLD.estado <> NEW.estado AND NEW.estado = 'Pagada' THEN
        IF NEW.membresia_id IS NOT NULL THEN
            UPDATE membresias
            SET estado = 'Activa'
            WHERE id = NEW.membresia_id
              AND estado = 'Pendiente'
              AND fecha_fin > NOW();

            SELECT tm.creditos_incluidos INTO v_cred_incluidos
            FROM membresias m
            JOIN tipos_membresia tm ON m.tipo_id = tm.id
            WHERE m.id = NEW.membresia_id;

            IF v_cred_incluidos > 0 THEN
                INSERT INTO movimientos_credito (usuario_id, membresia_id, creditos, tipo, fecha)
                VALUES (NEW.usuario_id, NEW.membresia_id, v_cred_incluidos, 'Reinicio', NOW());
            END IF;
        END IF;

        IF NEW.usuario_id IS NOT NULL THEN
            SELECT COUNT(*) INTO v_deuda_restante
            FROM facturas
            WHERE usuario_id = NEW.usuario_id
              AND saldo_pendiente > 0
              AND fecha_vencimiento < CURRENT_DATE;

            IF v_deuda_restante = 0 THEN
                UPDATE membresias
                SET estado = 'Activa'
                WHERE usuario_id = NEW.usuario_id
                  AND estado = 'Suspendida'
                  AND fecha_fin > NOW();
            END IF;
        ELSEIF NEW.empresa_id IS NOT NULL THEN
            SELECT COUNT(*) INTO v_deuda_restante
            FROM facturas
            WHERE empresa_id = NEW.empresa_id
              AND saldo_pendiente > 0
              AND fecha_vencimiento < CURRENT_DATE;

            IF v_deuda_restante = 0 THEN
                UPDATE membresias m
                JOIN usuarios u ON m.usuario_id = u.id
                SET m.estado = 'Activa'
                WHERE u.empresa_id = NEW.empresa_id
                  AND m.tipo_id = 3
                  AND m.estado = 'Suspendida'
                  AND m.fecha_fin > NOW();
            END IF;
        END IF;
    END IF;
END$$

-- T3. trg_au_facturas_incobrable_suspension

DROP TRIGGER IF EXISTS trg_au_facturas_incobrable_suspension$$
CREATE TRIGGER trg_au_facturas_incobrable_suspension
AFTER UPDATE ON facturas
FOR EACH ROW
BEGIN
    IF OLD.estado <> NEW.estado AND NEW.estado = 'Incobrable' THEN
        IF NEW.usuario_id IS NOT NULL THEN
            UPDATE membresias
            SET estado = 'Suspendida'
            WHERE usuario_id = NEW.usuario_id AND estado = 'Activa';
        ELSEIF NEW.empresa_id IS NOT NULL THEN
            UPDATE membresias m
            JOIN usuarios u ON m.usuario_id = u.id
            SET m.estado = 'Suspendida'
            WHERE u.empresa_id = NEW.empresa_id
              AND m.tipo_id = 3
              AND m.estado = 'Activa';
        END IF;
    END IF;
END$$

-- T4. trg_au_membresias_historial

DROP TRIGGER IF EXISTS trg_au_membresias_historial$$
CREATE TRIGGER trg_au_membresias_historial
AFTER UPDATE ON membresias
FOR EACH ROW
BEGIN
    IF OLD.tipo_id <> NEW.tipo_id THEN
        INSERT INTO historial_membresias (usuario_id, tipo_anterior, tipo_nuevo, fecha_cambio)
        VALUES (NEW.usuario_id, OLD.tipo_id, NEW.tipo_id, NOW());
    END IF;
END$$

-- T5. trg_bd_membresias_validar_eliminacion

DROP TRIGGER IF EXISTS trg_bd_membresias_validar_eliminacion$$
CREATE TRIGGER trg_bd_membresias_validar_eliminacion
BEFORE DELETE ON membresias
FOR EACH ROW
BEGIN
    DECLARE v_reservas_activas INT DEFAULT 0;
    DECLARE v_facturas_con_pago INT DEFAULT 0;

    SELECT COUNT(*) INTO v_reservas_activas
    FROM reservas
    WHERE usuario_id = OLD.usuario_id
      AND estado IN ('Pendiente', 'Confirmada')
      AND fecha_fin > NOW();

    IF v_reservas_activas > 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'No se puede eliminar la membresía: el usuario tiene reservas activas';
    END IF;

    SELECT COUNT(*) INTO v_facturas_con_pago
    FROM facturas f
    JOIN pagos p ON p.factura_id = f.id
    WHERE f.membresia_id = OLD.id AND p.estado = 'Aplicado';

    IF v_facturas_con_pago > 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'No se puede eliminar la membresía: tiene facturas con pagos aplicados';
    END IF;
END$$

-- SECCIÓN 2: TRIGGERS DE RESERVAS (T6 - T10)
-- Integrante responsable: Sofia Salazar Hernandez

-- T6. trg_bi_reservas_validaciones

DROP TRIGGER IF EXISTS trg_bi_reservas_validaciones$$
CREATE TRIGGER trg_bi_reservas_validaciones
BEFORE INSERT ON reservas
FOR EACH ROW
BEGIN
    DECLARE v_tipo_usuario VARCHAR(20);
    DECLARE v_membresia_activa BOOLEAN DEFAULT FALSE;
    DECLARE v_bloqueado BOOLEAN DEFAULT FALSE;
    DECLARE v_estado_espacio VARCHAR(20);
    DECLARE v_modo_ocupacion VARCHAR(20);
    DECLARE v_capacidad_max INT;
    DECLARE v_perm_hora BOOLEAN;
    DECLARE v_perm_mes  BOOLEAN;
    DECLARE v_solapados INT DEFAULT 0;
    DECLARE v_max_simultaneas INT DEFAULT 1;
    DECLARE v_activas INT DEFAULT 0;
    DECLARE v_dia_semana TINYINT;
    DECLARE v_hora_ini TIME;
    DECLARE v_hora_fin TIME;
    DECLARE v_apertura TIME;
    DECLARE v_cierre TIME;

    IF NEW.fecha_fin <= NEW.fecha_inicio THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La fecha de fin debe ser posterior a la de inicio';
    END IF;

    SELECT EXISTS (
        SELECT 1 FROM v_usuarios_bloqueados WHERE usuario_id = NEW.usuario_id
    ) INTO v_bloqueado;

    IF v_bloqueado THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Usuario bloqueado para reservas por morosidad';
    END IF;

    SELECT tipo_usuario INTO v_tipo_usuario FROM usuarios WHERE id = NEW.usuario_id;
    SET v_membresia_activa = fn_membresia_activa(NEW.usuario_id);

    IF NOT v_membresia_activa AND v_tipo_usuario <> 'Invitado' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El usuario no cuenta con una membresía activa';
    END IF;

    SELECT e.estado, te.modo_ocupacion, e.capacidad_maxima, te.permite_reserva_hora, te.permite_reserva_mes
    INTO v_estado_espacio, v_modo_ocupacion, v_capacidad_max, v_perm_hora, v_perm_mes
    FROM espacios e
    JOIN tipos_espacio te ON e.tipo_id = te.id
    WHERE e.id = NEW.espacio_id;

    IF v_estado_espacio <> 'Disponible' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El espacio no está disponible';
    END IF;

    IF NEW.modalidad = 'Hora' AND NOT v_perm_hora THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El espacio no permite reservas por hora';
    ELSEIF NEW.modalidad = 'Mes' AND NOT v_perm_mes THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El espacio no permite reservas mensuales';
    END IF;

    IF NEW.modalidad = 'Hora' THEN
        SET v_dia_semana = DAYOFWEEK(NEW.fecha_inicio);
        SET v_hora_ini = TIME(NEW.fecha_inicio);
        SET v_hora_fin = TIME(NEW.fecha_fin);

        SELECT hora_apertura, hora_cierre INTO v_apertura, v_cierre
        FROM horarios_disponibilidad
        WHERE (espacio_id = NEW.espacio_id OR espacio_id IS NULL)
          AND dia_semana = v_dia_semana
        ORDER BY espacio_id DESC
        LIMIT 1;

        IF v_apertura IS NULL OR v_hora_ini < v_apertura OR v_hora_fin > v_cierre THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Reserva fuera de los horarios de disponibilidad';
        END IF;
    END IF;

    IF NEW.num_personas > v_capacidad_max THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El número de personas excede la capacidad máxima del espacio';
    END IF;

    IF v_modo_ocupacion = 'Exclusivo' THEN
        SELECT COUNT(*) INTO v_solapados
        FROM reservas
        WHERE espacio_id = NEW.espacio_id
          AND estado IN ('Pendiente', 'Confirmada')
          AND NEW.fecha_inicio < fecha_fin
          AND NEW.fecha_fin > fecha_inicio;

        IF v_solapados > 0 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Existe solapamiento en el espacio exclusivo solicitado';
        END IF;
    ELSE
        SELECT COALESCE(SUM(num_personas), 0) INTO v_solapados
        FROM reservas
        WHERE espacio_id = NEW.espacio_id
          AND estado IN ('Pendiente', 'Confirmada')
          AND NEW.fecha_inicio < fecha_fin
          AND NEW.fecha_fin > fecha_inicio;

        IF (v_solapados + NEW.num_personas) > v_capacidad_max THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Capacidad compartida excedida durante el período';
        END IF;
    END IF;

    SELECT COALESCE(tm.max_reservas_simultaneas, 1) INTO v_max_simultaneas
    FROM membresias m
    JOIN tipos_membresia tm ON m.tipo_id = tm.id
    WHERE m.usuario_id = NEW.usuario_id
      AND m.estado = 'Activa'
      AND NOW() BETWEEN m.fecha_inicio AND m.fecha_fin
    ORDER BY m.fecha_inicio DESC
    LIMIT 1;

    SET v_activas = fn_reservas_activas(NEW.usuario_id);
    IF v_activas >= v_max_simultaneas THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Límite de reservas simultáneas alcanzado';
    END IF;
END$$

-- T7. trg_bi_reservas_estado_inicial

DROP TRIGGER IF EXISTS trg_bi_reservas_estado_inicial$$
CREATE TRIGGER trg_bi_reservas_estado_inicial
BEFORE INSERT ON reservas
FOR EACH ROW
FOLLOWS trg_bi_reservas_validaciones
BEGIN
    IF NEW.monto_facturable = 0 THEN
        SET NEW.estado = 'Confirmada';
    ELSE
        SET NEW.estado = 'Pendiente';
    END IF;
END$$

-- T8. trg_au_facturas_confirmar_reserva

DROP TRIGGER IF EXISTS trg_au_facturas_confirmar_reserva$$
CREATE TRIGGER trg_au_facturas_confirmar_reserva
AFTER UPDATE ON facturas
FOR EACH ROW
BEGIN
    IF OLD.estado <> NEW.estado AND NEW.estado = 'Pagada' AND NEW.tipo = 'Reserva' AND NEW.reserva_id IS NOT NULL THEN
        UPDATE reservas
        SET estado = 'Confirmada'
        WHERE id = NEW.reserva_id AND estado = 'Pendiente';
    END IF;
END$$

-- T9. trg_au_membresias_cancelar_reservas_futuras

DROP TRIGGER IF EXISTS trg_au_membresias_cancelar_reservas_futuras$$
CREATE TRIGGER trg_au_membresias_cancelar_reservas_futuras
AFTER UPDATE ON membresias
FOR EACH ROW
BEGIN
    IF OLD.estado <> NEW.estado AND NEW.estado = 'Suspendida' THEN
        UPDATE reservas
        SET estado = 'Cancelada'
        WHERE usuario_id = NEW.usuario_id
          AND estado IN ('Pendiente', 'Confirmada')
          AND fecha_inicio > NOW();
    END IF;
END$$

-- T10. trg_au_reservas_devolver_creditos

DROP TRIGGER IF EXISTS trg_au_reservas_devolver_creditos$$
CREATE TRIGGER trg_au_reservas_devolver_creditos
AFTER UPDATE ON reservas
FOR EACH ROW
BEGIN
    DECLARE v_empresa_id INT;
    DECLARE v_membresia_id INT;

    IF OLD.estado <> NEW.estado AND NEW.estado = 'Cancelada' AND NEW.creditos_usados > 0 THEN
        SELECT u.empresa_id, m.id INTO v_empresa_id, v_membresia_id
        FROM usuarios u
        LEFT JOIN membresias m ON m.usuario_id = u.id AND m.estado = 'Activa'
        WHERE u.id = NEW.usuario_id
        ORDER BY m.fecha_inicio DESC
        LIMIT 1;

        INSERT INTO movimientos_credito (usuario_id, membresia_id, empresa_id, reserva_id, creditos, tipo, fecha)
        VALUES (NEW.usuario_id, v_membresia_id, v_empresa_id, NEW.id, NEW.creditos_usados, 'Devolucion', NOW());

        INSERT INTO logs_auditoria (accion, tabla_afectada, registro_id, fecha)
        VALUES ('DEVOLUCION_CREDITOS_RESERVA_CANCELADA', 'reservas', NEW.id, NOW());
    END IF;
END$$

-- SECCIÓN 3: TRIGGERS DE PAGOS Y FACTURACIÓN 

DROP TRIGGER IF EXISTS trg_bi_servicios_contratados_validar_mora$$
CREATE TRIGGER trg_bi_servicios_contratados_validar_mora
BEFORE INSERT ON servicios_contratados
FOR EACH ROW
BEGIN
    DECLARE v_bloqueado BOOLEAN DEFAULT FALSE;

    SELECT EXISTS (
        SELECT 1 FROM v_usuarios_bloqueados WHERE usuario_id = NEW.usuario_id
    ) INTO v_bloqueado;

    IF v_bloqueado THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'No se pueden contratar servicios adicionales: el usuario presenta facturas vencidas en mora';
    END IF;
END$$

-- T12. trg_ai_pagos_actualizar_saldo

DROP TRIGGER IF EXISTS trg_ai_pagos_actualizar_saldo$$
CREATE TRIGGER trg_ai_pagos_actualizar_saldo
AFTER INSERT ON pagos
FOR EACH ROW
BEGIN
    DECLARE v_monto_total DECIMAL(12,2);
    DECLARE v_total_cobros DECIMAL(12,2);
    DECLARE v_nuevo_saldo DECIMAL(12,2);
    DECLARE v_nuevo_estado VARCHAR(20);

    SELECT monto_total INTO v_monto_total
    FROM facturas
    WHERE id = NEW.factura_id;

    SELECT COALESCE(SUM(monto), 0.00) INTO v_total_cobros
    FROM pagos
    WHERE factura_id = NEW.factura_id
      AND estado = 'Aplicado'
      AND monto > 0;

    SET v_nuevo_saldo = GREATEST(0.00, v_monto_total - v_total_cobros);

    IF v_nuevo_saldo = 0.00 THEN
        SET v_nuevo_estado = 'Pagada';
    ELSE
        SET v_nuevo_estado = 'Pendiente';
    END IF;

    UPDATE facturas
    SET saldo_pendiente = v_nuevo_saldo,
        estado = IF(estado IN ('Pendiente', 'Pagada'), v_nuevo_estado, estado)
    WHERE id = NEW.factura_id;
END$$

-- T13. trg_bd_facturas_validar_eliminacion

DROP TRIGGER IF EXISTS trg_bd_facturas_validar_eliminacion$$
CREATE TRIGGER trg_bd_facturas_validar_eliminacion
BEFORE DELETE ON facturas
FOR EACH ROW
BEGIN
    DECLARE v_pagos INT DEFAULT 0;

    SELECT COUNT(*) INTO v_pagos
    FROM pagos
    WHERE factura_id = OLD.id;

    IF v_pagos > 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'No se puede eliminar la factura: existen pagos registrados asociados';
    END IF;
END$$

-- T14. trg_bi_pagos_validar_monto_y_estado

DROP TRIGGER IF EXISTS trg_bi_pagos_validar_monto_y_estado$$
CREATE TRIGGER trg_bi_pagos_validar_monto_y_estado
BEFORE INSERT ON pagos
FOR EACH ROW
BEGIN
    DECLARE v_saldo DECIMAL(12,2);
    DECLARE v_estado VARCHAR(20);
    DECLARE v_neto_pagado DECIMAL(12,2);

    SELECT saldo_pendiente, estado INTO v_saldo, v_estado
    FROM facturas
    WHERE id = NEW.factura_id;

    IF NEW.monto > 0 THEN
        IF v_estado IN ('Anulada', 'Cancelada') THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'No se pueden registrar pagos en facturas Anuladas o Canceladas';
        END IF;

        IF NEW.monto > v_saldo THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El monto del cobro excede el saldo pendiente de la factura';
        END IF;
    ELSE
        -- Reembolso negativo
        SELECT COALESCE(SUM(monto), 0.00) INTO v_neto_pagado
        FROM pagos
        WHERE factura_id = NEW.factura_id AND estado = 'Aplicado';

        IF ABS(NEW.monto) > v_neto_pagado THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El reembolso no puede exceder el monto neto pagado de la factura';
        END IF;
    END IF;
END$$

-- T15. trg_au_pagos_recalcular_saldo

DROP TRIGGER IF EXISTS trg_au_pagos_recalcular_saldo$$
CREATE TRIGGER trg_au_pagos_recalcular_saldo
AFTER UPDATE ON pagos
FOR EACH ROW
BEGIN
    DECLARE v_monto_total DECIMAL(12,2);
    DECLARE v_total_cobros DECIMAL(12,2);
    DECLARE v_nuevo_saldo DECIMAL(12,2);

    IF OLD.estado <> NEW.estado AND NEW.estado = 'Cancelado' THEN
        SELECT monto_total INTO v_monto_total
        FROM facturas WHERE id = NEW.factura_id;

        SELECT COALESCE(SUM(monto), 0.00) INTO v_total_cobros
        FROM pagos
        WHERE factura_id = NEW.factura_id
          AND estado = 'Aplicado'
          AND monto > 0;

        SET v_nuevo_saldo = GREATEST(0.00, v_monto_total - v_total_cobros);

        UPDATE facturas
        SET saldo_pendiente = v_nuevo_saldo,
            estado = IF(v_nuevo_saldo = 0, 'Pagada', 'Pendiente')
        WHERE id = NEW.factura_id;

        INSERT INTO logs_auditoria (accion, tabla_afectada, registro_id, fecha)
        VALUES ('PAGO_CANCELADO_RECALCULO_SALDO', 'pagos', NEW.id, NOW());
    END IF;
END$$

-- SECCIÓN 4: TRIGGERS DE ACCESOS Y ASISTENCIAS (T16 - T20)
-- Integrante Responsable: Zlatan Ricardo Villamizar 

DROP TRIGGER IF EXISTS trg_bi_accesos_validar_ingreso$$
CREATE TRIGGER trg_bi_accesos_validar_ingreso
BEFORE INSERT ON accesos
FOR EACH ROW
BEGIN
    DECLARE v_apertura TIME;
    DECLARE v_cierre TIME;
    DECLARE v_hora_actual TIME;
    DECLARE v_dia_semana TINYINT;
    DECLARE v_tiene_membresia BOOLEAN;
    DECLARE v_reserva_valida BOOLEAN DEFAULT FALSE;

    SET v_dia_semana = DAYOFWEEK(NEW.fecha_hora_entrada);
    SET v_hora_actual = TIME(NEW.fecha_hora_entrada);

    SELECT hora_apertura, hora_cierre INTO v_apertura, v_cierre
    FROM horarios_disponibilidad
    WHERE espacio_id IS NULL AND dia_semana = v_dia_semana;

    IF v_apertura IS NOT NULL AND (v_hora_actual < v_apertura OR v_hora_actual > v_cierre) THEN
        SET NEW.estado_intento = 'Rechazado';
        SET NEW.motivo_rechazo = 'Intento de acceso fuera del horario general del coworking';
    ELSE
        IF NEW.reserva_id IS NULL THEN
            -- Acceso a Edificio
            SET v_tiene_membresia = fn_membresia_activa(NEW.usuario_id);

            SELECT EXISTS (
                SELECT 1 FROM reservas
                WHERE usuario_id = NEW.usuario_id
                  AND estado = 'Confirmada'
                  AND NEW.fecha_hora_entrada BETWEEN DATE_SUB(fecha_inicio, INTERVAL 10 MINUTE) AND fecha_fin
            ) INTO v_reserva_valida;

            IF v_tiene_membresia OR v_reserva_valida THEN
                SET NEW.estado_intento = 'Permitido';
                SET NEW.motivo_rechazo = NULL;
            ELSE
                SET NEW.estado_intento = 'Rechazado';
                SET NEW.motivo_rechazo = 'Sin membresía activa ni reserva confirmada en curso';
            END IF;
        ELSE

            SELECT EXISTS (
                SELECT 1 FROM reservas
                WHERE id = NEW.reserva_id
                  AND usuario_id = NEW.usuario_id
                  AND estado = 'Confirmada'
                  AND NEW.fecha_hora_entrada BETWEEN DATE_SUB(fecha_inicio, INTERVAL 10 MINUTE) AND fecha_fin
            ) INTO v_reserva_valida;

            IF v_reserva_valida THEN
                SET NEW.estado_intento = 'Permitido';
                SET NEW.motivo_rechazo = NULL;
            ELSE
                SET NEW.estado_intento = 'Rechazado';
                SET NEW.motivo_rechazo = 'Reserva de sala no válida o fuera de la ventana de tiempo';
            END IF;
        END IF;
    END IF;
END$$

-- T17. trg_ai_accesos_registrar_asistencia

DROP TRIGGER IF EXISTS trg_ai_accesos_registrar_asistencia$$
CREATE TRIGGER trg_ai_accesos_registrar_asistencia
AFTER INSERT ON accesos
FOR EACH ROW
BEGIN
    IF NEW.estado_intento = 'Permitido' THEN
        INSERT INTO asistencias (acceso_id, usuario_id, reserva_id, tipo, fecha_entrada, fecha_salida, minutos)
        VALUES (
            NEW.id,
            NEW.usuario_id,
            NEW.reserva_id,
            IF(NEW.reserva_id IS NOT NULL, 'Sala', 'Edificio'),
            NEW.fecha_hora_entrada,
            NEW.fecha_hora_salida,
            IF(NEW.fecha_hora_salida IS NOT NULL, TIMESTAMPDIFF(MINUTE, NEW.fecha_hora_entrada, NEW.fecha_hora_salida), NULL)
        );
    END IF;
END$$

-- T18. trg_ai_accesos_actualizar_ultimo_acceso

DROP TRIGGER IF EXISTS trg_ai_accesos_actualizar_ultimo_acceso$$
CREATE TRIGGER trg_ai_accesos_actualizar_ultimo_acceso
AFTER INSERT ON accesos
FOR EACH ROW
BEGIN
    IF NEW.estado_intento = 'Permitido' THEN
        UPDATE usuarios
        SET ultimo_acceso = NEW.fecha_hora_entrada
        WHERE id = NEW.usuario_id;
    END IF;
END$$


-- T19. trg_au_accesos_cerrar_asistencia

DROP TRIGGER IF EXISTS trg_au_accesos_cerrar_asistencia$$
CREATE TRIGGER trg_au_accesos_cerrar_asistencia
AFTER UPDATE ON accesos
FOR EACH ROW
BEGIN
    IF OLD.fecha_hora_salida IS NULL AND NEW.fecha_hora_salida IS NOT NULL THEN
        UPDATE asistencias
        SET fecha_salida = NEW.fecha_hora_salida,
            minutos = TIMESTAMPDIFF(MINUTE, fecha_entrada, NEW.fecha_hora_salida)
        WHERE acceso_id = NEW.id;
    END IF;
END$$

-- T20. trg_ai_accesos_auditar_rechazados

DROP TRIGGER IF EXISTS trg_ai_accesos_auditar_rechazados$$
CREATE TRIGGER trg_ai_accesos_auditar_rechazados
AFTER INSERT ON accesos
FOR EACH ROW
BEGIN
    IF NEW.estado_intento = 'Rechazado' THEN
        INSERT INTO logs_auditoria (accion, tabla_afectada, registro_id, fecha)
        VALUES (CONCAT('INTENTO_ACCESO_RECHAZADO: ', COALESCE(NEW.motivo_rechazo, 'Sin motivo')), 'accesos', NEW.id, NOW());
    END IF;
END$$

DELIMITER ;