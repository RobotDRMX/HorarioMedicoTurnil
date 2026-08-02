/**
 * HorarioMedicoTurnil - Servidor puente (Node.js + Socket.IO)
 *
 * Recibe telemetria BLE reenviada por la app movil ('telemetry') y la
 * retransmite en tiempo real a todos los clientes de la Smart TV ('update').
 *
 * Seguridad:
 *  - CORS restringido a los origenes de la TV y del Movil.
 *  - Handshake de Socket.IO validado con un token secreto (?token=...).
 *  - El "origin" de cada conexion socket es verificado antes de aceptarla.
 */

require('dotenv').config();

const express = require('express');
const cors = require('cors');
const http = require('http');
const { Server } = require('socket.io');

const PORT = process.env.PORT || 3000;
const SECRET_TOKEN = process.env.SECRET_TOKEN || 'secure123';

// Origenes permitidos: TV (PWA) y App Movil (WebView / emulador / dev server)
const ALLOWED_ORIGINS = [
  process.env.TV_ORIGIN || 'http://localhost:8080',
  process.env.MOBILE_ORIGIN || 'http://localhost:5000',
  'http://127.0.0.1:8080',
  'http://127.0.0.1:5000',
];

const app = express();

app.use(
  cors({
    origin(origin, callback) {
      // Permite requests sin origin (curl, apps nativas) y origenes en la lista blanca.
      if (!origin || ALLOWED_ORIGINS.includes(origin)) {
        callback(null, true);
      } else {
        callback(new Error(`Origen no permitido por CORS: ${origin}`));
      }
    },
  })
);

app.use(express.json());

app.get('/health', (req, res) => {
  res.status(200).json({
    status: 'ok',
    service: 'horariomedicoturnil-server',
    timestamp: new Date().toISOString(),
    tvClientsConnected: tvClients.size,
  });
});

const server = http.createServer(app);

const io = new Server(server, {
  cors: {
    origin(origin, callback) {
      if (!origin || ALLOWED_ORIGINS.includes(origin)) {
        callback(null, true);
      } else {
        callback(new Error(`Origen Socket.IO no permitido: ${origin}`));
      }
    },
    methods: ['GET', 'POST'],
  },
  // El cliente socket.io-client-java (usado por el wearable Kotlin) solo
  // habla Engine.IO v3; el servidor v4 requiere este flag de compatibilidad
  // para aceptar ese tipo de clientes ademas de los EIO4 (navegadores/Flutter).
  allowEIO3: true,
});

// Namespace para diferenciar clientes de la TV de los clientes moviles.
const tvClients = new Set();

// Umbral de ritmo cardiaco (bpm) fuera del cual un paciente pasa a
// prioridad alta y sube al frente de la lista de "proximos turnos".
const RITMO_CARDIACO_MIN_NORMAL = 50;
const RITMO_CARDIACO_MAX_NORMAL = 120;

// Umbral de saturacion de oxigeno en sangre (SpO2, %). Por debajo de este
// valor se considera hipoxemia y el turno tambien sube a prioridad alta.
// (94-100% se considera normal; <92% es el punto de corte clinico habitual
// para intervencion segun triage estandar).
const OXIGENACION_MIN_NORMAL = 92;

// Rango normal de temperatura corporal (°C). Por debajo se considera
// hipotermia y por encima fiebre; ambos casos suben el turno a prioridad
// alta (umbrales clinicos de triage estandar).
const TEMPERATURA_MIN_NORMAL = 35.0;
const TEMPERATURA_MAX_NORMAL = 38.0;

const MAX_HISTORIAL = 6;

// Cola compartida: fuente de verdad unica de la que se sirven la TV, el
// movil y el wearable, para que los tres muestren siempre la misma
// informacion (turno actual + proximos turnos con prioridad).
let historialReciente = [];

// Ultimo estado conocido de la simulacion de cada emisor (null = aun no
// reportado). Permite que un cliente que se conecta despues (ej. la TV)
// se sincronice de inmediato sin esperar al proximo cambio de estado.
const estadoSimulacion = { mobile: null, wearable: null };

function calcularPrioridad(ritmoCardiaco, oxigenacion, temperatura) {
  const ritmoFueraDeRango =
    typeof ritmoCardiaco === 'number' &&
    (ritmoCardiaco < RITMO_CARDIACO_MIN_NORMAL || ritmoCardiaco > RITMO_CARDIACO_MAX_NORMAL);

  const oxigenacionBaja =
    typeof oxigenacion === 'number' && oxigenacion < OXIGENACION_MIN_NORMAL;

  const temperaturaFueraDeRango =
    typeof temperatura === 'number' &&
    (temperatura < TEMPERATURA_MIN_NORMAL || temperatura > TEMPERATURA_MAX_NORMAL);

  return ritmoFueraDeRango || oxigenacionBaja || temperaturaFueraDeRango ? 'alta' : 'normal';
}

