USE eventos_premier;

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
