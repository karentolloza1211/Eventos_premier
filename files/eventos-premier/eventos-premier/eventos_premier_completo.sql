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


-- =====================================================================
-- 02. FUNCIONES
-- =====================================================================
DELIMITER $$

-- Valor total con IVA del 19 %
DROP FUNCTION IF EXISTS calcular_total_reserva$$
CREATE FUNCTION calcular_total_reserva(
    p_precio_hora DECIMAL(10,2),
    p_horas       DECIMAL(6,2)
)
RETURNS DECIMAL(12,2)
DETERMINISTIC
BEGIN
    RETURN ROUND(p_precio_hora * p_horas * 1.19, 2);
END$$

-- Disponibilidad: 1 = libre, 0 = ocupado
-- Hay cruce si: inicio_nueva < fin_existente Y fin_nueva > inicio_existente
DROP FUNCTION IF EXISTS verificar_disponibilidad$$
CREATE FUNCTION verificar_disponibilidad(
    p_salon_id INT,
    p_inicio   DATETIME,
    p_fin      DATETIME
)
RETURNS TINYINT
READS SQL DATA
BEGIN
    DECLARE v_cruces INT;

    SELECT COUNT(*) INTO v_cruces
    FROM reservas
    WHERE id_salon = p_salon_id
      AND estado = 'Confirmada'
      AND p_inicio < fecha_fin
      AND p_fin    > fecha_inicio;

    IF v_cruces = 0 THEN
        RETURN 1;
    ELSE
        RETURN 0;
    END IF;
END$$

DELIMITER ;


-- =====================================================================
-- 03. TRIGGERS
-- Obligatorios: actualizar_estado_salon_trigger, liberar_salon_trigger,
--               auditoria_precios_trigger
-- Extras (míos): validar_cruce_reserva_trigger, calcular_reserva_trigger
-- =====================================================================
DELIMITER $$

-- EXTRA 1: rechaza reservas que se cruzan o de un salón en mantenimiento
DROP TRIGGER IF EXISTS validar_cruce_reserva_trigger$$
CREATE TRIGGER validar_cruce_reserva_trigger
BEFORE INSERT ON reservas
FOR EACH ROW
BEGIN
    DECLARE v_estado_salon VARCHAR(20);

    SELECT estado INTO v_estado_salon
    FROM salones WHERE id_salon = NEW.id_salon;

    IF v_estado_salon = 'En mantenimiento' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El salón está en mantenimiento y no se puede reservar';
    END IF;

    IF verificar_disponibilidad(NEW.id_salon, NEW.fecha_inicio, NEW.fecha_fin) = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El salón ya está reservado en ese horario';
    END IF;
END$$

-- EXTRA 2: calcula total_horas y valor_total automáticamente
DROP TRIGGER IF EXISTS calcular_reserva_trigger$$
CREATE TRIGGER calcular_reserva_trigger
BEFORE INSERT ON reservas
FOR EACH ROW
BEGIN
    DECLARE v_precio DECIMAL(10,2);

    SELECT precio_hora INTO v_precio
    FROM salones WHERE id_salon = NEW.id_salon;

    SET NEW.total_horas = TIMESTAMPDIFF(MINUTE, NEW.fecha_inicio, NEW.fecha_fin) / 60;
    SET NEW.valor_total = calcular_total_reserva(v_precio, NEW.total_horas);
END$$

-- OBLIGATORIO 1: al registrar una reserva, el salón pasa a "Ocupado"
DROP TRIGGER IF EXISTS actualizar_estado_salon_trigger$$
CREATE TRIGGER actualizar_estado_salon_trigger
AFTER INSERT ON reservas
FOR EACH ROW
BEGIN
    UPDATE salones
    SET estado = 'Ocupado'
    WHERE id_salon = NEW.id_salon
      AND estado = 'Disponible';
END$$

-- OBLIGATORIO 2: al eliminar una reserva, el salón vuelve a "Disponible"
-- Versión segura: solo si estaba 'Ocupado' y ya no le quedan reservas.
DROP TRIGGER IF EXISTS liberar_salon_trigger$$
CREATE TRIGGER liberar_salon_trigger
AFTER DELETE ON reservas
FOR EACH ROW
BEGIN
    DECLARE v_restantes INT;

    SELECT COUNT(*) INTO v_restantes
    FROM reservas
    WHERE id_salon = OLD.id_salon;

    IF v_restantes = 0 THEN
        UPDATE salones
        SET estado = 'Disponible'
        WHERE id_salon = OLD.id_salon
          AND estado = 'Ocupado';
    END IF;
END$$

