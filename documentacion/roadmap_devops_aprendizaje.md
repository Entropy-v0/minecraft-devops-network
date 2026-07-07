# DevOps & Software Engineering Learning Path: Arquitectura Minecraft

Como tu Senior DevOps Engineer y Tutor, me entusiasma mucho este enfoque. No hay mejor forma de dominar la ingeniería de sistemas que entendiendo el **porqué** a bajo nivel de las herramientas que usas a diario. 

A continuación, tienes tu hoja de ruta estructurada en 5 pilares fundamentales. Cada uno conecta la teoría pura de sistemas de Linux y microservicios con las decisiones técnicas que hemos plasmado en tu `auditoria_avanzada.md` y `plan_fundamentos.md`.

---

## 1. Aislamiento a Bajo Nivel: Namespaces y Cgroups

**El Concepto Teórico:**
Docker no es una máquina virtual; es una ilusión óptica del kernel de Linux. Esta ilusión se crea mediante dos tecnologías del kernel:
- **Namespaces:** Aislan los recursos (Red, Procesos/PID, Puntos de montaje). Hacen creer al contenedor que está solo en el mundo.
- **Cgroups (Control Groups):** Limitan la cantidad de recursos físicos (CPU, RAM, I/O) que un grupo de procesos puede consumir.

**Aplicación Práctica (Tu Entorno):**
En tu Fase 3 del plan base, hablamos del "OOM Killer" (Out of Memory). Cuando configuras `limits: memory: 3G` en tu `docker-compose.yml`, estás creando un **Cgroup**. Si Java (el servidor Survival) intenta pedir al kernel 3.1 GB de RAM, el kernel ve que rompe las reglas del Cgroup y dispara el OOM Killer, asesinando el proceso sin piedad. Entender esto te enseña por qué los flags de Java (`-Xmx`) deben estar siempre por debajo del límite del Cgroup.

**Recursos Sugeridos (Qué buscar):**
- *Linux Cgroups memory limit implementation*
- *OOM Killer and Docker container exit code 137*
- *Docker PID and Network namespaces architecture*
- *Java JVM Cgroup awareness (UseContainerSupport)*

---

## 2. Redes Definidas por Software (SDN) y Modelo Zero Trust

**El Concepto Teórico:**
En infraestructuras modernas, la red física no importa; todo se enruta por software. El modelo **Zero Trust** (Confianza Cero) asume que la red interna ya está comprometida, por lo que ningún servicio debe confiar ciegamente en otro. A nivel técnico, esto se logra manipulando `iptables` (o `nftables`) a través de puentes virtuales (bridge interfaces).

**Aplicación Práctica (Tu Entorno):**
En tu Fase 2, dividimos la red plana en `mc-net` y `db-net`. Esto es una aplicación de *Zero Trust*. Si alguien descubre un *exploit* en un plugin defectuoso de tu Lobby (tomando control de ese contenedor), el asaltante estará encerrado en `mc-net`. A nivel de kernel, los `iptables` de Docker bloquearán matemáticamente cualquier intento de conexión hacia la IP de tu base de datos MariaDB, porque están en bridges distintos.

**Recursos Sugeridos (Qué buscar):**
- *Zero Trust Network Architecture (ZTNA) in Microservices*
- *Docker Bridge Network internals and iptables manipulation*
- *Linux virtual ethernet (veth) pairs*
- *East-West vs North-South traffic in Data Centers*

---

## 3. Cuellos de Botella de I/O, VFS y Persistencia de Datos

**El Concepto Teórico:**
Cuando una aplicación quiere guardar un archivo, no toca el disco duro directamente. Hace una llamada al sistema (Syscall) al **VFS (Virtual File System)** del Kernel. Si el disco es lento, el procesador se queda de brazos cruzados esperando que se complete la escritura. A este estado del procesador se le llama **I/O Wait**. Altos niveles de I/O Wait destruyen el rendimiento de toda la máquina.

