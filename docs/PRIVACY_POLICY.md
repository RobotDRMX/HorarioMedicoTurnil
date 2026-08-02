# Politica de Privacidad - HorarioMedicoTurnil

Ultima actualizacion: 2026-08-01

## 1. Alcance

Esta politica aplica a los cuatro componentes del ecosistema **HorarioMedicoTurnil**:
el Wearable (Wear OS), la App Movil (Flutter), la Smart TV (PWA) y el Servidor
puente (Node.js).

## 2. Datos que se recopilan

Los datos que circula por el sistema son:

- Un numero de turno (entero, sin relacion con la identidad del paciente).
- Un tiempo de espera en segundos.
- **Metricas fisiologicas simuladas**: ritmo cardiaco (bpm), oxigenacion (SpO2,
  %) y temperatura corporal (°C), generadas por el wearable.
- Marcas de tiempo tecnicas (timestamps) usadas unicamente para sincronizacion.

Estos datos **no incluyen nombres, documentos de identidad ni datos de
contacto**, por lo que no permiten identificar directamente a una persona.
Sin embargo, las metricas fisiologicas son, por su naturaleza, **datos
personales sensibles de salud** conforme al Art. 3, fraccion VI de la
LFPDPPP (aunque en este caso son datos **simulados/sinteticos**, no
capturados de pacientes reales) — se tratan con el mismo cuidado que si
fueran reales, dado que el sistema esta diseñado para escalar a un caso de
uso donde si lo serian.

## 3. Base legal (LFPDPPP)

El tratamiento de estos datos se justifica bajo el **consentimiento tacito**
del paciente al tomar su turno en la sala de espera (Art. 8 LFPDPPP), dado
que:

- El proposito (mostrar el turno y tiempo de espera en pantallas visibles)
  es evidente por el contexto del servicio.
- No se recopilan datos adicionales a los estrictamente necesarios para ese
  proposito (principio de **finalidad** y **proporcionalidad**, Art. 6
  LFPDPPP).
- Al ser datos de salud (categoria sensible), en un despliegue con pacientes
  reales se recomienda ademas consentimiento **expreso y por escrito** (Art.
  9 LFPDPPP), no solo tacito — esto queda pendiente de implementar si el
  proyecto migra de datos simulados a datos reales.

## 4. Derechos ARCO

Cualquier titular de los datos (paciente) puede ejercer sus derechos de
**Acceso, Rectificacion, Cancelacion y Oposicion (ARCO)** contactando al
responsable indicado en la seccion 7. Dado que el sistema no almacena datos
de forma persistente mas alla de los limites descritos en la seccion 5
(retencion), la mayoria de las solicitudes de Cancelacion se satisfacen de
forma automatica por el propio ciclo de vida de los datos.

## 5. Almacenamiento

- **App Movil**: guarda localmente (SharedPreferences) un historial acotado a
  los **ultimos 10 turnos recibidos** (por conteo, no por fecha), exclusivamente
  en el dispositivo del usuario.
- **Smart TV**: guarda en `localStorage` una fecha de instalacion
  (`hmt_install_date`) usada para controlar el ciclo de vida de los datos
  cacheados localmente.
- **Servidor**: no persiste telemetria; unicamente retransmite los eventos en
  tiempo real entre el Movil y la TV, sin escribir en base de datos ni logs
  permanentes de identidad.

## 6. Eliminacion automatica (30 dias en TV; por conteo en Movil)

Todo dato almacenado localmente en la Smart TV se elimina automaticamente
cuando han transcurrido **30 dias** desde la fecha de instalacion registrada en
`hmt_install_date`. Al superarse ese plazo, la aplicacion ejecuta
`localStorage.clear()` y reinicia el contador.

**Nota de precision** (la corrijo respecto a una version anterior de este
documento, donde decia algo distinto que no correspondia con mi codigo
real): el historial de turnos en la App Movil **no** expira por antiguedad
de 30 dias — se limita a los ultimos 10 registros por conteo, sin importar
cuanto tiempo lleven guardados. Si un mismo turno permanece entre los
ultimos 10 durante mas de 30 dias, seguira visible. Si en el futuro quiero
paridad exacta con la politica de 30 dias de la TV, me falta agregar un
timestamp de creacion a cada entrada del historial movil y filtrar por edad
(lo dejo pendiente; ver `docs/RUBRICA_AUTOEVALUACION.md`, seccion SA.4).

## 7. Comunicacion en red

Los datos viajan entre el Wearable, la App Movil, el Servidor y la Smart TV
mediante conexiones BLE y WebSocket protegidas por un token de autenticacion
compartido. No se envian datos a terceros ni a servicios de analitica externos.

## 8. Contacto y responsable

Responsable del tratamiento de datos de este proyecto academico: **Angel
Fabian Gutierrez Gomez**, estudiante de Desarrollo para Dispositivos
Inteligentes en la UTEQ. Para ejercer derechos ARCO o consultar esta
politica, pueden contactarme a: **[correo que voy a usar para el proyecto —
me falta completar]**.