-- OBLIGATORIO 3: auditoría de cambios de precio por hora
DROP TRIGGER IF EXISTS auditoria_precios_trigger$$
CREATE TRIGGER auditoria_precios_trigger
AFTER UPDATE ON salones
FOR EACH ROW
BEGIN
    IF OLD.precio_hora <> NEW.precio_hora THEN
        INSERT INTO auditoria_precios
            (id_salon, usuario, fecha_cambio, precio_anterior, precio_nuevo)
        VALUES
            (OLD.id_salon, USER(), NOW(), OLD.precio_hora, NEW.precio_hora);
    END IF;
END$$

DELIMITER ;


-- =====================================================================
-- 04. DATOS DE PRUEBA
-- Orden: clientes -> salones -> reservas -> pagos
-- (los triggers calculan horas/valor y cambian el estado de los salones)
-- =====================================================================

-- Clientes: 8 (3 corporativos)
INSERT INTO clientes (nombre_completo, identificacion, telefono, correo, tipo_cliente) VALUES
('Andrea Camila Torres Rojas',  '1098123456',   '3001234567', 'andrea.torres@correo.com',   'Individual'),   -- 1
('Luis Fernando Mora Pérez',    '1098234567',   '3012345678', 'luis.mora@correo.com',       'Individual'),   -- 2
('Tecnosoft S.A.S.',            '900123456-1',  '6076800001', 'eventos@tecnosoft.com',      'Corporativo'),  -- 3
('Distribuidora Andina Ltda.',  '900234567-2',  '6076800002', 'compras@andina.com',         'Corporativo'),  -- 4
('Sofía Valentina Díaz Ortiz',  '1098345678',   '3023456789', 'sofia.diaz@correo.com',      'Individual'),   -- 5
('Carlos Eduardo Rincón Vega',  '1098456789',   '3034567890', 'carlos.rincon@correo.com',   'Individual'),   -- 6
('Fundación Horizonte',         '900345678-3',  '6076800003', 'contacto@horizonte.org',     'Corporativo'),  -- 7
('María José Pardo Suárez',     '1098567890',   '3045678901', 'maria.pardo@correo.com',     'Individual');   -- 8

-- Salones: 7 (uno en mantenimiento)
INSERT INTO salones (nombre, capacidad, precio_hora, estado, encargado) VALUES
('Salón Esmeralda',  80,  150000.00, 'Disponible',       'Laura Gómez'),      -- 1
('Salón Zafiro',     150, 280000.00, 'Disponible',       'Carlos Ruiz'),      -- 2
('Salón Diamante',   300, 450000.00, 'Disponible',       'Marta Pineda'),     -- 3
('Salón Rubí',       40,   90000.00, 'Disponible',       'Andrés Salazar'),   -- 4
('Salón Ámbar',      60,  120000.00, 'Disponible',       'Laura Gómez'),      -- 5
('Salón Perla',      25,   70000.00, 'En mantenimiento', 'Julián Herrera'),   -- 6
('Salón Cristal',    200, 350000.00, 'Disponible',       'Marta Pineda');     -- 7

-- Reservas: 12 sin cruces. Tecnosoft (3) y Andina (4) tienen 4 cada una
INSERT INTO reservas (id_cliente, id_salon, fecha_inicio, fecha_fin, estado) VALUES
(3, 3, '2026-11-03 08:00:00', '2026-11-03 12:00:00', 'Confirmada'),  -- R1
(3, 3, '2026-11-10 08:00:00', '2026-11-10 13:00:00', 'Confirmada'),  -- R2
(3, 2, '2026-11-17 14:00:00', '2026-11-17 18:00:00', 'Confirmada'),  -- R3
(3, 2, '2026-11-24 09:00:00', '2026-11-24 12:30:00', 'Confirmada'),  -- R4
(4, 2, '2026-11-05 09:00:00', '2026-11-05 13:00:00', 'Confirmada'),  -- R5
(4, 2, '2026-11-12 09:00:00', '2026-11-12 17:00:00', 'Confirmada'),  -- R6
(4, 1, '2026-11-19 10:00:00', '2026-11-19 14:00:00', 'Confirmada'),  -- R7
(4, 1, '2026-11-26 10:00:00', '2026-11-26 15:00:00', 'Confirmada'),  -- R8
(1, 4, '2026-11-14 18:00:00', '2026-11-14 23:00:00', 'Confirmada'),  -- R9
(2, 5, '2026-11-21 19:00:00', '2026-11-21 23:00:00', 'Confirmada'),  -- R10
(5, 4, '2026-12-05 18:00:00', '2026-12-05 22:00:00', 'Confirmada'),  -- R11
(6, 5, '2026-12-12 15:00:00', '2026-12-12 19:00:00', 'Cancelada');   -- R12