/**
 * Registra una nueva lectura en el historial reciente y devuelve el estado
 * compartido (turno actual + proximos turnos, reordenados por prioridad).
 */
function registrarLectura(data) {
  const prioridad = calcularPrioridad(data.ritmoCardiaco, data.oxigenacion, data.temperatura);

  historialReciente = [
    {
      turno: data.turno,
      tiempoEspera: data.tiempoEspera,
      ritmoCardiaco: data.ritmoCardiaco ?? null,
      oxigenacion: data.oxigenacion ?? null,
      temperatura: data.temperatura ?? null,
      prioridad,
    },
    ...historialReciente.filter((p) => p.turno !== data.turno),
  ].slice(0, MAX_HISTORIAL);

  const [actual, ...resto] = historialReciente;

  // Los proximos turnos se reordenan: prioridad alta primero, luego el
  // resto en orden de llegada (mas reciente primero).
  const proximos = [...resto]
    .sort((a, b) => (a.prioridad === b.prioridad ? 0 : a.prioridad === 'alta' ? -1 : 1))
    .slice(0, 3)
    .map((p) => ({ turno: p.turno, prioridad: p.prioridad }));

  return {
    turno: actual.turno,
    tiempoEspera: actual.tiempoEspera,
    ritmoCardiaco: actual.ritmoCardiaco,
    oxigenacion: actual.oxigenacion,
    temperatura: actual.temperatura,
    prioridad: actual.prioridad,
    proximos,
    recibidoEn: Date.now(),
  };
}

/**
 * Middleware de autenticacion: exige un token valido en el query string
 * de la conexion (ej. ws://host:3000/socket.io/?token=secure123).
 */
io.use((socket, next) => {
  const { token, role } = socket.handshake.query;

  if (token !== SECRET_TOKEN) {
    return next(new Error('AUTH_ERROR: token invalido o ausente'));
  }

  if (role && !['tv', 'mobile', 'wearable'].includes(role)) {
    return next(new Error('AUTH_ERROR: rol desconocido'));
  }

  socket.data.role = role || 'unknown';
  next();
});

io.on('connection', (socket) => {
  const { role } = socket.data;
  console.log(`[HorarioMedicoTurnil] Cliente conectado: ${socket.id} (rol: ${role})`);

  if (role === 'tv') {
    tvClients.add(socket.id);
  }

  // Sincroniza al cliente recien conectado con el ultimo estado de
  // simulacion conocido de cada emisor (si ya fue reportado alguna vez).
  Object.entries(estadoSimulacion).forEach(([rol, activa]) => {
    if (activa !== null) socket.emit('simEstado', { rol, activa });
  });

  // El movil (o el wearable, si tiene WiFi) reenvia aqui los datos leidos
  // del sensor: turno, tiempo de espera y ritmo cardiaco.
  socket.on('telemetry', (data) => {
    if (!isValidTelemetry(data)) {
      console.warn('[HorarioMedicoTurnil] Telemetria invalida descartada:', data);
      return;
    }

    console.log('[HorarioMedicoTurnil] Telemetria recibida:', data);

    // Retransmite el estado compartido (cola con prioridad) a TODOS los
    // clientes conectados: TV, movil y wearable ven siempre lo mismo.
    io.emit('update', registrarLectura(data));
  });

  // El movil o el wearable reportan aqui cuando el usuario detiene o
  // reanuda la generacion de datos simulados desde su boton local, para
  // que la TV (y los demas clientes) puedan reflejarlo en pantalla.
  socket.on('simEstado', (data) => {
    if (!isValidSimEstado(data)) {
      console.warn('[HorarioMedicoTurnil] simEstado invalido descartado:', data);
      return;
    }

    estadoSimulacion[data.rol] = data.activa;
    io.emit('simEstado', data);
  });

  socket.on('disconnect', (reason) => {
    tvClients.delete(socket.id);
    console.log(`[HorarioMedicoTurnil] Cliente desconectado: ${socket.id} (${reason})`);
  });
});

function isValidTelemetry(data) {
  return (
    data &&
    typeof data.turno === 'number' &&
    typeof data.tiempoEspera === 'number' &&
    data.turno >= 0 &&
    data.tiempoEspera >= 0 &&
    (data.ritmoCardiaco === undefined || typeof data.ritmoCardiaco === 'number') &&
    (data.oxigenacion === undefined || typeof data.oxigenacion === 'number') &&
    (data.temperatura === undefined || typeof data.temperatura === 'number')
  );
}

function isValidSimEstado(data) {
  return (
    data &&
    (data.rol === 'mobile' || data.rol === 'wearable') &&
    typeof data.activa === 'boolean'
  );
}

server.listen(PORT, () => {
  console.log(`[HorarioMedicoTurnil] Servidor escuchando en el puerto ${PORT}`);
  console.log(`[HorarioMedicoTurnil] Origenes permitidos: ${ALLOWED_ORIGINS.join(', ')}`);
});
