# Clone Bitbucket Repository Script

Script bash (`clone-bitbucket-repo.sh`) para clonar automáticamente todos los repositorios de un proyecto en Bitbucket Server (bitbucket.once.es).

## 📋 Descripción

Este script automatiza la tarea de clonar múltiples repositorios de un proyecto de Bitbucket. Sus principales características son:

* **Interactivo:** Solicita usuario, contraseña (de forma segura/oculta) y nombre del proyecto al ejecutarlo.
* **Seguro:** Valida que estés ejecutando el script en un directorio que coincida con el nombre del proyecto (para evitar clonar en lugares equivocados).
* **Resiliente:** Detecta repositorios ya existentes y los salta, evitando errores o sobreescrituras accidentales.

**Servidor:** `bitbucket.once.es`

## 🛠️ Requisitos previos

El entorno donde se ejecute debe tener instalado:

* `git`: Para clonar los repositorios.
* `curl`: Para realizar las peticiones a la API de Bitbucket.
* `jq`: Para procesar las respuestas JSON de la API.

```bash
# Ejemplo instalación en Debian/Ubuntu
sudo apt-get install git curl jq
```

## 🚀 Uso

1. **Ejecuta el script:**

    ```bash
    ./<directorio-script>/clone-bitbucket-repo.sh
    ```

2. **Sigue las instrucciones en pantalla:**

    * **Usuario:** Tu usuario de Bitbucket/LDAP.
    * **Contraseña:** Tu contraseña de Bitbucket/LDAP.
    * **Proyecto:** El código del proyecto en Bitbucket (ej: `OCP-INFORMES`).

3. **Validación de Seguridad:**

    Si el directorio actual no contiene el nombre del proyecto (ignorando mayúsculas y prefijos como 'ocp-'), el script te mostrará una advertencia y pedirá confirmación antes de continuar.

    > **Ejemplo:**
    Si el proyecto es `OCP-INFORMES` y estás en la carpeta `~/tmp/pruebas`, el script te avisará. Si estás en `~/workspace/ocp-informes`, continuará automáticamente.

## ⚠️ Manejo de errores

El script maneja y notifica los siguientes casos:

* **Error 401:** Credenciales inválidas.
* **Error 404:** El proyecto no existe.
* **Error 403:** No tienes permisos ver el proyecto.
* **Directorios existentes:** Si encuentra una carpeta con el mismo nombre que un repo:
  * Si es un repo git: Lo salta e informa.
  * Si NO es un repo git: Lo salta y emite una advertencia.

## 🤵 Personalización

Puedes modificar el servidor mediante la variable global `SERVER="bitbucket.once.es"` que se encuentra al inicio del archivo.

## 📞 Soporte

Para más información o reportar problemas, contactar con el equipo **GSA Devops**.
