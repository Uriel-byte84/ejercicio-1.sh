#!/bin/bash

DB="data.sq3"
SYS_LOG="system.log"
ERR_LOG="error.log"

if ! command -v dialog &> /dev/null; then
    echo "Error: La herramienta 'dialog' no está instalada. Ejecute: sudo apt install dialog"
    exit 1
fi

registrar_log() {
    local username="$1"
    local accion="$2"
    local fecha_hora
    fecha_hora=$(date '+%Y-%m-%d %H:%M:%S')
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
    fi
}

inicializar_bd

registrar_usuario() {
    local temp_user=$(mktemp)
    local temp_pass=$(mktemp)

    dialog --title "Registro de Usuario" --inputbox "Ingrese nombre de usuario:" 8 40 2> "$temp_user"
    local usuario=$(cat "$temp_user")
    [ -z "$usuario" ] && rm -f "$temp_user" "$temp_pass" && return

    dialog --title "Registro de Usuario" --passwordbox "Ingrese contraseña:" 8 40 2> "$temp_pass"
    local password=$(cat "$temp_pass")
    rm -f "$temp_user" "$temp_pass"
    [ -z "$password" ] && return

    local existe
    existe=$(sqlite3 "$DB" "SELECT COUNT(*) FROM usuarios WHERE username='$usuario';")

    if [ "$existe" -gt 0 ]; then
        dialog --title "Error" --msgbox "El usuario '$usuario' ya existe." 6 40
        registrar_error "Intento de registrar usuario existente: $usuario"
        return
    fi

    local pass_hash=$(echo -n "$password" | sha256sum | awk '{print $1}')
    sqlite3 "$DB" "INSERT INTO usuarios (username, password_hash) VALUES ('$usuario', '$pass_hash');"
    
    if [ $? -eq 0 ]; then
        dialog --title "Éxito" --msgbox "¡Usuario registrado exitosamente!" 6 40
        registrar_log "$usuario" "REGISTRO SQLite TUI EXITOSO"
    else
        dialog --title "Error" --msgbox "Fallo al registrar el usuario." 6 40
        registrar_error "Fallo al insertar usuario en BD: $usuario"
    fi
}

iniciar_sesion() {
    local temp_user=$(mktemp)
    local temp_pass=$(mktemp)

    dialog --title "Iniciar Sesión" --inputbox "Usuario:" 8 40 2> "$temp_user"
    local usuario=$(cat "$temp_user")
    [ -z "$usuario" ] && rm -f "$temp_user" "$temp_pass" && return 1

    dialog --title "Iniciar Sesión" --passwordbox "Contraseña:" 8 40 2> "$temp_pass"
    local password=$(cat "$temp_pass")
    rm -f "$temp_user" "$temp_pass"
    [ -z "$password" ] && return 1

    local hash_ingresado=$(echo -n "$password" | sha256sum | awk '{print $1}')
    local pass_guardado
    pass_guardado=$(sqlite3 "$DB" "SELECT password_hash FROM usuarios WHERE username='$usuario';")

    if [ -n "$pass_guardado" ] && [ "$pass_guardado" == "$hash_ingresado" ]; then
        registrar_log "$usuario" "INICIO DE SESIÓN SQLITE TUI EXITOSO"
        menu_principal "$usuario"
    else
        dialog --title "Error" --msgbox "Usuario o contraseña incorrectos." 6 40
        registrar_error "Login fallido SQLite TUI para: $usuario"
        return 1
    fi
}

listar_productos() {
    local username="$1"
    local temp_list=$(mktemp)

    echo -e "ID\tNOMBRE\tPRECIO" > "$temp_list"
    sqlite3 -separator $'\t' "$DB" "SELECT id, nombre, '\$' || precio FROM productos;" >> "$temp_list"

    dialog --title "Lista de Productos (SQLite)" --textbox "$temp_list" 15 50
    rm -f "$temp_list"
    registrar_log "$username" "LISTAR PRODUCTOS SQLITE TUI"
}

