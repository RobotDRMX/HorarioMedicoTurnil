package com.horariomedicoturnil.wear

import android.app.Service
import android.bluetooth.*
import android.bluetooth.le.AdvertiseCallback
import android.bluetooth.le.AdvertiseData
import android.bluetooth.le.AdvertiseSettings
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import io.socket.client.IO
import io.socket.client.Socket
import org.json.JSONObject
import java.nio.charset.StandardCharsets
import java.util.UUID
import kotlin.random.Random

/** Estado compartido (turno actual + prioridad) tal como lo ve la TV y el movil. */
data class EstadoCompartido(
    val turno: Int,
    val tiempoEsperaSegundos: Int,
    val ritmoCardiacoBpm: Int,
    val oxigenacionPorcentaje: Int,
    val temperaturaCorporal: Double,
    val prioridad: String,
    val sincronizadoPorRed: Boolean,
)

/**
 * HorarioMedicoTurnil Wear - Servicio BLE en segundo plano.
 *
 * Actua como servidor GATT y simula un sensor de turnos: cada 3 segundos
 * incrementa el numero de turno y genera un tiempo de espera y ritmo
 * cardiaco aleatorios, notificando el cambio a todos los dispositivos
 * suscritos (ej. la app movil HorarioMedicoTurnil) mediante una
 * caracteristica NOTIFY.
 *
 * Ademas, si el dispositivo tiene WiFi (como el emulador, que no tiene BLE
 * real hacia un telefono fisico), se conecta directamente al servidor por
 * Socket.IO para reportar su lectura y recibir el estado compartido de la
 * cola (turno actual + prioridad), de forma que la pantalla del wearable
 * coincida exactamente con la TV y el movil. Esto es un complemento de
 * verificacion/demo: la emision BLE NOTIFY sigue siendo la via "oficial".
 */
class BluetoothLeService : Service() {

    companion object {
        private const val TAG = "HMT_BleService"

        val SERVICE_UUID: UUID = UUID.fromString("12345678-1234-1234-1234-123456789abc")
        val CHARACTERISTIC_UUID: UUID = UUID.fromString("87654321-4321-4321-4321-cba987654321")
        val CLIENT_CONFIG_DESCRIPTOR_UUID: UUID =
            UUID.fromString("00002902-0000-1000-8000-00805f9b34fb")

        private const val INTERVALO_MS = 3000L
        private const val TIEMPO_MIN_SEGUNDOS = 300
        private const val TIEMPO_MAX_SEGUNDOS = 1500
        // Rango tipico al generar una lectura simulada (sin picos).
        private const val RITMO_GENERACION_MIN = 60
        private const val RITMO_GENERACION_MAX = 100

        // Umbral clinico que dispara prioridad alta (debe coincidir con el
        // mismo umbral usado en server/index.js y mobile-app/lib/main.dart).
        private const val RITMO_UMBRAL_MIN = 50
        private const val RITMO_UMBRAL_MAX = 120

        // Rango tipico de saturacion de oxigeno simulada (sin picos).
        private const val OXIGENACION_GENERACION_MIN = 95
        private const val OXIGENACION_GENERACION_MAX = 100

        // Umbral clinico de hipoxemia (debe coincidir con OXIGENACION_MIN_NORMAL
        // de server/index.js).
        private const val OXIGENACION_UMBRAL_MIN = 92

        // Rango tipico de temperatura corporal simulada (sin picos), en °C.
        private const val TEMPERATURA_GENERACION_MIN = 36.1
        private const val TEMPERATURA_GENERACION_MAX = 37.2

        // Umbrales clinicos de hipotermia/fiebre (deben coincidir con
        // TEMPERATURA_MIN_NORMAL / TEMPERATURA_MAX_NORMAL de server/index.js).
        private const val TEMPERATURA_UMBRAL_MIN = 35.0
        private const val TEMPERATURA_UMBRAL_MAX = 38.0

        // 10.0.2.2 es el alias estandar con el que un emulador Android
        // accede al localhost de la maquina anfitriona.
        private const val SERVER_URL = "http://10.0.2.2:3000"
        private const val SERVER_TOKEN = "secure123"

        /** Ultimo estado conocido (local o confirmado por el servidor), observable por la UI. */
        val estadoActual = MutableStateFlow<EstadoCompartido?>(null)
        val estadoStream: StateFlow<EstadoCompartido?> get() = estadoActual

        /** Si la simulacion de turnos esta generando datos nuevos, observable por la UI. */
        val simulacionActiva = MutableStateFlow(true)

        // Referencia a la instancia en ejecucion, para que la UI (MainActivity)
        // pueda alternar la simulacion sin necesidad de un bindService.
        private var instancia: BluetoothLeService? = null

        /** Alterna la simulacion (pausa/reanuda la generacion de nuevos turnos). */
        fun alternarSimulacion() {
            instancia?.let { servicio ->
                simulacionActiva.value = !simulacionActiva.value
                servicio.reportarEstadoSimulacion()
            }
        }
    }

