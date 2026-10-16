#!/bin/bash

ARCHIVO="productos.txt"

if ! command -v dialog &> /dev/null; then
    echo "Error: La herramienta 'dialog' no está instalada. Ejecute: sudo apt install dialog"
    exit 1
fi

listar_productos() {
    local temp_list=$(mktemp)
    if [ -f "$ARCHIVO" ] && [ -s "$ARCHIVO" ]; then
        echo -e "ID\tNOMBRE\tPRECIO" > "$temp_list"
        cat "$ARCHIVO" >> "$temp_list"
        dialog --title "Lista de Productos" --textbox "$temp_list" 15 50
    else
        dialog --title "Aviso" --msgbox "No hay productos registrados." 6 40
    fi
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

        echo "$id:$nombre:$precio" >> "$ARCHIVO"
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

    if ! grep -q "^$id_buscado:" "$ARCHIVO"; then
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
        while IFS=: read -r id nombre precio; do
            if [ "$id" == "$id_buscado" ]; then
                echo "$id:$nuevo_nombre:$nuevo_precio" >> "$temp_temp"
            else
                echo "$id:$nombre:$precio" >> "$temp_temp"
            fi
        done < "$ARCHIVO"
        mv "$temp_temp" "$ARCHIVO"
        dialog --title "Éxito" --msgbox "¡Producto actualizado exitosamente!" 6 40
    else
        rm -f "$temp_file"
    fi
}

while true; do
    choice=$(dialog --clear --title "Menú Ejercicio 1 (TUI)" \
        --menu "Seleccione una opción:" 15 50 4 \
        "1" "Listar productos" \
        "2" "Agregar producto" \
        "3" "Editar producto" \
        "4" "Salir" 2>&1 >/dev/tty)

    case $choice in
        1) listar_productos ;;
        2) agregar_producto ;;
        3) editar_producto ;;
        4) clear; exit 0 ;;
        *) clear; exit 0 ;;
    esac
done
