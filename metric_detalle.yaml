pg_pi_cientifico_bbdd_detalle:
  query: |
    WITH latest_dates AS (
        SELECT
        table_name,
        MAX(fecha) AS max_fecha
    FROM
        cientifico_metrics_detalle
    GROUP BY
        table_name
    )
    SELECT
        a.id,
        a.datname,
        a.schema_name,
        a.table_name,
        a.constraint_fk,
        a.definicion,
        a.table_without_pk,
        a.trigger,
        a.all_varchar,
        a.num_clave_primaria,
        a.num_columns_in_table,
        a.column_name_pknonumerica,
        a.pk_mas_3_cols,
        a.column_name_varchar,
        a.db_schema_table
    FROM
        cientifico_metrics_detalle a
    JOIN
        latest_dates ld
    ON
        a.table_name = ld.table_name
        AND a.fecha = ld.max_fecha;

  metrics:
    - count:
        usage: "COUNTER"
        description: "Id"
    - datname:
        usage: "LABEL"
        description: "Base de datos"
    - schema_name:
        usage: "LABEL"
        description: "Esquema"
    - table_name:
        usage: "LABEL"
        description: "Tabla"
    - constraint_fk:
        usage: "LABEL"
        description: "Nombre de la FK"
    - definicion:
        usage: "LABEL"
        description: "FK explicados que faltan"
    - table_without_pk:
        usage: "LABEL"
        description: "Tablas sin indices"
    - trigger:
        usage: "LABEL"
        description: "Tablas con triggers"
    - all_varchar:
        usage: "LABEL"
        description: "Tablas con todas las columnas varchar"
    - num_clave_primaria:
        usage: "COUNTER"
        description: "0 es que no hay PK no numerica y 1 es que sí hay PK no numerica en la tabla "
    - column_name_pknonumerica:
        usage: "LABEL"
        description: "Nombre de la columna PK no numerica "
    - num_columns_in_table:
        usage: "COUNTER"
        description: "Recuento de columnas de cada tabla, mayor a 64 sale ko y por tanto la informacion que ponemos "
    - pk_mas_3_cols:
        usage: "LABEL"
        description: "PKs de cada tabla"
    - column_name_varchar:
        usage: "LABEL"
        description: "Nombre de la columna varchar "
    - db_schema_table:
        usage: "LABEL"
        description: "db y esquema y tabla "
