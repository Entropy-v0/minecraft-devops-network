# Auditoría de Infraestructura y DevOps: Red de Servidores Minecraft

Como Arquitecto de Infraestructura, he analizado detalladamente tu despliegue de `docker-compose.yml` y `.env`. Para alcanzar los estándares de grandes redes de la industria (Hypixel, CubeCraft), tu base tiene buenas prácticas (containerización, Velocity, bases de datos externas), pero presenta cuellos de botella significativos en I/O, diseño de redes y configuración de escalabilidad horizontal.

A continuación, presento mi reporte técnico de auditoría estructurado en las cuatro áreas críticas, enfocado en llevar tu entorno a un nivel *Enterprise*.

---

## 1. Topología de Red y Seguridad (Aislamiento)

**Estado Actual:**
- **Positivo:** Excelente aislamiento a nivel de exposición. Los contenedores backend (`mc-lobby`, `mc-survival`) y las bases de datos no tienen la directiva `ports`, por lo que solo son accesibles a través de la red interna de Docker `mc-net`. 
- **Positivo:** Uso de `VELOCITY_SECRET`. Al inyectarlo en los backends, aseguras el uso de *Modern Forwarding*, mitigando IP spoofing y previniendo que atacantes se salten el proxy.

**Vulnerabilidades y Soluciones a Nivel Enterprise:**
1. **Segmentación de Red Deficiente (Zero Trust):**
   Actualmente usas una red plana (`mc-net`) para todo. Si un plugin malicioso o un RCE vulnera el servidor `mc-lobby`, el atacante tiene acceso directo al puerto interno de la base de datos `postgres-luckperms` o `mariadb-plugins`.
   - **Solución:** Crea redes separadas: `proxy-net` (Proxy <-> Backends) y `db-net` (Backends <-> Bases de datos). El proxy no necesita ver la base de datos, y cada backend solo debe conectarse a lo estrictamente necesario.
2. **Mitigación DDoS y TCPShield:**
   Publicar el puerto `25577` directamente al host usando `mode: host` es peligroso. En infraestructuras masivas, la IP de tu nodo principal jamás debe ser expuesta. 
   - **Solución:** Utilizar TCPShield, Cloudflare Spectrum o AWS Global Accelerator y forzar a que el host local solo acepte tráfico entrante desde el ASN de estos proveedores de protección utilizando reglas estrictas de iptables (o infraestructura externa como un Firewall de Hardware).

---

## 2. Escalabilidad Horizontal y Balanceo de Carga

**Estado Actual:**
- **Cuello de botella severo:** Tienes anclada la infraestructura al uso intensivo de `container_name: servidor-lobby` y dependencias rígidas. Esto rompe la orquestación en la nube. **No puedes escalar** dinámicamente usando comandos como `docker-compose up --scale mc-lobby=5` sin generar conflictos de nombres y bloqueos.

**Migración a Arquitectura Elástica:**
1. **Eliminar variables estáticas:**
   - Elimina la directiva `container_name` en cualquier contenedor que deba escalar (`mc-lobby`).
   - Mueve los puertos específicos de host a rangos dinámicos o elimínalos para backends.
2. **Service Discovery y Balanceo en Velocity:**
   - Velocity asume IPs o hosts fijos en su configuración. Si docker-compose levanta 3 lobbies bajo el servicio `mc-lobby`, Docker responderá la consulta DNS con las 3 IPs (Round-Robin DNS). Sin embargo, Velocity no balancea cargas automáticamente basándose en múltiples IPs bajo un solo A-record a menos que esté programado para ello (ej. con el plugin de Redis).
   - **Solución Real:** Implementa **RedisBungee** (o un orquestador equivalente compatible con Velocity) y un contenedor de Redis. Cuando un contenedor `mc-lobby` inicia, debe registrarse dinámicamente en Redis; Velocity leerá este estado y balanceará a los jugadores entre las instancias disponibles en tiempo real, sin reiniciar el proxy.
