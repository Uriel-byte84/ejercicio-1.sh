#!/bin/bash

DB="data.sq3"
SYS_LOG="system.log"
ERR_LOG="error.log"

# ==========================================
# FUNCIONES DE LOGS Y UTILIDADES
# ==========================================

registrar_log() {
    local username="$1"
    local accion="$2"
    local fecha_hora
    fecha_hora=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Obtener el ID del usuario actual de la BD
    local user_id
    user_id=$(sqlite3 "$DB" "SELECT id FROM usuarios WHERE username='$username';" 2>/dev/null)
    [ -z "$user_id" ] && user_id="S/I"

    echo -e "$fecha_hora\t$user_id\t$username\t$accion" >> "$SYS_LOG"
}

registrar_error() {
    local error_msg="$1"
    local fecha_hora
    fecha_hora=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "$fecha_hora\tERROR: $error_msg" >> "$ERR_LOG"
}

# ==========================================
# INICIALIZACIÓN DE LA BASE DE DATOS (Punto 2 y 3)
# ==========================================

inicializar_bd() {
    if [ ! -f "$DB" ]; then
        sqlite3 "$DB" <<EOF
CREATE TABLE usuarios (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT UNIQUE NOT NULL,
    password_hash TEXT NOT NULL
);

CREATE TABLE productos (
    id TEXT PRIMARY KEY,
    nombre TEXT NOT NULL,
    precio REAL NOT NULL
);
EOF
        if [ $? -eq 0 ]; then
            echo "Base de datos '$DB' creada e inicializada correctamente."
        else
            registrar_error "No se pudo crear la base de datos SQLite."
        fi
    fi
}

# ==========================================
# AUTENTICACIÓN Y USUARIOS (SQLite3)
# ==========================================

registrar_usuario() {
    echo "=============================="
    echo "      REGISTRO DE USUARIO     "
    echo "=============================="
    
    read -p "Ingrese nombre de usuario: " nuevo_user
    
    # Verificar si el usuario ya existe en la BD
    local existe
    existe=$(sqlite3 "$DB" "SELECT COUNT(*) FROM usuarios WHERE username='$nuevo_user';")
    
    if [ "$existe" -gt 0 ]; then
        echo "Error: El usuario '$nuevo_user' ya existe."
        registrar_error "Intento de registrar usuario existente: $nuevo_user"
        return
    fi

    read -s -p "Ingrese contraseña: " password
    echo ""
    
    # Cifrar contraseña con sha256sum
    pass_hash=$(echo -n "$password" | sha256sum | awk '{print $1}')

    # Insertar en SQLite
    sqlite3 "$DB" "INSERT INTO usuarios (username, password_hash) VALUES ('$nuevo_user', '$pass_hash');"
    
    if [ $? -eq 0 ]; then
        echo "¡Usuario registrado exitosamente!"
        registrar_log "$nuevo_user" "REGISTRO DE USUARIO EXITOSO"
    else
        echo "Error al registrar el usuario."
        registrar_error "Fallo al insertar usuario en BD: $nuevo_user"
    fi
}

iniciar_sesion() {
    echo "=============================="
    echo "        INICIAR SESIÓN        "
    echo "=============================="
    
    read -p "Usuario: " user_ingresado
    read -s -p "Contraseña: " pass_ingresada
    echo ""

    hash_ingresado=$(echo -n "$pass_ingresada" | sha256sum | awk '{print $1}')

    # Consultar la contraseña en la BD
    local pass_guardado
    pass_guardado=$(sqlite3 "$DB" "SELECT password_hash FROM usuarios WHERE username='$user_ingresado';")

    if [ -n "$pass_guardado" ] && [ "$pass_guardado" == "$hash_ingresado" ]; then
        echo "¡Inicio de sesión exitoso. Bienvenido, $user_ingresado!"
        registrar_log "$user_ingresado" "INICIO DE SESIÓN EXITOSO"
        return 0
    else
        echo "Error: Usuario o contraseña incorrectos."
        registrar_error "Intento de inicio de sesión fallido para: $user_ingresado"
        return 1
    fi
}

# ==========================================
# GESTIÓN DE PRODUCTOS (SQLite3)
# ==========================================

agregar_producto() {
    local username="$1"
    echo "=============================="
    echo "      AGREGAR PRODUCTO        "
    echo "=============================="
    
    read -p "Ingrese el ID del producto: " id
    
    # Validar si el ID ya existe
    local existe
    existe=$(sqlite3 "$DB" "SELECT COUNT(*) FROM productos WHERE id='$id';")
    
    if [ "$existe" -gt 0 ]; then
        echo "Error: Ya existe un producto con el ID '$id'."
        registrar_error "Intento de agregar producto con ID existente: $id"
        return
    fi

    read -p "Ingrese el nombre del producto: " nombre
    read -p "Ingrese el precio del producto: " precio

    sqlite3 "$DB" "INSERT INTO productos (id, nombre, precio) VALUES ('$id', '$nombre', $precio);"
    
    if [ $? -eq 0 ]; then
        echo "¡Producto agregado exitosamente!"
        registrar_log "$username" "AGREGAR PRODUCTO ID: $id"
    else
        echo "Error al agregar el producto."
        registrar_error "Fallo al insertar producto ID: $id"
    fi
}