-- Pagos: 10 (los 3 métodos)
INSERT INTO pagos (id_reserva, fecha_pago, monto_pagado, metodo_pago) VALUES
(1,  '2026-10-28 10:15:00', 2142000.00, 'Transferencia'),
(2,  '2026-11-01 09:30:00', 1000000.00, 'Transferencia'),
(3,  '2026-11-10 11:00:00', 1332800.00, 'Transferencia'),
(5,  '2026-10-30 14:20:00',  666400.00, 'Tarjeta'),
(5,  '2026-11-05 08:45:00',  666400.00, 'Tarjeta'),
(6,  '2026-11-01 16:00:00', 1000000.00, 'Transferencia'),
(7,  '2026-11-18 10:10:00',  714000.00, 'Tarjeta'),
(9,  '2026-11-10 17:30:00',  535500.00, 'Efectivo'),
(10, '2026-11-15 12:00:00',  300000.00, 'Efectivo'),
(11, '2026-11-28 15:40:00',  428400.00, 'Tarjeta');


-- =====================================================================
-- 05. VISTA Y CONSULTAS
-- =====================================================================

-- Vista obligatoria
CREATE OR REPLACE VIEW vista_resumen_reservas AS
SELECT r.id_reserva,
       c.nombre_completo AS cliente,
       s.nombre          AS salon,
       r.fecha_inicio,
       r.fecha_fin,
       r.valor_total     AS total,
       r.estado
FROM reservas r
INNER JOIN clientes c ON c.id_cliente = r.id_cliente
INNER JOIN salones  s ON s.id_salon   = r.id_salon;

SELECT * FROM vista_resumen_reservas ORDER BY id_reserva;        -- 12 filas

-- C1. Reservas en un rango de fechas (BETWEEN)  -> 5 filas (R1, R2, R5, R6, R9)
SELECT id_reserva, id_cliente, id_salon, fecha_inicio, fecha_fin
FROM reservas
WHERE fecha_inicio BETWEEN '2026-11-01 00:00:00' AND '2026-11-15 23:59:59'
ORDER BY fecha_inicio;

-- C2. Salones con capacidad > 100 y Disponible  -> Salón Cristal
SELECT id_salon, nombre, capacidad, precio_hora
FROM salones
WHERE capacidad > 100 AND estado = 'Disponible';

-- C3a. Corporativos con más de 3 reservas (COUNT + HAVING) -> Tecnosoft y Andina
SELECT c.nombre_completo, COUNT(r.id_reserva) AS total_reservas
FROM clientes c
INNER JOIN reservas r ON r.id_cliente = c.id_cliente
WHERE c.tipo_cliente = 'Corporativo'
GROUP BY c.id_cliente, c.nombre_completo
HAVING COUNT(r.id_reserva) > 3;

-- C3b. Lo mismo con subconsulta
SELECT nombre_completo
FROM clientes
WHERE tipo_cliente = 'Corporativo'
  AND (SELECT COUNT(*) FROM reservas r WHERE r.id_cliente = clientes.id_cliente) > 3;

-- P1. Todos los clientes
SELECT * FROM clientes;

-- P2. Salones sin reservas (LEFT JOIN) -> Perla y Cristal
SELECT s.id_salon, s.nombre, s.estado
FROM salones s
LEFT JOIN reservas r ON r.id_salon = s.id_salon
WHERE r.id_reserva IS NULL;

-- P3. Reservas por salón (COUNT)
SELECT s.nombre, COUNT(r.id_reserva) AS num_reservas
FROM salones s
LEFT JOIN reservas r ON r.id_salon = s.id_salon
GROUP BY s.id_salon, s.nombre
ORDER BY num_reservas DESC, s.nombre;

-- P4. Total pagado por reserva
SELECT r.id_reserva, r.valor_total,
       IFNULL(SUM(p.monto_pagado), 0) AS total_pagado
FROM reservas r
LEFT JOIN pagos p ON p.id_reserva = r.id_reserva
GROUP BY r.id_reserva, r.valor_total
ORDER BY r.id_reserva;

-- P5. Saldo pendiente por reserva
SELECT r.id_reserva, r.valor_total,
       IFNULL(SUM(p.monto_pagado), 0)                 AS total_pagado,
       r.valor_total - IFNULL(SUM(p.monto_pagado), 0) AS saldo_pendiente
FROM reservas r
LEFT JOIN pagos p ON p.id_reserva = r.id_reserva
GROUP BY r.id_reserva, r.valor_total
ORDER BY r.id_reserva;

-- P6. Filtro por estado -> reserva 12
SELECT * FROM vista_resumen_reservas WHERE estado = 'Cancelada';

