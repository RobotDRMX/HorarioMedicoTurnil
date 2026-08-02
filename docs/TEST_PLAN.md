# Plan de Pruebas - HorarioMedicoTurnil

Alumno: Angel Fabian Gutierrez Gomez

## 1. Objetivo

Verificar el correcto funcionamiento end-to-end del ecosistema HorarioMedicoTurnil:
Wearable (Wear OS) -> App Movil (Flutter) -> Servidor (Node.js) -> Smart TV (PWA).

Armo este plan para cubrir los casos que exige SA.5/DE.3 de la rubrica de
Evaluacion 2: P2.5 (API/datos en tiempo real en el movil), P2.6 (BLE
NOTIFY), y P3.1-P3.4 (PWA: navegacion D-pad, modo offline, sincronizacion,
fallback de recursos). Son **7 casos numerados** (CP-01 a CP-07) mas **3
casos adicionales de auditoria** (seccion 3) — **10 casos en total**,
con lo que cumplo el minimo que exige SA.5.

**Nota de interpretacion sobre P2.5**: mi app movil no consume una API REST
via `http`/`https` (lo confirme: no hay uso del paquete `http` en mi
codigo) — mi flujo de datos en tiempo real usa Socket.IO/BLE en su lugar.
CP-02 cubre el manejo de error de red equivalente para ese canal. Si el
profesor exige literalmente una llamada REST, es un gap de arquitectura que
tengo que discutir con el, no de pruebas.

## 2. Casos de prueba

### CP-01 (P2.6): Conexion BLE (Wearable <-> App Movil)

| Campo | Detalle |
|---|---|
| Precondicion | Wearable con el servicio BLE activo (advertising habilitado). App movil con Bluetooth y permisos concedidos. |
| Pasos | 1. Abrir la app movil.<br>2. Pulsar "Escanear y Conectar".<br>3. Verificar que se descubre el dispositivo por `SERVICE_UUID`.<br>4. Verificar conexion y suscripcion NOTIFY a `CHARACTERISTIC_UUID`. |
| Resultado esperado | Estado pasa de "Escaneando..." a "Conectado". Se reciben notificaciones cada 3 segundos con turno y tiempo de espera. |
| Criterio de exito | 100% de las notificaciones emitidas por el wearable llegan a la app movil sin corrupcion de payload. |

### CP-02 (P2.5): Caida del servidor / manejo de error de red

| Campo | Detalle |
|---|---|
| Precondicion | App movil conectada al wearable y al servidor Socket.IO. |
| Pasos | 1. Detener el proceso del servidor (`Ctrl+C` en `/server`).<br>2. Observar el comportamiento de la app movil.<br>3. Reiniciar el servidor. |
| Resultado esperado | La app movil captura el evento `connect_error`/`disconnect` sin crashear y sigue mostrando el ultimo turno recibido localmente. Al reiniciar el servidor, Socket.IO reconecta automaticamente y la TV vuelve a recibir actualizaciones. |
| Criterio de exito | Cero crashes en la app movil. Reconexion automatica en menos de 10 segundos tras restaurar el servidor. |

### CP-03: Umbral de alerta (>= 900 segundos)

| Campo | Detalle |
|---|---|
| Precondicion | App movil conectada y recibiendo telemetria. |
| Pasos | 1. Forzar (o esperar) que el wearable emita un `tiempoEsperaSegundos >= 900`.<br>2. Observar la UI de la app movil. |
| Resultado esperado | Se reproduce el sonido de alerta, se muestra un Snackbar y un dialogo con fondo `#d8ffad`/blanco y texto `#2a5643` indicando el turno afectado. En la TV, la tarjeta de tiempo de espera aplica la clase `.alerta` (parpadeo). |
| Criterio de exito | La alerta se dispara en el 100% de los eventos donde `tiempoEsperaSegundos >= 900`, y no se dispara por debajo del umbral. |

### CP-04 (P3.1): Navegacion por teclado en la TV (D-pad)

