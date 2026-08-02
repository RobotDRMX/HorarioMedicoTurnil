# Checklist de Seguridad — HorarioMedicoTurnil

Alumno: Angel Fabián Gutiérrez Gómez

Esto cubre SA.4 de la rúbrica de Evaluación 2. Cada punto cita el código
real de mi proyecto que lo implementa; no pongo afirmaciones sin evidencia.

## 1. Validación de origen del canal en tiempo real

La rúbrica pide "validación de `event.origin` en BroadcastChannel". En mi
proyecto no uso BroadcastChannel (esa API sirve para pestañas del mismo
origen en el mismo navegador) — uso Socket.IO sobre WebSocket entre los
tres roles (`tv`, `mobile`, `wearable`) a través de un servidor central,
que es la elección de arquitectura correcta para sincronizar dispositivos
distintos en la misma red, no pestañas del mismo navegador.

El control equivalente en mi arquitectura es autenticación más CORS en el
servidor, no validación de `origin` en el cliente:

- Token compartido obligatorio en el handshake de Socket.IO:
  `server/index.js:167-180` — mi middleware `io.use()` rechaza cualquier
  conexión donde `token !== SECRET_TOKEN`, y valida que `role` sea uno de
  `tv | mobile | wearable`. Una conexión sin token o con token incorrecto
  recibe `AUTH_ERROR`.
- CORS restringido a orígenes explícitos: `server/index.js:24-29` (lista
  blanca `TV_ORIGIN`, `MOBILE_ORIGIN` más variantes `127.0.0.1`), aplicado
  tanto a Express (`:33-44`) como a Socket.IO (`:60-69`).

Voy a documentar esto explícitamente en mi entrega (citando este archivo)
para que quede claro que no omití el punto: lo resolví con el mecanismo
apropiado para la arquitectura real de mi proyecto, no con BroadcastChannel.

## 2. Content Security Policy (CSP)

`tv-pwa/index.html:6-7`:

```
default-src 'self'; connect-src 'self' ws://localhost:3000 wss: https:; img-src 'self' data:; media-src 'self'; style-src 'self'; script-src 'self';
```

- Uso `script-src 'self'` sin `unsafe-inline`: mi cliente de Socket.IO se
  sirve localmente desde `tv-pwa/vendor/`, no desde un CDN externo — esto
  también hace innecesario un CDN con SRI (ver punto 4).
- Mi `connect-src` incluye `ws://localhost:3000` explícitamente para el
  entorno de desarrollo local; antes de desplegar a un dominio real, tengo
  que reemplazar `localhost:3000` por el dominio/puerto real de producción y
  usar `wss://` (WebSocket seguro), no `ws://`.

## 3. HTTPS

- El Service Worker (requisito de toda PWA instalable) solo se registra en
  orígenes seguros: `https://` o `localhost` (que los navegadores tratan
  como seguro). Ya lo documenté en mi `README.md`, sección 2.
- Me falta confirmar antes de la demo/entrega: si voy a exponer la PWA con
  `ngrok` u otro túnel para probarla desde una Smart TV real, tengo que
  confirmar que la URL pública sea `https://` (ngrok lo hace por defecto) —
  si no, el Service Worker no se registra y pierdo el modo offline y el
  cache.

## 4. Subresource Integrity (SRI)

No aplica en el sentido estricto en mi proyecto: no cargo ningún script
desde un CDN externo (el cliente de Socket.IO vive en `tv-pwa/vendor/`,
servido desde el mismo origen). SRI existe para verificar que un recurso
cargado desde un tercero no fue alterado; al no tener terceros, no hay
superficie de ataque que SRI resuelva aquí. Si en el futuro agrego alguna
librería por CDN, agrego el atributo `integrity` en ese momento.

## 5. Secretos y control de versiones

- Mi `.gitignore` (raíz) excluye `.env`, `.env.*` (con excepción explícita
  de `.env.example`), `*.jks`, `*.keystore`, `*.p12`, `*.pfx`, `*.pem`,
  `*apikey*`, `*secret*`, `*credentials*`, `*service-account*`,
  `google-services.json`, `GoogleService-Info.plist`, `key.properties` y
  `local.properties` (patrón global, sin ruta fija, para cubrir cualquier
  subproyecto Android/Gradle presente o futuro) — confirmado en
  `.gitignore:1-18`. Lo verifiqué contra mis archivos reales en disco:
  `server/.env`, `mobile-app/android/horariomedicoturnil-release.jks`,
  `mobile-app/android/key.properties` y `wearable-app/local.properties`
  quedan todos excluidos.
- Pendiente: todavía no inicializo mi repositorio git (no existe carpeta
  `.git`), así que este control no lo he probado en la práctica todavía.
  Mi `server/.env` (con el `SECRET_TOKEN` real) ya existe en disco. Cuando
  corra `git init`, voy a verificar el `.gitignore` antes de mi primer
  `git add`, y después con:
  ```
  git ls-files | grep -E '\.env$|\.jks$|\.keystore$'
  git log --all -S 'SECRET_TOKEN' -- .
  ```
  Ambos comandos deben devolverme vacío.

## 6. Autolimpieza de datos (ver también `PRIVACY_POLICY.md`)

- Smart TV: `tv-pwa/app.js:20,25-41` — borro `localStorage` cuando pasan
  30 días desde `hmt_install_date`.
- App móvil: mi historial se limita a los últimos 10 turnos por conteo
  (`main.dart:260-261`), no por antigüedad de 30 días. Si quiero que el
  comportamiento sea idéntico al de la TV (borrado por fecha), me falta
  agregar un timestamp de creación a cada entrada del historial y filtrar
  por edad — todavía no lo implemento. Lo dejé documentado como pendiente
  en `docs/RUBRICA_AUTOEVALUACION.md`.

## 7. Resumen — checklist final

| Control | Estado |
|---|---|
| Autenticación por token en el canal en tiempo real | Cumple |
| CORS restringido a orígenes conocidos | Cumple |
| CSP sin `unsafe-inline` | Cumple |
| HTTPS para el Service Worker | Cumple en `localhost`; me falta verificar en despliegue real |
| SRI | No aplica (sin dependencias por CDN) |
| Secretos fuera del repositorio | Pendiente de confirmar en cuanto exista el repositorio git |
| Retención/autolimpieza de datos | Completa en TV, parcial en móvil (por conteo, no por fecha) |
