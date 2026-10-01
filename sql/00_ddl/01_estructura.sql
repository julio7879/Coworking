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

-- 4. tipos_membresia

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

-- 5. membresias

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

-- 6. historial_membresias

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

-- 7. tipos_espacio

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

-- 8. espacios

CREATE TABLE espacios (
    id               INT           NOT NULL AUTO_INCREMENT,
    tipo_id          INT           NOT NULL,
    nombre           VARCHAR(80)   NOT NULL,
    ubicacion_fisica VARCHAR(150)  NOT NULL,
    capacidad_maxima INT           NOT NULL,
    tarifa_hora      DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    tarifa_mes       DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    estado           ENUM('Disponible','Mantenimiento','Inactivo') NOT NULL DEFAULT 'Disponible',
    PRIMARY KEY (id),
    UNIQUE KEY uq_espacios_nombre (nombre),
    CONSTRAINT fk_espacios_tipo FOREIGN KEY (tipo_id) REFERENCES tipos_espacio (id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT chk_espacios_capacidad   CHECK (capacidad_maxima > 0),
    CONSTRAINT chk_espacios_tarifa_hora CHECK (tarifa_hora >= 0),
    CONSTRAINT chk_espacios_tarifa_mes  CHECK (tarifa_mes >= 0)
) ENGINE=InnoDB;

-- 9. horarios_disponibilidad

CREATE TABLE horarios_disponibilidad (
    id            INT     NOT NULL AUTO_INCREMENT,
    espacio_id    INT     NULL,
    dia_semana    TINYINT NOT NULL,
    hora_apertura TIME    NOT NULL,
    hora_cierre   TIME    NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT fk_horarios_espacio FOREIGN KEY (espacio_id) REFERENCES espacios (id)
        ON DELETE CASCADE ON UPDATE RESTRICT,
    CONSTRAINT chk_horarios_dia   CHECK (dia_semana BETWEEN 1 AND 7),
    CONSTRAINT chk_horarios_rango CHECK (hora_cierre > hora_apertura)
) ENGINE=InnoDB;

-- 10. reservas

CREATE TABLE reservas (
    id               INT           NOT NULL AUTO_INCREMENT,
    usuario_id       INT           NOT NULL,
    espacio_id       INT           NOT NULL,
    modalidad        ENUM('Hora','Mes') NOT NULL,
    fecha_inicio     DATETIME      NOT NULL,
    fecha_fin        DATETIME      NOT NULL,
    num_personas     INT           NOT NULL DEFAULT 1,
    estado           ENUM('Pendiente','Confirmada','Cancelada','No_Show','Completada')
                     NOT NULL DEFAULT 'Pendiente',
    costo_total      DECIMAL(12,2) NOT NULL,
    creditos_usados  DECIMAL(6,2)  NOT NULL DEFAULT 0.00,
    monto_facturable DECIMAL(12,2) NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT fk_reservas_usuario FOREIGN KEY (usuario_id) REFERENCES usuarios (id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_reservas_espacio FOREIGN KEY (espacio_id) REFERENCES espacios (id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT chk_reservas_periodo     CHECK (fecha_fin > fecha_inicio),
    CONSTRAINT chk_reservas_personas    CHECK (num_personas > 0),
    CONSTRAINT chk_reservas_costo       CHECK (costo_total >= 0),
    CONSTRAINT chk_reservas_creditos    CHECK (creditos_usados >= 0),
    CONSTRAINT chk_reservas_facturable  CHECK (monto_facturable >= 0)
) ENGINE=InnoDB;

-- 11. servicios_adicionales

CREATE TABLE servicios_adicionales (
    id     INT           NOT NULL AUTO_INCREMENT,
    nombre VARCHAR(80)   NOT NULL,
    precio DECIMAL(12,2) NOT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uq_servicios_adicionales_nombre (nombre),
    CONSTRAINT chk_servicios_adicionales_precio CHECK (precio >= 0)
) ENGINE=InnoDB;

-- 12. metodos_pago

CREATE TABLE metodos_pago (
    id     INT         NOT NULL AUTO_INCREMENT,
    nombre VARCHAR(40) NOT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uq_metodos_pago_nombre (nombre)
) ENGINE=InnoDB;

-- 13. facturas

CREATE TABLE facturas (
    id                INT           NOT NULL AUTO_INCREMENT,
    usuario_id        INT           NULL,
    empresa_id        INT           NULL,
    reserva_id        INT           NULL,
    membresia_id      INT           NULL,
    tipo              ENUM('Membresia','Reserva','Servicio','Penalizacion','Consolidada') NOT NULL,
    monto_base        DECIMAL(12,2) NOT NULL,
    recargo_acumulado DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    ultimo_recargo    DATE          NULL,
    monto_total       DECIMAL(12,2) GENERATED ALWAYS AS (monto_base + recargo_acumulado) STORED,
    saldo_pendiente   DECIMAL(12,2) NOT NULL,
    estado            ENUM('Pendiente','Pagada','Cancelada','Anulada','Incobrable')
                      NOT NULL DEFAULT 'Pendiente',
    fecha_emision     DATE          NOT NULL DEFAULT (CURRENT_DATE),
    fecha_vencimiento DATE          NOT NULL,
    motivo_anulacion  VARCHAR(255)  NULL,
    PRIMARY KEY (id),
    CONSTRAINT fk_facturas_usuario    FOREIGN KEY (usuario_id)   REFERENCES usuarios (id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_facturas_empresa    FOREIGN KEY (empresa_id)   REFERENCES empresas (id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_facturas_reserva    FOREIGN KEY (reserva_id)   REFERENCES reservas (id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_facturas_membresia  FOREIGN KEY (membresia_id) REFERENCES membresias (id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT chk_facturas_saldo     CHECK (saldo_pendiente >= 0),
    CONSTRAINT chk_facturas_base      CHECK (monto_base >= 0),
    CONSTRAINT chk_facturas_recargo   CHECK (recargo_acumulado >= 0),
    CONSTRAINT chk_facturas_titular   CHECK (usuario_id IS NOT NULL OR empresa_id IS NOT NULL),
    CONSTRAINT chk_facturas_consolidada
        CHECK (tipo <> 'Consolidada' OR (usuario_id IS NULL AND empresa_id IS NOT NULL))
) ENGINE=InnoDB;

-- 14. factura_detalle

CREATE TABLE factura_detalle (
    id              INT           NOT NULL AUTO_INCREMENT,
    factura_id      INT           NOT NULL,
    concepto        VARCHAR(200)  NOT NULL,
    referencia_tipo VARCHAR(30)   NULL,
    referencia_id   INT           NULL,
    monto           DECIMAL(12,2) NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT fk_factura_detalle_factura FOREIGN KEY (factura_id) REFERENCES facturas (id)
        ON DELETE CASCADE ON UPDATE RESTRICT
) ENGINE=InnoDB;

-- 15. servicios_contratados

CREATE TABLE servicios_contratados (
    id              INT           NOT NULL AUTO_INCREMENT,
    usuario_id      INT           NOT NULL,
    reserva_id      INT           NULL,
    servicio_id     INT           NOT NULL,
    cantidad        INT           NOT NULL DEFAULT 1,
    precio_unitario DECIMAL(12,2) NOT NULL,
    factura_id      INT           NULL,
    PRIMARY KEY (id),
    CONSTRAINT fk_serv_contr_usuario  FOREIGN KEY (usuario_id)  REFERENCES usuarios (id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_serv_contr_reserva  FOREIGN KEY (reserva_id)  REFERENCES reservas (id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_serv_contr_servicio FOREIGN KEY (servicio_id) REFERENCES servicios_adicionales (id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_serv_contr_factura  FOREIGN KEY (factura_id)  REFERENCES facturas (id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT chk_serv_contr_cantidad CHECK (cantidad > 0),
    CONSTRAINT chk_serv_contr_precio   CHECK (precio_unitario >= 0)
) ENGINE=InnoDB;

-- 16. pagos

CREATE TABLE pagos (
    id             INT           NOT NULL AUTO_INCREMENT,
    factura_id     INT           NOT NULL,
    monto          DECIMAL(12,2) NOT NULL,
    fecha_pago     DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    metodo_pago_id INT           NOT NULL,
    referencia     VARCHAR(100)  NULL,
    estado         ENUM('Aplicado','Cancelado') NOT NULL DEFAULT 'Aplicado',
    PRIMARY KEY (id),
    CONSTRAINT fk_pagos_factura FOREIGN KEY (factura_id)     REFERENCES facturas (id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_pagos_metodo  FOREIGN KEY (metodo_pago_id) REFERENCES metodos_pago (id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT chk_pagos_monto CHECK (monto <> 0)
) ENGINE=InnoDB;

-- 17. accesos

CREATE TABLE accesos (
    id                 BIGINT       NOT NULL AUTO_INCREMENT,
    usuario_id         INT          NOT NULL,
    reserva_id         INT          NULL,
    fecha_hora_entrada DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_hora_salida  DATETIME     NULL,
    metodo_acceso      ENUM('RFID','QR','Manual') NOT NULL,
    estado_intento     ENUM('Permitido','Rechazado') NOT NULL DEFAULT 'Rechazado',
    motivo_rechazo     VARCHAR(150) NULL,
    PRIMARY KEY (id),
    CONSTRAINT fk_accesos_usuario FOREIGN KEY (usuario_id) REFERENCES usuarios (id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_accesos_reserva FOREIGN KEY (reserva_id) REFERENCES reservas (id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT chk_accesos_salida
        CHECK (fecha_hora_salida IS NULL OR fecha_hora_salida >= fecha_hora_entrada)
) ENGINE=InnoDB;

-- 18. asistencias

CREATE TABLE asistencias (
    id            BIGINT   NOT NULL AUTO_INCREMENT,
    acceso_id     BIGINT   NOT NULL,
    usuario_id    INT      NOT NULL,
    reserva_id    INT      NULL,
    tipo          ENUM('Edificio','Sala') NOT NULL,
    fecha_entrada DATETIME NOT NULL,
    fecha_salida  DATETIME NULL,
    minutos       INT      NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uq_asistencias_acceso (acceso_id),
    CONSTRAINT fk_asistencias_acceso  FOREIGN KEY (acceso_id)  REFERENCES accesos (id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_asistencias_usuario FOREIGN KEY (usuario_id) REFERENCES usuarios (id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_asistencias_reserva FOREIGN KEY (reserva_id) REFERENCES reservas (id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT chk_asistencias_salida  CHECK (fecha_salida IS NULL OR fecha_salida >= fecha_entrada),
    CONSTRAINT chk_asistencias_minutos CHECK (minutos IS NULL OR minutos >= 0),
    CONSTRAINT chk_asistencias_tipo_reserva
        CHECK ((tipo = 'Sala' AND reserva_id IS NOT NULL)
            OR (tipo = 'Edificio' AND reserva_id IS NULL))
) ENGINE=InnoDB;

-- 19. movimientos_credito

CREATE TABLE movimientos_credito (
    id           BIGINT       NOT NULL AUTO_INCREMENT,
    usuario_id   INT          NULL,
    membresia_id INT          NULL,
    empresa_id   INT          NULL,
    reserva_id   INT          NULL,
    creditos     DECIMAL(6,2) NOT NULL,
    tipo         ENUM('Reinicio','Consumo','Devolucion') NOT NULL,
    fecha        DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    CONSTRAINT fk_mov_credito_usuario   FOREIGN KEY (usuario_id)   REFERENCES usuarios (id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_mov_credito_membresia FOREIGN KEY (membresia_id) REFERENCES membresias (id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_mov_credito_empresa   FOREIGN KEY (empresa_id)   REFERENCES empresas (id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_mov_credito_reserva   FOREIGN KEY (reserva_id)   REFERENCES reservas (id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT chk_mov_credito_origen  CHECK (membresia_id IS NOT NULL OR empresa_id IS NOT NULL),
    CONSTRAINT chk_mov_credito_usuario CHECK (usuario_id IS NOT NULL OR tipo = 'Reinicio'),
    CONSTRAINT chk_mov_credito_signo
        CHECK ((tipo = 'Consumo'    AND creditos < 0)
            OR (tipo = 'Devolucion' AND creditos > 0)
            OR (tipo = 'Reinicio'   AND creditos >= 0))
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 20. cola_notificaciones
-- ---------------------------------------------------------------------
CREATE TABLE cola_notificaciones (
    id             BIGINT       NOT NULL AUTO_INCREMENT,
    tipo           VARCHAR(40)  NOT NULL,
    destinatario   VARCHAR(150) NOT NULL,
    contenido      TEXT         NOT NULL,
    estado         ENUM('Pendiente','Enviada','Error') NOT NULL DEFAULT 'Pendiente',
    fecha_creacion DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_envio    DATETIME     NULL,
    PRIMARY KEY (id)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 21. configuracion_sistema
-- ---------------------------------------------------------------------
CREATE TABLE configuracion_sistema (
    id    INT          NOT NULL AUTO_INCREMENT,
    clave VARCHAR(60)  NOT NULL,
    valor VARCHAR(255) NOT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uq_configuracion_clave (clave)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 22. logs_auditoria
-- ---------------------------------------------------------------------
CREATE TABLE logs_auditoria (
    id             BIGINT       NOT NULL AUTO_INCREMENT,
    accion         VARCHAR(100) NOT NULL,
    tabla_afectada VARCHAR(64)  NOT NULL,
    registro_id    BIGINT       NULL,
    fecha          DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 23. reportes_generados
-- ---------------------------------------------------------------------
CREATE TABLE reportes_generados (
    id               BIGINT      NOT NULL AUTO_INCREMENT,
    tipo             VARCHAR(60) NOT NULL,
    datos            JSON        NOT NULL,
    fecha_generacion DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id)
) ENGINE=InnoDB;


-- =====================================================================
-- SECCIÓN 2: ÍNDICES SECUNDARIOS (Prefijo idx_)
-- =====================================================================

-- usuarios
CREATE INDEX idx_usuarios_fecha_registro ON usuarios (fecha_registro);

-- membresias
CREATE INDEX idx_membresias_usuario_periodo ON membresias (usuario_id, fecha_inicio, fecha_fin);
CREATE INDEX idx_membresias_estado_fin      ON membresias (estado, fecha_fin);

-- historial_membresias
CREATE INDEX idx_hist_memb_usuario_fecha ON historial_membresias (usuario_id, fecha_cambio);

-- horarios_disponibilidad
CREATE INDEX idx_horarios_espacio_dia ON horarios_disponibilidad (espacio_id, dia_semana);

-- reservas
CREATE INDEX idx_reservas_espacio_periodo    ON reservas (espacio_id, fecha_inicio, fecha_fin);
CREATE INDEX idx_reservas_usuario_estado_fin ON reservas (usuario_id, estado, fecha_fin);
CREATE INDEX idx_reservas_estado_inicio      ON reservas (estado, fecha_inicio);

-- servicios_contratados
CREATE INDEX idx_serv_contr_usuario_servicio ON servicios_contratados (usuario_id, servicio_id);

-- facturas
CREATE INDEX idx_facturas_estado_vencimiento ON facturas (estado, fecha_vencimiento);
CREATE INDEX idx_facturas_usuario_estado     ON facturas (usuario_id, estado);
CREATE INDEX idx_facturas_empresa_tipo       ON facturas (empresa_id, tipo, fecha_emision);
CREATE INDEX idx_facturas_tipo_emision       ON facturas (tipo, fecha_emision);

-- pagos
CREATE INDEX idx_pagos_factura_estado ON pagos (factura_id, estado);
CREATE INDEX idx_pagos_fecha_estado   ON pagos (fecha_pago, estado);

-- accesos
CREATE INDEX idx_accesos_usuario_entrada ON accesos (usuario_id, fecha_hora_entrada);
CREATE INDEX idx_accesos_entrada         ON accesos (fecha_hora_entrada);
CREATE INDEX idx_accesos_sesion_abierta  ON accesos (usuario_id, estado_intento, fecha_hora_salida);

-- asistencias
CREATE INDEX idx_asistencias_usuario_tipo_entrada ON asistencias (usuario_id, tipo, fecha_entrada);
CREATE INDEX idx_asistencias_tipo_entrada         ON asistencias (tipo, fecha_entrada);

-- movimientos_credito
CREATE INDEX idx_mov_credito_membresia_fecha ON movimientos_credito (membresia_id, fecha);
CREATE INDEX idx_mov_credito_empresa_fecha   ON movimientos_credito (empresa_id, fecha);
CREATE INDEX idx_mov_credito_usuario_fecha   ON movimientos_credito (usuario_id, fecha);

-- cola_notificaciones, logs_auditoria, reportes_generados
CREATE INDEX idx_cola_estado_creacion ON cola_notificaciones (estado, fecha_creacion);
CREATE INDEX idx_logs_tabla_registro  ON logs_auditoria (tabla_afectada, registro_id);
CREATE INDEX idx_logs_fecha           ON logs_auditoria (fecha);
CREATE INDEX idx_reportes_tipo_fecha  ON reportes_generados (tipo, fecha_generacion);


-- =====================================================================
-- SECCIÓN 3: VISTAS DEL SISTEMA
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. v_estado_espacio
-- Estado en tiempo real del espacio:
--   - Ocupado: si tiene sesión de Sala abierta en asistencias.
--   - Reservado: si tiene reserva Confirmada en curso sin sesión abierta.
--   - Mantenimiento / Inactivo: según estado del espacio.
--   - Libre: en cualquier otro caso.
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW v_estado_espacio AS
SELECT
    e.id AS espacio_id,
    e.nombre AS espacio_nombre,
    te.nombre AS tipo_espacio,
    te.modo_ocupacion,
    e.capacidad_maxima,
    CASE
        WHEN e.estado IN ('Mantenimiento','Inactivo') THEN e.estado
        WHEN EXISTS (
            SELECT 1 FROM asistencias a
            JOIN reservas r ON a.reserva_id = r.id
            WHERE r.espacio_id = e.id
              AND a.tipo = 'Sala'
              AND a.fecha_salida IS NULL
        ) THEN 'Ocupado'
        WHEN EXISTS (
            SELECT 1 FROM reservas r
            WHERE r.espacio_id = e.id
              AND r.estado = 'Confirmada'
              AND NOW() BETWEEN r.fecha_inicio AND r.fecha_fin
        ) THEN 'Reservado'
        ELSE 'Libre'
    END AS estado_actual,
    (
        SELECT COUNT(*)
        FROM asistencias a
        JOIN reservas r ON a.reserva_id = r.id
        WHERE r.espacio_id = e.id
          AND a.tipo = 'Sala'
          AND a.fecha_salida IS NULL
    ) AS personas_presentes
FROM espacios e
JOIN tipos_espacio te ON e.tipo_id = te.id;

-- ---------------------------------------------------------------------
-- 2. v_usuarios_bloqueados
-- Usuarios con facturas vencidas más allá de 'dias_bloqueo' (10 días)
-- con saldo pendiente > 0.
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW v_usuarios_bloqueados AS
SELECT DISTINCT
    u.id AS usuario_id,
    CONCAT(u.nombre, ' ', u.apellidos) AS usuario_nombre,
    u.email,
    f.id AS factura_id,
    f.tipo AS factura_tipo,
    f.fecha_vencimiento,
    DATEDIFF(CURRENT_DATE, f.fecha_vencimiento) AS dias_mora,
    f.saldo_pendiente
FROM usuarios u
JOIN facturas f ON (f.usuario_id = u.id OR f.empresa_id = u.empresa_id)
WHERE f.saldo_pendiente > 0
  AND f.estado IN ('Pendiente', 'Incobrable')
  AND DATEDIFF(CURRENT_DATE, f.fecha_vencimiento) > (
      SELECT CAST(COALESCE(MAX(valor), '10') AS UNSIGNED)
      FROM configuracion_sistema
      WHERE clave = 'dias_bloqueo'
  );

-- ---------------------------------------------------------------------
-- 3. v_creditos_saldo
-- Saldo de créditos calculado desde el libro de movimientos:
--   - Membresía individual: suma total histórica de movimientos de esa membresía.
--   - Empresa (pool mensual): suma desde el día 1 del mes actual (regla 4).
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW v_creditos_saldo AS
SELECT
    'Membresia' AS origen,
    m.id AS origen_id,
    m.usuario_id,
    NULL AS empresa_id,
    COALESCE(SUM(mc.creditos), 0.00) AS saldo_creditos
FROM membresias m
LEFT JOIN movimientos_credito mc ON mc.membresia_id = m.id
GROUP BY m.id, m.usuario_id
UNION ALL
SELECT
    'Empresa' AS origen,
    e.id AS origen_id,
    NULL AS usuario_id,
    e.id AS empresa_id,
    COALESCE(SUM(mc.creditos), 0.00) AS saldo_creditos
FROM empresas e
LEFT JOIN movimientos_credito mc ON mc.empresa_id = e.id
    AND mc.fecha >= DATE_FORMAT(CURRENT_DATE, '%Y-%m-01 00:00:00')
GROUP BY e.id;

-- ---------------------------------------------------------------------
-- 4. v_mis_reservas
-- Reservas visibles para el usuario autenticado en la sesión de BD.
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW v_mis_reservas AS
SELECT
    r.id AS reserva_id,
    r.usuario_id,
    e.nombre AS espacio,
    r.modalidad,
    r.fecha_inicio,
    r.fecha_fin,
    r.num_personas,
    r.estado,
    r.costo_total,
    r.creditos_usados,
    r.monto_facturable
FROM reservas r
JOIN espacios e ON r.espacio_id = e.id
JOIN usuarios u ON r.usuario_id = u.id
WHERE u.usuario_bd = SUBSTRING_INDEX(USER(), '@', 1);

-- ---------------------------------------------------------------------
-- 5. v_mis_facturas
-- Facturas visibles para el usuario autenticado en la sesión de BD.
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW v_mis_facturas AS
SELECT
    f.id AS factura_id,
    f.usuario_id,
    f.tipo,
    f.monto_base,
    f.recargo_acumulado,
    f.monto_total,
    f.saldo_pendiente,
    f.estado,
    f.fecha_emision,
    f.fecha_vencimiento
FROM facturas f
JOIN usuarios u ON f.usuario_id = u.id
WHERE u.usuario_bd = SUBSTRING_INDEX(USER(), '@', 1);

-- ---------------------------------------------------------------------
-- 6. v_mis_accesos
-- Accesos y asistencias visibles para el usuario autenticado.
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW v_mis_accesos AS
SELECT
    a.id AS acceso_id,
    a.usuario_id,
    a.fecha_hora_entrada,
    a.fecha_hora_salida,
    a.metodo_acceso,
    a.estado_intento,
    a.motivo_rechazo,
    asi.tipo AS tipo_asistencia,
    asi.minutos
FROM accesos a
LEFT JOIN asistencias asi ON asi.acceso_id = a.id
JOIN usuarios u ON a.usuario_id = u.id
WHERE u.usuario_bd = SUBSTRING_INDEX(USER(), '@', 1);

-- ---------------------------------------------------------------------
-- 7. v_empresa_empleados
-- Empleados visibles para el gerente corporativo autenticado.
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW v_empresa_empleados AS
SELECT
    u.id AS empleado_id,
    CONCAT(u.nombre, ' ', u.apellidos) AS nombre_completo,
    u.email,
    u.telefono,
    u.activo,
    u.fecha_registro,
    m.id AS membresia_id,
    m.estado AS estado_membresia,
    m.fecha_fin AS vigencia_membresia
FROM usuarios u
JOIN usuarios g ON g.usuario_bd = SUBSTRING_INDEX(USER(), '@', 1)
LEFT JOIN membresias m ON m.usuario_id = u.id
    AND m.id = (
        SELECT m2.id FROM membresias m2
        WHERE m2.usuario_id = u.id
        ORDER BY m2.fecha_inicio DESC LIMIT 1
    )
WHERE u.empresa_id = g.empresa_id;

-- ---------------------------------------------------------------------
-- 8. v_empresa_facturas
-- Facturas de la empresa visibles para el gerente corporativo autenticado.
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW v_empresa_facturas AS
SELECT
    f.id AS factura_id,
    f.empresa_id,
    e.nombre AS empresa_nombre,
    f.tipo,
    f.monto_base,
    f.recargo_acumulado,
    f.monto_total,
    f.saldo_pendiente,
    f.estado,
    f.fecha_emision,
    f.fecha_vencimiento
FROM facturas f
JOIN empresas e ON f.empresa_id = e.id
JOIN usuarios g ON g.usuario_bd = SUBSTRING_INDEX(USER(), '@', 1)
WHERE f.empresa_id = g.empresa_id;

-- ---------------------------------------------------------------------
-- 9. v_empresa_creditos
-- Historial y movimientos del pool de créditos de la empresa.
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW v_empresa_creditos AS
SELECT
    mc.id AS movimiento_id,
    mc.empresa_id,
    e.nombre AS empresa_nombre,
    u.nombre AS usuario_nombre,
    mc.reserva_id,
    mc.creditos,
    mc.tipo,
    mc.fecha
FROM movimientos_credito mc
JOIN empresas e ON mc.empresa_id = e.id
LEFT JOIN usuarios u ON mc.usuario_id = u.id
JOIN usuarios g ON g.usuario_bd = SUBSTRING_INDEX(USER(), '@', 1)
WHERE mc.empresa_id = g.empresa_id;