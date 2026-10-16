#!/bin/bash

ARCHIVO="productos.tsv"

# Función para dar de alta (agregar) un producto validando que no exista el ID
agregar_producto() {
    echo "=============================="
    echo "      AGREGAR PRODUCTO        "
    echo "=============================="
    
    read -p "Ingrese el ID del producto: " id
    
    # Validar si el archivo existe y si el ID ya fue registrado
    if [ -f "$ARCHIVO" ] && grep -q "^$id\t" "$ARCHIVO"; then
        echo "Error: Ya existe un producto con el ID '$id'."
        return
    fi

    read -p "Ingrese el nombre del producto: " nombre
    read -p "Ingrese el precio del producto: " precio

    # Guardar en formato TSV (separado por tabulador \t)
    echo -e "$id\t$nombre\t$precio" >> "$ARCHIVO"
    echo "¡Producto agregado exitosamente!"
}

# Función para editar un producto existente
editar_producto() {
    echo "=============================="
    echo "   EDITAR PRODUCTO EXISTENTE  "
    echo "=============================="
    
    if [ ! -f "$ARCHIVO" ] || [ ! -s "$ARCHIVO" ]; then
        echo "No hay productos registrados o el archivo no existe."
        return
    fi

    read -p "Ingrese el ID del producto que desea modificar: " id_buscado

    if ! grep -q "^$id_buscado\t" "$ARCHIVO"; then
        echo "Error: No se encontró ningún producto con el ID '$id_buscado'."
        return
    fi

    echo "Producto actual encontrado:"
    grep "^$id_buscado\t" "$ARCHIVO"
    echo "------------------------------"

    read -p "Ingrese el nuevo nombre del producto: " nuevo_nombre
    read -p "Ingrese el nuevo precio del producto: " nuevo_precio

    temp_file=$(mktemp)

    while IFS=$'\t' read -r id nombre precio; do
        if [ "$id" == "$id_buscado" ]; then
            echo -e "$id\t$nuevo_nombre\t$nuevo_precio" >> "$temp_file"
        else
            echo -e "$id\t$nombre\t$precio" >> "$temp_file"
        fi
    done < "$ARCHIVO"

    mv "$temp_file" "$ARCHIVO"
    echo "¡Producto actualizado exitosamente!"
}

# Función para listar los productos en consola
listar_productos() {
    if [ -f "$ARCHIVO" ] && [ -s "$ARCHIVO" ]; then
        echo ""
        echo "--- LISTA DE PRODUCTOS ---"
        echo -e "ID\tNOMBRE\tPRECIO"
        echo "--------------------------"
        while IFS=$'\t' read -r id nombre precio; do
            echo -e "$id\t$nombre\t\$$precio"
        done < "$ARCHIVO"
    else
        echo "No hay productos registrados."
    fi
}

# Función para generar el reporte HTML (Punto 1)
generar_html() {
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

    if [ -f "$ARCHIVO" ] && [ -s "$ARCHIVO" ]; then
        while IFS=$'\t' read -r id nombre precio; do
            echo "        <tr><td>$id</td><td>$nombre</td><td>\$$precio</td></tr>" >> "$html_file"
        done < "$ARCHIVO"
    else
        echo "        <tr><td colspan='3'>No hay productos registrados.</td></tr>" >> "$html_file"
    fi

    cat << EOF >> "$html_file"
    </table>
</body>
</html>
EOF

    echo "¡Reporte 'productos.html' generado exitosamente!"
}

# Menú principal
while true; do
    echo ""
    echo "--- MENÚ ABM DE PRODUCTOS (TSV) ---"
    echo "1. Listar productos"
    echo "2. Agregar producto"
    echo "3. Editar un producto existente"
    echo "4. Generar reporte HTML"
    echo "5. Salir"
    read -p "Seleccione una opción: " opcion

    case $opcion in
        1)
            listar_productos
            ;;
        2)
            agregar_producto
            ;;
        3)
            editar_producto
            ;;
        4)
            generar_html
            ;;
        5)
            echo "Saliendo del programa..."
            exit 0
            ;;
        *)
            echo "Opción inválida. Intente nuevamente."
            ;;
    esac
done