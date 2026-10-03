/*

Integrante Responsable: Julio Ernesto Castaño Palacios

Módulo: Seguridad - Asignación de Privilegios y Permisos
Archivo: 02_permisos.sql

Descripción:
Matriz de privilegios mínimos (GRANT) asignados a cada rol MySQL:
- rol_admin: ALL PRIVILEGES.
- rol_recepcionista: Gestión de usuarios, accesos, membresías y cobros (sin acceso a reportes financieros).
- rol_usuario: Vistas de datos propios (v_mis_*) y procedimientos propios.
- rol_gerente: Vistas corporativas de su empresa (v_empresa_*) y registro de lotes de empleados.
- rol_contador: Facturas, pagos, detalles y reportes contables.

Requisitos:
Ejecutar previamente 01_roles.sql y todos los procedimientos y vistas.
*/

USE coworking;

-- =====================================================================
-- 1. rol_admin (Acceso Total)
-- =====================================================================
GRANT ALL PRIVILEGES ON coworking.* TO 'rol_admin';

-- =====================================================================
-- 2. rol_recepcionista (Operación Diaria)
-- =====================================================================
GRANT SELECT, INSERT, UPDATE ON coworking.usuarios TO 'rol_recepcionista';
GRANT SELECT ON coworking.membresias TO 'rol_recepcionista';
GRANT SELECT ON coworking.reservas   TO 'rol_recepcionista';
GRANT SELECT ON coworking.espacios   TO 'rol_recepcionista';
GRANT SELECT ON coworking.accesos    TO 'rol_recepcionista';
GRANT SELECT ON coworking.asistencias TO 'rol_recepcionista';
GRANT SELECT ON coworking.v_estado_espacio TO 'rol_recepcionista';

GRANT EXECUTE ON PROCEDURE coworking.sp_registrar_membresia TO 'rol_recepcionista';
GRANT EXECUTE ON PROCEDURE coworking.sp_renovar_membresia   TO 'rol_recepcionista';
GRANT EXECUTE ON PROCEDURE coworking.sp_crear_reserva       TO 'rol_recepcionista';
GRANT EXECUTE ON PROCEDURE coworking.sp_cancelar_reserva    TO 'rol_recepcionista';
GRANT EXECUTE ON PROCEDURE coworking.sp_registrar_acceso    TO 'rol_recepcionista';
GRANT EXECUTE ON PROCEDURE coworking.sp_registrar_salida    TO 'rol_recepcionista';
GRANT EXECUTE ON PROCEDURE coworking.sp_registrar_pago      TO 'rol_recepcionista';

-- =====================================================================
-- 3. rol_usuario (Autoservicio y Datos Propios)
-- =====================================================================
GRANT SELECT ON coworking.v_mis_reservas  TO 'rol_usuario';
GRANT SELECT ON coworking.v_mis_facturas  TO 'rol_usuario';
GRANT SELECT ON coworking.v_mis_accesos   TO 'rol_usuario';
GRANT SELECT ON coworking.espacios        TO 'rol_usuario';
GRANT SELECT ON coworking.v_estado_espacio TO 'rol_usuario';

GRANT EXECUTE ON PROCEDURE coworking.sp_crear_reserva    TO 'rol_usuario';
GRANT EXECUTE ON PROCEDURE coworking.sp_cancelar_reserva TO 'rol_usuario';

-- =====================================================================
-- 4. rol_gerente (Administración Corporativa)
-- =====================================================================
GRANT SELECT ON coworking.v_empresa_empleados TO 'rol_gerente';
GRANT SELECT ON coworking.v_empresa_facturas  TO 'rol_gerente';
GRANT SELECT ON coworking.v_empresa_creditos  TO 'rol_gerente';
GRANT SELECT ON coworking.v_estado_espacio     TO 'rol_gerente';

GRANT EXECUTE ON PROCEDURE coworking.sp_registrar_lote_empleados TO 'rol_gerente';

-- =====================================================================
-- 5. rol_contador (Módulo Financiero y Contable)
-- =====================================================================
GRANT SELECT ON coworking.facturas           TO 'rol_contador';
GRANT SELECT ON coworking.pagos              TO 'rol_contador';
GRANT SELECT ON coworking.factura_detalle    TO 'rol_contador';
GRANT SELECT ON coworking.reportes_generados TO 'rol_contador';
GRANT SELECT ON coworking.reservas           TO 'rol_contador';
GRANT SELECT ON coworking.accesos            TO 'rol_contador';
GRANT SELECT ON coworking.asistencias        TO 'rol_contador';

GRANT EXECUTE ON PROCEDURE coworking.sp_generar_reporte_ingresos_mensuales TO 'rol_contador';
GRANT EXECUTE ON PROCEDURE coworking.sp_generar_reporte_diario_asistencias TO 'rol_contador';

FLUSH PRIVILEGES;
