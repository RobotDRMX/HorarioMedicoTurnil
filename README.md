# HorarioMedicoTurnil

Ecosistema multiplataforma para sala de espera medica: un **Wearable** (Wear OS)
simula un sensor de turnos y lo transmite por **Bluetooth Low Energy (BLE)** a
una **App Movil** (Flutter), que reenvia los datos en tiempo real a un
**Servidor** (Node.js + Socket.IO), el cual los distribuye a un **Dashboard de
Smart TV** (PWA) para que los pacientes vean su turno en pantalla.

```
Wearable (Kotlin/BLE GATT) --NOTIFY--> App Movil (Flutter)
                                            |
                                      Socket.IO 'telemetry'
                                            v
                                 Servidor (Node.js + Socket.IO)
                                            |
                                       io.emit('update')
                                            v
                                   Smart TV (PWA, grid 2x2)
```

## Estructura del proyecto

```
/server         Backend Node.js + Socket.IO (puente Movil <-> TV)
/tv-pwa         Progressive Web App para Smart TV (diseño 10-foot)
/mobile-app     App Flutter (escaneo BLE + cliente Socket.IO)
/wearable-app   App Wear OS en Kotlin (servidor GATT simulado)
/docs           Politica de privacidad y plan de pruebas
```

## Paleta de colores oficial

| Uso | Color |
|---|---|
| Texto principal / bordes | `#2a5643` |
| Texto secundario | `#3a674b` |
| Acentos / botones / foco (glow) | `#5b8a5f` |
| Fondo de tarjetas | `#8cbd7f` |
| Fondo general de la app | `#d8ffad` |

---

## Instrucciones de instalacion y ejecucion (paso a paso)

Ejecuta cada componente **uno por uno** para no saturar el dispositivo, en el
siguiente orden:

### 1. Servidor (Node.js)

```bash
cd server
cp .env.example .env      # ajusta PORT y SECRET_TOKEN si lo necesitas
npm install
npm start
```

El servidor queda escuchando en `http://localhost:3000` y expone:
- `GET /health` -> estado del servicio.
- Socket.IO en la misma URL, exigiendo `?token=<SECRET_TOKEN>` en la conexion.

Verifica que este corriendo antes de continuar (`curl http://localhost:3000/health`).

### 2. Smart TV (PWA)

**CRITICO:** el Service Worker (`sw.js`) solo se registra correctamente sobre
**HTTPS** (o `localhost`, que el navegador trata como origen seguro). Para
servir la PWA localmente:

```bash
cd tv-pwa
npx serve -l 8080 -S .
# o alternativamente, para exponerla por HTTPS publico:
# ngrok http 8080
```

Abre `http://localhost:8080` (o la URL de `ngrok`) en el navegador de la Smart
TV o en un navegador de escritorio en modo landscape. La app se conecta
automaticamente al servidor en `http://<host>:3000`.

Antes de continuar, agrega un video real en `tv-pwa/assets/sample-video.mp4`
(ver `tv-pwa/assets/sample-video.README.txt` para el comando `ffmpeg` sugerido:
1080p, H.264, `faststart`, < 5MB). Si el archivo no existe o falla, la Tarjeta
4 muestra automaticamente `fallback.svg`.

### 3. App Movil (Flutter) - en un telefono Android real

El codigo fuente esta en `/mobile-app`. Para ejecutarlo en tu telefono fisico:

```bash
# Si es la primera vez, genera el scaffold nativo de Flutter en un directorio
# temporal y copia lib/, pubspec.yaml y android/app/src/main/AndroidManifest.xml
# sobre el:
flutter create --org com.horariomedicoturnil temp_scaffold
# copia mobile-app/lib, mobile-app/pubspec.yaml y el AndroidManifest.xml provistos

cd mobile-app
flutter pub get
```

1. Conecta el telefono por USB con **Depuracion USB** activada (o usa
   depuracion inalambrica: `Ajustes > Opciones de desarrollador > Depuracion
   inalambrica`), y confirma que aparece con `flutter devices` o `adb devices`.
2. Asegurate de que el telefono este en la **misma red Wi-Fi** que el PC donde
   corre `/server`.
