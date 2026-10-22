USE eventos_premier;

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
