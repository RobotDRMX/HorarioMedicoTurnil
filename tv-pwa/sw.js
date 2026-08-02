/**
 * HorarioMedicoTurnil TV - Service Worker
 * Estrategias:
 *  - Cache First para recursos estaticos (CSS, JS, iconos, manifest).
 *  - Network First para llamadas al servidor (ej. /health), con fallback a cache.
 *
 * Escrito a mano (sin Workbox) para evitar dependencias externas y
 * respetar la CSP de la aplicacion (script-src 'self').
 */

const CACHE_NAME = 'horariomedicoturnil-tv-v2';

const STATIC_ASSETS = [
  './',
  './index.html',
  './styles.css',
  './app.js',
  './manifest.json',
  './vendor/socket.io.min.js',
  './icons/icon-192.svg',
  './icons/icon-512.svg',
  './assets/fallback.svg',
];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => cache.addAll(STATIC_ASSETS)).then(() => self.skipWaiting())
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches
      .keys()
      .then((keys) =>
        Promise.all(keys.filter((key) => key !== CACHE_NAME).map((key) => caches.delete(key)))
      )
      .then(() => self.clients.claim())
  );
});

function esPeticionAlServidor(url) {
  return url.pathname.startsWith('/health') || url.pathname.startsWith('/socket.io');
}

self.addEventListener('fetch', (event) => {
  const url = new URL(event.request.url);

  if (event.request.method !== 'GET') {
    return;
  }

  if (esPeticionAlServidor(url)) {
    // Network First: intenta red, si falla usa cache.
    event.respondWith(networkFirst(event.request));
    return;
  }

  // Cache First para todo lo estatico de la propia PWA.
  event.respondWith(cacheFirst(event.request));
});

async function cacheFirst(request) {
  const cached = await caches.match(request);
  if (cached) {
    return cached;
  }

  try {
    const response = await fetch(request);
    if (response && response.ok) {
      const cache = await caches.open(CACHE_NAME);
      cache.put(request, response.clone());
    }
    return response;
  } catch (error) {
    return cached || Response.error();
  }
}

async function networkFirst(request) {
  try {
    const response = await fetch(request);
    if (response && response.ok) {
      const cache = await caches.open(CACHE_NAME);
      cache.put(request, response.clone());
    }
    return response;
  } catch (error) {
    const cached = await caches.match(request);
    if (cached) {
      return cached;
    }
    throw error;
  }
}