3. Ejecuta `flutter run` y selecciona el telefono en la lista.
4. En la app, en el campo **"Servidor (http://IP-de-tu-PC:3000)"** escribe la
   IP LAN real de tu PC (ejemplo: `http://192.168.0.218:3000`, visible con
   `ipconfig` en Windows) y pulsa **Conectar**. El indicador "Servidor:
   Conectado" confirma el enlace real por WebSocket con `/server`.

#### Sin un wearable/ESP32 fisico: boton "Simular wearable"

BLE requiere hardware real en ambos extremos (el telefono no puede escanear
un periferico BLE si nadie lo esta anunciando). Si no tienes un reloj Wear OS
ni una placa ESP32 a mano, usa el boton **"Simular wearable (sin hardware
BLE)"** en la pantalla principal: genera un turno cada 3 segundos con el
mismo formato y rango (300-1500s) que emitiria el servicio GATT real, y lo
envia por el **mismo pipeline real** (persistencia en `SharedPreferences`,
alerta de umbral, y `emit('telemetry', ...)` por Socket.IO real hacia tu
servidor). Es decir: solo el salto BLE Wearable -> Movil es simulado; todo lo
demas (Movil -> Servidor -> TV) es una conexion de red genuina.

Si mas adelante consigues un reloj Wear OS o una placa ESP32, sigue la
seccion 4 para reemplazar esa simulacion por BLE real, sin cambiar nada del
Movil, el Servidor ni la TV.

> Recomendacion de recursos: si tambien quieres usar un emulador Android en
> vez del telefono fisico, usa un AVD con imagen `Google APIs` (sin Google
> Play) y perfil "Pixel" de gama baja. Ten en cuenta que los emuladores no
> soportan BLE real, por lo que el escaneo del wearable nunca encontrara un
> dispositivo real desde un emulador (usa siempre el boton de simulacion en
> ese caso).

#### Build de release firmado (APK de produccion)

`flutter run` solo genera un build de **debug**. Para un APK de **release**
firmado (no con la firma de debug de Android):

```bash
cd mobile-app/android
keytool -genkeypair -v -keystore horariomedicoturnil-release.jks \
  -alias horariomedicoturnil -keyalg RSA -keysize 2048 -validity 10000 \
  -storepass TU_PASSWORD -keypass TU_PASSWORD \
  -dname "CN=HorarioMedicoTurnil, OU=Academico, O=HorarioMedicoTurnil, L=CDMX, ST=CDMX, C=MX"
```

Crea `mobile-app/android/key.properties` (ya excluido en `.gitignore`, nunca
lo subas a un repositorio):

```
storePassword=TU_PASSWORD
keyPassword=TU_PASSWORD
keyAlias=horariomedicoturnil
storeFile=horariomedicoturnil-release.jks
```

`android/app/build.gradle.kts` ya esta configurado para leer este archivo y
firmar el `buildType release` con el (si no existe, cae de vuelta a la firma
de debug para que `flutter run --release` no se rompa). Luego compila:

```bash
cd mobile-app
flutter build apk --release
```

El APK queda en `build/app/outputs/flutter-apk/app-release.apk`. Para
confirmar que quedo firmado con tu certificado (y no con el de debug):

```bash
"$ANDROID_HOME/build-tools/<version>/apksigner" verify --print-certs -v app-release.apk
```

Debe mostrar `Verifies` y el `Signer #1 certificate DN` con los datos que
pusiste en `-dname`. Este keystore es para pruebas/entrega academica; para
publicar en Play Store se recomienda generar uno propio y resguardarlo con
mas cuidado (contraseña fuerte, backup seguro).

### 4. Wearable (Wear OS)

El codigo fuente esta en `/wearable-app`. Para ejecutarlo:

1. Abre Android Studio -> `New Project` -> plantilla **Wear OS** (o crea un
   proyecto vacio con `minSdk 28`).
2. Reemplaza `AndroidManifest.xml`, `build.gradle`, `settings.gradle` y el
   contenido de `src/main/java` y `src/main/res` con los archivos de esta
   carpeta.
3. Crea/ejecuta un **AVD de Wear OS** (ej. "Wear OS Small Round") desde el
   Device Manager. Prefiere la imagen mas ligera disponible (Wear OS 4, sin
   Google Play) para minimizar el consumo de recursos.
4. Ejecuta la app (`Run`). Veras el texto "Servicio BLE Activo -
   HorarioMedicoTurnil" y el `BluetoothLeService` comenzara a emitir turnos
   simulados cada 3 segundos.

