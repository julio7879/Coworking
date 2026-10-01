# Roles y Permisos - Gestión de Coworking

## 👥 Convención de Nombres
Todos los roles deben definirse con el prefijo obligatorio `rol_`.

## 🛡️ Matriz de Roles y Privilegios

| Rol | Descripción | Permisos Principales |
| :--- | :--- | :--- |
| `rol_administrador` | Acceso total al sistema y configuración | ALL PRIVILEGES |
| `rol_recepcion` | Gestión de accesos, asistencias y reservas directas | SELECT, INSERT, UPDATE en usuarios, reservas, accesos |
| `rol_facturacion` | Gestión de pagos, facturas y membresías | SELECT, INSERT, UPDATE en pagos, facturas, suscripciones |
| `rol_usuario` | Consulta de perfil, propias reservas y consumos | SELECT en espacios, propias reservas |
| `rol_mantenimiento` | Consulta y reporte sobre estado de espacios e instalaciones | SELECT, UPDATE en estado_espacio |
