/**
 * HorarioMedicoTurnil TV - Logica de la aplicacion
 * - Conexion WebSocket (Socket.IO) al servidor puente.
 * - Navegacion por teclado (D-pad) con wrap-around entre las 4 tarjetas.
 * - Lazy loading del video (solo carga si la Tarjeta 4 esta enfocada/visible).
 * - Ciclo de vida de datos: autolimpieza de localStorage cada 30 dias.
 */

(function () {
  'use strict';

  const SOCKET_URL = window.location.hostname
    ? `${window.location.protocol === 'https:' ? 'https' : 'http'}://${window.location.hostname}:3000`
    : 'http://localhost:3000';

  const SOCKET_TOKEN = 'secure123'; // Debe coincidir con SECRET_TOKEN del servidor
  const UMBRAL_ALERTA_SEGUNDOS = 900;
  const TREINTA_DIAS_MS = 30 * 24 * 60 * 60 * 1000;

  const INSTALL_DATE_KEY = 'hmt_install_date';

  // ---------------------------------------------------------------------
  // 1. Ciclo de vida de datos: autolimpieza a los 30 dias
  // ---------------------------------------------------------------------
  function gestionarCicloDeVidaDeDatos() {
    const instalado = localStorage.getItem(INSTALL_DATE_KEY);

    if (!instalado) {
      localStorage.setItem(INSTALL_DATE_KEY, String(Date.now()));
      return;
    }

    const fechaInstalacion = Number(instalado);
    const antiguedad = Date.now() - fechaInstalacion;

    if (antiguedad > TREINTA_DIAS_MS) {
      localStorage.clear();
      localStorage.setItem(INSTALL_DATE_KEY, String(Date.now()));
      console.info('[HorarioMedicoTurnil] localStorage reiniciado tras superar 30 dias.');
    }
  }

  gestionarCicloDeVidaDeDatos();

  if ('serviceWorker' in navigator) {
    window.addEventListener('load', () => {
      navigator.serviceWorker
        .register('./sw.js')
        .catch((err) => console.error('[HorarioMedicoTurnil] Error registrando SW:', err));
    });
  }

  // ---------------------------------------------------------------------
  // 2. Navegacion D-pad entre tarjetas (grid 2x2 con wrap-around)
  // ---------------------------------------------------------------------
  const cards = Array.from(document.querySelectorAll('.card'));
  let focusIndex = 0;

  // Mapa de posiciones en el grid de 2 columnas x 3 filas: [fila, columna].
  // El video ocupa toda la fila 2 (ver .card-video en styles.css), por lo
  // que solo se registra en la columna 0 a efectos de navegacion.
  const GRID_ROWS = 3;
  const GRID_COLS = 2;
  const GRID_POS = [
    [0, 0], // Tarjeta 1: Turno
    [0, 1], // Tarjeta 2: Tiempo
    [1, 0], // Tarjeta 3: Proximos
    [1, 1], // Tarjeta 4: Historial
    [2, 0], // Tarjeta 5: Video (ancho completo)
  ];

  function setFocus(index) {
    cards.forEach((c) => c.classList.remove('focused'));
    focusIndex = (index + cards.length) % cards.length;
    cards[focusIndex].classList.add('focused');
    cards[focusIndex].focus();
    onCardFocused(focusIndex);
  }

  function moveFocus(direction) {
    const [row, col] = GRID_POS[focusIndex];
    let targetRow = row;
    let targetCol = col;

    if (direction === 'ArrowUp') targetRow = (row - 1 + GRID_ROWS) % GRID_ROWS;
    if (direction === 'ArrowDown') targetRow = (row + 1) % GRID_ROWS;
    if (direction === 'ArrowLeft') targetCol = (col - 1 + GRID_COLS) % GRID_COLS;
    if (direction === 'ArrowRight') targetCol = (col + 1) % GRID_COLS;

    const nextIndex = GRID_POS.findIndex(([r, c]) => r === targetRow && c === targetCol);
    setFocus(nextIndex === -1 ? focusIndex : nextIndex);
  }

  document.addEventListener('keydown', (event) => {
    switch (event.key) {
      case 'ArrowUp':
      case 'ArrowDown':
      case 'ArrowLeft':
      case 'ArrowRight':
        event.preventDefault();
        moveFocus(event.key);
        break;
      case 'Enter':
        event.preventDefault();
        cards[focusIndex].click();
        break;
      default:
        break;
    }
  });

  // Inicializa el foco en la primera tarjeta.
  setFocus(0);

  // ---------------------------------------------------------------------
  // 3. Lazy loading del video (Tarjeta 4)
  // ---------------------------------------------------------------------
  const videoWrapper = document.getElementById('video-wrapper');
  const cardVideo = document.getElementById('card-video');
  let videoCargado = false;

  function cargarVideo() {
    if (videoCargado) return;
    videoCargado = true;

    const video = document.createElement('video');
    video.id = 'video-informativo';
    video.src = 'assets/sample-video.mp4';
    video.poster = 'assets/fallback.svg';
    video.autoplay = true;
    video.loop = true;
    video.muted = true;
    video.playsInline = true;

    video.addEventListener('error', () => {
      // Fallback a imagen si el video no puede cargarse/reproducirse.
      videoWrapper.innerHTML =
        '<img src="assets/fallback.svg" alt="Informacion HorarioMedicoTurnil" class="video-fallback" />';
    });

    videoWrapper.innerHTML = '';
    videoWrapper.appendChild(video);
  }

  function onCardFocused(index) {
    if (index === 4) {
      cargarVideo();
    }
  }

  // IntersectionObserver como mecanismo adicional de lazy-load (visibilidad real).
  if ('IntersectionObserver' in window) {
    const observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) {
            cargarVideo();
          }
        });
      },
      { threshold: 0.5 }
    );
    observer.observe(cardVideo);
  }

  // ---------------------------------------------------------------------
  // 4. Conexion WebSocket y actualizacion del DOM
  // ---------------------------------------------------------------------
  const valorTurno = document.getElementById('valor-turno');
  const valorTiempo = document.getElementById('valor-tiempo');
  const valorRitmo = document.getElementById('valor-ritmo');
  const valorOxigenacion = document.getElementById('valor-oxigenacion');
  const valorTemperatura = document.getElementById('valor-temperatura');
  const badgePrioridad = document.getElementById('badge-prioridad');
  const listaProximos = document.getElementById('lista-proximos');
  const listaHistorial = document.getElementById('lista-historial');
  const cardTiempo = document.getElementById('card-tiempo');

  // Historial local (ultimos 10 turnos), acumulado a partir del broadcast
  // 'update' del servidor. No depende de quien genero el turno (wearable,
  // movil o BLE): siempre refleja la misma cola compartida que ve la TV.
  const MAX_HISTORIAL_TV = 10;
  let historialTv = [];

  const socket = window.io(SOCKET_URL, {
    query: { token: SOCKET_TOKEN, role: 'tv' },
    transports: ['websocket'],
  });

  socket.on('connect', () => {
    console.info('[HorarioMedicoTurnil] Conectado al servidor:', SOCKET_URL);
  });

  socket.on('connect_error', (err) => {
    console.error('[HorarioMedicoTurnil] Error de conexion:', err.message);
  });

  socket.on('update', (data) => {
    actualizarDashboard(data);
  });

  // ---------------------------------------------------------------------
  // 3b. Aviso de simulacion detenida (reportado por el movil/wearable)
  // ---------------------------------------------------------------------
  const estadoSimulacionEl = document.getElementById('estado-simulacion');
  const estadoSimulacion = { mobile: null, wearable: null };
  const ETIQUETAS_ROL = { mobile: 'Movil', wearable: 'Wearable' };

  socket.on('simEstado', ({ rol, activa }) => {
    if ((rol !== 'mobile' && rol !== 'wearable') || typeof activa !== 'boolean') return;
    estadoSimulacion[rol] = activa;
    actualizarBannerSimulacion();
  });

  function actualizarBannerSimulacion() {
    const detenidos = Object.entries(estadoSimulacion)
      .filter(([, activa]) => activa === false)
      .map(([rol]) => ETIQUETAS_ROL[rol]);

    if (detenidos.length === 0) {
      estadoSimulacionEl.hidden = true;
      return;
    }

    estadoSimulacionEl.hidden = false;
    estadoSimulacionEl.textContent = `Simulacion detenida: ${detenidos.join(' y ')}`;
  }

  function registrarEnHistorialSiCambio(data) {
    if (historialTv.length > 0 && historialTv[0].turno === data.turno) {
      return;
    }
    historialTv = [
      {
        turno: data.turno,
        tiempoEspera: data.tiempoEspera,
        ritmoCardiaco: data.ritmoCardiaco,
        oxigenacion: data.oxigenacion,
        temperatura: data.temperatura,
        prioridad: data.prioridad,
      },
      ...historialTv,
    ].slice(0, MAX_HISTORIAL_TV);

    listaHistorial.innerHTML = historialTv
      .map((h) => {
        const esAlta = h.prioridad === 'alta';
        const etiqueta = esAlta ? '<span class="etiqueta-prioridad">ALTA</span>' : '';
        return `<li>
          <span>
            <strong>Turno ${h.turno}</strong>
            <span class="historial-detalle">Ritmo ${h.ritmoCardiaco ?? '--'}bpm · SpO2 ${h.oxigenacion ?? '--'}% · Temp ${h.temperatura ?? '--'}°C</span>
          </span>
          ${etiqueta}
        </li>`;
      })
      .join('');
  }

  function actualizarDashboard(data) {
    const { turno, tiempoEspera, ritmoCardiaco, oxigenacion, temperatura, prioridad, proximos } = data;

    registrarEnHistorialSiCambio(data);

    valorTurno.textContent = turno ?? '--';

    const minutos = typeof tiempoEspera === 'number' ? Math.round(tiempoEspera / 60) : '--';
    valorTiempo.textContent = minutos;

    valorRitmo.textContent = `Ritmo cardiaco: ${typeof ritmoCardiaco === 'number' ? ritmoCardiaco : '--'} bpm`;
    valorOxigenacion.textContent = `Oxigenacion (SpO2): ${typeof oxigenacion === 'number' ? oxigenacion : '--'}%`;
    valorTemperatura.textContent = `Temperatura: ${typeof temperatura === 'number' ? temperatura : '--'}°C`;

    // La prioridad la calcula el SERVIDOR (fuente de verdad compartida con
    // el movil y el wearable), a partir del ritmo cardiaco, la oxigenacion
    // y la temperatura del turno actual.
    badgePrioridad.hidden = prioridad !== 'alta';

    if (Array.isArray(proximos) && proximos.length > 0) {
      listaProximos.innerHTML = proximos
        .slice(0, 3)
        .map((p) => {
          const t = typeof p === 'object' ? p.turno : p;
          const esAlta = typeof p === 'object' && p.prioridad === 'alta';
          const etiqueta = esAlta ? '<span class="etiqueta-prioridad">ALTA</span>' : '';
          return `<li><span>Turno ${t}</span>${etiqueta}</li>`;
        })
        .join('');
    }

    if (typeof tiempoEspera === 'number' && tiempoEspera >= UMBRAL_ALERTA_SEGUNDOS) {
      cardTiempo.classList.add('alerta');
    } else {
      cardTiempo.classList.remove('alerta');
    }
  }
})();
