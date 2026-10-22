# Eventos Premier S.A.S. – Base de datos de reservas de salones

## Descripción

Eventos Premier S.A.S. alquila salones para reuniones, fiestas y conferencias. Este proyecto es la base de datos en **MySQL** del sistema de reservas: permite gestionar salones, clientes, reservas y pagos, garantizar la disponibilidad de los salones y generar informes de uso e ingresos.

Incluye:

- 5 tablas con llaves primarias, llaves foráneas y restricciones.
- 2 funciones personalizadas.
- 3 triggers obligatorios y 2 triggers adicionales.
- 1 vista y consultas de ejemplo.
- Datos de prueba y un script de pruebas.

## Requisitos

- **MySQL 8.0.16 o superior** (desde esa versión las restricciones `CHECK` se aplican; en versiones anteriores se ignoran).
- **MySQL Workbench** (o cualquier cliente MySQL).
- Para comprobar tu versión:

```sql
SELECT VERSION();
```

## Instrucciones de ejecución

Hay dos formas de ejecutar el proyecto. Las dos dan el mismo resultado.

### Opción rápida: un solo archivo

Ejecuta `eventos_premier_completo.sql`, que contiene los scripts 01 a 06 en orden:

1. Abre MySQL Workbench y conéctate a tu servidor local.
2. **File → Open SQL Script...** y selecciona `eventos_premier_completo.sql`.
3. Pulsa el rayo (⚡) o `Ctrl+Shift+Enter` sin seleccionar nada.
4. Revisa que el panel **Output** muestre todo en verde.

### Opción por scripts: paso a paso

1. Abre MySQL Workbench y conéctate a tu servidor local.
2. Para cada archivo de la carpeta `sql/`: **File → Open SQL Script...**, y ejecútalo con el rayo (⚡) o `Ctrl+Shift+Enter` sin seleccionar nada.
3. Ejecuta los scripts **en este orden**:

| Orden | Script | Qué hace |
|---|---|---|
| 1 | `sql/01_crear_bd_y_tablas.sql` | Crea la base `eventos_premier` y las 5 tablas |
| 2 | `sql/02_funciones.sql` | Crea las 2 funciones |
| 3 | `sql/03_triggers.sql` | Crea los 5 triggers |
| 4 | `sql/04_datos_prueba.sql` | Inserta clientes, salones, reservas y pagos |
| 5 | `sql/05_vistas_y_consultas.sql` | Crea la vista y ejecuta las consultas |
| 6 | `sql/06_pruebas.sql` | Demuestra el funcionamiento de funciones y triggers |

> **Atención:** el script 01 empieza con `DROP DATABASE IF EXISTS eventos_premier`, por lo que borra y recrea la base de datos. Así se puede repetir todo el proceso desde cero.

4. Verifica que todo se creó:

```sql
USE eventos_premier;
SHOW TABLES;                                          -- 5 tablas y 1 vista
SHOW FUNCTION STATUS WHERE Db = 'eventos_premier';    -- 2 funciones
SHOW TRIGGERS FROM eventos_premier;                   -- 5 triggers
```

## Modelo de datos

Tablas: `clientes`, `salones`, `reservas`, `pagos` y `auditoria_precios`.

- Un cliente puede tener muchas reservas (1:N).
- Un salón puede tener muchas reservas (1:N).
- Una reserva puede tener muchos pagos (1:N).
- Un salón puede tener muchos registros de auditoría de precios (1:N).

Diagrama entidad-relación: [`docs/diagrama_er.md`](docs/diagrama_er.md).

### Decisiones de diseño

- **Dinero en `DECIMAL`**, nunca `FLOAT`, para evitar errores de redondeo.
- **`encargado` es un `VARCHAR` en `salones`**: el enunciado solo pide el nombre del responsable, por lo que no se creó una tabla de empleados.
- **Estado del salón** como `ENUM('Disponible','En mantenimiento','Ocupado')`, porque el trigger exige el estado "Ocupado".
- **Estado de la reserva** (`Confirmada` / `Cancelada`): columna agregada para poder mostrarla en la vista de resumen.
- **`total_horas` y `valor_total`** se calculan automáticamente con un trigger al insertar la reserva.
- **Llaves foráneas con `ON DELETE RESTRICT`**: no se puede borrar un cliente o salón que tenga reservas, ni una reserva que tenga pagos.

### Normalización

- **1FN:** todas las columnas guardan un solo valor; los pagos están en su propia tabla, no en columnas repetidas.
- **2FN:** todas las tablas tienen llave primaria de una sola columna, sin dependencias parciales.
- **3FN:** los atributos dependen solo de la llave de su tabla (por ejemplo, el precio por hora vive en `salones`, no en `reservas`).
- **Excepciones conscientes:** `total_horas` y `valor_total` son datos derivados que el enunciado pide guardar (y conservan el valor vigente al momento de reservar), y `encargado` se repite como texto entre salones.

## Funciones

### `calcular_total_reserva(precio_hora, horas)`

Retorna el valor total con IVA del 19 %.

