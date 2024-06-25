datnames=$(psql -At -c "SELECT datname FROM pg_database WHERE datname NOT IN ('postgres', 'template0', 'template1')")

recovery=$(psql -At -c "select pg_is_in_recovery();")
if [ "$recovery" = "t" ]; then
    exit 0
else

for current_db in $datnames; do
    schema_names=$(psql -d "$current_db" -At -c "
        SELECT schema_name
        FROM information_schema.schemata
        WHERE schema_name NOT LIKE 'pg\\_%' AND schema_name NOT IN ('public', 'information_schema');")

    for schema_name in $schema_names; do
        table_names=$(psql -d "$current_db" -At -c "
            SELECT tab.table_name
            FROM information_schema.tables tab
            LEFT JOIN information_schema.table_constraints tco
                ON tab.table_schema = tco.table_schema
                AND tab.table_name = tco.table_name
                AND tco.constraint_type = 'PRIMARY KEY'
            WHERE tab.table_schema='$schema_name'
                AND tab.table_type = 'BASE TABLE';")

        for table_name in $table_names; do

            constraint_pk=$(psql -d "$current_db" -At -c "
                SELECT conname
                FROM pg_constraint
                WHERE conrelid = '\"$schema_name\".\"$table_name\"'::regclass AND contype = 'p';")

            if [ -z "$constraint_pk" ]; then
                table_without_pk="true"
            else
                table_without_pk="false"
            fi

            trigger_names=$(psql -d "$current_db" -At -c "
                SELECT trigger_name
                FROM information_schema.triggers
                WHERE event_object_table = '$table_name' AND trigger_schema = '$schema_name';")

            if [ -z "$trigger_names" ]; then
                trigger_names="false"
            fi

            column_count_64=$(psql -d "$current_db" -At -c "
                SELECT COUNT(*)
                FROM information_schema.columns
                WHERE table_schema = '$schema_name'
                  AND table_name = '$table_name';")

            same_count=$(psql -d "$current_db" -At -c "
            WITH total_columns AS (
                SELECT COUNT(column_name) AS total_columns
                FROM information_schema.columns
                WHERE table_name = '$table_name'
            ),
            varchar_columns AS (
                SELECT COUNT(column_name) AS varchar_columns
                FROM information_schema.columns
                WHERE table_name = '$table_name'
                AND data_type = 'character varying'
            )
            SELECT
                CASE
                    WHEN total_columns = varchar_columns THEN 1
                    ELSE 0
                END AS same_count
            FROM total_columns, varchar_columns;")

            if [ "$same_count" -eq 1 ]; then
                column_names=$(psql -d "$current_db" -At -c "
                    SELECT string_agg(column_name, ',')
                    FROM information_schema.columns
                    WHERE table_name = '$table_name'
                    AND data_type = 'character varying';")
                varchar_columns="$column_names"
            else
                varchar_columns="NOallVarchar"
            fi

            pk_non_numeric_count=$(psql -d "$current_db" -At -c "
                SELECT COUNT(*)
                FROM pg_constraint
                INNER JOIN pg_class ON pg_constraint.conrelid = pg_class.oid
                INNER JOIN pg_namespace ON pg_class.relnamespace = pg_namespace.oid
                INNER JOIN pg_attribute ON pg_constraint.conkey[1] = pg_attribute.attnum AND pg_constraint.conrelid = pg_attribute.attrelid
                INNER JOIN pg_type ON pg_attribute.atttypid = pg_type.oid
                WHERE pg_class.relname = '$table_name'
                    AND pg_namespace.nspname = '$schema_name'
                    AND pg_type.typcategory <> 'N'
                    AND pg_constraint.contype = 'p'
                    AND array_length(pg_constraint.conkey, 1) = 1;")

            if [[ $pk_non_numeric_count -eq 1 ]]; then
                pk_column_info=$(psql -d "$current_db" -At -c "
                    SELECT a.attname AS column_name, t.typname AS data_type
                    FROM pg_index i
                    JOIN pg_attribute a ON a.attrelid = i.indrelid AND a.attnum = ANY(i.indkey)
                    JOIN pg_type t ON a.atttypid = t.oid
                    WHERE i.indrelid = '$schema_name.$table_name'::regclass
                    AND i.indisprimary
                    AND array_length(i.indkey, 1) = 1
                    AND t.typcategory <> 'N';")

                pk_column_name=$(echo $pk_column_info | cut -d '|' -f 1)
            elif [[ $pk_non_numeric_count -eq 0 ]]; then
                pk_column_name="NOpkNONUM"
            fi

            pk_mas_3_cols=$(psql -d "$current_db" -At -c "
                SELECT
                    pg_namespace.nspname                      AS Esquema,
                    pg_class.relname                          AS Tabla,
                    pg_get_constraintdef(pg_constraint.oid)   AS Definición,
                    array_length(conkey, 1)                   AS \"Número de columnas\"
                FROM
                    pg_constraint
                    INNER JOIN pg_class ON pg_constraint.conrelid = pg_class.oid
                    INNER JOIN pg_namespace ON pg_constraint.connamespace = pg_namespace.oid
                    INNER JOIN pg_class index ON pg_constraint.conindid = index.oid
                WHERE
                    pg_namespace.nspname NOT IN ('pg_catalog', 'information_schema', 'pg_toast', 'ggobjects')
                    AND contype = 'p'
                    AND array_length(conkey, 1) > 3
                    AND pg_class.relispartition = 'f'
                    AND pg_class.relname = '$table_name'
                ORDER BY
                    array_length(conkey, 1) DESC;")

            if [ -n "$pk_mas_3_cols" ]; then
                pk_value="$pk_mas_3_cols"
            else
                pk_value="PKisOK"
            fi

            fks=$(psql -d "$current_db" -At -c "
                SELECT
                    conname,
                    CASE WHEN indexrelid IS NOT NULL THEN 'OK' ELSE pg_get_constraintdef(pg_constraint.oid) END AS Definicion
                FROM
                    pg_class
                    INNER JOIN
                    pg_constraint ON pg_class.oid = conrelid
                    LEFT JOIN
                    pg_index ON
                        conrelid = indrelid
                        AND conkey = ARRAY(SELECT * FROM unnest(indkey))
                    INNER JOIN
                    pg_namespace ON pg_class.relnamespace = pg_namespace.oid
                WHERE
                    contype = 'f'
                    AND relnamespace NOT IN (
                        'pg_catalog'::regnamespace,
                        'information_schema'::regnamespace,
                        'pg_toast'::regnamespace)
                    AND pg_class.relname = '$table_name'
                    AND pg_namespace.nspname = '$schema_name'")

            if [[ -n "$fks" ]]; then
                while IFS='|' read -r constraint_fk definicion_def; do
                    psql -c "INSERT INTO cientifico_metrics_detalle (datname, fecha, schema_name, table_name, constraint_fk, definicion, table_without_pk, trigger, column_name_pknonumerica, num_clave_primaria, all_varchar, num_columns_in_table, pk_mas_3_cols, column_name_varchar, db_schema_table)
                                VALUES ('$current_db', CURRENT_TIMESTAMP, '$schema_name', '$table_name', '$constraint_fk', '$definicion_def', $table_without_pk,'$trigger_names', '$pk_column_name', '$pk_non_numeric_count', '$same_count', '$column_count_64', '$pk_value', '$varchar_columns', '$current_db.$schema_name.$table_name');"
                done <<< "$fks"
            else
                psql -c "INSERT INTO cientifico_metrics_detalle (datname, fecha, schema_name, table_name, constraint_fk, definicion, table_without_pk, trigger, column_name_pknonumerica, num_clave_primaria, all_varchar, num_columns_in_table, pk_mas_3_cols, column_name_varchar, db_schema_table)
                            VALUES ('$current_db', CURRENT_TIMESTAMP, '$schema_name', '$table_name', 'Nofk', 'ok', $table_without_pk,'$trigger_names', '$pk_column_name', '$pk_non_numeric_count', '$same_count', '$column_count_64', '$pk_value', '$varchar_columns', '$current_db.$schema_name.$table_name');"
            fi
        done
    done
done
fi
