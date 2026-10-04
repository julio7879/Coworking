# 🏢 Coworking DB — Sistema de Gestión de Coworking (Una Sede)

Base de datos relacional completa implementada en **MySQL 8.0+** para la administración integral de un espacio de coworking: usuarios, membresías, reservas, créditos corporativos, pagos, facturación con mora no capitalizable, control de accesos físicos, registro de asistencia real y reportes automatizados.

---

## 👥 Integrantes del Proyecto (Grupo 06)

| # | Nombre Completo | Rol / Módulo Responsable |
|---|-----------------|--------------------------|
| 1 | **Sofia Salazar Hernandez** | Módulo de Reservas y Disponibilidad (Funciones 5-8, SPs 5-9, Triggers T6-T10, Eventos 6-10, Consultas 01-02) |
| 2 | **Valeria Lizcano Arena** | Módulo de Pagos y Facturación (Funciones 9-12, SPs 10-13, Triggers T11-T15, Eventos 11-15, Consultas 03) |
| 3 | **Zlatan Ricardo Villamizar Fajardo** | Módulo de Accesos y Asistencias (Funciones 13-16, SPs 14-17, Triggers T16-T20, Consultas 04) |
| 4 | **Brenda Nicol Carrillo Gonzalez** | Módulo de Automatización, Reportes y Auditoría (Funciones 17-20, SPs 18-20, Eventos 16-20, Consultas 05) |
| 5 | **Julio Ernesto Castaño Palacios** | Módulo de Estructura DDL, Membresías y Seguridad (DDL 00, DML 01, Funciones 1-4, SPs 1-4, Triggers T1-T5, Eventos 1-5, Seguridad 07) |

---

## 📑 Índice

