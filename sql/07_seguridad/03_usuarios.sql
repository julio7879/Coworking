/*

Integrante Responsable: Julio Ernesto Castaño Palacios

Módulo: Seguridad - Creación y Asignación de Usuarios MySQL
Archivo: 03_usuarios.sql

Descripción:
Creación de cuentas de usuario en el servidor MySQL vinculadas a la columna
'usuario_bd' de la tabla 'usuarios'.

Requisitos:
Ejecutar previamente 01_roles.sql y 02_permisos.sql.
*/

USE coworking;

-- 1. Administrador del Sistema

CREATE USER IF NOT EXISTS 'admin1'@'localhost' IDENTIFIED BY 'AdminCowork2026!';
GRANT 'rol_admin' TO 'admin1'@'localhost';
SET DEFAULT ROLE 'rol_admin' TO 'admin1'@'localhost';

-- 2. Personal de Recepción

CREATE USER IF NOT EXISTS 'recepcion1'@'localhost' IDENTIFIED BY 'RecepCowork2026!';
GRANT 'rol_recepcionista' TO 'recepcion1'@'localhost';
SET DEFAULT ROLE 'rol_recepcionista' TO 'recepcion1'@'localhost';

-- 3. Usuarios Clientes (Autoservicio)

CREATE USER IF NOT EXISTS 'user_elena'@'localhost' IDENTIFIED BY 'UserPass2026!';
GRANT 'rol_usuario' TO 'user_elena'@'localhost';
SET DEFAULT ROLE 'rol_usuario' TO 'user_elena'@'localhost';

CREATE USER IF NOT EXISTS 'user_gonzalo'@'localhost' IDENTIFIED BY 'UserPass2026!';
GRANT 'rol_usuario' TO 'user_gonzalo'@'localhost';
SET DEFAULT ROLE 'rol_usuario' TO 'user_gonzalo'@'localhost';

-- 4. Gerente Corporativo

CREATE USER IF NOT EXISTS 'gerente_tech'@'localhost' IDENTIFIED BY 'GerenteTech2026!';
GRANT 'rol_gerente' TO 'gerente_tech'@'localhost';
SET DEFAULT ROLE 'rol_gerente' TO 'gerente_tech'@'localhost';

-- 5. Contador

CREATE USER IF NOT EXISTS 'contador1'@'localhost' IDENTIFIED BY 'ContaCowork2026!';
GRANT 'rol_contador' TO 'contador1'@'localhost';
SET DEFAULT ROLE 'rol_contador' TO 'contador1'@'localhost';

FLUSH PRIVILEGES;
