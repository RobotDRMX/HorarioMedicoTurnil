# Bitácora de Proceso

Alumno: Angel Fabián Gutiérrez Gómez


## Práctica: Integración del ecosistema de 3 dispositivos (Evaluación 2) — Wearable, App Móvil y Smart TV con Socket.IO

Fecha: 01/08/2026

### 1. ¿Qué fue lo más difícil de esta práctica y cómo lo resolví?

Lo más difícil no fue conectar los tres dispositivos la primera vez, sino
diagnosticar por qué dejaban de verse datos sin que nada "se rompiera" de
forma obvia. En un momento, la tarjeta de turno en la app móvil se quedó
mostrando un recuadro verde vacío, sin ningún error visible. Mi primer
instinto fue pensar que había un bug en el widget de la tarjeta. Pero
revisando el log del servidor me di cuenta de que el emulador del wearable
había perdido la conexión Socket.IO ("ping timeout") porque estaba
compitiendo por recursos con otro build de Gradle corriendo al mismo
tiempo, así que dejó de emitir telemetría. Es decir: la tarjeta no estaba
rota, estaba mostrando correctamente su estado de "esqueleto" (shimmer) de
carga — pasa que el color del shimmer se confunde con el fondo de la
tarjeta en una captura estática, y por eso parecía un error de UI cuando en
realidad era un problema de red aguas arriba. Lo resolví reiniciando la app
del wearable (`am force-stop` + `am start`), lo que retomó la emisión de
datos. Aprendí a no asumir dónde está el bug por cómo se ve en pantalla, y a
revisar primero el log del servidor cuando el dato simplemente "no llega".


### 2. ¿Qué consulté que no entendí a la primera? (incluye si usé IA y cómo)

Usé Claude de dos formas distintas en este proyecto:

- Como tutor: no tenía claro qué diferencia real hay entre animar con una
  curva interpolada (`Curve`/`Tween`) y animar con física de resorte
  (`SpringSimulation`/`SpringDescription`). Le pedí que me explicara la
  diferencia con ejemplos, y terminé entendiendo que una curva sigue una
  trayectoria fija de tiempo->valor, mientras que un resorte simula masa,
  rigidez y amortiguación, por lo que el rebote depende de cómo se llega al
  estado, no de un tiempo fijo. Por eso lo usé para el "pop" de la tarjeta
  de turno cuando llega un dato nuevo.
- Como verificador: al final, contra la lista de cotejo de la rúbrica de
  Evaluación 2, le pedí que revisara mi código y me dijera qué me faltaba
  citando archivo y línea. Yo decidí qué corregir de esa lista y en qué
  orden (documentado en `docs/RUBRICA_AUTOEVALUACION.md`); no le pedí que
  tomara esas decisiones por mí.

### 3. Si repitiera esta práctica mañana, ¿qué haría diferente y por qué?

Definiría los UUIDs de servicio y característica BLE en un solo archivo de
constantes compartido entre el wearable y la app móvil desde el principio,
en vez de escribir el mismo valor a mano en los dos proyectos. Ahora mismo
si cambio uno y se me olvida cambiar el otro, la conexión se rompe sin que
el compilador me avise — es un error silencioso que solo se detecta en
tiempo de ejecución. También inicializaría el repositorio git desde el
primer día del proyecto en vez de dejarlo para el final: llegar a esta
etapa sin historial de commits significa que no puedo demostrar mi proceso
de desarrollo con evidencia real de Git, y tengo que reconstruir esa parte
de la rúbrica (Release v1.0, verificación de que nunca subí un secreto) casi
de un solo golpe al final.

