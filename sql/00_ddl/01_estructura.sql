/*
Proyecto: Gestión de Coworking
Grupo: 01
Módulo: DDL - Definición de Estructura de Base de Datos
Archivo: 01_estructura.sql

Descripción:
Creación de la base de datos coworking_db, tablas, claves primarias, claves foráneas,
restricciones e índices secundarios con prefijo idx_.

Requisitos:
Tener privilegios de administrador en MySQL.
*/

CREATE DATABASE IF NOT EXISTS coworking_db
CHARACTER SET utf8mb4
COLLATE utf8mb4_unicode_ci;

USE coworking_db;
