#!/bin/bash

ARCHIVO="productos.tsv"
ARCHIVO_USUARIOS="usuarios.tsv"

# ==========================================
# SECCIÓN DE AUTENTICACIÓN Y USUARIOS
# ==========================================

registrar_usuario() {
    echo "=============================="
    echo "      REGISTRO DE USUARIO     "
    echo "=============================="
    
    read -p "Ingrese nombre de usuario: " nuevo_user
    
    # Validar si el usuario ya existe
    if [ -f "$ARCHIVO_USUARIOS" ] && grep -q "^$newUser\t" "$ARCHIVO_USUARIOS"; then
        echo "Error: El usuario '$nuevo_user' ya existe."
        return
    fi

    # Solicitar contraseña de forma oculta (-s)
    read -s -p "Ingrese contraseña: " password
    echo ""
    
    # Cifrar la contraseña usando sha256sum
    pass_hash=$(echo -n "$password" | sha256sum | awk '{print $1}')

    # Guardar en usuarios.tsv (usuario y hash separados por tabulador)
    echo -e "$nuevo_user\t$pass_hash" >> "$ARCHIVO_USUARIOS"
    echo "¡Usuario registrado exitosamente!"
}

iniciar_sesion() {
    echo "=============================="
    echo "        INICIAR SESIÓN        "
    echo "=============================="
    
    if [ ! -f "$ARCHIVO_USUARIOS" ] || [ ! -s "$ARCHIVO_USUARIOS" ]; then
        echo "No hay usuarios registrados. Debe registrarse primero."
        return 1
    fi

    read -p "Usuario: " user_ingresado
    read -s -p "Contraseña: " pass_ingresada
    echo ""

    # Cifrar la contraseña ingresada para compararla con el hash guardado
    hash_ingresado=$(echo -n "$pass_ingresada" | sha256sum | awk '{print $1}')

    # Buscar coincidencia en el archivo usuarios.tsv
    while IFS=$'\t' read -r user pass_guardado; do
        # Limpiar posibles espacios o retornos de carro
        user=$(echo "$user" | tr -d '\r')
        pass_guardado=$(echo "$pass_guardado" | tr -d '\r')
        
        if [ "$user" == "$user_ingresado" ] && [ "$pass_guardado" == "$hash_ingresado" ]; then
            echo "¡Inicio de sesión exitoso. Bienvenido, $user!"
            return 0
        fi
    done < "$ARCHIVO_USUARIOS"

    echo "Error: Usuario o contraseña incorrectos."
    return 1
}

# ==========================================
# SECCIÓN DE PRODUCTOS (ABM Y REPORTE)
# ==========================================

agregar_producto() {
    echo "=============================="
    echo "      AGREGAR PRODUCTO        "
    echo "=============================="
    
    read -p "Ingrese el ID del producto: " id
    
    if [ -f "$ARCHIVO" ] && grep -q "^$id\t" "$ARCHIVO"; then
        echo "Error: Ya existe un producto con el ID '$id'."
        return
    fi

    read -p "Ingrese el nombre del producto: " nombre
    read -p "Ingrese el precio del producto: " precio

    echo -e "$id\t$nombre\t$precio" >> "$ARCHIVO"
    echo "¡Producto agregado exitosamente!"
}

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

# ==========================================
# MENÚ DE AUTENTICACIÓN INICIAL
# ==========================================

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
                # Si el login es exitoso, entra al menú principal de productos
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
                        1) listar_productos ;;
                        2) agregar_producto ;;
                        3) editar_producto ;;
                        4) generar_html ;;
                        5) 
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