```sql
SELECT calcular_total_reserva(100000, 3) AS total_con_iva;
-- Resultado: 357000.00
```

### `verificar_disponibilidad(salon_id, fecha_inicio, fecha_fin)`

Retorna `1` si el salón está disponible y `0` si está ocupado. Hay cruce cuando `inicio_nueva < fin_existente AND fin_nueva > inicio_existente`.

```sql
SELECT verificar_disponibilidad(3, '2026-11-03 10:00:00', '2026-11-03 11:00:00');
-- Resultado: 0 (el salón Diamante ya está reservado de 08:00 a 12:00)

SELECT verificar_disponibilidad(3, '2026-11-03 12:00:00', '2026-11-03 14:00:00');
-- Resultado: 1 (empieza justo cuando termina la otra reserva)
```

## Triggers

| Trigger | Evento | Qué hace |
|---|---|---|
| `actualizar_estado_salon_trigger` | `AFTER INSERT` en `reservas` | El salón pasa a "Ocupado" |
| `liberar_salon_trigger` | `AFTER DELETE` en `reservas` | El salón vuelve a "Disponible" (solo si estaba "Ocupado" y no le quedan otras reservas) |
| `auditoria_precios_trigger` | `AFTER UPDATE` en `salones` | Registra usuario, fecha y precio anterior/nuevo en `auditoria_precios` |
| `calcular_reserva_trigger` *(extra)* | `BEFORE INSERT` en `reservas` | Calcula `total_horas` y `valor_total` |
| `validar_cruce_reserva_trigger` *(extra)* | `BEFORE INSERT` en `reservas` | Rechaza reservas que se cruzan o de salones en mantenimiento, con `SIGNAL SQLSTATE '45000'` |

### Ejemplos

Reserva válida (los triggers calculan horas y valor, y el salón pasa a "Ocupado"):

```sql
INSERT INTO reservas (id_cliente, id_salon, fecha_inicio, fecha_fin)
VALUES (7, 7, '2026-12-18 09:00:00', '2026-12-18 12:00:00');

SELECT total_horas, valor_total, estado FROM reservas WHERE id_reserva = LAST_INSERT_ID();
-- 3.00 | 1249500.00 | Confirmada
```

Reserva que se cruza (debe fallar):

```sql
INSERT INTO reservas (id_cliente, id_salon, fecha_inicio, fecha_fin)
VALUES (1, 3, '2026-11-03 10:00:00', '2026-11-03 14:00:00');
-- Error 1644: El salón ya está reservado en ese horario
```

Auditoría de precios:

```sql
UPDATE salones SET precio_hora = 95000 WHERE id_salon = 4;
SELECT usuario, precio_anterior, precio_nuevo FROM auditoria_precios;
-- root@localhost | 90000.00 | 95000.00
```

## Consultas de ejemplo

Reservas en un rango de fechas (`BETWEEN`):

```sql
SELECT id_reserva, id_cliente, id_salon, fecha_inicio, fecha_fin
FROM reservas
WHERE fecha_inicio BETWEEN '2026-11-01 00:00:00' AND '2026-11-15 23:59:59';
-- 5 filas: reservas 1, 2, 5, 6 y 9
```

Salones con capacidad mayor a 100 y disponibles:

```sql
SELECT id_salon, nombre, capacidad FROM salones
WHERE capacidad > 100 AND estado = 'Disponible';
-- Salón Cristal (200)
```

Clientes corporativos con más de 3 reservas:

```sql
SELECT c.nombre_completo, COUNT(r.id_reserva) AS total_reservas
FROM clientes c
INNER JOIN reservas r ON r.id_cliente = c.id_cliente
WHERE c.tipo_cliente = 'Corporativo'
GROUP BY c.id_cliente, c.nombre_completo
HAVING COUNT(r.id_reserva) > 3;
-- Tecnosoft S.A.S. (4) y Distribuidora Andina Ltda. (4)
```

Vista de resumen:

```sql
SELECT * FROM vista_resumen_reservas;
-- 12 filas: cliente, salón, fecha de inicio, fecha de fin, total y estado
```

El resto de consultas (clientes, salones sin reservas, reservas por salón, total pagado, saldo pendiente, filtro por estado y `UPDATE`) están en `sql/05_vistas_y_consultas.sql`.

## Estructura del repositorio

```
eventos-premier/
├── README.md
├── eventos_premier_completo.sql      (todo el proyecto en un solo archivo)
├── sql/
│   ├── 01_crear_bd_y_tablas.sql
│   ├── 02_funciones.sql
│   ├── 03_triggers.sql
│   ├── 04_datos_prueba.sql
│   ├── 05_vistas_y_consultas.sql
│   └── 06_pruebas.sql
└── docs/
    └── diagrama_er.md
```

- `eventos_premier_completo.sql` reúne los scripts 01 a 06 para ejecutar todo de una sola vez.
- La carpeta `sql/` tiene los mismos scripts separados y numerados, uno por cada entregable.

## Créditos y autor

Proyecto académico desarrollado por **[MI NOMBRE]**.
