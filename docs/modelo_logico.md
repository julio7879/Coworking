# 📊 Modelo Lógico — Coworking DB

Este documento describe el modelo lógico entidad-relación de la base de datos de gestión del coworking.

---

## Diagrama del Modelo Lógico

![Modelo Lógico Entidad-Relación](modelo_logico.png)

---

## Descripción de Entidades Principales

### Grupo 1 — Configuración y Seguridad (arriba izquierda)

| Entidad                | Atributos clave                                                |
|------------------------|----------------------------------------------------------------|
| `configuracion_sistema`| `clave` (PK), `valor`, `descripcion`                          |
| `roles`                | `id` (PK), `nombre`, `permisos` (JSON), `puede_reservar`      |
| `logs_auditoria`       | `id` (PK), `tipo`, `referencia_id`, `datos_anteriores`, `datos_nuevos` |
| `reportes_generados`   | `id` (PK), `tipo`, `datos` (JSON), `generado_por`             |

---

### Grupo 2 — Usuarios y Empresas (centro-superior)

| Entidad                | Atributos clave                                                            |
|------------------------|----------------------------------------------------------------------------|
| `roles`                | `id` (PK), `nombre`, `activo`                                              |
| `empresas`             | `id` (PK), `nombre`, `rfc`, `creditos_mensuales`, `pool_creditos_actual`   |
| `usuarios`             | `id` (PK), `nombre`, `apellidos`, `email`, `tipo_usuario`, `empresa_id` (FK), `rol_id` (FK), `usuario_bd`, `ultimo_acceso` |
| `membresias`           | `id` (PK), `usuario_id` (FK), `tipo_id` (FK), `fecha_inicio`, `fecha_fin`, `estado`, `creditos_disponibles` |
| `historial_membresias` | `id` (PK), `usuario_id` (FK), `tipo_anterior`, `tipo_nuevo`, `fecha_cambio`|
| `tipos_membresia`      | `id` (PK), `nombre`, `duracion_dias`, `precio`, `creditos_incluidos`, `activo`, `creditos_adicionales` |

---

### Grupo 3 — Espacios y Disponibilidad (izquierda)

| Entidad                   | Atributos clave                                                        |
|---------------------------|------------------------------------------------------------------------|
| `tipos_espacio`           | `id` (PK), `nombre`, `modo_ocupacion` (Compartido/Exclusivo), `duracion_minima`, `creditos_adicionales` |
| `espacios`                | `id` (PK), `tipo_id` (FK), `nombre`, `ubicacion_fisica`, `capacidad_maxima`, `tarifa_hora`, `tarifa_mes`, `estado` |
| `horarios_disponibilidad` | `id` (PK), `espacio_id` (FK), `dia_semana`, `hora_apertura`, `hora_cierre` |

---

### Grupo 4 — Reservas y Servicios (centro)

| Entidad                   | Atributos clave                                                           |
|---------------------------|---------------------------------------------------------------------------|
| `reservas`                | `id` (PK), `usuario_id` (FK), `espacio_id` (FK), `modalidad` (Hora/Mes), `fecha_inicio`, `fecha_fin`, `num_personas`, `estado`, `creditos_usados`, `monto_facturable`, `costo_total` |
| `servicios_adicionales`   | `id` (PK), `nombre`, `precio_unitario`, `activo`                          |
| `servicios_contratados`   | `id` (PK), `usuario_id` (FK), `reserva_id` (FK), `servicio_id` (FK), `cantidad`, `precio_unitario`, `factura_id` (FK) |

---

### Grupo 5 — Accesos y Asistencias (derecha)

| Entidad       | Atributos clave                                                                                    |
|---------------|----------------------------------------------------------------------------------------------------|
| `accesos`     | `id` (PK), `usuario_id` (FK), `reserva_id` (FK), `fecha_hora_entrada`, `fecha_hora_salida`, `metodo_acceso`, `estado_intento`, `motivo_rechazo` |
| `asistencias` | `id` (PK), `acceso_id` (FK), `usuario_id` (FK), `reserva_id` (FK), `tipo` (Edificio/Sala), `fecha_entrada`, `fecha_salida`, `minutos` |

---

### Grupo 6 — Facturación y Pagos (abajo)

| Entidad           | Atributos clave                                                                                       |
|-------------------|-------------------------------------------------------------------------------------------------------|
| `metodos_pago`    | `id` (PK), `nombre`, `activo`                                                                         |
| `facturas`        | `id` (PK), `usuario_id` (FK), `empresa_id` (FK), `reserva_id` (FK), `membresia_id` (FK), `tipo`, `monto_base`, `recargo_acumulado`, `monto_total`, `saldo_pendiente`, `estado`, `fecha_emision`, `fecha_vencimiento`, `motivo_anulacion` |
| `factura_detalle` | `id` (PK), `factura_id` (FK), `concepto_tipo` (FK), `referencia_id`, `monto`                          |
| `pagos`           | `id` (PK), `factura_id` (FK), `metodo_pago_id` (FK), `monto`, `fecha_pago`, `referencia`, `estado`    |

---

### Grupo 7 — Créditos y Notificaciones

| Entidad               | Atributos clave                                                                      |
|-----------------------|--------------------------------------------------------------------------------------|
| `movimientos_credito` | `id` (PK), `usuario_id` (FK), `empresa_id` (FK), `membresia_id` (FK), `reserva_id` (FK), `creditos`, `tipo` (Reinicio/Consumo/Devolución), `fecha` |
| `cola_notificaciones` | `id` (PK), `usuario_id` (FK), `canal`, `asunto`, `mensaje`, `estado`, `fecha`        |

---

## Relaciones Principales

```
empresas ─────────── usuarios (N:1)
usuarios ─────────── membresias (1:N)
tipos_membresia ──── membresias (N:1)
usuarios ──────────── reservas (1:N)
espacios ─────────── reservas (1:N)
tipos_espacio ─────── espacios (N:1)
reservas ──────────── facturas (1:1 o 1:N servicios)
facturas ──────────── pagos (1:N)
reservas ──────────── accesos (1:N)
accesos ───────────── asistencias (1:1)
usuarios ──────────── movimientos_credito (1:N)
empresas ──────────── movimientos_credito (1:N pool)
```

---

## Cardinalidades Clave

| Relación | Cardinalidad | Restricción |
|---|---|---|
+| Usuario → Membresías | 1:N | Solo 1 activa simultáneamente (T1) |
+| Espacio Exclusivo → Reservas activas | 1:1 | No solapamiento (T6) |
+| Espacio Compartido → Reservas activas | 1:N | Hasta capacidad_maxima personas |
+| Factura → Pagos | 1:N | Solo T12 escribe saldo_pendiente |
+| Acceso → Asistencia | 1:1 | Una asistencia por acceso Permitido |
+| Membresía Corporativa → Factura individual | 1:0 | Sin factura individual (regla 10) |

---

## Archivos Relacionados

| Archivo | Descripción |
|---|---|
+| [`modelo_logico.png`](modelo_logico.png) | Imagen del diagrama entidad-relación |
+| [`../sql/00_ddl/01_estructura.sql`](../sql/00_ddl/01_estructura.sql) | DDL completo: CREATE TABLE, índices, vistas |
+| [`../README.md`](../README.md) | Documentación general del proyecto |
+| [`roles_permisos.md`](roles_permisos.md) | Seguridad: roles, permisos y vistas filtradas |
