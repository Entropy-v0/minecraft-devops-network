# Automatización de Despliegue con GitHub Actions

Este plan define la arquitectura para reemplazar el script manual `deploy.sh` con un flujo de CI/CD automatizado usando GitHub Actions, asegurando que los datos dinámicos (mundos, jugadores) nunca se sobrescriban y que los reinicios sean eficientes.

## Cambios Propuestos

### Repositorio y Git

#### [NUEVO] .gitignore
Se creará un archivo `.gitignore` estricto en la raíz del proyecto. Su función principal será **proteger los datos dinámicos**.
- **Bloqueados:** `mariadb-data/`, `backups/`, `*.db`, carpetas de mundos (`world*`), datos de jugadores (`playerdata`, `stats`), y el archivo `.env`.
- **Permitidos:** Archivos `.yml`, `.toml`, `.json` de configuración estática y carpetas de plugins.

#### [NUEVO] .env.example
Se creará una plantilla vacía de tu archivo `.env` (ej. `DB_PASSWORD=`). Esto documenta qué variables necesita el servidor sin exponer tus contraseñas reales en Git. El `.env` real vivirá únicamente en tu VPS de forma manual.

### Pipeline de CI/CD (GitHub Actions)

#### [ELIMINAR] deploy.sh
Se eliminará el script manual local, ya que GitHub asumirá esta responsabilidad.

#### [NUEVO] .github/workflows/deploy.yml
Se creará el flujo de trabajo automatizado que reaccionará cada vez que hagas un `git push`. La arquitectura ultra-segura tendrá los siguientes pasos:
1. **Detección de Cambios (Smart Restarts):** Usará `tj-actions/changed-files` para analizar qué carpetas fueron modificadas. Marcará qué servicios (Lobby, Survival, Proxy) necesitan reiniciarse.
2. **Conexión VPN Efímera (Tailscale):** Usará `tailscale/github-action` para unir el servidor de GitHub temporalmente a tu red privada. **Esto evita que tengas que abrir el puerto 22 de tu VPS al internet público**, bloqueando ataques de fuerza bruta.
3. **Conexión SSH Segura:** Una vez dentro de la VPN, usará `appleboy/ssh-action` para conectarse a tu VPS usando tu IP segura de Tailscale (ej. `100.x.x.x`).
4. **Sincronización:** Ejecutará comandos en el VPS para descargar los últimos cambios (`git pull`).
5. **Reinicio Selectivo:** Dependiendo de los cambios detectados en el paso 1, ejecutará `docker-compose restart` únicamente en los contenedores afectados.

## Plan de Verificación

### Verificación Manual
1. Generaremos las llaves de Tailscale (Auth Key) y SSH necesarias y las subiremos a los Secrets de GitHub.
2. Subiremos un cambio menor de configuración (ej. un MOTD en el proxy).
3. Verificaremos en "Actions" que el runner logra conectarse por Tailscale y despliega.
4. Comprobaremos en el VPS que el archivo cambió y que solo el contenedor del proxy se reinició.
