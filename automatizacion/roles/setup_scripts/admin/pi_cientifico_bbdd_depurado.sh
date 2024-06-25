datnames=$(psql -At -c "SELECT datname FROM pg_database WHERE datname NOT IN ('postgres', 'template0', 'template1')")

# Verificar si el servidor está en modo de recuperación
recovery=$(psql -At -c "SELECT pg_is_in_recovery();")
if [ "$recovery" = "t" ]; then
    exit 0
else
    for current_db in $datnames; do
        echo "Procesando base de datos: $current_db"

        schema_names=$(psql -d "$current_db" -At -c "
            SELECT schema_name
            FROM information_schema.schemata
            WHERE schema_name NOT LIKE 'pg\\_%' AND schema_name NOT IN ('public', 'information_schema');")

        for schema_name in $schema_names; do
            echo "  Procesando esquema: $schema_name"

            table_names=$(psql -d "$current_db" -At -c "
                SELECT table_name
                FROM information_schema.tables
                WHERE table_schema = '$schema_name' AND table_type = 'BASE TABLE';")

            for table_name in $table_names; do

                date_columns=$(psql -d "$current_db" -At -c "
                    SELECT column_name
                    FROM information_schema.columns
                    WHERE table_schema = '$schema_name'
                    AND table_name = '$table_name'
                    AND data_type = 'date';")

                if [ -n "$date_columns" ]; then
                    for date_column in $date_columns; do

                        old_dates=$(psql -d "$current_db" -At -c "
                            SELECT $date_column
                            FROM \"$schema_name\".\"$table_name\"
                            WHERE $date_column < NOW() - INTERVAL '5 year'
                            LIMIT 1;")

                        if [ -n "$old_dates" ]; then
                            for old_date in $old_dates; do

                                psql -c "
                                    INSERT INTO cientifico_metrics_depurado_date (datname, schema_name, table_name, depurado, db_schema_table)
                                    VALUES ('$current_db', '$schema_name', '$table_name', '$old_date', '$current_db.$schema_name.$table_name');"
                            done
                        fi
                    done
                fi
            done
        done
    done
fi