**Aplicación Práctica (Tu Entorno):**
Al usar *Bind Mounts* (`./data:/data`), Docker tiene que traducir cada operación de lectura/escritura de Minecraft a través del sistema de archivos de tu sistema operativo anfitrión. En operaciones masivas (como la generación de *chunks* o consultas a PostgreSQL), esto genera *I/O Wait* y micro-cortes, causando que el mundo se corrompa. Migrar a *Named Volumes* (Fase 1) o usar discos en RAM (`tmpfs`) permite a Docker saltarse estas traducciones lentas, interactuando de forma más directa y segura con el Kernel.

**Recursos Sugeridos (Qué buscar):**
- *Linux VFS (Virtual File System) layers*
- *Understanding I/O Wait (iowait) CPU metric*
- *Docker Named Volumes overlay2 storage driver*
- *tmpfs ramdisk benefits and risks*

---

## 4. Escalabilidad Horizontal y Service Discovery

**El Concepto Teórico:**
Escalar verticalmente (darle 64GB de RAM a un solo servidor) tiene un límite físico e introduce cuellos de botella de un solo hilo (muy comunes en Minecraft). Escalar **horizontalmente** implica levantar 10 servidores pequeños. El reto de la ingeniería aquí es: si los contenedores son efímeros (nacen y mueren, cambiando de IP), ¿cómo sabe el enrutador central hacia dónde enviar a los usuarios? Esto se resuelve con **Service Discovery** (Descubrimiento de Servicios).

**Aplicación Práctica (Tu Entorno):**
En la Fase 4 y en la auditoría, abordamos el problema de `container_name: servidor-lobby`. Al eliminarlo, Docker puede levantar 3 lobbies en IPs aleatorias. Velocity, sin embargo, está configurado estáticamente. Aquí entra la teoría de microservicios: necesitas un "Registro de Servicios" (como RedisBungee). Cuando un Lobby nace, hace un POST a Redis diciendo "¡Existo, mi IP es X!". Velocity escucha a Redis y añade la IP a su balanceador de carga dinámico, completando el ciclo de escalabilidad elástica.

**Recursos Sugeridos (Qué buscar):**
- *Microservices Service Registry and Discovery pattern*
- *Round-Robin DNS vs Layer 7 Load Balancing*
- *Consul / Redis as a state store*
- *Ephemeral containers orchestration*

---

## 5. Tuning de Kernel, Afinamiento de Threads y Redes Asíncronas

**El Concepto Teórico:**
Históricamente, los servidores creaban un "Hilo" (Thread) en el procesador por cada usuario conectado (modelo bloqueante). Esto es insostenible para miles de conexiones. Los sistemas modernos usan I/O Asíncrono manejado por eventos a nivel de kernel (como **epoll** en Linux o **kqueue** en FreeBSD). Además, los lenguajes como Java sufren de interrupciones de milisegundos cuando su Recolector de Basura (Garbage Collector) limpia la memoria.

**Aplicación Práctica (Tu Entorno):**
La auditoría enfatiza que Velocity requiere `epoll` para disparar su *throughput* (rendimiento de red). Si corres Velocity en Alpine Linux, no usa `glibc`, por lo que pierde acceso a `epoll` nativo del kernel y recae en el sistema viejo y lento de Java. Por otro lado, usar los flags `-XX:+UseG1GC` (Garbage First Garbage Collector) afina el manejo de memoria en Java para evitar picos de "Stop-The-World" (donde el juego se congela por 2 segundos). Esto es crucial para mantener los 20 TPS (Ticks Per Second) impecables.

**Recursos Sugeridos (Qué buscar):**
- *Netty Native Transports (epoll vs kqueue)*
- *Event-driven non-blocking I/O (NIO) architecture*
- *Java JVM G1GC vs ZGC low latency tuning*
- *User-space vs Kernel-space context switching overhead*