agregar_producto() {
    local username="$1"
    local temp_file=$(mktemp)

    dialog --title "Agregar Producto" --form "Ingrese los datos del producto:" 12 50 3 \
        "ID:" 1 1 "" 1 10 15 0 \
        "Nombre:" 2 1 "" 2 10 20 0 \
        "Precio:" 3 1 "" 3 10 10 0 2> "$temp_file"

    if [ $? -eq 0 ]; then
        local id=$(sed -n '1p' "$temp_file")
        local nombre=$(sed -n '2p' "$temp_file")
        local precio=$(sed -n '3p' "$temp_file")
        rm -f "$temp_file"

        [ -z "$id" ] || [ -z "$nombre" ] || [ -z "$precio" ] && return

        local existe
        existe=$(sqlite3 "$DB" "SELECT COUNT(*) FROM productos WHERE id='$id';")
        if [ "$existe" -gt 0 ]; then
            dialog --title "Error" --msgbox "Ya existe un producto con el ID '$id'." 6 40
            registrar_error "Intento de agregar producto con ID existente: $id"
            return
        fi

        sqlite3 "$DB" "INSERT INTO productos (id, nombre, precio) VALUES ('$id', '$nombre', $precio);"
        dialog --title "Éxito" --msgbox "¡Producto agregado exitosamente!" 6 40
        registrar_log "$username" "AGREGAR PRODUCTO SQLITE TUI ID: $id"
    else
        rm -f "$temp_file"
    fi
}

editar_producto() {
    local username="$1"
    local temp_id=$(mktemp)

    dialog --title "Editar Producto" --inputbox "Ingrese el ID del producto a modificar:" 8 40 2> "$temp_id"
    local id_buscado=$(cat "$temp_id")
    rm -f "$temp_id"
    [ -z "$id_buscado" ] && return

    local existe
    existe=$(sqlite3 "$DB" "SELECT COUNT(*) FROM productos WHERE id='$id_buscado';")
    if [ "$existe" -eq 0 ]; then
        dialog --title "Error" --msgbox "No se encontró el producto con ID '$id_buscado'." 6 40
        registrar_error "Intento de editar producto inexistente ID: $id_buscado"
        return
    fi

    local temp_file=$(mktemp)
    dialog --title "Editar Producto" --form "Modifique los datos:" 12 50 2 \
        "Nuevo Nombre:" 1 1 "" 1 15 20 0 \
        "Nuevo Precio:" 2 1 "" 2 15 10 0 2> "$temp_file"

    if [ $? -eq 0 ]; then
        local nuevo_nombre=$(sed -n '1p' "$temp_file")
        local nuevo_precio=$(sed -n '2p' "$temp_file")
        rm -f "$temp_file"

        sqlite3 "$DB" "UPDATE productos SET nombre='$nuevo_nombre', precio=$nuevo_precio WHERE id='$id_buscado';"
        dialog --title "Éxito" --msgbox "¡Producto actualizado exitosamente!" 6 40
        registrar_log "$username" "EDITAR PRODUCTO SQLITE TUI ID: $id_buscado"
    else
        rm -f "$temp_file"
    fi
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
        <tr><th>ID</th><th>Nombre</th><th>Precio</th></tr>
EOF

    sqlite3 "$DB" "SELECT id, nombre, '\$' || precio FROM productos;" | while IFS='|' read -r id nombre precio; do
        echo "        <tr><td>$id</td><td>$nombre</td><td>$precio</td></tr>" >> "$html_file"
    done

    cat << EOF >> "$html_file"
    </table>
</body>
</html>
EOF

    dialog --title "Éxito" --msgbox "¡Reporte 'productos.html' generado exitosamente!" 6 50
    registrar_log "$username" "GENERAR REPORTE HTML SQLITE"
}

menu_principal() {
    local username="$1"
    while true; do
        local choice
        choice=$(dialog --clear --title "Menú ABM de Productos (SQLite + TUI)" \
            --menu "Seleccione una opción:" 15 50 5 \
            "1" "Listar productos" \
            "2" "Agregar producto" \
            "3" "Editar producto" \
            "4" "Generar reporte HTML" \
            "5" "Cerrar sesión" 2>&1 >/dev/tty)

        case $choice in
            1) listar_productos "$username" ;;
            2) agregar_producto "$username" ;;
            3) editar_producto "$username" ;;
            4) generar_html "$username" ;;
            5) 
                registrar_log "$username" "CIERRE DE SESIÓN SQLITE"
                break 
                ;;
            *) break ;;
        esac
    done
}

while true; do
    auth_choice=$(dialog --clear --title "Sistema de Acceso (SQLite)" \
        --menu "Seleccione una opción:" 12 40 3 \
        "1" "Iniciar sesión" \
        "2" "Registrar usuario" \
        "3" "Salir" 2>&1 >/dev/tty)

    case $auth_choice in
        1) iniciar_sesion ;;
        2) registrar_usuario ;;
        3) 
            clear
            exit 0 
            ;;
        *) 
            clear
            exit 0 
            ;;
    esac
done