-- P7. UPDATE de una reserva (WHERE por llave primaria: evita el error 1175)
UPDATE reservas SET estado = 'Cancelada' WHERE id_reserva = 8;
SELECT id_reserva, estado FROM reservas WHERE id_reserva = 8;
UPDATE reservas SET estado = 'Confirmada' WHERE id_reserva = 8;   -- se revierte


-- =====================================================================
-- 06. PRUEBAS DE FUNCIONES Y TRIGGERS
-- =====================================================================

-- 6.1 Funciones
SELECT calcular_total_reserva(100000, 3) AS total_con_iva;                                   -- 357000.00
SELECT verificar_disponibilidad(3, '2026-11-03 10:00:00', '2026-11-03 11:00:00') AS cruza;   -- 0
SELECT verificar_disponibilidad(3, '2026-11-03 12:00:00', '2026-11-03 14:00:00') AS justo_despues; -- 1
SELECT verificar_disponibilidad(7, '2026-12-18 09:00:00', '2026-12-18 12:00:00') AS libre;   -- 1

-- 6.2 Reserva válida: cálculo automático y salón pasa a Ocupado
SELECT id_salon, estado FROM salones WHERE id_salon = 7;          -- Disponible

INSERT INTO reservas (id_cliente, id_salon, fecha_inicio, fecha_fin)
VALUES (7, 7, '2026-12-18 09:00:00', '2026-12-18 12:00:00');
SET @id_a = LAST_INSERT_ID();

SELECT id_reserva, total_horas, valor_total, estado
FROM reservas WHERE id_reserva = @id_a;                           -- 3.00 | 1249500.00 | Confirmada

SELECT id_salon, estado FROM salones WHERE id_salon = 7;          -- Ocupado

-- 6.3 Liberar salón (versión segura)
INSERT INTO reservas (id_cliente, id_salon, fecha_inicio, fecha_fin)
VALUES (7, 7, '2026-12-19 09:00:00', '2026-12-19 12:00:00');
SET @id_b = LAST_INSERT_ID();

DELETE FROM reservas WHERE id_reserva = @id_a;
SELECT id_salon, estado FROM salones WHERE id_salon = 7;          -- Ocupado (aún queda otra reserva)

DELETE FROM reservas WHERE id_reserva = @id_b;
SELECT id_salon, estado FROM salones WHERE id_salon = 7;          -- Disponible

-- 6.4 Auditoría de precios
UPDATE salones SET precio_hora = 95000 WHERE id_salon = 4;
SELECT id_salon, usuario, fecha_cambio, precio_anterior, precio_nuevo
FROM auditoria_precios;                                           -- 90000.00 -> 95000.00

UPDATE salones SET precio_hora = 90000 WHERE id_salon = 4;        -- se revierte (queda 2.ª fila de auditoría)

-- 6.5 Resumen final
SELECT COUNT(*) AS total_reservas FROM reservas;                  -- 12
SELECT id_salon, nombre, estado FROM salones ORDER BY id_salon;

-- 6.6 PRUEBAS QUE DEBEN FALLAR
-- Están comentadas para que el script completo no se detenga.
-- Para probarlas: quita los "-- " de UNA, selecciónala y pulsa Ctrl+Enter.

-- 6a. Cruce con la reserva 1 (Diamante, 3-nov, 08:00-12:00)
-- Esperado: Error 1644 "El salón ya está reservado en ese horario"
-- INSERT INTO reservas (id_cliente, id_salon, fecha_inicio, fecha_fin)
-- VALUES (1, 3, '2026-11-03 10:00:00', '2026-11-03 14:00:00');

-- 6b. Reserva en salón en mantenimiento (Perla)
-- Esperado: Error 1644 "El salón está en mantenimiento y no se puede reservar"
-- INSERT INTO reservas (id_cliente, id_salon, fecha_inicio, fecha_fin)
-- VALUES (1, 6, '2026-12-20 09:00:00', '2026-12-20 11:00:00');

-- =====================================================================
-- VERIFICACIÓN DE OBJETOS CREADOS (opcional)
-- =====================================================================
-- SHOW TABLES;
-- SHOW FUNCTION STATUS WHERE Db = 'eventos_premier';   -- 2 funciones
-- SHOW TRIGGERS FROM eventos_premier;                  -- 5 triggers
-- SHOW CREATE VIEW vista_resumen_reservas;
-- SELECT TABLE_NAME, COLUMN_NAME, REFERENCED_TABLE_NAME, REFERENCED_COLUMN_NAME
-- FROM information_schema.KEY_COLUMN_USAGE
-- WHERE TABLE_SCHEMA = 'eventos_premier' AND REFERENCED_TABLE_NAME IS NOT NULL;  -- 4 FK
