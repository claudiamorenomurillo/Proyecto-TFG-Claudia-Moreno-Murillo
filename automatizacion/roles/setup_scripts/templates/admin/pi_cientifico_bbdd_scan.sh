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
                SELECT table_name
                FROM information_schema.tables
                WHERE table_schema = '$schema_name' AND table_type = 'BASE TABLE';")

            for table_name in $table_names; do
                scan_and_idx=$(psql -d "$current_db" -At -c "
                    SELECT
                        seq_scan,
                        idx_scan,
                        100 * idx_scan / GREATEST(seq_scan + idx_scan, 1) AS porcentaje_idx_usado,
                        n_live_tup AS filas_en_tabla
                    FROM
                        pg_stat_all_tables
                    WHERE
                        schemaname = '$schema_name'
                        AND relname = '$table_name'
                        AND seq_scan + idx_scan > 0
                        AND 100 * idx_scan / GREATEST(seq_scan + idx_scan, 1) < 80
                        AND seq_scan + idx_scan > 100
                        AND n_live_tup >= 1000;")

                if [ -n "$scan_and_idx" ]; then
                    while IFS='|' read -r seq_scan idx_scan porcentaje_idx_usado filas_en_tabla; do
                        psql -c "
                            INSERT INTO cientifico_metrics_scan (datname, schema_name, table_name, seq_scan, idx_scan, porcentaje_idx_usado, filas_en_tabla, db_schema_table)
                            VALUES ('$current_db.$schema_name', '$schema_name', '$table_name', $seq_scan, $idx_scan, $porcentaje_idx_usado, $filas_en_tabla, '$current_db.$schema_name.$table_name');"
                    done <<< "$scan_and_idx"
                else
                    psql -c "
                        INSERT INTO cientifico_metrics_scan (datname, schema_name, table_name, seq_scan, idx_scan, porcentaje_idx_usado, filas_en_tabla, db_schema_table)
                        VALUES ('$current_db.$schema_name', '$schema_name', '$table_name', 0, 0, 0, 0, '$current_db.$schema_name.$table_name');"
                fi
            done
        done
    done
fi
