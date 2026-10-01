# 🔐 Roles y Permisos — Coworking DB

Documento de referencia del modelo de seguridad implementado con el principio de **mínimo privilegio** sobre MySQL 8.0. Define los cinco roles del sistema, sus permisos SQL y las vistas filtradas por usuario autenticado.

---

## Índice

1. [Arquitectura de Seguridad](#arquitectura)
2. [Roles de Aplicación](#roles-aplicacion)
3. [Roles MySQL del Servidor](#roles-mysql)
4. [Permisos Detallados por Rol](#permisos)
5. [Usuarios MySQL Predefinidos](#usuarios-mysql)
6. [Vistas Filtradas por Usuario](#vistas-filtradas)
7. [Gestión de Roles en Tiempo de Ejecución](#gestion)

---

## Arquitectura de Seguridad

El sistema implementa **dos capas** de control de acceso:

```
┌─────────────────────────────────────────────────────────┐
│  CAPA 1 — Roles de Aplicación (tabla roles)             │
│  Define qué puede hacer cada perfil de usuario          │
│  dentro de la interfaz de usuario / API                 │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│  CAPA 2 — Roles MySQL (CREATE ROLE ... ON coworking.*)  │
│  Controla directamente qué sentencias SQL puede         │
│  ejecutar cada conexión al servidor de base de datos    │
└─────────────────────────────────────────────────────────┘
```

Los roles de aplicación se almacenan en la tabla `roles` y se asignan mediante `usuarios.rol_id`. Los roles MySQL se asignan a los usuarios del servidor con `SET DEFAULT ROLE`.

---

## Roles de Aplicación

Definidos en [`sql/07_seguridad/01_roles.sql`](../sql/07_seguridad/01_roles.sql).

| ID | Nombre               | Descripción                                          |
|----|----------------------|------------------------------------------------------|
| 1  | **Administrador**    | Control total del sistema. Sin restricciones.        |
| 2  | **Recepcionista**    | Operación diaria: check-in, cobros, reservas, accesos |
| 3  | **Usuario**          | Cliente: autoservicio sobre sus propios datos        |
| 4  | **Gerente Corporativo** | Administración del equipo y facturación corporativa |
| 5  | **Contador**         | Acceso de solo lectura a módulo financiero y reportes|

---

## Roles MySQL del Servidor

Definidos en [`sql/07_seguridad/02_permisos.sql`](../sql/07_seguridad/02_permisos.sql).

| Rol MySQL            | Creado como         | Asignado al usuario predefinido |
|----------------------|---------------------|---------------------------------|
| `rol_admin`          | `ROLE`              | `admin_coworking@localhost`     |
| `rol_recepcionista`  | `ROLE`              | `recepcion_coworking@localhost` |
| `rol_usuario`        | `ROLE`              | Dinámico por cliente            |
| `rol_gerente`        | `ROLE`              | `gerente_coworking@localhost`   |
| `rol_contador`       | `ROLE`              | `contador_coworking@localhost`  |

---

## Permisos Detallados por Rol

### 1. `rol_admin` — Administrador Total

```sql
GRANT ALL PRIVILEGES ON coworking.* TO 'rol_admin';
GRANT EXECUTE ON PROCEDURE coworking.* TO 'rol_admin';
GRANT EXECUTE ON FUNCTION  coworking.* TO 'rol_admin';
```

**Puede hacer:** cualquier operación DDL, DML, CALL, CREATE EVENT, GRANT.

---

### 2. `rol_recepcionista` — Operación Diaria

**Tablas con acceso de lectura (SELECT):**

| Tabla / Vista                | Propósito                                    |
|------------------------------|----------------------------------------------|
| `usuarios`                   | Ver perfiles de clientes                     |
| `membresias`                 | Consultar vigencia                           |
| `tipos_membresia`            | Catálogo de planes                           |
| `reservas`                   | Ver agenda                                   |
| `espacios`                   | Ver disponibilidad                           |
| `v_estado_espacio`           | Estado en tiempo real de espacios            |
| `accesos`                    | Registro de ingresos del día                 |
| `asistencias`                | Asistencia real                              |
| `cola_notificaciones`        | Bandeja de avisos a clientes                 |

**Tablas con acceso de escritura (INSERT/UPDATE):**

| Tabla         | Operación permitida         |
|---------------|-----------------------------|
| `accesos`     | Registrar entradas/salidas  |
| `pagos`       | Registrar cobros en caja    |

**Procedimientos permitidos:**

| Procedimiento                           | Uso                                     |
|-----------------------------------------|-----------------------------------------|
| `sp_registrar_membresia`                | Alta de nueva membresía                 |
| `sp_renovar_membresia`                  | Renovación manual                       |
| `sp_crear_reserva`                      | Reservar espacio para un cliente        |
| `sp_cancelar_reserva`                   | Cancelar y gestionar reembolso          |
| `sp_registrar_pago`                     | Cobrar factura pendiente                |
| `sp_registrar_acceso`                   | Check-in cliente                        |
| `sp_registrar_salida`                   | Check-out cliente                       |
| `sp_generar_reporte_diario_asistencias` | Reporte del día                         |

---

### 3. `rol_usuario` — Autoservicio del Cliente

El rol más restringido. Solo puede ver **sus propios datos** a través de vistas filtradas.

**Vistas con acceso de lectura:**

| Vista                 | Descripción                                            |
|-----------------------|--------------------------------------------------------|
| `v_mis_reservas`      | Solo reservas del usuario autenticado (filtro por USER()) |
| `v_mis_facturas`      | Solo facturas propias con saldo pendiente              |
| `v_mis_accesos`       | Historial propio de entradas/salidas                   |
| `v_estado_espacio`    | Disponibilidad de espacios (sin datos personales)      |

**Tablas con acceso de lectura:**

| Tabla     | Propósito                       |
|-----------|---------------------------------|
| `espacios` | Consultar tarifas y capacidades |

**Procedimientos permitidos:**

| Procedimiento         | Uso                              |
|-----------------------|----------------------------------|
| `sp_crear_reserva`    | Auto-gestión de reservas propias |
| `sp_cancelar_reserva` | Cancelar sus propias reservas    |

> ⚠️ Las vistas `v_mis_*` filtran con `WHERE u.usuario_bd = SUBSTRING_INDEX(USER(),'@',1)`. El usuario de base de datos debe coincidir con el campo `usuarios.usuario_bd`.

---

### 4. `rol_gerente` — Administración Corporativa

Accede solo a datos de su empresa a través de vistas filtradas por `empresa_id`.

**Vistas con acceso de lectura:**

| Vista                  | Descripción                                          |
|------------------------|------------------------------------------------------|
| `v_empresa_empleados`  | Empleados activos de la empresa autenticada          |
| `v_empresa_facturas`   | Facturas consolidadas e individuales de la empresa   |
| `v_empresa_creditos`   | Saldo y movimientos del pool de créditos corporativo |
| `v_estado_espacio`     | Disponibilidad general de espacios                   |

**Procedimientos permitidos:**

| Procedimiento                     | Uso                                        |
|-----------------------------------|--------------------------------------------|
| `sp_registrar_lote_empleados`     | Alta de nuevos empleados con membresía     |

---

### 5. `rol_contador` — Módulo Financiero

Solo lectura. Sin posibilidad de modificar datos financieros directamente.

**Tablas con acceso de lectura:**

| Tabla                 | Propósito                               |
|-----------------------|-----------------------------------------|
| `facturas`            | Deuda, recargos, anulaciones            |
| `pagos`               | Cobros y reembolsos                     |
| `factura_detalle`     | Líneas de facturas consolidadas         |
| `reportes_generados`  | JSON de reportes mensuales y anuales    |
| `reservas`            | Base para análisis de ingresos          |
| `accesos`             | Análisis de flujo de personas           |
| `asistencias`         | Datos de ocupación real                 |
| `empresas`            | Información corporativa para reportes   |
| `usuarios`            | Datos de clientes para reportes         |
| `membresias`          | Vigencias para análisis de churn        |

**Procedimientos permitidos:**

| Procedimiento                         | Uso                                  |
|---------------------------------------|--------------------------------------|
| `sp_generar_reporte_ingresos_mensuales` | Reporte anual en formato JSON      |
| `sp_generar_factura_consolidada_empresa` | Generar factura de cierre mensual |

---

## Usuarios MySQL Predefinidos

Definidos en [`sql/07_seguridad/03_usuarios.sql`](../sql/07_seguridad/03_usuarios.sql).

| Usuario MySQL                    | Rol Asignado         | Contraseña (cambiar en producción) |
|----------------------------------|----------------------|------------------------------------|
| `admin_coworking@localhost`      | `rol_admin`          | `Admin_Cowork#2024`                |
| `recepcion_coworking@localhost`  | `rol_recepcionista`  | `Recep_Cowork#2024`                |
| `gerente_coworking@localhost`    | `rol_gerente`        | `Ger_Cowork#2024`                  |
| `contador_coworking@localhost`   | `rol_contador`       | `Cont_Cowork#2024`                 |

> **⚠️ Importante:** Cambiar todas las contraseñas antes de poner en producción.  
> Usar `ALTER USER 'admin_coworking'@'localhost' IDENTIFIED BY 'nueva_contraseña';`

---

## Vistas Filtradas por Usuario

Las vistas con prefijo `v_mis_` y `v_empresa_` implementan seguridad a nivel de fila usando la función `USER()` de MySQL.

### Mecanismo de filtrado

```sql
-- Ejemplo interno de v_mis_reservas
SELECT r.*
FROM reservas r
JOIN usuarios u ON r.usuario_id = u.id
WHERE u.usuario_bd = SUBSTRING_INDEX(USER(), '@', 1);
                     -- ↑ Extrae solo la parte 'usuario' de 'usuario@host'
```

### Tabla de vistas y su filtro

| Vista                   | Filtro                                                    |
|-------------------------|-----------------------------------------------------------|
| `v_mis_reservas`        | `usuarios.usuario_bd = SUBSTRING_INDEX(USER(),'@',1)`    |
| `v_mis_facturas`        | Igual — solo facturas con saldo > 0                      |
| `v_mis_accesos`         | Igual — solo últimos 30 días                             |
| `v_empresa_empleados`   | `empresa_id` del usuario autenticado                     |
| `v_empresa_facturas`    | `empresa_id` del usuario autenticado                     |
| `v_empresa_creditos`    | `empresa_id` del usuario autenticado                     |
| `v_estado_espacio`      | Sin filtro — disponibilidad pública de espacios          |
| `v_usuarios_bloqueados` | Solo admin/recepcionista tiene GRANT sobre esta vista    |
| `v_creditos_saldo`      | Vista global de créditos (acceso solo admin/recepcionista)|

---

## Gestión de Roles en Tiempo de Ejecución

### Crear un usuario cliente nuevo con rol

```sql
-- 1. Asegurarse de que el campo usuario_bd coincida con el usuario MySQL
UPDATE usuarios SET usuario_bd = 'ana_garcia' WHERE id = 55;

-- 2. Crear el usuario MySQL
CREATE USER 'ana_garcia'@'%' IDENTIFIED BY 'Passw0rd#Seguro';

-- 3. Asignar rol
GRANT 'rol_usuario' TO 'ana_garcia'@'%';
SET DEFAULT ROLE 'rol_usuario' TO 'ana_garcia'@'%';
```

### Revocar acceso de un empleado que abandona la empresa

```sql
-- Revocar rol
REVOKE 'rol_recepcionista' FROM 'juan_perez'@'localhost';

-- O bien, bloquear sin eliminar
ALTER USER 'juan_perez'@'localhost' ACCOUNT LOCK;
```

### Ver roles activos en la sesión actual

```sql
SELECT CURRENT_ROLE();
SHOW GRANTS FOR CURRENT_USER();
```

### Activar manualmente un rol en la sesión

```sql
SET ROLE 'rol_contador';
```

---

## Archivos Relacionados

| Archivo | Descripción |
|---|---|
| [`01_roles.sql`](../sql/07_seguridad/01_roles.sql) | INSERT en tabla `roles`; CREATE ROLE MySQL |
| [`02_permisos.sql`](../sql/07_seguridad/02_permisos.sql) | GRANT por cada rol MySQL |
| [`03_usuarios.sql`](../sql/07_seguridad/03_usuarios.sql) | CREATE USER + SET DEFAULT ROLE |
| [`01_estructura.sql`](../sql/00_ddl/01_estructura.sql) | DDL de las vistas filtradas `v_mis_*` y `v_empresa_*` |