1. [Descripción del Proyecto](#descripción-del-proyecto)
2. [Requisitos del Sistema](#requisitos-del-sistema)
3. [Estructura del Proyecto](#estructura-del-proyecto)
4. [Documentación Técnica](#documentación-técnica)
5. [Orden de Instalación](#orden-de-instalación)
6. [Modelo de Base de Datos](#modelo-de-base-de-datos)
7. [Componentes Principales](#componentes-principales)
   - [Funciones Almacenadas (fn_*)](#funciones-almacenadas-fn_)
   - [Procedimientos Almacenados (sp_*)](#procedimientos-almacenados-sp_)
   - [Triggers (trg_*)](#triggers-trg_)
   - [Eventos Programados (evt_*)](#eventos-programados-evt_)
8. [Roles y Seguridad](#roles-y-seguridad)
9. [Escalera de Mora](#escalera-de-mora)
10. [Consultas Analíticas](#consultas-analíticas)
11. [Ejemplos de Uso](#ejemplos-de-uso)
12. [Flujos de Negocio y Verificación](#flujos-de-negocio-y-verificación)
13. [Contribuciones y Licencia](#contribuciones-y-licencia)

---

## Descripción del Proyecto

Este sistema modela e implementa la lógica completa de negocio de un coworking de una sola sede mediante **MySQL 8.0+**, resolviendo los requerimientos operativos y financieros:

- **Membresías**: Planes Diaria, Mensual, Corporativa y Premium con vigencias calculadas, solapamientos controlados y auditoría de cambios.
- **Reservas**: Modalidades por *Hora* y por *Mes* para espacios *Compartidos* y *Exclusivos*, con validación estricta de disponibilidad, aforo y estado de mora.
- **Créditos Corporativos e Individuales**: Pool corporativo mensual compartido entre empleados con recarga mensual y libro de movimientos (`movimientos_credito`).
- **Facturación y Pagos**: Facturas individuales y consolidadas para empresas, con saldo actualizado atómicamente por triggers, reembolsos y escalera de mora sin capitalización.
- **Accesos Físicos y Asistencia Real**: Validación de ingreso por RFID/QR/Manual, auto-cierre de sesiones previas huérfanas y cálculo de minutos de permanencia efectiva.
- **Automatización Completa**: 20 triggers reactivos, 20 eventos programados en background, 20 funciones deterministas y 20 procedimientos almacenados transaccionales con control de concurrencia.
- **Seguridad Robusta**: 5 roles de aplicación, 5 roles MySQL con mínimo privilegio y vistas filtradas por usuario autenticado (`USER()`).

---

## Requisitos del Sistema

| Componente | Versión Mínima / Configuración |
|---|---|
| **Motor de Base de Datos** | MySQL Server 8.0.16+ (soporte nativo para CHECK constraints activos y roles) |
| **Privilegios Requeridos** | `CREATE`, `GRANT`, `EVENT`, `SUPER` (o `SYSTEM_VARIABLES_ADMIN` para scheduler) |
| **Event Scheduler** | Debe activarse explícitamente: `SET GLOBAL event_scheduler = ON;` |
| **Juego de Caracteres** | `utf8mb4` con collation `utf8mb4_unicode_ci` |
| **Espacio en Disco** | ~50 MB para esquema completo, vistas, índices y datos iniciales de prueba |

---

## Estructura del Proyecto

```
coworking-db/
│
├── README.md                                  # Documentación principal del proyecto
│
├── docs/                                      # Documentación técnica y diagramas
│   ├── modelo_logico.md                       # Especificación detallada del modelo relacional
│   ├── Modelo_Logico.png                      # Diagrama relacional visual (ER)
│   └── roles_permisos.md                      # Matriz de roles, usuarios y permisos MySQL
│
└── sql/                                       # Scripts SQL modulares
    ├── 00_ddl/
    │   └── 01_estructura.sql                  # DDL: 23 tablas, índices y 9 vistas filtradas
    │
    ├── 01_dml/
    │   └── 01_datos_iniciales.sql             # DML: Datos base (55 usuarios, 110 reservas, 210+ pagos)
    │
    ├── 02_consultas/
    │   ├── 01_usuarios_membresias.sql         # Consultas analíticas Q01 a Q20
    │   ├── 02_espacios_reservas.sql           # Consultas analíticas Q21 a Q40
    │   ├── 03_pagos_facturacion.sql           # Consultas analíticas Q41 a Q60
    │   ├── 04_accesos_asistencias.sql         # Consultas analíticas Q61 a Q80
    │   └── 05_consultas_avanzadas.sql         # Consultas avanzadas Q81 a Q100 (KPIs y agregados)
    │
    ├── 03_funciones/
    │   └── 01_funciones.sql                   # 20 funciones deterministas (fn_*)
    │
    ├── 04_procedimientos/
    │   └── 01_procedimientos.sql              # 20 SPs transaccionales (sp_*) con FOR UPDATE
    │
    ├── 05_triggers/
    │   └── 01_triggers.sql                    # 20 triggers reactivos (trg_* / T1-T20)
    │
    ├── 06_eventos/
    │   └── 01_eventos.sql                     # 20 eventos programados (evt_*) en segundo plano
    │
    └── 07_seguridad/
        ├── 01_roles.sql                       # Roles de aplicación y roles MySQL del servidor
        ├── 02_permisos.sql                    # Concesión de privilegios GRANT (mínimo privilegio)
        └── 03_usuarios.sql                    # Creación de usuarios MySQL predefinidos
```

---

## Documentación Técnica

El directorio [`docs/`](docs/) contiene guías detalladas para el diseño y administración de la base de datos:

- **[docs/modelo_logico.md](docs/modelo_logico.md)**: Explicación de los 7 grupos de entidades, claves primarias, foráneas, tipos de datos y relaciones de negocio.
- **[docs/Modelo_Logico.png](docs/Modelo_Logico.png)**: Diagrama entidad-relación gráfico del sistema.
- **[docs/roles_permisos.md](docs/roles_permisos.md)**: Matriz completa de permisos por tabla/vista, seguridad a nivel de fila y gestión de usuarios del servidor.

---

## Orden de Instalación

> **⚠️ Importante:** El script de datos iniciales (`01_dml`) debe ejecutarse **antes** de compilar los triggers (`05_triggers`). Esto asegura que los datos históricos se carguen limpiamente sin activar disparadores de validación futuros, mientras que las operaciones posteriores sí quedarán completamente protegidas.

Ejecute los scripts en el siguiente orden desde la consola de MySQL o su cliente preferido:

```sql
-- 1. Crear base de datos, 23 tablas, índices y 9 vistas
SOURCE sql/00_ddl/01_estructura.sql;

-- 2. Cargar datos de prueba (usuarios, empresas, espacios, tarifas)
SOURCE sql/01_dml/01_datos_iniciales.sql;

-- 3. Funciones deterministas (requeridas por triggers y procedimientos)
SOURCE sql/03_funciones/01_funciones.sql;

-- 4. Procedimientos almacenados de negocio
SOURCE sql/04_procedimientos/01_procedimientos.sql;

-- 5. Triggers reactivos de integridad y saldo
SOURCE sql/05_triggers/01_triggers.sql;

-- 6. Habilitar y compilar eventos programados del sistema
SET GLOBAL event_scheduler = ON;
SOURCE sql/06_eventos/01_eventos.sql;

-- 7. Configuración de seguridad (roles, permisos y cuentas)
SOURCE sql/07_seguridad/01_roles.sql;
SOURCE sql/07_seguridad/02_permisos.sql;
SOURCE sql/07_seguridad/03_usuarios.sql;
```

---

## Modelo de Base de Datos

### Tablas Principales (23)

| # | Tabla | Descripción |
|---|-------|-------------|
| 1 | `roles` | Catálogo de roles de la aplicación (Admin, Recepción, Cliente, Gerente, Contador) |
| 2 | `empresas` | Empresas corporativas asociadas con bolsa/pool mensual de créditos |
| 3 | `usuarios` | Personas registradas (clientes individuales, corporativos y personal) con enlace a usuario BD |
| 4 | `tipos_membresia` | Catálogo de membresías: Diaria, Mensual, Corporativa y Premium |
| 5 | `membresias` | Asignación de membresías con vigencias (`fecha_inicio`, `fecha_fin`) y estados |
| 6 | `historial_membresias` | Auditoría de modificaciones de planes y upgrades/downgrades |
| 7 | `tipos_espacio` | Modalidades de ocupación (`Compartido` o `Exclusivo`) y reglas |
| 8 | `espacios` | Salas de juntas, oficinas privadas y puestos flexibles con aforo y tarifas |
| 9 | `horarios_disponibilidad` | Franjas horarias operativas por espacio y día de la semana |
| 10 | `reservas` | Reservaciones con control de horas, modalidad, estado y créditos aplicados |
| 11 | `servicios_adicionales` | Servicios complementarios (cafetería premium, lockers, proyector, catering) |
| 12 | `metodos_pago` | Medios admitidos: Efectivo, Tarjeta, Transferencia y PayPal |
| 13 | `facturas` | Documentos de cobro con control de recargos por mora no capitalizable y saldo pendiente |
| 14 | `factura_detalle` | Ítems de facturación desglosados (membresías, horas extra, servicios) |
| 15 | `servicios_contratados`| Extras asociados a reservas o membresías |
| 16 | `pagos` | Movimientos financieros (abonos positivos y reembolsos con montos negativos) |
| 17 | `accesos` | Registro de torniquetes/puertas: intentos Permitidos o Rechazados con motivo |
| 18 | `asistencias` | Sesiones reales efectivas vinculadas 1:1 con un acceso para medir permanencia |
| 19 | `movimientos_credito` | Libro mayor contable de créditos (Reinicio mensual, Consumo y Devolución) |
| 20 | `cola_notificaciones` | Cola asíncrona de alertas por mora, avisos de reservas y bienvenida |
| 21 | `configuracion_sistema` | Parámetros globales parametrizables (días de corte, tasa mora, penalizaciones) |
| 22 | `logs_auditoria` | Bitácora de seguridad ante eventos críticos y rechazos |
| 23 | `reportes_generados` | Almacenamiento histórico de reportes consolidados en formato JSON |

### Vistas del Sistema (9)

| # | Vista | Propósito y Seguridad |
|---|-------|------------------------|
| 1 | `v_estado_espacio` | Disponibilidad pública de espacios en tiempo real para reservaciones |
| 2 | `v_usuarios_bloqueados` | Lista de usuarios con morosidad > 10 días para bloqueo en recepción |
| 3 | `v_creditos_saldo` | Balance consolidado de créditos corporativos e individuales |
| 4 | `v_mis_reservas` | Autoservicio: reservas pertenecientes al usuario autenticado (`USER()`) |
| 5 | `v_mis_facturas` | Autoservicio: facturas pendientes pertenecientes al usuario autenticado |
| 6 | `v_mis_accesos` | Autoservicio: historial de entradas y salidas del cliente en los últimos 30 días |
| 7 | `v_empresa_empleados` | Gerencial: lista de colaboradores activos pertenecientes a la empresa del usuario |
| 8 | `v_empresa_facturas` | Gerencial: facturas individuales y consolidadas de la empresa del usuario |
| 9 | `v_empresa_creditos` | Gerencial: estado de consumo del pool corporativo de la empresa |

---

## Componentes Principales

### Funciones Almacenadas (fn_*)

| Módulo | Función | Descripción |
|---|---|---|
| **Membresías** | `fn_membresia_activa(p_usuario_id)` | Retorna `TRUE` si el usuario cuenta con una membresía activa vigente |
| | `fn_estado_membresia(p_usuario_id)` | Obtiene el estado actual (`Activa`, `Suspendida`, `Vencida` o `Sin Membresia`) |
| | `fn_tipo_membresia(p_usuario_id)` | Nombre de la membresía activa actual del usuario |
| | `fn_dias_restantes_membresia(p_usuario_id)` | Días restantes antes del vencimiento |
| | `fn_renovaciones_membresia(p_usuario_id)` | Cantidad acumulada de renovaciones históricas |
| **Reservas** | `fn_total_reservas(p_usuario_id)` | Total histórico de reservas realizadas por un usuario |
| | `fn_horas_reservadas(p_usuario_id, p_mes, p_anio)` | Total de horas reservadas en un mes y año específicos |
| | `fn_espacio_mas_reservado()` | Identificador del espacio con mayor demanda |
| | `fn_reservas_activas(p_usuario_id)` | Conteo de reservas activas o pendientes para validar límites simultáneos |
| | `fn_duracion_promedio_reservas(p_espacio_id)` | Promedio en horas de las reservas de un espacio determinado |
| **Pagos** | `fn_total_pagado(p_usuario_id)` | Monto neto histórico pagado por un usuario (pagos menos reembolsos) |
| | `fn_ingresos_por_mes(p_mes, p_anio)` | Total de ingresos netos recaudados en un mes calendario |
| | `fn_ingresos_por_membresia(p_tipo_id)` | Ingresos acumulados por cada tipo de membresía |
| | `fn_ingresos_por_reservas(p_mes, p_anio)` | Facturación total por concepto de reservas de espacios |
| | `fn_ingresos_por_empresa(p_empresa_id)` | Recaudación total originada por una empresa y sus colaboradores |
| **Asistencias** | `fn_total_asistencias(p_usuario_id)` | Cantidad histórica de visitas al edificio |
| | `fn_asistencias_mes(p_usuario_id, p_mes, p_anio)` | Asistencias registradas en un mes específico |
| | `fn_ultima_asistencia(p_usuario_id)` | Timestamp exacto de la última visita registrada |
| | `fn_top_usuario_asistencias()` | ID del usuario con mayor frecuencia de asistencia |
| | `fn_promedio_asistencias()` | Promedio de visitas entre usuarios con membresía vigente |

### Procedimientos Almacenados (sp_*)

| Procedimiento | Parámetros Clave | Descripción |
|---|---|---|
| `sp_registrar_membresia` | `(usuario_id, tipo_id, fecha_inicio, OUT membresia_id)` | Crea membresía, calcula vigencia y genera factura correspondiente |
| `sp_renovar_membresia` | `(membresia_actual_id, OUT nueva_membresia_id)` | Encadena renovación exactamente desde `fecha_fin + 1 segundo` |
| `sp_actualizar_membresias_vencidas` | `()` | Vence membresías expiradas y suspende aquellas con morosidad |
| `sp_suspender_membresias_impagas` | `(p_dias_mora)` | Suspende usuarios con mora prolongada y cancela reservas futuras |
| `sp_verificar_disponibilidad` | `(espacio_id, f_ini, f_fin, OUT disponible, OUT motivo)` | Valida horarios operativos, solapamiento de fechas y aforo |
| `sp_crear_reserva` | `(usuario_id, espacio_id, modalidad, f_ini, f_fin, personas, créditos, OUT reserva_id)` | Valida mora, deduce créditos o emite factura según corresponda |
| `sp_confirmar_reserva_con_pago` | `(reserva_id, metodo_pago_id, referencia)` | Realiza cobro inmediato y confirma la reservación |
| `sp_cancelar_reserva` | `(reserva_id, con_reembolso)` | Cancela la reserva, restituye créditos y gestiona reembolso/anulación |
| `sp_liberar_reservas_no_confirmadas` | `(p_horas_limite)` | Libera reservaciones pendientes que no fueron pagadas a tiempo |
| `sp_generar_factura_por_consumo` | `(usuario_id, concepto, monto, OUT factura_id)` | Emite factura directa por servicios o consumos extras |
| `sp_generar_factura_consolidada_empresa` | `(empresa_id, mes, anio, OUT factura_id)` | Consolida en una sola factura mensual las membresías y consumos de empleados |
| `sp_aplicar_recargos_facturas_vencidas` | `()` | Aplica mora diaria (0.5%) sobre base vencida sin interés compuesto |
| `sp_registrar_pago` | `(factura_id, monto, metodo_id, referencia, OUT pago_id)` | Inserta pago y dispara actualización atómica del saldo |
| `sp_registrar_acceso` | `(identificador, tipo_id, punto_acceso, OUT acceso_id)` | Valida credencial (RFID/QR), auto-cierra sesiones previas e ingresa |
| `sp_registrar_salida` | `(usuario_id)` | Registra egreso cerrando asistencias de Sala y Edificio |
| `sp_generar_reporte_diario_asistencias` | `(p_fecha)` | Genera resumen estadístico del día en formato JSON |
| `sp_marcar_no_show_y_penalizar` | `(reserva_id)` | Penaliza inasistencias en reservas por hora sin ingreso tras 15 minutos |
| `sp_registrar_lote_empleados` | `(empresa_id, json_empleados)` | Alta masiva transaccional de trabajadores y membresías corporativas |
| `sp_cancelar_reservas_futuras_usuario` | `(usuario_id, motivo)` | Cancela reservas futuras por suspensión o baja del usuario |
| `sp_generar_reporte_ingresos_mensuales` | `(p_anio)` | Compila reporte financiero anual en formato JSON para contabilidad |

### Triggers (trg_*)

| # | Trigger | Evento / Tabla | Acción Principal |
|---|---|---|---|
| **T1** | `trg_bi_membresias_vigencia_solapamiento` | BEFORE INSERT `membresias` | Calcula `fecha_fin`, fija estado inicial y evita solapamientos activos |
| **T2** | `trg_au_facturas_activar_membresia` | AFTER UPDATE `facturas` (Pagada) | Activa membresía vinculada y reinicia créditos mensuales |
| **T3** | `trg_au_facturas_incobrable_suspension` | AFTER UPDATE `facturas` (Incobrable) | Suspende membresías asociadas al entrar en incobrabilidad (>90 días) |
| **T4** | `trg_au_membresias_historial` | AFTER UPDATE `membresias` | Registra en auditoría cualquier cambio de tipo de membresía |
| **T5** | `trg_bd_membresias_validar_eliminacion` | BEFORE DELETE `membresias` | Impide borrar membresías con reservas asociadas o pagos |
| **T6** | `trg_bi_reservas_validaciones` | BEFORE INSERT `reservas` | Bloquea por morosidad, valida horario del espacio y aforo máximo |
| **T7** | `trg_bi_reservas_estado_inicial` | BEFORE INSERT `reservas` (FOLLOWS T6) | Fija `Confirmada` si `monto_facturable = 0` (por créditos); sino `Pendiente` |
| **T8** | `trg_au_facturas_confirmar_reserva` | AFTER UPDATE `facturas` (Pagada) | Cambia automáticamente la reserva asociada de `Pendiente` a `Confirmada` |
| **T9** | `trg_au_membresias_cancelar_reservas_futuras` | AFTER UPDATE `membresias` (Suspendida) | Cancela reservas futuras al suspenderse la membresía |
| **T10** | `trg_au_reservas_devolver_creditos` | AFTER UPDATE `reservas` (Cancelada) | Registra la restitución en `movimientos_credito` y audita |
| **T11** | `trg_bi_servicios_contratados_validar_mora` | BEFORE INSERT `servicios_contratados` | Impide contratar servicios extra si el usuario presenta deuda vencida |
| **T12** | `trg_ai_pagos_actualizar_saldo` | AFTER INSERT `pagos` | Fuente única de verdad que actualiza `saldo_pendiente` y estado de factura |
| **T13** | `trg_bd_facturas_validar_eliminacion` | BEFORE DELETE `facturas` | Bloquea eliminación de facturas que posean pagos vinculados |
| **T14** | `trg_bi_pagos_validar_monto_y_estado` | BEFORE INSERT `pagos` | Valida que abonos no superen saldo y que reembolsos no superen lo pagado |
| **T15** | `trg_au_pagos_recalcular_saldo` | AFTER UPDATE `pagos` (Cancelado) | Recalcula el saldo pendiente de la factura y registra en auditoría |
| **T16** | `trg_bi_accesos_validar_ingreso` | BEFORE INSERT `accesos` | Evalúa membresía, suspensiones y horarios para fijar `Permitido` o `Rechazado` |
| **T17** | `trg_ai_accesos_registrar_asistencia` | AFTER INSERT `accesos` | Inserta automáticamente sesión abierta en `asistencias` si fue permitido |
| **T18** | `trg_ai_accesos_actualizar_ultimo_acceso` | AFTER INSERT `accesos` | Actualiza `usuarios.ultimo_acceso` con el timestamp de ingreso |
| **T19** | `trg_au_accesos_cerrar_asistencia` | AFTER UPDATE `accesos` (Salida) | Registra `fecha_salida` y calcula minutos efectivos de permanencia |
| **T20** | `trg_ai_accesos_auditar_rechazados` | AFTER INSERT `accesos` (Rechazado) | Inserta registro en `logs_auditoria` detallando el motivo de rechazo |

### Eventos Programados (evt_*)

| Frecuencia | Evento | Descripción Operativa |
|---|---|---|
| **Diario (00:01)** | `evt_diario_vencer_membresias` | Marca como `Vencida` las membresías cuya `fecha_fin < NOW()` |
| **Diario (08:00)** | `evt_diario_aviso_vencimiento_membresias` | Encola recordatorio a socios cuya membresía vence en 5 días |
| **Diario (02:00)** | `evt_diario_suspender_por_mora` | Suspende membresías con facturas impagas superiores a 30 días de mora |
| **Semanal (Lunes 07:00)** | `evt_semanal_reporte_nuevas_membresias` | Consolida socios incorporados en la última semana |
| **Diario (07:30)** | `evt_diario_alerta_suspendidas` | Notifica a recepción el listado de suspendidos para control de acceso |
| **Cada hora** | `evt_horario_cancelar_reservas_pendientes` | Cancela reservas en `Pendiente` sin pago tras 2 horas de su creación |
| **Cada hora** | `evt_horario_recordatorio_reservas` | Notifica al usuario 1 hora antes del inicio de su reserva |
| **Diario (23:00)** | `evt_diario_completar_reservas` | Pasa a `Completada` las reservas cuyo horario final ya concluyó |
| **Semanal (Domingo 23:30)** | `evt_semanal_reporte_ocupacion` | Calcula y guarda ratio de ocupación real vs. reservada |
| **Cada 15 min** | `evt_15min_marcar_no_show` | Detecta reservas por hora sin ingreso 15 min tras inicio y penaliza |
| **Cada 3 días** | `evt_3dias_aviso_pago_pendiente` | Recordatorio automático de deuda a clientes con saldo pendiente |
| **Diario (03:00)** | `evt_diario_marcar_incobrables` | Declara `Incobrable` facturas con mora > 90 días y detiene recargos |
| **Mensual (Día 1 00:05)** | `evt_mensual_renovacion_corporativa` | Renueva membresías corporativas, genera consolidada y recarga pool |
| **Diario (01:00)** | `evt_diario_aplicar_recargos_mora` | Aplica recargo diario del 0.5% desde el día 16 de vencida la factura |
| **Mensual (Día 1 04:00)** | `evt_mensual_reporte_contable` | Genera balance financiero mensual en formato JSON |
| **Cada 15 min** | `evt_15min_auto_checkout_cierre` | Auto-checkout de asistencias abiertas al alcanzar la hora de cierre |
| **Diario (23:45)** | `evt_diario_reporte_asistencias` | Resumen de afluencia diaria guardado en `reportes_generados` |
| **Semanal (Lunes 09:00)** | `evt_semanal_usuarios_inactivos` | Identifica socios activos sin visitas en 30 días para fidelización |
| **Diario (06:00)** | `evt_diario_alerta_accesos_fuera_horario` | Audita y alerta sobre accesos anómalos fuera de franja permitida |
| **Mensual (Día 1 05:00)** | `evt_mensual_top_frecuentes_y_depuracion` | Ranking Top 10 mensual y depuración de notificaciones > 90 días |

---

## Roles y Seguridad

El sistema implementa separación de responsabilidades a dos niveles: **roles de aplicación** (en tabla `roles`) y **roles de base de datos MySQL** (en servidor).

### Roles de Aplicación (tabla `roles`)

| ID | Nombre Rol | Descripción |
|---|---|---|
| 1 | **Administrador** | Control total técnico y operativo del espacio de coworking |
| 2 | **Recepcionista** | Operación diaria en mostrador: check-in, cobros y registro |
| 3 | **Usuario** | Cliente final: consulta de disponibilidad, reservas y pagos propios |
| 4 | **Gerente Corporativo** | Representante de empresa: gestión de empleados y créditos del pool |
| 5 | **Contador** | Consulta financiera, facturación consolidada y reportes contables |

### Roles MySQL del Servidor y Cuentas Predefinidas

| Rol MySQL | Cuentas Predefinidas (`03_usuarios.sql`) | Privilegios Otorgados |
|---|---|---|
| `rol_admin` | `admin1@localhost` | `ALL PRIVILEGES ON coworking.*` |
| `rol_recepcionista` | `recepcion1@localhost` | DML sobre usuarios, accesos, membresías, reservas y SPs de recepción |
| `rol_usuario` | `user_elena@localhost`, `user_gonzalo@localhost` | Vistas personales `v_mis_*`, consulta de espacios y SPs de reserva propios |
| `rol_gerente` | `gerente_tech@localhost` | Vistas corporativas `v_empresa_*` y `sp_registrar_lote_empleados` |
| `rol_contador` | `contador1@localhost` | Solo lectura sobre facturas, pagos, reportes y SPs de cierre |

> Las vistas con prefijo `v_mis_*` y `v_empresa_*` implementan **seguridad a nivel de fila** mediante la función nativa `USER()` de MySQL:  
> `WHERE u.usuario_bd = SUBSTRING_INDEX(USER(), '@', 1)`

---

## Escalera de Mora

| Días de Vencimiento | Estado / Efecto en el Sistema | Mecanismo de Control |
|---|---|---|
| **Día 0** | Período de gracia: acceso físico permitido | Operativo |
| **Día > 10** | **Bloqueo preventivo**: se impide crear nuevas reservas o contratar servicios adicionales | Trigger T6, Trigger T11 y `v_usuarios_bloqueados` |
| **Día = 16** | **Recargo diario**: 0.5% diario sobre saldo pendiente original (sin capitalización) | `evt_diario_aplicar_recargos_mora` |
| **Día > 30** | **Suspensión**: membresía pasa a `Suspendida`, acceso denegado y reservas futuras canceladas | `evt_diario_suspender_por_mora` + Trigger T9 |
| **Día > 90** | **Incobrabilidad**: factura pasa a `Incobrable`, recargos se detienen definitivamente | `evt_diario_marcar_incobrables` + Trigger T3 |

---

## Consultas Analíticas

El directorio [`sql/02_consultas/`](sql/02_consultas/) contiene **100 consultas analíticas avanzadas** (20 por archivo):

- **[01_usuarios_membresias.sql](sql/02_consultas/01_usuarios_membresias.sql)** (Q01 - Q20): Análisis de cohortes, retención, churn rate, distribución por plan y renovación.
- **[02_espacios_reservas.sql](sql/02_consultas/02_espacios_reservas.sql)** (Q21 - Q40): Ocupación horaria, espacios de mayor demanda, tasas de cancelación y horas pico.
- **[03_pagos_facturacion.sql](sql/02_consultas/03_pagos_facturacion.sql)** (Q41 - Q60): Flujo de caja, distribución de métodos de pago, recargos recaudados y cuentas por cobrar.
- **[04_accesos_asistencias.sql](sql/02_consultas/04_accesos_asistencias.sql)** (Q61 - Q80): Horas de permanencia real, accesos rechazados por morosidad y ratios de uso de instalaciones.
- **[05_consultas_avanzadas.sql](sql/02_consultas/05_consultas_avanzadas.sql)** (Q81 - Q100): KPIs financieros avanzados (LTV, ARPU), comparativa uso real vs. reservado y detección de patrones de fraude.

---

## Ejemplos de Uso

### 1. Registrar una nueva membresía individual y abonar el pago
```sql
-- 1. Registrar membresía Mensual para el usuario 50
CALL sp_registrar_membresia(50, 2, NOW(), @mid);

-- 2. Obtener el ID de factura emitida automáticamente
SELECT id INTO @fid FROM facturas WHERE membresia_id = @mid LIMIT 1;

-- 3. Registrar el pago total con tarjeta
CALL sp_registrar_pago(@fid, 180.00, 2, 'TARJ-OPERACION-1234', @pid);

-- 4. Comprobar que el Trigger T2 activó la membresía
SELECT id, usuario_id, tipo_id, estado, fecha_inicio, fecha_fin 
FROM membresias WHERE id = @mid;
```

### 2. Crear una reserva consumiendo créditos del pool corporativo
```sql
-- Empleado de empresa corporativa reserva Sala de Juntas (Espacio 3) por 2 horas
CALL sp_crear_reserva(
    6,                      -- ID usuario (Elena Vásquez - TechCorp)
    3,                      -- ID espacio (Sala de Reuniones A)
    'Hora',                 -- Modalidad
    '2026-10-15 10:00:00',  -- Fecha inicio
    '2026-10-15 12:00:00',  -- Fecha fin
    4,                      -- Asistentes
    TRUE,                   -- Usar créditos de empresa
    @rid                    -- OUT: ID de reserva generada
);

-- Verificar deducción contable del pool en movimientos_credito
SELECT * FROM movimientos_credito WHERE reserva_id = @rid;
```

### 3. Consulta analítica: Espacios con mayor ocupación en tiempo real (Q82)
```sql
SELECT 
    e.id AS espacio_id,
    e.nombre AS espacio,
    te.nombre AS tipo,
    COUNT(DISTINCT r.id) AS reservas_con_uso_real,
    ROUND(SUM(
        TIMESTAMPDIFF(MINUTE,
            GREATEST(a.fecha_entrada, r.fecha_inicio),
            LEAST(COALESCE(a.fecha_salida, NOW()), r.fecha_fin)
        )
    ) / 60.0, 2) AS horas_uso_real
FROM asistencias a
JOIN reservas r ON a.reserva_id = r.id
JOIN espacios e ON r.espacio_id = e.id
JOIN tipos_espacio te ON e.tipo_id = te.id
GROUP BY e.id, e.nombre, te.nombre
ORDER BY horas_uso_real DESC;
```

---

## Flujos de Negocio y Verificación

El diseño de la base de datos articula y garantiza la integridad de los **11 flujos de negocio** mediante la interacción de SPs y triggers:

| Flujo | Circuito de Negocio Verificado | Disparadores y Componentes Involucrados |
|---|---|---|
| **1** | Membresía Individual | `sp_registrar_membresia` → T1 → Factura → `sp_registrar_pago` → T12 → T2 → Estado `Activa` |
| **2** | Renovación de Membresía | `sp_renovar_membresia` → cálculo fecha fin + 1 segundo → T1 |
| **3** | Membresía Corporativa | `sp_registrar_lote_empleados` → T1 (`Activa` directa) → factura consolidada → recarga pool |
| **4** | Reserva con Pago en Dinero | `sp_crear_reserva` → T6/T7 (`Pendiente`) → Factura → Pago → T8 (`Confirmada`) |
| **5** | Reserva con Créditos | `sp_crear_reserva` → Consumo pool → `monto_facturable = 0` → T7 directo a `Confirmada` |
| **6** | Check-in al Edificio | `sp_registrar_acceso` → T16 (validación) → T17 (asistencia abierta) + T18 (`ultimo_acceso`) |
| **7** | Check-out del Edificio | `sp_registrar_salida` → T19 (cierra asistencias y computa minutos de permanencia) |
| **8** | Penalización por No Show | `evt_15min_marcar_no_show` → `sp_marcar_no_show_y_penalizar` → cancelación y penalidad |
| **9** | Cancelación y Reembolso | `sp_cancelar_reserva` → T10 (restitución de créditos) → anulación/reembolso de pago |
| **10** | Escalera de Morosidad | Bloqueo día 10 → recargo día 16 → suspensión día 30 → incobrable día 90 |
| **11** | Reactivación tras Pago | Pago de factura vencida → T12 → T2 (evalúa deuda) → reactiva membresía a `Activa` |

---

## Contribuciones y Licencia

- **Proyecto:** Base de Datos Relacional para Sistema de Gestión de Coworking
- **Asignatura:** Diseño de Bases de Datos
- **Versión de Especificación:** v3 (Octubre 2026)
- **Licencia:** Proyecto con fines académicos bajo licencia MIT. Prohibida su copia no autorizada.
