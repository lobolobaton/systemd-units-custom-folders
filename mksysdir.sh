#!/bin/bash

#
# Permite organizar y trabajar con ficheros unit de systemd
# desde directorios personalizados, fuera de los directorios estándar.
#
# IMPORTANTE: El directorio personalizado donde las unidades 
# se encuentran debe ser accesible cuando se inicia systemd
# (por ejemplo, no se permite nada debajo de /home o /var, a menos
# que esos directorios estén ubicados en el sistema de archivos raíz).
# 

# NO EDITAR: Ruta absoluta al directorio personalizado
# con las units a instalar o desinstalar.
path_inst=""

# NO EDITAR: Si la operación es como usuario normal, usuario global o root.
# Por defecto como usuario root.
# 0 = root, 1 = user, 2 = global
user_type=0

# NO EDITAR: El tipo de operación (create o delete)
operation=""

# NO EDITAR: Contendra el comando systemctl
comando=""

# Es el directorio que contendra la base de datos.
# Por defecto el path desde donde se ejecuta este script.
db_dir=$(dirname "$0")

# Nombre para la base de datos.
db_name="basedatos.txt"

# El formato de linea de la base de datos es:
# path:fecha:tipo-de-usuario
# Valores del campo tipo-de-usuario;
# 0 = root, 1 = usuario (user), 2 = todos los usuarios (global)


#=========================================================================
# Comprobar si tenemos privilegios de root.
#=========================================================================

function is_root {
  if [ $EUID -ne 0 ]; then
    echo "WARNING: Si no usa el parametro 'user'"\
    "necesita ejecutar esta herramienta como root!"
    exit 1
  fi
}

#=========================================================================
# Función de ayuda del programa.
#=========================================================================

function uso {
  printf "\nUso:\n"
  printf " mksysdir.sh [user|global] create|delete {directory}\n"
  printf "Opciones:\n"
  printf " user      : instalación/desinstalación para el usuario llamador.\n"
  printf " global    : instalación/desinstalación para todos los usuarios.\n"
  printf " create    : Crea una instalación.\n"
  printf " delete    : Elimina una instalación.\n"
  printf " directory : El directorio objetivo, debe ser un path absoluto.\n\n"
  printf "Si 'user' no esta activo, la instalación/desinstalación, sea 'global',\n"
  printf "o sin nada activo de (Sistema), necesitara ejecutar esta herramienta\n"
  printf "como root, de ser necesario se le avisará.\n\n"
  exit 0
}

#=========================================================================
# Función que comprueba los parametros pasados al programa.
#=========================================================================

function parse_cmdline {

  if [ $# -lt 2 ] || [ $# -gt 3 ]; then
    uso
  fi
  if [ $# -eq 2 ] && [ "$1" != "create" ] && [ "$1" != "delete" ]; then
    uso
  fi
  if [ $# -eq 3 ] && [ $1 != "user" ] && [ $1 != "global" ]; then
    uso
  fi
  if [ $# -eq 3 ] && [ "$2" != "create" ] && [ "$2" != "delete" ]; then
    uso
  fi
  
  if [ $# -eq 3 ]; then 
    if [ "$1" = "user" ]; then
      user_type=1
    else
      user_type=2
      # 2 = global: comprobar si tenemos privilegios.
      is_root
    fi
    
    operation=$2
    path_inst="$3"
    
    # Comprobar conflicto entre el parametro 'user' y la ejecución como root.
    if [ "$user_type" = "1" ] && [ $EUID -eq 0 ]; then
      echo -e "CONFLICTO!: Se pasó el parametro 'user' y se esta ejecutando\n"\
           "esta herramineta como root!, corriga esto."
      exit 1
    fi
  else
    # 0 = root: Comprobar si tenemos privilegios de root.
    is_root
    operation=$1
    path_inst="$2"
  fi
  
  # Comprobar si existe el path objetivo.
  if [ ! -d "$path_inst" ]; then
    echo "ERROR: El path '$path_inst' no existe!"
    exit 1
  fi
}

#=========================================================================
# Función create.
#=========================================================================

function create {
  echo "Instalando unidades de: $path_inst ..."
  list_units=$(ls $path_inst | grep -E \
  '^.+\.(service|timer|path|device|scope|slice|mount|automount|socket|swap|target)')
  for i in $list_units; do
    $comando link $path_inst/$i
  done
}

#=========================================================================
# Función delete.
#=========================================================================

function delete {
  echo "Desinstalando unidades de: $path_inst ..."
  list_units=$(ls $path_inst | grep -E \
  '^.+\.(service|timer|path|device|scope|slice|mount|automount|socket|swap|target)')
  for i in $list_units; do  
    $comando is-active $i | grep -q -s "^active"
    if [ $? -eq 0 ]; then
      $comando stop $i
    fi 
    
    $comando is-enabled $i | grep -q -s "^masked"
    if [ $? -eq 0 ]; then
      $comando unmask $i
    else
      $comando disable $i
    fi      
  done
}

#=========================================================================
# Main.
#=========================================================================

# Comprobar los parametros pasados.
parse_cmdline "$@"

# Establecer el comando.
if [ "$user_type" = "0" ]; then
  comando="systemctl"
elif [ "$user_type" = "1" ]; then
  comando="systemctl --user"
else
  comando="systemctl --user --global"
fi

# Comprobar el tipo de operación.
if [ "$operation" = "create" ]; then
  create
  if [ $? -eq 0 ]; then
    echo "$path_inst:$(date):$user_type" >> $db_dir/$db_name
  fi
else
  delete
  if [ $? -eq 0 ]; then
    grep -v "$path_inst" $db_dir/$db_name > $db_dir/${db_name}.tmp
    rm $db_dir/$db_name
    mv $db_dir/${db_name}.tmp $db_dir/$db_name
  fi
fi


