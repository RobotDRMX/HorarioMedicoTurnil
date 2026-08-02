# Autoevaluación contra la Lista de Cotejo — Evaluación 2

Alumno: Angel Fabián Gutiérrez Gómez
Materia: Desarrollo para Dispositivos Inteligentes · Cuatrimestre Mayo–Agosto 2026
Rúbrica de referencia: `DDI - Lista_Cotejo_Criterios_Evaluacion2.pdf`
Fecha de esta autoevaluación: 2026-08-01

## Cómo hice esta autoevaluación

Fui punto por punto de la lista de cotejo y revisé mi propio código para
confirmar, con archivo y número de línea, qué tengo cumplido, qué está a
medias y qué me falta. Uso Claude como verificador (uso aceptado número 2 de
la política de IA del curso): le pedí que leyera mi repositorio y me
señalara huecos contra la rúbrica; yo decidí qué corregir y en qué orden,
que es lo que documento en el resumen ejecutivo al final. El detalle de cómo
usé la IA en esta entrega está en `docs/DECLARACION_USO_IA.md`.

Uso estas etiquetas de estado en las tablas:

- Cumple — verificado en mi código actual.
- Parcial — existe pero no cumple el criterio literal (explico por qué).
- Falta — no lo he implementado.
- Verificar — no puedo confirmarlo solo leyendo código; necesito una
  ejecución en vivo, una compilación o una medición con hardware.

---

## SA.1.A — App wearable (Wear OS emulado) — 8 elementos

| # | Elemento | Estado | Evidencia |
|---|---|---|---|
| 1 | Proyecto Wear OS compila sin errores en emulador | Verificar | Ya lo compilé e instalé varias veces en sesiones anteriores de desarrollo (`gradlew assembleDebug` / `installDebug`), pero antes de la demo voy a repetir un build limpio para confirmarlo de nuevo. |
| 2 | Ícono de aplicación propio (no default) | Cumple | `wearable-app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml` + `drawable/ic_launcher_foreground.xml`: hice un glifo "HMT" propio, no dejé las densidades por default de Android Studio. Formato: adaptive icon vectorial (XML), no PNG plano — voy a anotar este formato así en mi reporte SA.6. |
| 3 | Simulador genera datos cada segundo | Parcial | `BluetoothLeService.kt:61` → `INTERVALO_MS = 3000L`. Mi intervalo real es de 3 segundos, no de 1. Tengo dos opciones: cambiarlo a `1000L` antes de la demo, o dejarlo así y justificar la desviación (throughput BLE, consumo de batería) directamente con el profesor. Todavía no decido cuál. |
| 4 | Al menos 3 tipos de datos generados | Cumple | Genero `turno`, `ritmoCardiacoBpm`, `oxigenacionPorcentaje` y `temperaturaCorporal` — 4 métricas (`MainActivity.kt:129-144`). |
| 5 | Pantalla del wearable muestra datos localmente en tiempo real | Cumple | `MainActivity.kt:124-160`: en pantalla se ven turno, ritmo, SpO2, temperatura, prioridad y estado de sincronización. |
| 6 | Botón Iniciar/Detener controla la generación | Cumple | `MainActivity.kt:169-174` (`BluetoothLeService.alternarSimulacion()`). |
| 7 | Características GATT con NOTIFY (no solo WRITE) | Cumple | `BluetoothLeService.kt:217-221` (`PROPERTY_READ or PROPERTY_NOTIFY`); notificación real en `:349-353` (`notifyCharacteristicChanged`). |
| 8 | UUIDs como constantes compartidas | Parcial | Los valores son idénticos en el wearable (`BluetoothLeService.kt:56-57`) y en el móvil (`ble_service.dart:10-11`), pero no los tengo en un archivo realmente compartido — los dupliqué a mano en ambos proyectos. Cumple el espíritu, no la letra: si algún día cambio un UUID solo de un lado, se rompe la conexión sin que el compilador me avise. |

