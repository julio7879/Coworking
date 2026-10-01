/*
Proyecto: Gestión de Coworking

Grupo: 06

Integrantes:

1. Sofia Salazar Hernandez
2. Valeria Lizcano Arena
3. Zlatan Ricardo Villamizar 
4. Brenda Nico Carrillo Gonzalez
5. Julio Ernesto Castaño Palacios

Módulo: DDL - Estructura de Base de Datos, Tablas, Índices y Vistas
Archivo: 01_estructura.sql

Descripción:
Creación de la base de datos 'coworking', definición de las 23 tablas relacionales
con restricciones CHECK y UNIQUE, índices optimizados y vistas de negocio.

Requisitos:
Servidor MySQL 8.0.16 o superior.
*/

CREATE DATABASE IF NOT EXISTS coworking
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_0900_ai_ci;

USE coworking;


-- CREACIÓN DE TABLAS


-- 1. roles (Catálogo de roles de aplicación)

CREATE TABLE roles (
    id          INT          NOT NULL AUTO_INCREMENT,
    nombre      VARCHAR(50)  NOT NULL,
    descripcion VARCHAR(255) NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uq_roles_nombre (nombre)
) ENGINE=InnoDB;

-- 2. empresas

CREATE TABLE empresas (
    id                 INT          NOT NULL AUTO_INCREMENT,
    nombre             VARCHAR(120) NOT NULL,
    industria          VARCHAR(80)  NULL,
    contacto           VARCHAR(150) NULL,
    creditos_mensuales INT          NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    CONSTRAINT chk_empresas_creditos CHECK (creditos_mensuales >= 0)
) ENGINE=InnoDB;


-- 3. usuarios

CREATE TABLE usuarios (
    id             INT          NOT NULL AUTO_INCREMENT,
    nombre         VARCHAR(80)  NOT NULL,
    apellidos      VARCHAR(100) NOT NULL,
    fecha_nac      DATE         NULL,
    email          VARCHAR(150) NOT NULL,
    telefono       VARCHAR(30)  NULL,
    empresa_id     INT          NULL,
    rol_id         INT          NOT NULL,
    rfid_tag       VARCHAR(50)  NULL,
    tipo_usuario   ENUM('Cliente','Invitado') NOT NULL DEFAULT 'Cliente',
    anfitrion_id   INT          NULL,
    usuario_bd     VARCHAR(32)  NULL,
    ultimo_acceso  DATETIME     NULL,
    activo         BOOLEAN      NOT NULL DEFAULT TRUE,
    fecha_registro DATE         NOT NULL DEFAULT (CURRENT_DATE),
    PRIMARY KEY (id),
    UNIQUE KEY uq_usuarios_email      (email),
    UNIQUE KEY uq_usuarios_rfid_tag   (rfid_tag),
    UNIQUE KEY uq_usuarios_usuario_bd (usuario_bd),
    CONSTRAINT fk_usuarios_empresa   FOREIGN KEY (empresa_id)   REFERENCES empresas (id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_usuarios_rol       FOREIGN KEY (rol_id)       REFERENCES roles (id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_usuarios_anfitrion FOREIGN KEY (anfitrion_id) REFERENCES usuarios (id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT chk_usuarios_invitado_anfitrion
        CHECK (tipo_usuario <> 'Invitado' OR anfitrion_id IS NOT NULL)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 4. tipos_membresia
-- ---------------------------------------------------------------------
CREATE TABLE tipos_membresia (
    id                       INT           NOT NULL AUTO_INCREMENT,
    nombre                   VARCHAR(50)   NOT NULL,
    precio                   DECIMAL(12,2) NOT NULL,
    duracion_dias            INT           NULL,
    max_reservas_simultaneas INT           NOT NULL DEFAULT 1,
    creditos_incluidos       INT           NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    UNIQUE KEY uq_tipos_membresia_nombre (nombre),
    CONSTRAINT chk_tipos_membresia_precio    CHECK (precio >= 0),
    CONSTRAINT chk_tipos_membresia_duracion  CHECK (duracion_dias IS NULL OR duracion_dias > 0),
    CONSTRAINT chk_tipos_membresia_max_res   CHECK (max_reservas_simultaneas >= 0),
    CONSTRAINT chk_tipos_membresia_creditos  CHECK (creditos_incluidos >= 0)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 5. membresias
-- ---------------------------------------------------------------------
CREATE TABLE membresias (
    id           INT      NOT NULL AUTO_INCREMENT,
    usuario_id   INT      NOT NULL,
    tipo_id      INT      NOT NULL,
    fecha_inicio DATETIME NOT NULL,
    fecha_fin    DATETIME NOT NULL,
    estado       ENUM('Pendiente','Activa','Suspendida','Vencida') NOT NULL DEFAULT 'Pendiente',
    renovaciones INT      NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    CONSTRAINT fk_membresias_usuario FOREIGN KEY (usuario_id) REFERENCES usuarios (id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_membresias_tipo    FOREIGN KEY (tipo_id)    REFERENCES tipos_membresia (id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT chk_membresias_periodo      CHECK (fecha_fin > fecha_inicio),
    CONSTRAINT chk_membresias_renovaciones CHECK (renovaciones >= 0)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 6. historial_membresias
-- ---------------------------------------------------------------------
CREATE TABLE historial_membresias (
    id            INT      NOT NULL AUTO_INCREMENT,
    usuario_id    INT      NOT NULL,
    tipo_anterior INT      NOT NULL,
    tipo_nuevo    INT      NOT NULL,
    fecha_cambio  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    CONSTRAINT fk_hist_memb_usuario  FOREIGN KEY (usuario_id)    REFERENCES usuarios (id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_hist_memb_anterior FOREIGN KEY (tipo_anterior) REFERENCES tipos_membresia (id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_hist_memb_nuevo    FOREIGN KEY (tipo_nuevo)    REFERENCES tipos_membresia (id)
        ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 7. tipos_espacio
-- ---------------------------------------------------------------------
CREATE TABLE tipos_espacio (
    id                   INT         NOT NULL AUTO_INCREMENT,
    nombre               VARCHAR(60) NOT NULL,
    modo_ocupacion       ENUM('Compartido','Exclusivo') NOT NULL,
    permite_reserva_hora BOOLEAN     NOT NULL DEFAULT TRUE,
    permite_reserva_mes  BOOLEAN     NOT NULL DEFAULT FALSE,
    usa_creditos         BOOLEAN     NOT NULL DEFAULT FALSE,
    PRIMARY KEY (id),
    UNIQUE KEY uq_tipos_espacio_nombre (nombre)
) ENGINE=InnoDB;
