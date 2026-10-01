# Proyecto MySQL II - Gestión de Coworking

Sistema de base de datos relacional en MySQL para la gestión integral de un espacio de Coworking.

## 📁 Estructura del Repositorio

```text
coworking/
├── README.md
├── docs/
│   ├── modelo_logico.png
│   └── roles_permisos.md
└── sql/
    ├── 00_ddl/
    │   └── 01_estructura.sql
    ├── 01_dml/
    │   └── 01_datos_iniciales.sql
    ├── 02_consultas/
    │   ├── 01_usuarios_membresias.sql
    │   ├── 02_espacios_reservas.sql
    │   ├── 03_pagos_facturacion.sql
    │   ├── 04_accesos_asistencias.sql
    │   └── 05_consultas_avanzadas.sql
    ├── 03_funciones/
    │   └── 01_funciones.sql
    ├── 04_procedimientos/
    │   └── 01_procedimientos.sql
    ├── 05_triggers/
    │   └── 01_triggers.sql
    ├── 06_eventos/
    │   └── 01_eventos.sql
    └── 07_seguridad/
        ├── 01_roles.sql
        ├── 02_permisos.sql
        └── 03_usuarios.sql
```

## 📋 Convenciones Obligatorias

| Elemento | Convención | Ejemplo |
| :--- | :--- | :--- |
| **Archivos** | Minúsculas, sin espacios ni tildes | `01_estructura.sql` |
| **Tablas y columnas** | snake_case | `id_usuario`, `fecha_inicio` |
| **Procedimientos** | Prefijo `sp_` | `sp_registrar_reserva` |
| **Funciones** | Prefijo `fn_` | `fn_calcular_total` |
| **Triggers** | Prefijo `trg_` | `trg_auditoria_reservas` |
| **Eventos** | Prefijo `evt_` | `evt_expirar_membresias` |
| **Índices secundarios** | Prefijo `idx_` | `idx_usuario_email` |
| **Roles** | Prefijo `rol_` | `rol_administrador` |
