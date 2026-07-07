# Plan de Fundamentos: Cimientos Sólidos para Servidor Minecraft (Docker)

Dado que el proyecto aún es pequeño, aplicar tecnologías complejas (como orquestadores masivos, tmpfs o RedisBungee) es contraproducente en esta etapa. El objetivo ahora es establecer cimientos sólidos en Docker que te permitan aprender las mejores prácticas, mantener el proyecto estable y tenerlo preparado para escalar a futuro sin dolores de cabeza.

A continuación se presenta un plan paso a paso con las mejoras fundamentales y básicas:

## Fase 1: Persistencia Segura y Rendimiento (Named Volumes)
El paso más crítico al usar Docker en producción es manejar los datos correctamente para evitar que el progreso del mapa o las bases de datos se corrompan.
- **Objetivo:** Migrar los "Bind Mounts" (ej. `./mariadb-data:/var/lib/mysql`) a "Named Volumes" (volúmenes nombrados) gestionados internamente por Docker.
- **Por qué:** Los Named Volumes evitan problemas de permisos entre tu sistema operativo y los contenedores, y son más seguros para bases de datos (MariaDB/Postgres). Docker los guarda en una ruta especial optimizada.
- **Acción:** Modificaremos el `docker-compose.yml` para declarar la sección `volumes:` al final del archivo y usar esos volúmenes en `postgres`, `mariadb` y las carpetas de datos de los servidores de Minecraft.

## Fase 2: Aislamiento Básico de Red
Aprender a segmentar redes en Docker es una habilidad esencial de DevOps y seguridad.
- **Objetivo:** Separar las bases de datos de los servidores Minecraft a nivel de red virtual.
- **Por qué:** Por seguridad, el proxy Velocity no necesita tener acceso directo a la base de datos. Cada contenedor solo debe tener acceso a lo que realmente necesita.
- **Acción:** Crearemos dos redes en el `docker-compose.yml`:
  - `mc-net`: Para la comunicación entre Velocity y los servidores (Lobby y Survival).
  - `db-net`: Para la comunicación entre los servidores (Lobby/Survival) y las bases de datos (Postgres/MariaDB).

## Fase 3: Ajuste de Memoria (Evitar Cierres Repentinos)
Docker y Java (Minecraft) interactúan de forma particular con la memoria. Si no los configuras bien, el servidor se apagará de repente (el "OOM Killer" de Linux).
- **Objetivo:** Armonizar los límites de memoria RAM de Docker con la memoria Heap de Java.
- **Por qué:** Java utiliza más memoria que solo la asignada al Heap (la variable `MEMORY` o `-Xmx`). Utiliza memoria adicional para procesos internos. Si limitas el contenedor de Docker a 2G y le dices a Java que puede usar hasta 2G, Docker matará el contenedor en cuanto Java intente usar memoria extra.
- **Acción:** Asegurarnos de mantener una regla de oro en el `docker-compose.yml`: El límite de memoria de Docker (`limits: memory: ...`) debe ser siempre mayor (al menos un 20% más) que la variable `MEMORY` asignada al servidor de Minecraft.

## Fase 4: Escalabilidad Horizontal Básica (El Siguiente Nivel)
Cuando quieras probar cómo se siente instanciar 2 o 3 Lobbies, hay que quitar una restricción básica de tu configuración actual.
- **Objetivo:** Permitir que Docker levante múltiples instancias del mismo servicio (ej. múltiples lobbies).
- **Por qué:** Aprenderás cómo levantar infraestructura dinámica sin conflictos de nombres.
- **Acción:** Eliminar la línea `container_name: servidor-lobby` del archivo. De esta forma podrás usar un comando como `docker-compose up --scale mc-lobby=2` sin que Docker falle diciendo que el nombre ya existe.

---
**¿Cómo proceder?**
Esta documentación sirve como tu hoja de ruta. Cuando desees comenzar a construir estos cimientos básicos, podemos arrancar con la **Fase 1**. Solo dímelo y prepararé los cambios específicos para tu `docker-compose.yml`.
