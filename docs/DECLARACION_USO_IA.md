# Declaración de Uso de IA

Alumno: Angel Fabián Gutiérrez Gómez

La política de uso de IA del curso me exige declarar esto en cada entregable
del proyecto (E1.1 a E2.4). No declararlo me penaliza -10 pts; declararlo
correctamente no me penaliza.

## Cómo uso esta plantilla

Copio la tabla de la sección 2 en cada entregable (E2.1, E2.2, E2.3, E2.4) y
la lleno con mi propia experiencia real de esa entrega específica — no
reutilizo literalmente lo que dice este archivo, porque esto describe la
sesión de documentación en la que usé Claude como apoyo, no todo mi proceso
de desarrollo.

Los tres usos que acepta la política, para tenerlos a la mano:

| Uso | Descripción |
|---|---|
| USO 1 — Tutor | Le pido a la IA que me explique un concepto, y luego lo escribo con mis propias palabras en el entregable. |
| USO 2 — Verificador | Termino mi trabajo y le pido a la IA que revise errores u omisiones. Yo decido qué corregir y por qué. |
| USO 3 — Punto de partida | Le pido a la IA una lista de fuentes/conceptos para investigar por mi cuenta. |

Lo que no debo declarar como propio: cualquier texto que copié directamente
de una respuesta de IA sin leerlo, sin interpretarlo, o que no puedo
explicar yo mismo si el profesor me pregunta en la demo.

## 1. Mi declaración de esta sesión de documentación

En esta sesión generé o actualicé: `RUBRICA_AUTOEVALUACION.md`,
`CONFIGURACION_HERRAMIENTAS.md`, `SECURITY.md`, `PRIVACY_POLICY.md`,
`TEST_PLAN.md` (expandido) y este mismo archivo.

- Uso principal: USO 2 (verificador). Le pedí a Claude que leyera el código
  fuente real de mi repositorio (`tv-pwa/`, `mobile-app/`, `wearable-app/`,
  `server/`) y me señalara, con cita de archivo y línea, qué puntos de la
  lista de cotejo tenía cumplidos, parciales o ausentes. Las decisiones de
  qué corregir antes de la demo (íconos PNG, intervalo del simulador,
  header de fecha/hora, inicializar git, etc.) las tomo yo.
- Uso secundario: USO 3 (punto de partida). Los documentos nuevos
  (seguridad, configuración de herramientas, plan de pruebas expandido) son
  un borrador estructurado a partir de hechos verificados en mi código y
  comandos reales que corrí yo (`flutter --version`, etc.) — no son una
  redacción final que voy a entregar sin revisar.
- Explícitamente no usé IA para: generar capturas de pantalla, resultados
  de pruebas que no he ejecutado, un tester externo, un video demo, ni las
  respuestas de mi Bitácora de Proceso. Esos campos los dejé como espacios
  en blanco (`___`, checkboxes vacíos) porque inventarlos sería "IA como
  evidencia falsa" (NO 3 de la política), y eso no está permitido.

Antes de entregar, me falta leer cada documento que generé con ayuda de
Claude, verificar personalmente al menos una muestra de las citas
archivo:línea contra mi código real, corregir cualquier error, completar
los espacios en blanco que son datos personales (mi correo, mis capturas,
mi firma), y estar en condiciones de explicar cualquier parte de estos
documentos si el profesor me pregunta durante la demo — si no lo puedo
explicar, no lo entrego tal cual.

## 2. Plantilla para cada entregable (E2.1 – E2.4)

```
### Declaración de Uso de IA — Entregable: [E2.1 / E2.2 / E2.3 / E2.4]

Herramienta(s) usada(s): [ChatGPT / Claude / Copilot / Gemini / ninguna]

¿Usé IA en este entregable?  [ Sí / No ]

Si sí, ¿qué uso(s) le di? (marco los que apliquen)
[ ] USO 1 - Tutor: le pedí que me explicara ___ y lo escribí con mis
    propias palabras en la sección ___.
[ ] USO 2 - Verificador: le pedí que revisara ___ y decidí corregir ___
    (y no corregir ___) porque ___.
[ ] USO 3 - Punto de partida: le pedí ideas/fuentes sobre ___ y luego
    investigué/implementé por mi cuenta ___.

¿Qué partes de este entregable son enteramente de mi autoría, sin
asistencia de IA?
___

Firma: ___________________   Fecha: ___________________
```