> Nota: los emuladores de Android/Wear OS no soportan BLE real entre dos
> instancias virtuales. Para probar la conexion BLE de extremo a extremo se
> recomienda usar al menos un dispositivo fisico (telefono o reloj) con
> Bluetooth.

---

## Seguridad implementada

- **CORS** restringido a los origenes configurados de la TV y el Movil (`/server/index.js`).
- **Token de autenticacion** obligatorio en el handshake de Socket.IO (`?token=...`), validado contra `SECRET_TOKEN`.
- **CSP restrictiva** en la PWA (`tv-pwa/index.html`): `script-src 'self'` sin `unsafe-inline`; el cliente de Socket.IO se sirve localmente desde `tv-pwa/vendor/` (sin CDN externo).
- **Autolimpieza de datos**: la TV borra `localStorage` automaticamente a los 30 dias (`tv-pwa/app.js`), y la app movil conserva solo los ultimos 10 turnos en `SharedPreferences`.

## Notas tecnicas

- El JS de la TV esta escrito en sintaxis ES6 (sin `#private` fields ni
  caracteristicas ES2022+); `tv-pwa/babel.config.json` esta listo para
  transpilar con Babel si el navegador objetivo lo requiere. Verificalo con
  `cd tv-pwa && npm install && npm run transpile:check` (confirma que
  `app.js`/`sw.js` pasan por Babel sin errores y sin necesitar transformacion,
  lo que prueba que no usan sintaxis mas nueva que ES6).
- El Service Worker usa **Cache First** para estaticos y **Network First**
  para llamadas al servidor (`tv-pwa/sw.js`), escrito a mano sin dependencias
  externas.
- Los UUIDs de servicio/caracteristica BLE (`12345678-...` /
  `87654321-...`) son identicos en `mobile-app/lib/ble_service.dart` y
  `wearable-app/.../BluetoothLeService.kt`; si los cambias, actualizalos en
  ambos lados.

## Documentacion adicional

Proyecto de Angel Fabian Gutierrez Gomez para la materia Desarrollo para
Dispositivos Inteligentes (UTEQ). Ademas de este README, arme estos
documentos para cubrir la rubrica de Evaluacion 2:

- [`docs/RUBRICA_AUTOEVALUACION.md`](docs/RUBRICA_AUTOEVALUACION.md) - mi autoevaluacion item por item contra la lista de cotejo de Evaluacion 2, con cita de codigo por cada punto y resumen de que me falta para SA/DE/AU.
- [`docs/CONFIGURACION_HERRAMIENTAS.md`](docs/CONFIGURACION_HERRAMIENTAS.md) - versiones de Flutter/Dart/Node/ffmpeg que uso y configuracion de mis emuladores (SA.6).
- [`docs/SECURITY.md`](docs/SECURITY.md) - mi checklist de seguridad de la PWA (CSP, HTTPS, SRI, autenticacion/origin) (SA.4).
- [`docs/PRIVACY_POLICY.md`](docs/PRIVACY_POLICY.md) - mi politica de privacidad, base legal LFPDPPP, derechos ARCO y retencion de datos.
- [`docs/TEST_PLAN.md`](docs/TEST_PLAN.md) - mi plan de pruebas (10 casos): BLE, caida del servidor, umbral de alerta, navegacion TV, offline, fallback de video, latencia < 1s.
- [`docs/DECLARACION_USO_IA.md`](docs/DECLARACION_USO_IA.md) - plantilla que uso para declarar el uso de IA en cada entregable.
- [`docs/BITACORA_TEMPLATE.md`](docs/BITACORA_TEMPLATE.md) - plantilla de mi bitacora de proceso (la lleno yo por practica).

### Lo que tengo pendiente como bloqueante critico

Todavia no inicializo este proyecto como repositorio git (no existe carpeta
`.git`). Varios requisitos criticos de la rubrica de Evaluacion 2 (verificar
que `.env`/`.jks` nunca esten en el historial, Release `v1.0` en GitHub) no
los puedo cumplir hasta que haga `git init` + primer commit + push. Ver el
detalle en `docs/RUBRICA_AUTOEVALUACION.md`, seccion "Lo que tengo
pendiente: no he inicializado el repositorio git".