Subtotal que me sale: 5 de 8 claramente cumplidos, 2 parciales, 1 pendiente de verificar de nuevo antes de la demo. Mínimo que exige la rúbrica para SA: 7/8.

---

## SA.1.B — App teléfono: recepción y visualización — 8 elementos

| # | Elemento | Estado | Evidencia |
|---|---|---|---|
| 1 | BleClient escanea por serviceUUID | Cumple | `ble_service.dart:85-88` (`FlutterBluePlus.startScan(withServices: [HmtBleUuids.serviceUuid], ...)`). |
| 2 | Suscripción NOTIFY activa | Cumple | `ble_service.dart:116-123` (`setNotifyValue(true)`, `lastValueStream.listen`). |
| 3 | Bytes parseados por tipo | Cumple | `ble_service.dart:137-159` (`_decodificarPayload`). |
| 4 | Provider acumula datos y notifica UI | Cumple | `main.dart:117-149` (cliente Socket.IO + estado compartido con la UI). |
| 5 | Widget muestra mínimo 3 métricas en tiempo real | Cumple | Mi tarjeta de turno muestra turno, espera, ritmo, SpO2 y temperatura (`_TarjetaTurno` en `main.dart`). |
| 6 | Alerta visible sobre umbral crítico | Cumple | `main.dart:16` (`umbralAlertaSegundos = 900`), disparo en `:271-273`, UI en `:286-331`. |
| 7 | UI muestra estado de conexión BLE | Cumple | Enum `EstadoConexionBle` (`ble_service.dart:36`) mapeado en `main.dart:333-344`. |
| 8 | Al desconectar, no crashea | Verificar | Todavía no tengo un `try/catch` explícito alrededor del stream de BLE que haya confirmado a fondo. Me falta desconectar el wearable a mitad de una sesión y confirmar que no salte ninguna excepción no capturada antes de dar esto por hecho. |

