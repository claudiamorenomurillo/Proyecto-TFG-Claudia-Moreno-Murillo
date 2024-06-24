datnames=$(psql -At -c "
select datname from pg_database 
where datname not in ('postgres', 'template0', 'template1')")

  recovery=$(psql -At -c "select pg_is_in_recovery();")

  if [ "$recovery" = "t" ]; then
      exit 0
  else
      for current_db in $datnames; do
          schema_names=$(psql -d "$current_db" -At -c "
          select schema_name FROM information_schema.schemata 
          where schema_name 
          not like 'pg\_%' and schema_name not in ('public', 'ggobjects', 'information_schema');")


          for schema_name in $schema_names; do
          
          fk=$(psql -d "$current_db" -At -c "
          select count(*) 
          from pg_class 
          inner join pg_constraint ON pg_class.oid = conrelid 
          left join pg_index on conrelid = indrelid and conkey = array(select * from unnest(indkey)) 
          where contype = 'f' and indexrelid is null and relnamespace not in ('pg_catalog'::regnamespace, 'information_schema'::regnamespace, 'pg_toast'::regnamespace);")
          
          pk=$(psql -d "$current_db" -At -c "
          select count(*) AS \"Cantidad de tablas sin clave primaria\" 
          from information_schema.tables tab l
          left join information_schema.table_constraints tco on tab.table_schema = tco.table_schema and tab.table_name = tco.table_name and tco.constraint_type = 'PRIMARY KEY' where tab.table_type = 'BASE TABLE' and tab.table_schema = '$schema_name' and tco.constraint_name is null;")
          
        trigger=$(psql -d "$current_db" -At -c "
                select count(*)
                from pg_catalog.pg_trigger t
                join pg_catalog.pg_class c on t.tgrelid = c.oid
                join pg_catalog.pg_namespace n on c.relnamespace = n.oid
                where n.nspname = '$schema_name' and not t.tgisinternal;")

        varchar_all=$(psql -d "$current_db" -At -c "
                  select count (*) 
                  from pg_class
                  inner join pg_attribute on pg_class.oid = attrelid
                  inner join pg_type on atttypid = pg_type.oid
                  where relnamespace::regnamespace = '$schema_name'::regnamespace
                  and attnum > 0
                  and relkind = 'r'
                  and not exists(select 1 from pg_attribute inner join pg_type ON atttypid = pg_type.oid WHERE attrelid = pg_class.oid and typname <> 'varchar' and attnum > 0);")
            
          pk_no_num_unacolumn=$(psql -d "$current_db" -At -c "
                  select count(*)
                  from pg_constraint
                  inner join pg_class on pg_constraint.conrelid = pg_class.oid
                  inner join pg_namespace on pg_constraint.connamespace = pg_namespace.oid
                  inner join pg_attribute on pg_constraint.conkey[1] = pg_attribute.attnum and pg_constraint.conrelid = pg_attribute.attrelid
                  inner join pg_type on pg_attribute.atttypid = pg_type.oid
                  where pg_namespace.nspname = '$schema_name'
                      and pg_type.typcategory <> 'N'
                      and pg_constraint.contype = 'p'
                      and array_length(pg_constraint.conkey, 1) = 1;")
          columnas_mas_64=$(psql -d "$current_db" -At -c "
                  select coalesce((
                  select count(*)
                  from information_schema.columns
                  where table_schema = '$schema_name'
                  group by table_name
                  having count(*) > 64
                  limit 1), 0);")
          pk_column_mas_3=$(psql -d "$current_db" -At -c "
                  select count(*)
                  from pg_constraint
                  inner join pg_class on pg_constraint.conrelid = pg_class.oid
                  inner join pg_namespace on pg_constraint.connamespace = pg_namespace.oid
                  where pg_namespace.nspname = '$schema_name'
                      and pg_constraint.contype = 'p'  -- Primary key
                      and array_length(pg_constraint.conkey, 1) > 3
                      and pg_class.relispartition = 'f';  ")

        psql -c "insert into cientifico_metrics (datname, schema_name, fk, pk, trigger, varchar_all, pk_no_num_unacolumn, columnas_mas_64, pk_column_mas_3) 
        values ('$current_db.$schema_name', '$schema_name', '$fk', '$pk', '$trigger', '$varchar_all', '$pk_no_num_unacolumn', '$columnas_mas_64', '$pk_column_mas_3');"
        done
    done
  fi
