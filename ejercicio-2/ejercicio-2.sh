#!/bin/bash

ARCHIVO="productos.tsv"
ARCHIVO_USUARIOS="usuarios.tsv"

if ! command -v dialog &> /dev/null; then
    echo "Error: La herramienta 'dialog' no está instalada. Ejecute: sudo apt install dialog"
    exit 1
fi

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

    if [ -f "$ARCHIVO_USUARIOS" ] && grep -q "^$usuario\t" "$ARCHIVO_USUARIOS"; then
        dialog --title "Error" --msgbox "El usuario '$usuario' ya existe." 6 40
        return
    fi

    local pass_hash=$(echo -n "$password" | sha256sum | awk '{print $1}')
    echo -e "$usuario\t$pass_hash" >> "$ARCHIVO_USUARIOS"
    dialog --title "Éxito" --msgbox "¡Usuario registrado exitosamente!" 6 40
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
    
    if [ -f "$ARCHIVO_USUARIOS" ]; then
        while IFS=$'\t' read -r user pass_guardado; do
            user=$(echo "$user" | tr -d '\r')
            pass_guardado=$(echo "$pass_guardado" | tr -d '\r')
            if [ "$user" == "$usuario" ] && [ "$pass_guardado" == "$hash_ingresado" ]; then
                menu_principal "$usuario"
                return 0
            fi
        done < "$ARCHIVO_USUARIOS"
    fi

    dialog --title "Error" --msgbox "Usuario o contraseña incorrectos." 6 40
    return 1
}

listar_productos() {
    local temp_list=$(mktemp)
    echo -e "ID\tNOMBRE\tPRECIO" > "$temp_list"
    if [ -f "$ARCHIVO" ] && [ -s "$ARCHIVO" ]; then
        while IFS=$'\t' read -r id nombre precio; do
            echo -e "$id\t$nombre\t\$$precio" >> "$temp_list"
        done < "$ARCHIVO"
    fi
    dialog --title "Lista de Productos (TSV)" --textbox "$temp_list" 15 50
    rm -f "$temp_list"
}

agregar_producto() {
    local temp_file=$(mktemp)
    dialog --title "Agregar Producto" --form "Ingrese los datos:" 12 50 3 \
        "ID:" 1 1 "" 1 10 15 0 \
        "Nombre:" 2 1 "" 2 10 20 0 \
        "Precio:" 3 1 "" 3 10 10 0 2> "$temp_file"

    if [ $? -eq 0 ]; then
        local id=$(sed -n '1p' "$temp_file")
        local nombre=$(sed -n '2p' "$temp_file")
        local precio=$(sed -n '3p' "$temp_file")
        rm -f "$temp_file"

        [ -z "$id" ] || [ -z "$nombre" ] || [ -z "$precio" ] && return

        if [ -f "$ARCHIVO" ] && grep -q "^$id\t" "$ARCHIVO"; then
            dialog --title "Error" --msgbox "Ya existe un producto con el ID '$id'." 6 40
            return
        fi

        echo -e "$id\t$nombre\t$precio" >> "$ARCHIVO"
        dialog --title "Éxito" --msgbox "¡Producto agregado exitosamente!" 6 40
    else
        rm -f "$temp_file"
    fi
}

editar_producto() {
    local temp_id=$(mktemp)
    dialog --title "Editar Producto" --inputbox "Ingrese el ID del producto a modificar:" 8 40 2> "$temp_id"
    local id_buscado=$(cat "$temp_id")
    rm -f "$temp_id"
    [ -z "$id_buscado" ] && return

    if ! grep -q "^$id_buscado\t" "$ARCHIVO"; then
        dialog --title "Error" --msgbox "No se encontró el producto con ID '$id_buscado'." 6 40
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

        local temp_temp=$(mktemp)
        while IFS=$'\t' read -r id nombre precio; do
            if [ "$id" == "$id_buscado" ]; then
                echo -e "$id\t$nuevo_nombre\t$nuevo_precio" >> "$temp_temp"
            else
                echo -e "$id\t$nombre\t$precio" >> "$temp_temp"
            fi
        done < "$ARCHIVO"
        mv "$temp_temp" "$ARCHIVO"
        dialog --title "Éxito" --msgbox "¡Producto actualizado exitosamente!" 6 40
    else
        rm -f "$temp_file"
    fi
}

generar_html() {
    local html_file="productos.html"
    cat << EOF > "$html_file"
<!DOCTYPE html>
<html lang="es">
<head><meta charset="UTF-8"><title>Reporte</title></head>
<body>
<h2>Inventario de Productos</h2>
<table border="1">
<tr><th>ID</th><th>Nombre</th><th>Precio</th></tr>
EOF
    if [ -f "$ARCHIVO" ]; then
        while IFS=$'\t' read -r id nombre precio; do
            echo "<tr><td>$id</td><td>$nombre</td><td>\$$precio</td></tr>" >> "$html_file"
        done < "$ARCHIVO"
    fi
    echo "</table></body></html>" >> "$html_file"
    dialog --title "Éxito" --msgbox "¡Reporte 'productos.html' generado!" 6 40
}

menu_principal() {
    local username="$1"
    while true; do
        choice=$(dialog --clear --title "Menú Principal - Usuario: $username" \
            --menu "Seleccione una opción:" 15 50 5 \
            "1" "Listar productos" \
            "2" "Agregar producto" \
            "3" "Editar producto" \
            "4" "Generar reporte HTML" \
            "5" "Cerrar sesión" 2>&1 >/dev/tty)

        case $choice in
            1) listar_productos ;;
            2) agregar_producto ;;
            3) editar_producto ;;
            4) generar_html ;;
            5) break ;;
            *) break ;;
        esac
    done
}

while true; do
    auth_choice=$(dialog --clear --title "Sistema de Acceso" \
        --menu "Seleccione una opción:" 12 40 3 \
        "1" "Iniciar sesión" \
        "2" "Registrar usuario" \
        "3" "Salir" 2>&1 >/dev/tty)

    case $auth_choice in
        1) iniciar_sesion ;;
        2) registrar_usuario ;;
        3) clear; exit 0 ;;
        *) clear; exit 0 ;;
    esac
done
