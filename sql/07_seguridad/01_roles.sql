/*
Integrante Responsable: Julio Ernesto Castaño Palacios

Módulo: Seguridad - Definición de Roles
Archivo: 01_roles.sql

Descripción:
Definición de roles de aplicación y creación de roles de base de datos MySQL'rol_'.

Requisitos:
Ejecutar previamente 01_estructura.sql.
*/

USE coworking;

-- SECCIÓN 1: ROLES DE APLICACIÓN (Tabla roles)

INSERT INTO roles (id, nombre, descripcion) VALUES
 (1, 'Administrador', 'Acceso total y configuración del sistema'),
 (2, 'Recepcionista', 'Operación diaria, registro de accesos y pagos en recepción'),
 (3, 'Usuario', 'Cliente general, reservas y servicios personales'),
 (4, 'Gerente Corporativo', 'Administra membresías y créditos de su empresa'),
 (5, 'Contador', 'Gestión financiera, facturación y reportes contables')
ON DUPLICATE KEY UPDATE descripcion = VALUES(descripcion);

-- SECCIÓN 2: CREACIÓN DE ROLES MYSQL (Prefijo rol_)

CREATE ROLE IF NOT EXISTS 'rol_admin';
CREATE ROLE IF NOT EXISTS 'rol_recepcionista';
CREATE ROLE IF NOT EXISTS 'rol_usuario';
CREATE ROLE IF NOT EXISTS 'rol_gerente';
CREATE ROLE IF NOT EXISTS 'rol_contador';
