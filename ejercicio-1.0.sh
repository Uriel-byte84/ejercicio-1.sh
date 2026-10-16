Set-Content -Path "ejercicio-1.sh" -Value '#!/bin/bash

ARCHIVO="productos.txt"

editar_producto() {
    echo "=============================="
    echo "   EDITAR PRODUCTO EXISTENTE  "
    echo "=============================="
    
    if [ ! -f "$ARCHIVO" ] || [ ! -s "$ARCHIVO" ]; then
        echo "No hay productos registrados o el archivo no existe."
        return
    fi

    read -p "Ingrese el ID del producto que desea modificar: " id_buscado

    if ! grep -q "^$id_buscado:" "$ARCHIVO"; then
        echo "Error: No se encontró ningún producto con el ID '\''$id_buscado'\''."
        return
    fi

    echo "Producto actual encontrado:"
    grep "^$id_buscado:" "$ARCHIVO"
    echo "------------------------------"

    read -p "Ingrese el nuevo nombre del producto: " nuevo_nombre
    read -p "Ingrese el nuevo precio del producto: " nuevo_precio

    temp_file=$(mktemp)

    while IFS=: read -r id nombre precio; do
        if [ "$id" == "$id_buscado" ]; then
            echo "$id:$nuevo_nombre:$nuevo_precio" >> "$temp_file"
        else
            echo "$id:$nombre:$precio" >> "$temp_file"
        fi
    done < "$ARCHIVO"

    mv "$temp_file" "$ARCHIVO"
    echo "¡Producto actualizado exitosamente!"
}

while true; do
    echo ""
    echo "--- MENÚ ABM DE PRODUCTOS ---"
    echo "1. Listar productos"
    echo "2. Agregar producto"
    echo "3. Editar un producto existente"
    echo "4. Salir"
    read -p "Seleccione una opción: " opcion

    case $opcion in
        1)
            if [ -f "$ARCHIVO" ] && [ -s "$ARCHIVO" ]; then
                echo ""
                echo "--- LISTA DE PRODUCTOS ---"
                cat "$ARCHIVO"
            else
                echo "No hay productos registrados."
            fi
            ;;
        2)
            read -p "Ingrese ID: " id
            read -p "Ingrese Nombre: " nombre
            read -p "Ingrese Precio: " precio
            echo "$id:$nombre:$precio" >> "$ARCHIVO"
            echo "¡Producto agregado exitosamente!"
            ;;
        3)
            editar_producto
            ;;
        4)
            echo "Saliendo del programa..."
            exit 0
            ;;
        *)
            echo "Opción inválida. Intente nuevamente."
            ;;
    esac
done