editar_producto() {
    local username="$1"
    echo "=============================="
    echo "   EDITAR PRODUCTO EXISTENTE  "
    echo "=============================="
    
    read -p "Ingrese el ID del producto que desea modificar: " id_buscado

    local existe
    existe=$(sqlite3 "$DB" "SELECT COUNT(*) FROM productos WHERE id='$id_buscado';")

    if [ "$existe" -eq 0 ]; then
        echo "Error: No se encontró ningún producto con el ID '$id_buscado'."
        registrar_error "Intento de editar producto inexistente ID: $id_buscado"
        return
    fi

    echo "Producto actual encontrado:"
    sqlite3 -separator " | " "$DB" "SELECT id, nombre, precio FROM productos WHERE id='$id_buscado';"
    echo "------------------------------"

    read -p "Ingrese el nuevo nombre del producto: " nuevo_nombre
    read -p "Ingrese el nuevo precio del producto: " nuevo_precio

    sqlite3 "$DB" "UPDATE productos SET nombre='$nuevo_nombre', precio=$nuevo_precio WHERE id='$id_buscado';"

    if [ $? -eq 0 ]; then
        echo "¡Producto actualizado exitosamente!"
        registrar_log "$username" "EDITAR PRODUCTO ID: $id_buscado"
    else
        echo "Error al actualizar el producto."
        registrar_error "Fallo al actualizar producto ID: $id_buscado"
    fi
}

listar_productos() {
    local username="$1"
    echo ""
    echo "--- LISTA DE PRODUCTOS ---"
    echo -e "ID\tNOMBRE\tPRECIO"
    echo "--------------------------"
    
    # Consultar y formatear la salida directamente desde SQLite
    sqlite3 -separator $'\t' "$DB" "SELECT id, nombre, '\$' || precio FROM productos;"
    
    registrar_log "$username" "LISTAR PRODUCTOS"
}

generar_html() {
    local username="$1"
    local html_file="productos.html"
    
    cat << EOF > "$html_file"
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <title>Reporte de Productos</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; background-color: #f4f4f9; }
        h2 { color: #333; }
        table { width: 100%; border-collapse: collapse; background: #fff; box-shadow: 0 2px 5px rgba(0,0,0,0.1); }
        th, td { padding: 12px 15px; text-align: left; border-bottom: 1px solid #ddd; }
        th { background-color: #007bff; color: white; }
        tr:hover { background-color: #f1f1f1; }
    </style>
</head>
<body>
    <h2>Reporte de Inventario de Productos</h2>
    <table>
        <tr>
            <th>ID</th>
            <th>Nombre</th>
            <th>Precio</th>
        </tr>
EOF

    # Extraer los datos de la base de datos y volcarlos al HTML
    sqlite3 "$DB" "SELECT id, nombre, '\$' || precio FROM productos;" | while IFS='|' read -r id nombre precio; do
        echo "        <tr><td>$id</td><td>$nombre</td><td>$precio</td></tr>" >> "$html_file"
    done

    cat << EOF >> "$html_file"
    </table>
</body>
</html>
EOF

    echo "¡Reporte 'productos.html' generado exitosamente!"
    registrar_log "$username" "GENERAR REPORTE HTML"
}

# ==========================================
# EJECUCIÓN PRINCIPAL
# ==========================================

# Inicializar la base de datos al arrancar el script
inicializar_bd

while true; do
    echo ""
    echo "--- SISTEMA DE ACCESO ---"
    echo "1. Iniciar sesión"
    echo "2. Registrar usuario"
    echo "3. Salir"
    read -p "Seleccione una opción: " opcion_auth

    case $opcion_auth in
        1)
            if iniciar_sesion; then
                # Obtener el nombre del usuario logueado recientemente (último inicio o guardarlo en variable)
                # Para simplificar la trazabilidad en el menú de productos:
                # (Asociamos la sesión activa)
                while true; do
                    echo ""
                    echo "--- MENÚ ABM DE PRODUCTOS ---"
                    echo "1. Listar productos"
                    echo "2. Agregar producto"
                    echo "3. Editar un producto existente"
                    echo "4. Generar reporte HTML"
                    echo "5. Cerrar sesión"
                    read -p "Seleccione una opción: " opcion

                    case $opcion in
                        1) listar_productos "$user_ingresado" ;;
                        2) agregar_producto "$user_ingresado" ;;
                        3) editar_producto "$user_ingresado" ;;
                        4) generar_html "$user_ingresado" ;;
                        5) 
                            registrar_log "$user_ingresado" "CIERRE DE SESIÓN"
                            echo "Cerrando sesión..."
                            break 
                            ;;
                        *) echo "Opción inválida." ;;
                    esac
                done
            fi
            ;;
        2)
            registrar_usuario
            ;;
        3)
            echo "Saliendo del programa..."
            exit 0
            ;;
        *)
            echo "Opción inválida."
            ;;
    esac
done