3. **El Límite de Docker Compose:**
   - Para redes "masivas", Docker Compose no es viable. Las redes AAA usan **Kubernetes + Agones** (orquestador open source de Google para game servers), o Pterodactyl Wings sobre servidores bare-metal distribuidos. Te recomiendo mirar hacia Docker Swarm o k3s para permitir escalado multi-nodo.

---

## 3. Gestión de Recursos y Persistencia de Datos (I/O)

**Estado Actual:**
- **Riesgo crítico de rendimiento:** Estás utilizando **Bind Mounts** locales (ej. `./data:/data`, `./postgres-data:/var/lib/postgresql/data`) para montajes de altísimo rendimiento de lectura/escritura (Bases de datos y mundos de Minecraft).

**Best Practices para Prevención de Chunk Corruption y Latencia:**
1. **Named Volumes vs Bind Mounts:**
   Los Bind Mounts fuerzan a Docker a depender del driver del sistema de archivos del sistema operativo host, generando overhead en cada operación I/O. En la carga masiva de chunks o consultas SQL, esto introduce un *IO Delay* terrible y aumenta el riesgo de corrupción si el host sufre micro-cortes.
   - **Solución:** Reemplaza todos los `./ruta:/ruta` por **Docker Named Volumes**. Docker administra el I/O en su propia ruta interna (/var/lib/docker/volumes) utilizando drivers altamente optimizados.
2. **Almacenamiento en Memoria Volátil (tmpfs):**
   Para servidores temporales como Lobbies o minijuegos efímeros, el disco duro ni siquiera debería tocarse.
   - **Solución:** Monta las carpetas del mundo (ej. `/data/world`) como volúmenes `tmpfs` (RAM). Los lobbies no guardan inventarios ni cambios en el mapa, su mundo base debe clonarse a RAM al arrancar. El tiempo de respuesta de lectura de chunks será instantáneo.

---

## 4. Optimización del Proxy y Contenedores

**Estado Actual:**
- **Peligro de OOM (Out Of Memory) Killer:** Tus límites de Docker chocan con los de Java. En `mc-survival`, el heap de Java (`MEMORY: 2G`) y el hard limit de Docker (`limits: memory: 3G`) dejan buen espacio. Sin embargo, en el Proxy, `MEMORY: 512M` con limit `1G` es poco para grandes redes. 

**Tuning Avanzado:**
1. **Throughput de Red Nativo (Netty Epoll):**
   Las imágenes de Alpine Linux (usadas a menudo para ahorrar peso) no incluyen `glibc` sino `musl`. Esto desactiva *Netty Native Transports* (epoll), el motor de red C++ ultra-rápido de Minecraft y Velocity, cayendo en un fallback Java mucho más lento.
   - **Solución:** Asegúrate de que las imágenes de Java usen bases basadas en Debian (ej. Ubuntu, Debian Slim). Puedes verificar si `epoll` está activo leyendo el log de inicio de Velocity (`[Netty] Using epoll channel type`).
2. **Optimización de JVM en Velocity:**
   - Aunque Paper tiene Aikar flags automáticos en tu imagen (`USE_AIKAR_FLAGS`), Velocity no se beneficia de esto y a gran escala sufre. Para Velocity con miles de conexiones, usa los flags de G1GC especializados para baja latencia agregando una variable de entorno `JVM_OPTS: "-XX:+UseG1GC -XX:G1HeapRegionSize=4M -XX:+UnlockExperimentalVMOptions -XX:+ParallelRefProcEnabled -XX:+AlwaysPreTouch"`.
3. **Limitación de Paquetes en Velocity:**
   - La configuración por defecto de Velocity es generosa. En redes masivas, debes ajustar estrictamente los límites de decodificación de paquetes (`compression-threshold` y rate limits a conexiones lentas) para mitigar intentos de saturación de CPU del proxy (explotando Netty).
