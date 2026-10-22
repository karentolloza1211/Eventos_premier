USE eventos_premier;

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