| Campo | Detalle |
|---|---|
| Precondicion | PWA cargada en la Smart TV (o navegador con teclado), grid 2x2 visible. |
| Pasos | 1. Presionar `ArrowRight`/`ArrowLeft`/`ArrowUp`/`ArrowDown` repetidamente.<br>2. Verificar que el foco se mueve entre las 4 tarjetas.<br>3. Continuar presionando en una direccion hasta superar el limite del grid (wrap-around).<br>4. Presionar `Enter` sobre la Tarjeta 4 (video). |
| Resultado esperado | El foco visual (`outline: 4px solid #2a5643` + `box-shadow #5b8a5f`) es claramente visible en todo momento. Al llegar al borde del grid, el foco regresa al extremo opuesto (wrap-around). `Enter` dispara el `click` de la tarjeta enfocada y carga el video de forma perezosa. |
| Criterio de exito | Navegacion 100% funcional solo con teclado, sin necesidad de mouse/touch. |

### CP-05 (P3.3): Tiempo de sincronizacion (Movil -> Servidor -> TV)

| Campo | Detalle |
|---|---|
| Precondicion | Servidor, App Movil y TV conectados simultaneamente. |
| Pasos | 1. Registrar el timestamp en el que la app movil emite `telemetry`.<br>2. Registrar el timestamp en el que la TV recibe `update` y actualiza el DOM.<br>3. Calcular la diferencia. |
| Resultado esperado | La diferencia entre ambos timestamps es **menor a 1 segundo**, cumpliendo el requisito de latencia en tiempo real. |
| Criterio de exito | Latencia promedio < 1000 ms en al menos 10 mediciones consecutivas. |

### CP-06 (P3.2): Modo offline (Service Worker)

| Campo | Detalle |
|---|---|
| Precondicion | PWA cargada al menos una vez con red disponible (para que el SW cachee el shell). |
| Pasos | 1. Abrir Chrome DevTools -> Network -> marcar "Offline".<br>2. Recargar la pagina de la TV.<br>3. Observar si carga el shell desde cache y como se comporta la conexion Socket.IO (que si requiere red). |
| Resultado esperado | La estructura estatica (HTML/CSS/JS) carga desde cache gracias a la estrategia Cache First (`tv-pwa/sw.js`). Los datos en tiempo real no se actualizan (esperado, requieren red), pero la app no muestra una pantalla en blanco ni un error no controlado. |
| Criterio de exito | La app sigue siendo visualmente utilizable sin red; no hay crash ni pantalla en blanco. |
| Estado | Pendiente de ejecucion — todavia no corro esta prueba. No tengo una pagina `offline.html` dedicada (ver `docs/RUBRICA_AUTOEVALUACION.md`, SA.2.A), asi que el resultado real puede diferir de lo esperado; me falta ejecutarla antes de la demo. |

### CP-07 (P3.4): Fallback de video de fondo si no carga

| Campo | Detalle |
|---|---|
| Precondicion | PWA cargada, Tarjeta 4 (video) visible. |
| Pasos | 1. Renombrar o eliminar temporalmente `tv-pwa/assets/sample-video.mp4`.<br>2. Recargar la PWA y navegar hasta la tarjeta de video.<br>3. Confirmar que se muestra `fallback.svg` en vez de un reproductor roto. |
| Resultado esperado | El listener de error del elemento `<video>` (`tv-pwa/app.js:135-139`) reemplaza el video por `assets/fallback.svg` automaticamente. |
| Criterio de exito | Nunca se muestra un reproductor de video roto o un espacio en blanco; siempre hay una imagen de respaldo. |
| Estado | Pendiente de ejecucion — el codigo del fallback ya existe y lo verifique leyendolo, pero todavia no lo disparo en vivo. Me falta restaurar el archivo de video despues de hacer la prueba. |

## 3. Casos adicionales de auditoria

- **Autolimpieza de 30 dias (TV)**: modificar manualmente `hmt_install_date` en
  `localStorage` a un valor mayor a 30 dias atras, recargar la app y confirmar
  que `localStorage.clear()` se ejecuta y la clave se reinicia.
- **Validacion de token (Servidor)**: intentar conectar un cliente Socket.IO sin
  `token` o con un token incorrecto y confirmar que la conexion es rechazada
  (evento `connect_error` con mensaje `AUTH_ERROR`).