    private lateinit var bluetoothManager: BluetoothManager
    private var gattServer: BluetoothGattServer? = null
    private var characteristic: BluetoothGattCharacteristic? = null
    private var socket: Socket? = null

    private val dispositivosSuscritos = mutableSetOf<BluetoothDevice>()
    private val handler = Handler(Looper.getMainLooper())
    private val random = Random(System.currentTimeMillis())

    private var turnoActual = 0

    private val simulacionRunnable = object : Runnable {
        override fun run() {
            if (simulacionActiva.value) {
                emitirNuevoTurno()
            }
            handler.postDelayed(this, INTERVALO_MS)
        }
    }

    override fun onCreate() {
        super.onCreate()
        instancia = this
        bluetoothManager = getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
        iniciarServidorGatt()
        iniciarAdvertising()
        conectarAlServidor()
        handler.post(simulacionRunnable)
        Log.i(TAG, "Servicio BLE HorarioMedicoTurnil iniciado")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    /**
     * Crea el servidor GATT con el servicio y la caracteristica NOTIFY/READ
     * que expondra el turno, el tiempo de espera y el ritmo cardiaco actuales.
     */
    private fun iniciarServidorGatt() {
        val callback = object : BluetoothGattServerCallback() {
            override fun onConnectionStateChange(device: BluetoothDevice, status: Int, newState: Int) {
                super.onConnectionStateChange(device, status, newState)
                if (newState == BluetoothProfile.STATE_CONNECTED) {
                    Log.i(TAG, "Dispositivo conectado: ${device.address}")
                } else if (newState == BluetoothProfile.STATE_DISCONNECTED) {
                    dispositivosSuscritos.remove(device)
                    Log.i(TAG, "Dispositivo desconectado: ${device.address}")
                }
            }

            override fun onCharacteristicReadRequest(
                device: BluetoothDevice,
                requestId: Int,
                offset: Int,
                characteristic: BluetoothGattCharacteristic
            ) {
                gattServer?.sendResponse(
                    device,
                    requestId,
                    BluetoothGatt.GATT_SUCCESS,
                    offset,
                    characteristic.value
                )
            }

            override fun onDescriptorWriteRequest(
                device: BluetoothDevice,
                requestId: Int,
                descriptor: BluetoothGattDescriptor,
                preparedWrite: Boolean,
                responseNeeded: Boolean,
                offset: Int,
                value: ByteArray
            ) {
                if (descriptor.uuid == CLIENT_CONFIG_DESCRIPTOR_UUID) {
                    if (value.contentEquals(BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE)) {
                        dispositivosSuscritos.add(device)
                        Log.i(TAG, "Suscripcion NOTIFY habilitada para ${device.address}")
                    } else {
                        dispositivosSuscritos.remove(device)
                    }
                }

                if (responseNeeded) {
                    gattServer?.sendResponse(
                        device,
                        requestId,
                        BluetoothGatt.GATT_SUCCESS,
                        offset,
                        value
                    )
                }
            }
        }

        gattServer = bluetoothManager.openGattServer(this, callback)

        val service = BluetoothGattService(SERVICE_UUID, BluetoothGattService.SERVICE_TYPE_PRIMARY)

        characteristic = BluetoothGattCharacteristic(
            CHARACTERISTIC_UUID,
            BluetoothGattCharacteristic.PROPERTY_READ or BluetoothGattCharacteristic.PROPERTY_NOTIFY,
            BluetoothGattCharacteristic.PERMISSION_READ
        )

        val configDescriptor = BluetoothGattDescriptor(
            CLIENT_CONFIG_DESCRIPTOR_UUID,
            BluetoothGattDescriptor.PERMISSION_READ or BluetoothGattDescriptor.PERMISSION_WRITE
        )
        characteristic?.addDescriptor(configDescriptor)

        service.addCharacteristic(characteristic)
        gattServer?.addService(service)
    }

    /** Anuncia el servicio para que la app movil pueda descubrirlo al escanear. */
    private fun iniciarAdvertising() {
        val advertiser = bluetoothManager.adapter?.bluetoothLeAdvertiser ?: run {
            Log.w(TAG, "Este dispositivo no soporta advertising BLE")
            return
        }

        val settings = AdvertiseSettings.Builder()
            .setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_LOW_LATENCY)
            .setTxPowerLevel(AdvertiseSettings.ADVERTISE_TX_POWER_HIGH)
            .setConnectable(true)
            .build()

        // No se incluye el nombre del dispositivo: junto con un UUID de 128 bits
        // supera el limite de 31 bytes del paquete de advertising BLE clasico
        // (error ADVERTISE_FAILED_DATA_TOO_LARGE). El UUID de servicio es
        // suficiente para que la app movil filtre y descubra el wearable.
        val data = AdvertiseData.Builder()
            .setIncludeDeviceName(false)
            .addServiceUuid(android.os.ParcelUuid(SERVICE_UUID))
            .build()

        val callback = object : AdvertiseCallback() {
            override fun onStartSuccess(settingsInEffect: AdvertiseSettings?) {
                Log.i(TAG, "Advertising BLE iniciado correctamente")
            }

            override fun onStartFailure(errorCode: Int) {
                Log.e(TAG, "Fallo al iniciar advertising BLE: $errorCode")
            }
        }

        advertiser.startAdvertising(settings, data, callback)
    }

