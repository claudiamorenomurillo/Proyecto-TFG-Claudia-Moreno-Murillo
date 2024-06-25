datnames=$(psql -At -c "SELECT datname FROM pg_database WHERE datname NOT IN ('postgres', 'template0', 'template1')")

  recovery=$(psql -At -c "select pg_is_in_recovery();")

  if [ "$recovery" = "t" ]; then
      exit 0
  else
      for current_db in $datnames; do
          schema_names=$(psql -d "$current_db" -At -c "SELECT schema_name FROM information_schema.schemata WHERE schema_name NOT LIKE 'pg\_%' AND schema_name NOT IN ('public', 'ggobjects', 'information_schema');")


          for schema_name in $schema_names; do
          
          fk=$(psql -d "$current_db" -At -c "SELECT COUNT(*) FROM pg_class INNER JOIN pg_constraint ON pg_class.oid = conrelid LEFT JOIN pg_index ON conrelid = indrelid AND conkey = ARRAY(SELECT * FROM unnest(indkey)) WHERE contype = 'f' AND indexrelid IS NULL AND relnamespace NOT IN ('pg_catalog'::regnamespace, 'information_schema'::regnamespace, 'pg_toast'::regnamespace);")
            pk=$(psql -d "$current_db" -At -c "SELECT COUNT(*) AS \"Cantidad de tablas sin clave primaria\" FROM information_schema.tables tab LEFT JOIN information_schema.table_constraints tco ON tab.table_schema = tco.table_schema AND tab.table_name = tco.table_name AND tco.constraint_type = 'PRIMARY KEY' WHERE tab.table_type = 'BASE TABLE' AND tab.table_schema = '$schema_name' AND tco.constraint_name IS NULL;")
            trigger=$(psql -d "$current_db" -At -c "
                  SELECT COUNT(*)
                  FROM pg_catalog.pg_trigger t
                  JOIN pg_catalog.pg_class c ON t.tgrelid = c.oid
                  JOIN pg_catalog.pg_namespace n ON c.relnamespace = n.oid
                  WHERE n.nspname = '$schema_name' AND NOT t.tgisinternal;")

            --varchar_all=$(psql -d "$current_db" -At -c "
                 -- SELECT COUNT(*)
                --  FROM pg_class
                 -- INNER JOIN pg_attribute ON pg_class.oid = attrelid
                  --INNER JOIN pg_type ON atttypid = pg_type.oid
                --  WHERE relnamespace::regnamespace = '$schema_name'::regnamespace
                   --   AND attnum > 0
                     -- AND relkind = 'r'
                     -- AND NOT EXISTS (SELECT 1 FROM pg_attribute INNER JOIN pg_type ON atttypid = pg_type.oid WHERE attrelid = pg_class.oid AND typname <> 'varchar' AND attnum > 0);")
            
          pk_no_num_unacolumn=$(psql -d "$current_db" -At -c "
                  SELECT COUNT(*)
                  FROM pg_constraint
                  INNER JOIN pg_class ON pg_constraint.conrelid = pg_class.oid
                  INNER JOIN pg_namespace ON pg_constraint.connamespace = pg_namespace.oid
                  INNER JOIN pg_attribute ON pg_constraint.conkey[1] = pg_attribute.attnum AND pg_constraint.conrelid = pg_attribute.attrelid
                  INNER JOIN pg_type ON pg_attribute.atttypid = pg_type.oid
                  WHERE pg_namespace.nspname = '$schema_name'
                      AND pg_type.typcategory <> 'N'
                      AND pg_constraint.contype = 'p'
                      AND array_length(pg_constraint.conkey, 1) = 1;")
          columnas_mas_64=$(psql -d "$current_db" -At -c "
                  SELECT COALESCE((
                      SELECT COUNT(*)
                      FROM information_schema.columns
                      WHERE table_schema = '$schema_name'
                      GROUP BY table_name
                      HAVING COUNT(*) > 64
                      LIMIT 1), 0);")
          pk_column_mas_3=$(psql -d "$current_db" -At -c "
                  SELECT COUNT(*)
                  FROM pg_constraint
                  INNER JOIN pg_class ON pg_constraint.conrelid = pg_class.oid
                  INNER JOIN pg_namespace ON pg_constraint.connamespace = pg_namespace.oid
                  WHERE pg_namespace.nspname = '$schema_name'
                      AND pg_constraint.contype = 'p'  -- Primary key
                      AND array_length(pg_constraint.conkey, 1) > 3
                      AND pg_class.relispartition = 'f';  -- Exclude partitions")

          psql -c "INSERT INTO cientifico_metrics (datname, schema_name, fk, pk, trigger, varchar_all, pk_no_num_unacolumn, columnas_mas_64, pk_column_mas_3) VALUES ('$current_db.$schema_name', '$schema_name', '$fk', '$pk', '$trigger', '$varchar_all', '$pk_no_num_unacolumn', '$columnas_mas_64', '$pk_column_mas_3');"
        done
    done
  fi