- **Validacion de origen CORS**: intentar una peticion HTTP `GET /health` desde
  un origen no incluido en la lista blanca y confirmar que es bloqueada.

## 4. Resultados de ejecucion que ya registre

### CP-02: Caida del servidor - EJECUTADO (2026-07-21)

Conecte un cliente real con rol `mobile` al servidor, mate el proceso
del servidor (`Stop-Process -Force`) para simular una caida, y lo reinicie.

```
02:24:49.995Z CONNECT (id=KxQyM3Ia82pzONp1AAAT)
02:24:53.978Z DISCONNECT detectado, razon: transport close
02:24:54.576Z connect_error (esperado mientras el server esta caido): xhr poll error
02:24:55.150Z connect_error (esperado mientras el server esta caido): xhr poll error
02:24:56.674Z connect_error (esperado mientras el server esta caido): xhr poll error
02:25:01.424Z CONNECT (id=UM7AweyRmbe9hN2OAAAD)
```

**Resultado**: cero crashes del cliente durante la caida; reconexion automatica
exitosa en **7.45s** despues de restaurar el servidor (menos de los 10s que exige la rubrica). **Cumple**.

### CP-05: Tiempo de sincronizacion - EJECUTADO (2026-07-21)

Medi con `process.hrtime.bigint()` el tiempo entre la emision de
`telemetry` (rol `mobile`) y la recepcion de `update` (rol `tv`) en 10
mediciones consecutivas contra el servidor real:

```
Mediciones (ms): 4.0, 1.3, 2.1, 2.0, 1.9, 1.9, 14.3, 1.9, 1.1, 1.8
Promedio: 3.23 ms
Maxima:   14.29 ms
```

**Resultado**: el promedio quedo muy por debajo de los 1000 ms que exige la rubrica. **Cumple**.

### Lo que me falta ejecutar con hardware fisico

- CP-01 (BLE real Wearable <-> Movil): no lo he ejecutado formalmente por
  falta de un wearable/ESP32 fisico disponible; en su lugar valide el
  pipeline completo Movil -> Servidor -> TV usando el boton "Simular
  wearable" de mi app (ver README, seccion 3), que reutiliza el mismo
  codigo de recepcion, persistencia, alerta de umbral y emision Socket.IO
  que usaria un dato BLE real.
- CP-03 (umbral de alerta): lo confirme manualmente en mi telefono fisico
  (Samsung SM A556E, Android 16) usando la simulacion de wearable: se
  disparo correctamente el Snackbar/Dialog para un turno con
  `tiempoEsperaSegundos = 1309` (mayor o igual a 900).
- CP-04 (navegacion D-pad en TV): me falta confirmarlo de forma interactiva
  en el navegador siguiendo los pasos de la tabla.
- CP-06 (modo offline) y CP-07 (fallback de video): todavia no las ejecuto
  (ver detalle en cada caso arriba).

## 5. Evidencia y firma (requisito SA.5)

La rubrica exige minimo 5 capturas de pantalla mostrando los 3 dispositivos
funcionando, y que yo firme el documento con fecha. No genere ninguna de
las dos cosas en esta sesion de documentacion porque serian evidencia falsa
si no corresponden a una ejecucion real que yo mismo haya presenciado (la
politica de uso de IA del curso prohibe explicitamente "IA como evidencia
falsa").

- [ ] Captura 1: wearable mostrando datos en pantalla.
- [ ] Captura 2: app movil mostrando el turno actual y las metricas.
- [ ] Captura 3: Smart TV (PWA) mostrando el grid con datos reales.
- [ ] Captura 4: los 3 dispositivos visibles a la vez (o en secuencia con timestamps cercanos).
- [ ] Captura 5: consola/log del servidor mostrando los eventos en transito.

Me falta poner las capturas en `docs/evidencia/` y enlazarlas aqui antes de entregar.

---

**Firma**: ___________________________
**Fecha**: ___________________________

Angel Fabian Gutierrez Gomez — firma pendiente, me falta ponerla antes de entregar.
