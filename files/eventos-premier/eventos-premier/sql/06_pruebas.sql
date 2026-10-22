USE eventos_premier;

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
