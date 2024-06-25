#!/bin/bash
V_ADMIN_DIR=/opt/postgres/admin
source ${V_ADMIN_DIR}/funcionesPG.sh
parametro=${HOSTNAME}
definir_salida -o pantallanombrada

msg "Ejecutando pi_cientifico_bbdd.sh"
${V_ADMIN_DIR}/pi_cientifico_bbdd.sh
if [ $? -ne 0 ]; then
  err "Fallo en la ejecución de pi_cientifico_bbdd.sh"

fi

msg "Ejecutando pi_cientifico_bbdd_detalle.sh"
${V_ADMIN_DIR}/pi_cientifico_bbdd_detalle.sh
if [ $? -ne 0 ]; then
  err "Fallo en la ejecución de pi_cientifico_bbdd_detalle.sh"

fi

msg "Ejecutando pi_cientifico_bbdd_scan.sh"
${V_ADMIN_DIR}/pi_cientifico_bbdd_scan.sh
if [ $? -ne 0 ]; then
  err "Fallo en la ejecución de pi_cientifico_bbdd_scan.sh"

fi

msg "Ejecutando pi_cientifico_bbdd_depurado_date.sh"
${V_ADMIN_DIR}/pi_cientifico_bbdd_depurado_date.sh
if [ $? -ne 0 ]; then
  err "Fallo en la ejecución de pi_cientifico_bbdd_depurado_date.sh"

fi


msg "Finalizado"
