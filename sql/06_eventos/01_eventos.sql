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

-- SECCIÓN 2: EVENTOS DE RESERVAS (6 - 10)
-- Integrante responsable: Sofia Salazar Hernandez

-- 6. evt_horario_cancelar_reservas_pendientes

DROP EVENT IF EXISTS evt_horario_cancelar_reservas_pendientes;
DELIMITER $$
CREATE EVENT evt_horario_cancelar_reservas_pendientes
ON SCHEDULE EVERY 1 HOUR
DO
BEGIN
    CALL sp_liberar_reservas_no_confirmadas(2);
END$$
DELIMITER ;

-- 7. evt_horario_recordatorio_reservas

DROP EVENT IF EXISTS evt_horario_recordatorio_reservas;
DELIMITER $$
CREATE EVENT evt_horario_recordatorio_reservas
ON SCHEDULE EVERY 1 HOUR
DO
BEGIN
    INSERT INTO cola_notificaciones (tipo, destinatario, contenido, estado, fecha_creacion)
    SELECT 
        'Recordatorio_Reserva',
        u.email,
        CONCAT('Hola ', u.nombre, ', recordatorio: su reserva en el espacio "', e.nombre, '" inicia a las ', DATE_FORMAT(r.fecha_inicio, '%H:%i'), '.'),
        'Pendiente',
        NOW()
    FROM reservas r
    JOIN usuarios u ON r.usuario_id = u.id
    JOIN espacios e ON r.espacio_id = e.id
    WHERE r.estado = 'Confirmada'
      AND r.fecha_inicio BETWEEN NOW() AND DATE_ADD(NOW(), INTERVAL 1 HOUR);
END$$
DELIMITER ;

-- 8. evt_diario_completar_reservas

DROP EVENT IF EXISTS evt_diario_completar_reservas;
DELIMITER $$
CREATE EVENT evt_diario_completar_reservas
ON SCHEDULE EVERY 1 DAY
STARTS (CURRENT_DATE + INTERVAL 23 HOUR + INTERVAL 45 MINUTE)
DO
BEGIN
    UPDATE reservas
    SET estado = 'Completada'
    WHERE modalidad = 'Mes'
      AND estado = 'Confirmada'
      AND fecha_fin <= NOW();

    UPDATE reservas r
    SET r.estado = 'Completada'
    WHERE r.modalidad = 'Hora'
      AND r.estado = 'Confirmada'
      AND r.fecha_fin <= NOW()
      AND EXISTS (
          SELECT 1 FROM asistencias a
          WHERE a.reserva_id = r.id AND a.tipo = 'Sala'
      );
END$$
DELIMITER ;

-- 9. evt_semanal_reporte_ocupacion

DROP EVENT IF EXISTS evt_semanal_reporte_ocupacion;
DELIMITER $$
CREATE EVENT evt_semanal_reporte_ocupacion
ON SCHEDULE EVERY 1 WEEK
STARTS (CURRENT_DATE + INTERVAL 23 HOUR)
DO
BEGIN
    DECLARE v_reporte JSON;

    SELECT JSON_ARRAYAGG(
        JSON_OBJECT(
            'espacio', e.nombre,
            'horas_reservadas', COALESCE(res.horas_res, 0.0),
            'horas_asistidas', COALESCE(asi.horas_real, 0.0)
        )
    ) INTO v_reporte
    FROM espacios e
    LEFT JOIN (
        SELECT espacio_id, SUM(TIMESTAMPDIFF(MINUTE, fecha_inicio, fecha_fin) / 60.0) AS horas_res
        FROM reservas
        WHERE estado IN ('Confirmada', 'Completada')
          AND fecha_inicio >= DATE_SUB(NOW(), INTERVAL 7 DAY)
        GROUP BY espacio_id
    ) res ON res.espacio_id = e.id
    LEFT JOIN (
        SELECT r.espacio_id, SUM(a.minutos / 60.0) AS horas_real
        FROM asistencias a
        JOIN reservas r ON a.reserva_id = r.id
        WHERE a.tipo = 'Sala'
          AND a.fecha_entrada >= DATE_SUB(NOW(), INTERVAL 7 DAY)
        GROUP BY r.espacio_id
    ) asi ON asi.espacio_id = e.id;

    INSERT INTO reportes_generados (tipo, datos, fecha_generacion)
    VALUES ('Reporte_Semanal_Ocupacion', COALESCE(v_reporte, JSON_ARRAY()), NOW());
END$$
DELIMITER ;

-- 10. evt_15min_marcar_no_show

DROP EVENT IF EXISTS evt_15min_marcar_no_show;
DELIMITER $$
CREATE EVENT evt_15min_marcar_no_show
ON SCHEDULE EVERY 15 MINUTE
DO
BEGIN
    DECLARE v_done INT DEFAULT FALSE;
    DECLARE v_rid INT;
    DECLARE cur_noshow CURSOR FOR
        SELECT r.id
        FROM reservas r
        WHERE r.estado = 'Confirmada'
          AND r.modalidad = 'Hora'
          AND NOW() >= DATE_ADD(r.fecha_inicio, INTERVAL 15 MINUTE)
          AND NOT EXISTS (
              SELECT 1 FROM accesos a
              WHERE a.reserva_id = r.id
                AND a.estado_intento = 'Permitido'
          );

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = TRUE;

    OPEN cur_noshow;
    noshow_loop: LOOP
        FETCH cur_noshow INTO v_rid;
        IF v_done THEN
            LEAVE noshow_loop;
        END IF;

        CALL sp_marcar_no_show_y_penalizar(v_rid);
    END LOOP;
    CLOSE cur_noshow;
END$$
DELIMITER ;
