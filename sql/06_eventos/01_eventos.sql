/*
Módulo: Eventos Programados del Sistema
Archivo: 01_eventos.sql

Descripción:
20 eventos programados (MySQL Event Scheduler) con prefijo 'evt_':

Requisitos:
Ejecutar previamente 01_estructura.sql, 01_datos_iniciales.sql, 01_funciones.sql, 01_procedimientos.sql y 01_triggers.sql.
Requiere activar el scheduler: SET GLOBAL event_scheduler = ON;
*/

USE coworking;

SET GLOBAL event_scheduler = ON;

-- =====================================================================
-- SECCIÓN 1: EVENTOS DE MEMBRESÍAS (1 - 5)
-- Integrante Responsable: Julio Ernesto Castaño Palacios
-- =====================================================================

-- 1. evt_diario_vencer_membresias

DROP EVENT IF EXISTS evt_diario_vencer_membresias;
DELIMITER $$
CREATE EVENT evt_diario_vencer_membresias
ON SCHEDULE EVERY 1 DAY
STARTS (CURRENT_DATE + INTERVAL 1 DAY + INTERVAL 1 MINUTE)
DO
BEGIN
    CALL sp_actualizar_membresias_vencidas();
END$$
DELIMITER ;

-- 2. evt_diario_aviso_vencimiento_membresias

DROP EVENT IF EXISTS evt_diario_aviso_vencimiento_membresias;
DELIMITER $$
CREATE EVENT evt_diario_aviso_vencimiento_membresias
ON SCHEDULE EVERY 1 DAY
STARTS (CURRENT_DATE + INTERVAL 8 HOUR)
DO
BEGIN
    INSERT INTO cola_notificaciones (tipo, destinatario, contenido, estado, fecha_creacion)
    SELECT 
        'Aviso_Vencimiento_Proximo',
        u.email,
        CONCAT('Hola ', u.nombre, ', su membresía vence el ', DATE_FORMAT(m.fecha_fin, '%d/%m/%Y'), '. Puede renovarla desde su panel o en recepción.'),
        'Pendiente',
        NOW()
    FROM membresias m
    JOIN usuarios u ON m.usuario_id = u.id
    WHERE m.estado = 'Activa'
      AND DATEDIFF(DATE(m.fecha_fin), CURRENT_DATE) = 5;
END$$
DELIMITER ;

-- 3. evt_diario_suspender_por_mora

DROP EVENT IF EXISTS evt_diario_suspender_por_mora;
DELIMITER $$
CREATE EVENT evt_diario_suspender_por_mora
ON SCHEDULE EVERY 1 DAY
STARTS (CURRENT_DATE + INTERVAL 1 DAY + INTERVAL 15 MINUTE)
DO
BEGIN
    DECLARE v_dias_susp INT DEFAULT 30;
    SELECT CAST(COALESCE(MAX(valor), '30') AS UNSIGNED) INTO v_dias_susp
    FROM configuracion_sistema WHERE clave = 'dias_suspension';

    CALL sp_suspender_membresias_impagas(v_dias_susp);
END$$
DELIMITER ;

-- 4. evt_semanal_reporte_nuevas_membresias

DROP EVENT IF EXISTS evt_semanal_reporte_nuevas_membresias;
DELIMITER $$
CREATE EVENT evt_semanal_reporte_nuevas_membresias
ON SCHEDULE EVERY 1 WEEK
STARTS (CURRENT_DATE + INTERVAL 6 HOUR)
DO
BEGIN
    DECLARE v_reporte JSON;

    SELECT JSON_ARRAYAGG(
        JSON_OBJECT(
            'membresia_id', m.id,
            'usuario', CONCAT(u.nombre, ' ', u.apellidos),
            'tipo', tm.nombre,
            'fecha_inicio', m.fecha_inicio,
            'fecha_fin', m.fecha_fin,
            'estado', m.estado
        )
    ) INTO v_reporte
    FROM membresias m
    JOIN usuarios u ON m.usuario_id = u.id
    JOIN tipos_membresia tm ON m.tipo_id = tm.id
    WHERE m.fecha_inicio >= DATE_SUB(NOW(), INTERVAL 7 DAY);

    INSERT INTO reportes_generados (tipo, datos, fecha_generacion)
    VALUES ('Reporte_Semanal_Nuevas_Membresias', COALESCE(v_reporte, JSON_ARRAY()), NOW());
END$$
DELIMITER ;

-- 5. evt_diario_alerta_suspendidas

DROP EVENT IF EXISTS evt_diario_alerta_suspendidas;
DELIMITER $$
CREATE EVENT evt_diario_alerta_suspendidas
ON SCHEDULE EVERY 1 DAY
STARTS (CURRENT_DATE + INTERVAL 7 HOUR + INTERVAL 30 MINUTE)
DO
BEGIN
    DECLARE v_recepcion_email VARCHAR(150);
    DECLARE v_count INT DEFAULT 0;

    SELECT COALESCE(MAX(valor), 'recepcion@coworking.com') INTO v_recepcion_email
    FROM configuracion_sistema WHERE clave = 'email_recepcion';

    SELECT COUNT(*) INTO v_count
    FROM membresias
    WHERE estado = 'Suspendida';

    IF v_count > 0 THEN
        INSERT INTO cola_notificaciones (tipo, destinatario, contenido, estado, fecha_creacion)
        VALUES (
            'Alerta_Membresias_Suspendidas',
            v_recepcion_email,
            CONCAT('Alerta Recepción: Actualmente existen ', v_count, ' cuentas con membresía Suspendida. Verificar accesos y cobros pendientes.'),
            'Pendiente',
            NOW()
        );
    END IF;
END$$
DELIMITER ;
