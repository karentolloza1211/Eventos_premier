USE eventos_premier;

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
