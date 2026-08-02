package com.horariomedicoturnil.wear

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.Button
import androidx.compose.material.ButtonDefaults
import androidx.compose.material.MaterialTheme
import androidx.compose.material.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat

/** Colores oficiales de HorarioMedicoTurnil */
private val FondoApp = Color(0xFFD8FFAD)
private val TextoPrincipal = Color(0xFF2A5643)
private val TextoSecundario = Color(0xFF3A674B)

/**
 * Actividad principal del wearable. Pide los permisos de Bluetooth en tiempo
 * de ejecucion (obligatorio desde Android 12 / API 31) y, una vez concedidos,
 * arranca el servicio BLE en segundo plano (BluetoothLeService). Muestra en
 * pantalla el turno/ritmo cardiaco actuales, tomados del estado compartido
 * que expone el servicio (sincronizado con el servidor cuando hay WiFi).
 */
class MainActivity : ComponentActivity() {

    private var servicioActivo = mutableStateOf(false)

    /** Permisos runtime necesarios para actuar como servidor GATT (Android 12+). */
    private val permisosBluetooth: Array<String>
        get() = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            arrayOf(Manifest.permission.BLUETOOTH_CONNECT, Manifest.permission.BLUETOOTH_ADVERTISE)
        } else {
            emptyArray()
        }

    private val solicitarPermisos =
        registerForActivityResult(ActivityResultContracts.RequestMultiplePermissions()) { resultados ->
            if (resultados.values.all { it }) {
                iniciarServicioBle()
            }
        }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        setContent {
            HorarioMedicoTurnilWearScreen(servicioActivo = servicioActivo.value)
        }

        if (permisosFaltantes().isEmpty()) {
            iniciarServicioBle()
        } else {
            solicitarPermisos.launch(permisosBluetooth)
        }
    }

    private fun permisosFaltantes(): List<String> =
        permisosBluetooth.filter {
            ContextCompat.checkSelfPermission(this, it) != PackageManager.PERMISSION_GRANTED
        }

    private fun iniciarServicioBle() {
        startService(Intent(this, BluetoothLeService::class.java))
        servicioActivo.value = true
    }
}

@Composable
fun HorarioMedicoTurnilWearScreen(servicioActivo: Boolean) {
    val estado by BluetoothLeService.estadoStream.collectAsState()
    val simulacionActiva by BluetoothLeService.simulacionActiva.collectAsState()

    MaterialTheme {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(FondoApp)
                .padding(16.dp),
            contentAlignment = Alignment.Center
        ) {
            if (!servicioActivo || estado == null) {
                Text(
                    text = if (!servicioActivo) {
                        "Esperando permisos de Bluetooth - HorarioMedicoTurnil"
                    } else {
                        "HorarioMedicoTurnil Wear\nIniciando servicio..."
                    },
                    color = TextoPrincipal,
                    textAlign = TextAlign.Center
                )
            } else {
                val datos = estado!!
                Column(
                    modifier = Modifier
                        .verticalScroll(rememberScrollState())
                        .padding(vertical = 24.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    Text(
                        text = "Turno",
                        color = TextoSecundario,
                    )
                    Text(
                        text = "${datos.turno}",
                        color = TextoPrincipal,
                        fontWeight = FontWeight.Bold,
                        style = MaterialTheme.typography.h3,
                    )
                    Text(
                        text = "Ritmo: ${datos.ritmoCardiacoBpm} bpm",
                        color = TextoSecundario,
                    )
                    Text(
                        text = "SpO2: ${datos.oxigenacionPorcentaje}%",
                        color = TextoSecundario,
                    )
                    Text(
                        text = "Temp: ${datos.temperaturaCorporal}°C",
                        color = TextoSecundario,
                    )
                    if (datos.prioridad == "alta") {
                        Text(
                            text = "PRIORIDAD ALTA",
                            color = TextoPrincipal,
                            fontWeight = FontWeight.Bold,
                        )
                    }
                    Text(
                        text = if (datos.sincronizadoPorRed) {
                            "Sincronizado con el servidor"
                        } else {
                            "Local (sin WiFi al servidor)"
                        },
                        color = TextoSecundario,
                    )
                    if (!simulacionActiva) {
                        Text(
                            text = "Simulacion detenida",
                            color = TextoPrincipal,
                            fontWeight = FontWeight.Bold,
                        )
                    }
                    Spacer(modifier = Modifier.height(8.dp))
                    Button(
                        onClick = { BluetoothLeService.alternarSimulacion() },
                        colors = ButtonDefaults.buttonColors(backgroundColor = TextoSecundario),
                    ) {
                        Text(if (simulacionActiva) "Detener" else "Reanudar")
                    }
                }
            }
        }
    }
}
