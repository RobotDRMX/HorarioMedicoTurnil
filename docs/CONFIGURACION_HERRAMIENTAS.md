# Reporte de Configuración de Herramientas y Emuladores

Alumno: Angel Fabián Gutiérrez Gómez
Materia: Desarrollo para Dispositivos Inteligentes

Este reporte lo exige SA.6 de la rúbrica de Evaluación 2, tanto para la
Unidad de Wearables como para la de Pantallas Inteligentes.

## 1. Configuración de herramientas (SA.6.A)

### 1.1 Versiones de SDK (salida real de mi terminal, 2026-08-01)

```
$ flutter --version
Flutter 3.44.0 • channel stable • https://github.com/flutter/flutter.git
Framework • revision 559ffa3f75 (3 months ago) • 2026-05-15 14:13:13 -0700
Engine • hash fcf463a2242790d1fdcd9d044f533080f5022e18 (revision 4c525dac5e) (2 months ago) • 2026-05-15 19:00:04.000Z
Tools • Dart 3.12.0 • DevTools 2.57.0

$ dart --version
Dart SDK version: 3.12.0 (stable) (Fri May 8 01:51:14 2026 -0700) on "windows_x64"

$ node --version
v22.22.0

$ npm --version
11.17.0

$ ffmpeg -version
ffmpeg version 8.1.2-full_build-www.gyan.dev
```

### 1.2 Android Studio y plugins

Esto todavía me falta completarlo: la versión de Android Studio y la lista
de plugins instalados solo se ven desde `Android Studio → Help → About` y
`Settings → Plugins`, no desde la terminal, así que lo dejo con espacios en
blanco para llenar con mis datos reales en vez de inventarlos:

- Versión de Android Studio: ___
- Plugin Flutter: versión ___
- Plugin Dart: versión ___
- Android SDK Platform instalado: API ___ (Android ___)
- Android SDK Build-Tools: ___

### 1.3 Herramientas de la Unidad 3 (PWA / Smart TV)

- VS Code: versión ___ (`code --version`)
- Extensiones que usé para desarrollar la PWA: ___ (las que realmente usé, por ejemplo Live Server, ESLint, Prettier)
- ffmpeg: `8.1.2-full_build` (confirmado arriba) — lo uso para comprimir el video de fondo de la TV (ver `tv-pwa/assets/sample-video.README.txt` para el comando exacto que utilicé).
- Servidor estático de desarrollo: `npx serve` (paquete `serve`).

### 1.4 Dependencias clave de mi proyecto (con versión, de `pubspec.yaml`)

```yaml
flutter_blue_plus: ^1.32.11   # escaneo/conexión BLE
socket_io_client: ^2.0.3+1    # cliente WebSocket hacia /server
shared_preferences: ^2.2.2    # historial local en el teléfono
audioplayers: ^6.0.0          # sonido de alerta de umbral
lottie: ^3.5.1                # microinteracción del botón de simulación
cupertino_icons: ^1.0.6
```

Backend (`server/package.json` — me falta completar con `npm ls --depth=0` dentro de `/server`):

```
$ cd server && npm ls --depth=0
___   # pego aquí mi salida real
```

### 1.5 Pasos de instalación reproducibles

Ya los documenté con detalle en mi [`README.md`](../README.md), en la
sección "Instrucciones de instalación y ejecución (paso a paso)": cubre
servidor, PWA, app móvil (incluye el build de release firmado) y wearable,
en orden, con los comandos exactos. Ese README es el artefacto que otro
alumno necesitaría para replicar mi entorno, así que no lo repito aquí, solo
lo referencio:

> Ver [`README.md`](../README.md) secciones 1-4.

---

## 2. Configuración de emuladores (SA.6.B)

Esta sección depende de qué AVDs tenga activos en el momento de la demo. Me
falta llenar los espacios en blanco con mis valores reales (los veo en
`Android Studio → Device Manager`) y agregar mis capturas de pantalla antes
de entregar.

### 2.1 Emulador de teléfono

- Modelo: ___ (por ejemplo, Pixel 6)
- API level: ___
- RAM asignada: ___ MB
- Imagen del sistema: ___ (Google APIs / Google Play)

### 2.2 Emulador Wear OS

- Forma: ___ (round / square)
- API level: ___
- RAM asignada: ___ MB

Ya sé, por experiencia propia desarrollando este proyecto, que los
emuladores de Android/Wear OS no soportan BLE real entre dos instancias
virtuales — para probar BLE de extremo a extremo necesito al menos un
dispositivo físico.

### 2.3 Emulación de TV en Chrome DevTools

- Resolución que usé: `1920x1080` (para validar el layout 10-foot de `tv-pwa`).
- User agent que usé: ___ (opcional; si usé alguno específico de Smart TV lo anoto, si no, uso el que trae Chrome por defecto en modo responsive).

### 2.4 Capturas de pantalla de cada emulador

- [ ] Teléfono corriendo mi app — agregar la imagen en `docs/evidencia/`.
- [ ] Wear OS corriendo mi app — agregar la imagen en `docs/evidencia/`.
- [ ] Chrome DevTools en 1920x1080 con la PWA — agregar la imagen en `docs/evidencia/`.

No generé estas capturas en esta sesión de documentación porque no
corresponderían a una ejecución real que yo haya presenciado en ese momento
— sería evidencia falsa. Las voy a generar yo mismo con
`adb exec-out screencap` o directamente desde el emulador y las voy a poner
en `docs/evidencia/`.

### 2.5 Problemas de configuración que encontré y cómo los resolví

Del historial real de desarrollo de mi proyecto, dos problemas que ya
resolví y puedo citar tal cual:

1. Botón inalcanzable en el wearable: en el emulador Wear OS (pantalla
   redonda de 384x384), el `Column` de `MainActivity.kt` no tenía scroll y
   el contenido quedaba recortado fuera del área visible. Lo resolví
   agregando `Modifier.verticalScroll(rememberScrollState())` al `Column`
   (`MainActivity.kt:118-121`).
2. `EADDRINUSE` al reiniciar el servidor: en Windows, detener el proceso
   del servidor desde una tarea en segundo plano no siempre mata el
   proceso `node.exe` subyacente. Lo resolví buscando el PID con
   `netstat -ano | findstr :3000` y matándolo con `taskkill /PID <pid> /F`.

Aquí voy a agregar cualquier otro problema que encuentre al volver a montar
el entorno desde cero antes de la demo.
