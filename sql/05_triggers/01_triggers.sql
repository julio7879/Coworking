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