    /**
     * Conecta por WiFi al mismo servidor Socket.IO que usan el movil y la TV,
     * unicamente para que la pantalla del wearable muestre el estado
     * compartido y sincronizado de la cola (util para la demo, dado que no
     * hay hardware BLE fisico disponible para probar el enlace real).
     */
    private fun conectarAlServidor() {
        try {
            // No se fuerza "websocket" como transporte unico: el cliente EIO3
            // necesita negociar primero por polling y luego actualizar a
            // websocket; forzarlo directamente causaba "websocket error".
            val opciones = IO.Options.builder()
                .setQuery("token=$SERVER_TOKEN&role=wearable")
                .build()

            socket = IO.socket(SERVER_URL, opciones).apply {
                on(Socket.EVENT_CONNECT) {
                    Log.i(TAG, "Conectado al servidor por WiFi: $SERVER_URL")
                    reportarEstadoSimulacion()
                }
                on(Socket.EVENT_CONNECT_ERROR) { args ->
                    Log.w(TAG, "Sin conexion WiFi al servidor (se sigue funcionando solo por BLE): ${args.firstOrNull()}")
                }
                on("update") { args ->
                    (args.firstOrNull() as? JSONObject)?.let { procesarActualizacionServidor(it) }
                }
                connect()
            }
        } catch (e: Exception) {
            Log.w(TAG, "No se pudo inicializar Socket.IO, se continua solo con BLE", e)
        }
    }

    /**
     * Informa al servidor si la simulacion de este wearable esta activa o
     * detenida (boton en pantalla), para que la TV y el movil lo reflejen.
     * No hay equivalente por BLE: ese salto solo lo ve la app movil, que ya
     * deja de recibir NOTIFY mientras la simulacion esta en pausa.
     */
    private fun reportarEstadoSimulacion() {
        if (socket?.connected() == true) {
            val payload = JSONObject()
                .put("rol", "wearable")
                .put("activa", simulacionActiva.value)
            socket?.emit("simEstado", payload)
        }
    }

    private fun procesarActualizacionServidor(json: JSONObject) {
        val estado = EstadoCompartido(
            turno = json.optInt("turno"),
            tiempoEsperaSegundos = json.optInt("tiempoEspera"),
            ritmoCardiacoBpm = json.optInt("ritmoCardiaco"),
            oxigenacionPorcentaje = json.optInt("oxigenacion"),
            temperaturaCorporal = json.optDouble("temperatura", 36.5),
            prioridad = json.optString("prioridad", "normal"),
            sincronizadoPorRed = true,
        )
        estadoActual.value = estado
        Log.d(TAG, "Estado compartido recibido del servidor: $estado")
    }

    /**
     * Simula la lectura de un sensor: incrementa el turno y genera un
     * tiempo de espera y ritmo cardiaco aleatorios, notifica el nuevo valor
     * a los dispositivos BLE suscritos, y lo reporta al servidor por WiFi
     * (si hay conexion disponible).
     */
    private fun emitirNuevoTurno() {
        turnoActual += 1
        val tiempoEspera = Random.nextInt(TIEMPO_MIN_SEGUNDOS, TIEMPO_MAX_SEGUNDOS + 1)
        val ritmoCardiaco = generarRitmoCardiaco()
        val oxigenacion = generarOxigenacion()
        val temperatura = generarTemperatura()

        val payload = "$turnoActual,$tiempoEspera,$ritmoCardiaco,$oxigenacion,$temperatura"
            .toByteArray(StandardCharsets.UTF_8)
        characteristic?.value = payload

        dispositivosSuscritos.forEach { device ->
            characteristic?.let { char ->
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    gattServer?.notifyCharacteristicChanged(device, char, false, payload)
                } else {
                    @Suppress("DEPRECATION")
                    gattServer?.notifyCharacteristicChanged(device, char, false)
                }
            }
        }