Subtotal que me sale: 7 de 8 cumplidos, 1 pendiente de probar. Mínimo exigido: 7/8 — lo alcanzo, siempre que la prueba de desconexión (#8) no me saque un crash.

---

## SA.2.A — PWA: estructura y configuración — 7 elementos

| # | Elemento | Estado | Evidencia |
|---|---|---|---|
| 1 | manifest.json: name/short_name/fullscreen/landscape | Cumple | `tv-pwa/manifest.json:2-3,7-8`. |
| 2 | Íconos 192x192 y 512x512 PNG con `purpose: any maskable` | Parcial | En `tv-pwa/icons/` tengo `icon-192.svg` e `icon-512.svg` — son SVG, no PNG. Además tengo `purpose` como `"maskable any"` (orden invertido respecto al que pide la rúbrica; funcionalmente es lo mismo, pero no es literal). Me falta exportar PNG reales de 192x192 y 512x512 y actualizar el manifest — es un requisito literal, así que lo voy a corregir antes de entregar. |
| 3 | Service worker registrado y activo | Cumple | `tv-pwa/app.js:47-49`. |
| 4 | Cache First estáticos / Network First datos | Cumple | `tv-pwa/sw.js:59-79` (cacheFirst), `:42-44,81-96` (networkFirst para `/health` y `/socket.io`). |
| 5 | Modo offline: carga estructura desde cache | Parcial | Mi service worker cachea los estáticos, pero no tengo una página `offline.html` dedicada — si no hay red, la app carga el shell cacheado pero puede que muestre errores de conexión de Socket.IO sin un mensaje amigable. Me falta probarlo con DevTools en modo offline para ver la experiencia real. |
| 6 | CSP en meta tag | Cumple | `tv-pwa/index.html:6-7` (`default-src 'self'; connect-src 'self' ws://localhost:3000 wss: https:; ...`). |
| 7 | `.gitignore` incluye `.env`; API key nunca en commit | Cumple, pendiente de repositorio | `.gitignore:1-18` excluye `.env`, `*.jks`, `*.keystore`, `*.p12`, `*.pfx`, `*.pem`, `*apikey*`, `*secret*`, `*credentials*`, `google-services.json`, `key.properties` y `local.properties` (patrón global). Ya confirmé que cubre todos mis archivos sensibles reales: `server/.env`, `mobile-app/android/horariomedicoturnil-release.jks`, `mobile-app/android/key.properties` y `wearable-app/local.properties`. Pero **todavía no inicializo el repositorio git**, así que este punto solo lo puedo verificar de verdad después de mi primer commit. |

Subtotal que me sale: 5 de 7 cumplidos, 2 parciales. Mínimo exigido: 6/7 — me falta resolver el punto de los íconos PNG para asegurarlo.

---

## SA.2.B — Layout 1920x1080 y diseño 10-foot — 7 elementos

| # | Elemento | Estado | Evidencia |
|---|---|---|---|
| 1 | Safe zone 5% (54px v / 96px h) | Parcial | `tv-pwa/styles.css:25` uso `padding: 5vh 5vw`, que es 5% relativo al viewport, no los 54px/96px absolutos que pide la rúbrica para 1920x1080 exacto. En esa resolución matemáticamente coincide (5% de 1080 = 54, 5% de 1920 = 96), así que en la práctica sí me da el mismo resultado si el viewport es exactamente 1920x1080. Me falta confirmarlo con DevTools en esa resolución exacta. |
| 2 | Sin scroll (`overflow: hidden`) | Cumple | `tv-pwa/styles.css:16-20`. |
| 3 | Grid mínimo 4 elementos en 2x2 | Cumple | Tengo 5 tarjetas en `tv-pwa/index.html:17-56`. |
| 4 | Tipografía dato principal >= 5rem (80px) | Cumple | `.value` → `5rem` (`styles.css:75`). |
| 5 | Etiqueta secundaria >= 2rem, detalle >= 1.5rem | Cumple | `.label` → `2rem` (`styles.css:66`); me falta revisar puntualmente el selector de "detalle". |
| 6 | Contraste WCAG AA (4.5:1) | Verificar | No lo puedo confirmar solo leyendo el CSS — voy a usar el verificador de contraste de Chrome DevTools o Lighthouse (que de todas formas necesito para DE.1) sobre mis colores reales `#2a5643`/`#d8ffad`. |
| 7 | Foco visible D-pad (borde/glow dorado) | Parcial | `styles.css:57-62`: mi foco usa `outline: 4px solid #2a5643` + `box-shadow #5b8a5f` (verde oscuro, no dorado). La rúbrica pide explícitamente "glow dorado" — es una diferencia de color, no de funcionalidad. Me falta decidir si ajusto al dorado literal o justifico mi paleta institucional propia ante el profesor. |

Subtotal que me sale: 4 de 7 cumplidos, 2 parciales, 1 pendiente de medir. Mínimo exigido: 6/7.

---

## SA.2.C — Navegación D-pad y datos reales — 8 elementos

| # | Elemento | Estado | Evidencia |
|---|---|---|---|
| 1 | Flechas mueven el foco | Cumple | `tv-pwa/app.js:94-110`. |
| 2 | Enter/OK selecciona y actualiza fondo multimedia | Cumple | `app.js:94-110` (`cards[focusIndex].click()`). |
| 3 | Lógica de límites (wrap-around) | Cumple | `app.js:72-77,85-88` (aritmética modular). |
| 4 | Mínimo 4 registros con datos reales de API | Cumple | Mis datos llegan vía Socket.IO `update` (`app.js:185-200`), no están mockeados. |
| 5 | Cada tarjeta con mínimo 3 campos relevantes | Cumple | Turno, tiempo de espera, historial, etc. en `index.html:17-56`. |
| 6 | Recurso multimedia cambia según selección | Verificar | Me falta confirmar manualmente que el video/imagen de fondo cambia al navegar entre tarjetas, no solo en la tarjeta 4. |
| 7 | Fallback visual si el recurso no carga | Cumple | `app.js:135-139` + `assets/fallback.svg`. |
| 8 | Info contextual en header (hora/fecha/proyecto) | Falta | No tengo reloj, fecha ni identificador de proyecto en el header (solo el banner oculto de simulación en `index.html:14`). Me falta agregar esto — es rápido: un `<div id="header-fecha">` actualizado con `setInterval` cada minuto. |

Subtotal que me sale: 6 de 8 cumplidos, 1 pendiente de verificar, 1 que me falta hacer. Mínimo exigido: 7/8 — no lo alcanzo hasta que agregue el header de fecha/hora.

---

## SA.3 — Integración del ecosistema (3 dispositivos) — 7 elementos

| # | Elemento | Estado | Evidencia |
|---|---|---|---|
| 1 | Teléfono muestra datos en tiempo real (P2.5) | Cumple | Vía Socket.IO, lo confirmé end-to-end en sesiones previas de desarrollo. |
| 2 | Wearable envía datos por BLE NOTIFY (P2.6) | Cumple | Ver SA.1.A #7. |
| 3 | PWA TV sincronizada con el teléfono (P3.3) | Cumple | `server/index.js` retransmite `update`/`telemetry` a todos los roles conectados. |
| 4 | Los 3 dispositivos simultáneos 5 min | Verificar | Esto lo tengo que demostrar en vivo — no lo puedo certificar solo desde el código. |
| 5 | README con instrucciones de los 3 proyectos | Cumple | Mi `README.md` ya documenta servidor, TV, móvil y wearable paso a paso. |
| 6 | Release v1.0 en GitHub con descripción | Falta | Todavía no puedo hacerlo: no tengo repositorio git. |
| 7 | Repositorio limpio sin API keys/.jks/.env | Falta, no verificable | No tengo repositorio git todavía. Mi `server/.env` real ya existe en disco — cuando inicialice git, tengo que confirmar que `.gitignore` lo excluye desde el primer commit (si lo agrego y luego lo quito, el secreto se queda igual en el historial). |

Subtotal que me sale: 4 de 7 cumplidos, 1 pendiente de demo en vivo, 2 bloqueados por no tener repositorio git todavía. Mínimo exigido: 6/7 — no lo alcanzo hasta que resuelva lo de git (ver abajo).

---

## SA.4 — Documentación de seguridad — 5 elementos

| # | Elemento | Estado | Evidencia |
|---|---|---|---|
| 1 | Validación de `event.origin` en BroadcastChannel | Cumple, no aplica literal | No uso BroadcastChannel en mi proyecto — toda mi comunicación pasa por Socket.IO con token de autenticación (`server/index.js:167-180`) y CORS restringido (`:24-29,33-44,60-69`), que es mi mecanismo real de origen/autenticación. Voy a documentar esta decisión explícitamente en mi entrega (ver `docs/SECURITY.md`) para que quede claro que no omití el punto, sino que mi arquitectura usa un canal distinto y ya autenticado. |
| 2 | Datos personales con base legal LFPDPPP | Cumple | Lo agregué en `docs/PRIVACY_POLICY.md`, secciones 2 y 3. |
| 3 | Aviso de privacidad (responsable, finalidad, ARCO) | Cumple | Puse mi nombre como responsable en `docs/PRIVACY_POLICY.md` sección 8; me falta agregar mi correo de contacto real. |
| 4 | Plan de retención de datos | Cumple | `docs/PRIVACY_POLICY.md` sección 6, y corregí ahí una imprecisión que tenía sobre el móvil (ver más abajo). |
| 5 | Checklist de seguridad PWA (CSP, HTTPS, SRI, origin) | Cumple | Lo armé en `docs/SECURITY.md`. |

Subtotal que me sale: 4 de 5 cumplidos, 1 con un pendiente menor (mi correo real). Mínimo exigido: 4/5 — lo alcanzo.

---

## SA.5 — Plan y reporte de pruebas — 8 elementos

Ver `docs/TEST_PLAN.md`, que expandí a 10 casos etiquetados P2.5/P2.6/P3.1-P3.4. Resumen:

| # | Elemento | Estado |
|---|---|---|
| 1 | Plan con mínimo 10 casos | Cumple (documento actualizado) |
| 2 | Prueba API/datos reales (P2.5) | Cumple, ya ejecutada (ver TEST_PLAN) |
| 3 | Prueba BLE NOTIFY (P2.6) | Verificar, pendiente con hardware real |
| 4 | Prueba D-pad (PWA) | Verificar, pendiente de confirmación interactiva |
| 5 | Prueba modo offline | Falta, no ejecutada todavía |
| 6 | Prueba de sincronización < 2s | Cumple, ejecutada (3.23 ms promedio) |
| 7 | Evidencia con mínimo 5 screenshots | Falta, no las he tomado |
| 8 | Documento firmado con fecha | Falta, me falta firmarlo |

Mínimo exigido: 7/8 — me faltan los screenshots y mi firma, que solo puedo poner yo.

---

## SA.6.A — Configuración de herramientas — 5 elementos

Ver `docs/CONFIGURACION_HERRAMIENTAS.md`, donde documenté salidas reales de
`flutter --version`, `dart --version`, `node --version` y `ffmpeg -version`
que corrí yo mismo en esta sesión. Me falta completar ahí la versión de
Android Studio y sus plugins (solo se ve desde la interfaz de Android
Studio, no desde la terminal) y los pasos de troubleshooting reales que haya
vivido.

Subtotal que me sale: 3 de 5 verificable por comando, 2 me faltan completar desde Android Studio.

## SA.6.B — Configuración de emuladores — 5 elementos

Esto no se puede verificar desde el código — depende de qué AVDs tenga
configurados en este momento (modelo, API level, RAM). Dejé la plantilla
lista en `docs/CONFIGURACION_HERRAMIENTAS.md` sección 2, con los espacios en
blanco que me faltan llenar con mis datos reales y mis capturas de pantalla.

Subtotal: 0 de 5 hasta que complete la plantilla con mis datos y capturas.

---

## Lo que tengo pendiente: no he inicializado el repositorio git

La rúbrica exige, como requisitos críticos con NA automático:

- `git log --all -S 'API_KEY' -- .` sin resultados.
- Ningún `.jks`/`.keystore` en `git ls-files`.
- `.env` no versionado.
- Release `v1.0` etiquetado en GitHub.

Ninguno de estos lo puedo verificar ni cumplir todavía porque mi proyecto no
tiene carpeta `.git`. Esto también me bloquea SA.3 #6 y #7 de arriba.

Antes de la demo me falta, en este orden:

1. Correr `git init` en la raíz del proyecto.
2. Confirmar que mi `.gitignore` ya excluye `.env`, `*.jks`, `*.keystore`
   (ya lo revisé y sí los excluye) antes de mi primer `git add`.
3. Hacer el primer commit.
4. Crear el repositorio en GitHub y hacer push.
5. Crear el Release `v1.0` con descripción de cambios.

Este paso lo tengo que decidir yo (repositorio público o privado, qué
cuenta de GitHub usar), así que no lo ejecuté todavía en esta sesión.

---

## Resumen ejecutivo — qué me falta para SA (80 pts)

Bloqueantes duros (sin esto, no llego a SA):
1. Inicializar mi repositorio git y hacer el primer commit + Release v1.0.
2. Tomar mis screenshots y firmar el plan de pruebas (SA.5).
3. Agregar el header con fecha/hora en la PWA (SA.2.C).

Gaps rápidos que puedo corregir en el código (~30 min cada uno):
4. Íconos PNG reales de 192x192/512x512 (SA.2.A).
5. Decidir sobre el intervalo del simulador wearable: 3s → cambiar a 1s o justificarlo (SA.1.A).
6. Verificar contraste WCAG y color de foco D-pad (SA.2.B).
7. Decidir si corrijo en la app móvil el historial para que expire por fecha (30 días) igual que la TV, o si dejo mi política de privacidad como está ahora, reflejando el comportamiento real (ya lo corregí en esta sesión).

Todo lo demás en SA.1.A, SA.1.B, SA.2.A/B/C y SA.3 ya lo tengo implementado
y citado arriba con evidencia de mi propio código.
