-- =====================================================================
-- 01. CREAR BASE DE DATOS Y TABLAS
-- =====================================================================
DROP DATABASE IF EXISTS eventos_premier;

CREATE DATABASE eventos_premier
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE eventos_premier;

-- Tabla clientes (padre)
CREATE TABLE clientes (
    id_cliente      INT AUTO_INCREMENT PRIMARY KEY,
    nombre_completo VARCHAR(100) NOT NULL,
    identificacion  VARCHAR(20)  NOT NULL UNIQUE,
    telefono        VARCHAR(20)  NOT NULL,
    correo          VARCHAR(100) NOT NULL UNIQUE,
    tipo_cliente    ENUM('Individual','Corporativo') NOT NULL DEFAULT 'Individual'
) ENGINE=InnoDB;

-- Tabla salones (padre). "encargado" es VARCHAR: el enunciado solo pide el nombre.
CREATE TABLE salones (
    id_salon    INT AUTO_INCREMENT PRIMARY KEY,
    nombre      VARCHAR(80)   NOT NULL UNIQUE,
    capacidad   INT           NOT NULL,
    precio_hora DECIMAL(10,2) NOT NULL,
    estado      ENUM('Disponible','En mantenimiento','Ocupado')
                NOT NULL DEFAULT 'Disponible',
    encargado   VARCHAR(100)  NOT NULL,
    CONSTRAINT chk_salon_capacidad CHECK (capacidad > 0),
    CONSTRAINT chk_salon_precio    CHECK (precio_hora > 0)
) ENGINE=InnoDB;

-- Tabla reservas (hija de clientes y salones).
-- total_horas y valor_total los llena un trigger BEFORE INSERT.
CREATE TABLE reservas (
    id_reserva   INT AUTO_INCREMENT PRIMARY KEY,
    id_cliente   INT           NOT NULL,
    id_salon     INT           NOT NULL,
    fecha_inicio DATETIME      NOT NULL,
    fecha_fin    DATETIME      NOT NULL,
    total_horas  DECIMAL(6,2)  NULL,
    valor_total  DECIMAL(12,2) NULL,
    estado       ENUM('Confirmada','Cancelada') NOT NULL DEFAULT 'Confirmada',
    CONSTRAINT fk_reserva_cliente FOREIGN KEY (id_cliente)
        REFERENCES clientes(id_cliente)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_reserva_salon FOREIGN KEY (id_salon)
        REFERENCES salones(id_salon)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT chk_reserva_fechas CHECK (fecha_fin > fecha_inicio)
) ENGINE=InnoDB;

-- Tabla pagos (hija de reservas). Una reserva puede tener varios pagos.
CREATE TABLE pagos (
    id_pago      INT AUTO_INCREMENT PRIMARY KEY,
    id_reserva   INT           NOT NULL,
    fecha_pago   DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    monto_pagado DECIMAL(12,2) NOT NULL,
    metodo_pago  ENUM('Efectivo','Tarjeta','Transferencia') NOT NULL,
    CONSTRAINT fk_pago_reserva FOREIGN KEY (id_reserva)
        REFERENCES reservas(id_reserva)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT chk_pago_monto CHECK (monto_pagado > 0)
) ENGINE=InnoDB;

-- Tabla auditoria_precios (la llena el trigger de auditoría)
CREATE TABLE auditoria_precios (
    id_auditoria    INT AUTO_INCREMENT PRIMARY KEY,
    id_salon        INT           NOT NULL,
    usuario         VARCHAR(100)  NOT NULL,
    fecha_cambio    DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    precio_anterior DECIMAL(10,2) NOT NULL,
    precio_nuevo    DECIMAL(10,2) NOT NULL,
    CONSTRAINT fk_auditoria_salon FOREIGN KEY (id_salon)
        REFERENCES salones(id_salon)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;
