En el inventorio encontramos el host, groups, groups_cluster y tier para cada entorno (DEV, ITG, PRE y PRO).
En automatizado se encuentra: - playbooks: playbook de creación de tablas en la base de datos postgres donde se insertrán los datsos recopilado spor los scripts
                                            playbook para la distribución de los scripts ejecutando el role setup_scripts.
                                            El role a ejecutar tiene la siguiente estructura:


                                            [PRO] [local_bbdd@pvvgl0652 setup_scripts](developer_pg14)$ tree
                                            .
                                            ├── tasks
                                            │   ├── main.yml
                                            │   ├── setup_scripts_admin.yml
                                            └── templates
                                                ├── admin
                                                │   ├── mantenimiento.sh.template
                                                │   ├── pi_cientifico_bbdd_depurado.sh.template
                                                │   ├── pi_cientifico_bbdd_detalle.sh.template
                                                │   ├── pi_cientifico_bbdd_scan.sh.template
                                                │   ├── pi_cientifico_bbdd.sh.template


En roles se encuentra: tasks donde se define cada uno de los archivos yaml
                       templates: donde se encuentran todos los scripts que se ejecutarán y el de mantenimiento que será el que ejcute cada día el timer y este                              lanzará todos los scripts.

La manera de ejecutar la distribución de scripts y creación de tablas desde ansible es la siguiente:
Utilizaremos el usuario local_bbdd que es un usuario que tiene permisos sobre todas las máquinas del inventario.
Para asegurar la correcta ejecución y no afectar a entornos productivos, primero se ejecutará en DEV, ITG y PRE y posteriormente en PRO una vez nos hemos asegurado que todo es correcto.
Para la creación de las tablas (por ejemplo en pre):

ansible-playbook -i $pre -l cm auxiliar/pi_cientifico.yml

Para la distribución de scripts, otro ejemplo: (en dev)

ansible-playbook -l cm -i $dev playbooks/06_setup_scripts.yml

El archivo queries.yml tiene todas las métricas que recogen la información de las tablas.
Para ver lo que sacan estas querys:
Utilizaremos el usuario local_bbdd que es un usuario que tiene permisos sobre todas las máquinas del inventario.
Nos conectamos a una máquina para ver que sacan las métricas sobre esta tabla con:

ssh iv1ml0039.itg.cm.mercadona.com

Una vez dentro entramos a la ruta:

 curl localhost:9187/metrics (con eto vemos todas las métricas, es decir, las que tiene por defecto el exporter también aparecerán)

 curl localhost:9187/metrics | grep pg_pi_cientifico_bbdd (con esto le filtramos por el inicio del nombre de las métricas creadas(no por defecto)):
 salida: 
 pg_pi_cientifico_bbdd_scan_seq_scan{datname="adt-maestros.adm-adt-maestros",db_schema_table="adt-maestros.adm-adt-maestros.t_centros_para_adt",schema_name="adm-adt-maestros",server="localhost:5432",table_name="t_centros_para_adt"} 0
 pg_pi_cientifico_bbdd_varchar_all{datname="adt-autenticador.adm-adt-autenticador",schema_name="adm-adt-autenticador",server="localhost:5432"} 4

Estos ejemplos es lo que sacan dos de las métricas.

El archivo queries.yaml se encuentra en: cd /opt/prometheus_exporters/postgresql_exporter/


 

 

 