        // Mientras no llegue una confirmacion del servidor, la UI muestra el
        // valor generado localmente (marcado como no sincronizado por red).
        if (estadoActual.value?.sincronizadoPorRed != true) {
            estadoActual.value = EstadoCompartido(
                turno = turnoActual,
                tiempoEsperaSegundos = tiempoEspera,
                ritmoCardiacoBpm = ritmoCardiaco,
                oxigenacionPorcentaje = oxigenacion,
                temperaturaCorporal = temperatura,
                prioridad = calcularPrioridadLocal(ritmoCardiaco, oxigenacion, temperatura),
                sincronizadoPorRed = false,
            )
        }

        if (socket?.connected() == true) {
            val telemetria = JSONObject()
                .put("turno", turnoActual)
                .put("tiempoEspera", tiempoEspera)
                .put("ritmoCardiaco", ritmoCardiaco)
                .put("oxigenacion", oxigenacion)
                .put("temperatura", temperatura)
            socket?.emit("telemetry", telemetria)
        }

        Log.d(
            TAG,
            "Turno emitido -> turno=$turnoActual, espera=${tiempoEspera}s, ritmo=${ritmoCardiaco}bpm, " +
                "oxigenacion=${oxigenacion}%, temperatura=${temperatura}C, suscritos=${dispositivosSuscritos.size}"
        )
    }

    /** Ritmo cardiaco simulado: normalmente 60-100 bpm, con ~20% de picos fuera de rango. */
    private fun generarRitmoCardiaco(): Int {
        val esPico = random.nextInt(100) < 20
        return if (esPico) {
            if (random.nextBoolean()) 40 + random.nextInt(10) else 121 + random.nextInt(39)
        } else {
            RITMO_GENERACION_MIN + random.nextInt(RITMO_GENERACION_MAX - RITMO_GENERACION_MIN + 1)
        }
    }

    /** Saturacion de oxigeno simulada: normalmente 95-100%, con ~15% de picos bajos (hipoxemia). */
    private fun generarOxigenacion(): Int {
        val esPico = random.nextInt(100) < 15
        return if (esPico) {
            80 + random.nextInt(OXIGENACION_UMBRAL_MIN - 80)
        } else {
            OXIGENACION_GENERACION_MIN + random.nextInt(OXIGENACION_GENERACION_MAX - OXIGENACION_GENERACION_MIN + 1)
        }
    }

    /**
     * Temperatura corporal simulada: normalmente 36.1-37.2 C, con ~15% de
     * picos (mitad hipotermia 34.0-35.0 C, mitad fiebre 38.0-39.5 C).
     */
    private fun generarTemperatura(): Double {
        val esPico = random.nextInt(100) < 15
        val valor = if (esPico) {
            if (random.nextBoolean()) {
                34.0 + random.nextDouble() * (TEMPERATURA_UMBRAL_MIN - 34.0)
            } else {
                TEMPERATURA_UMBRAL_MAX + random.nextDouble() * 1.5
            }
        } else {
            TEMPERATURA_GENERACION_MIN +
                random.nextDouble() * (TEMPERATURA_GENERACION_MAX - TEMPERATURA_GENERACION_MIN)
        }
        return Math.round(valor * 10) / 10.0
    }

    private fun calcularPrioridadLocal(ritmoCardiaco: Int, oxigenacion: Int, temperatura: Double): String =
        if (ritmoCardiaco < RITMO_UMBRAL_MIN || ritmoCardiaco > RITMO_UMBRAL_MAX ||
            oxigenacion < OXIGENACION_UMBRAL_MIN ||
            temperatura < TEMPERATURA_UMBRAL_MIN || temperatura > TEMPERATURA_UMBRAL_MAX
        ) "alta" else "normal"

    override fun onDestroy() {
        handler.removeCallbacks(simulacionRunnable)
        gattServer?.close()
        socket?.disconnect()
        if (instancia === this) instancia = null
        super.onDestroy()
        Log.i(TAG, "Servicio BLE HorarioMedicoTurnil detenido")
    }
}
