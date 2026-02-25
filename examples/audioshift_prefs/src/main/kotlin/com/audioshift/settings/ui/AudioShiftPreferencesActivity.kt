package com.audioshift.settings.ui

import android.annotation.SuppressLint
import android.content.Context
import android.content.SharedPreferences
import android.media.AudioManager
import android.os.Build
import android.os.Bundle
import android.os.SystemProperties
import android.util.Log
import androidx.appcompat.app.AppCompatActivity
import androidx.preference.Preference
import androidx.preference.PreferenceFragmentCompat
import androidx.preference.PreferenceManager
import androidx.preference.SeekBarPreference
import androidx.preference.SwitchPreference
import com.audioshift.settings.R

/**
 * AudioShift Preferences Activity
 *
 * Purpose:
 *   Main settings activity for real-time control of AudioShift effect.
 *   Provides UI for adjusting pitch, latency, and CPU parameters.
 *
 * Features:
 *   - Enable/disable toggle
 *   - Pitch shift slider (±100 cents)
 *   - WSOLA parameter tuning
 *   - Live performance monitoring
 *   - Verification and help
 *
 * Implementation:
 *   - PreferenceFragmentCompat for modern preference UI
 *   - SystemProperties for runtime parameter changes
 *   - Shared preferences for default values
 *   - Background service for continuous monitoring
 *
 * Permissions Required:
 *   - MODIFY_AUDIO_SETTINGS
 *   - READ_PHONE_STATE (optional)
 */

class AudioShiftPreferencesActivity : AppCompatActivity() {

    companion object {
        private const val TAG = "AudioShiftSettings"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_preferences)

        // Load preferences fragment
        if (savedInstanceState == null) {
            supportFragmentManager
                .beginTransaction()
                .replace(R.id.preferences_container, AudioShiftPreferencesFragment())
                .commit()
        }

        // Verify AudioShift module is installed
        verifyModuleInstallation()
    }

    /**
     * Verify AudioShift module installation
     */
    private fun verifyModuleInstallation() {
        try {
            val version = SystemProperties.get("audioshift.version", "")
            if (version.isEmpty()) {
                Log.w(TAG, "AudioShift module not detected")
                showModuleNotInstalledDialog()
            } else {
                Log.i(TAG, "AudioShift module detected: v$version")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error verifying module: ${e.message}")
        }
    }

    /**
     * Show dialog if module is not installed
     */
    private fun showModuleNotInstalledDialog() {
        // Would be implemented with AlertDialog
        // For now, just log the issue
        Log.w(TAG, "Module not installed - verify via Magisk Manager")
    }
}

/**
 * Preferences Fragment Implementation
 *
 * Handles:
 *   - Preference UI loading
 *   - Preference value changes
 *   - System property synchronization
 *   - Performance readout updates
 *   - Help/verification actions
 */
class AudioShiftPreferencesFragment : PreferenceFragmentCompat(),
    SharedPreferences.OnSharedPreferenceChangeListener {

    companion object {
        private const val TAG = "AudioShiftPrefs"
    }

    private lateinit var audioManager: AudioManager
    private lateinit var prefs: SharedPreferences

    override fun onCreatePreferences(savedInstanceState: Bundle?, rootKey: String?) {
        setPreferencesFromResource(R.xml.preferences, rootKey)
        audioManager = requireContext().getSystemService(Context.AUDIO_SERVICE) as AudioManager
        prefs = PreferenceManager.getDefaultSharedPreferences(requireContext())
    }

    override fun onResume() {
        super.onResume()
        prefs.registerOnSharedPreferenceChangeListener(this)
        updatePerformanceReadouts()
    }

    override fun onPause() {
        super.onPause()
        prefs.unregisterOnSharedPreferenceChangeListener(this)
    }

    override fun onSharedPreferenceChanged(sharedPrefs: SharedPreferences?, key: String?) {
        when (key) {
            // Enable/disable toggle
            "audioshift.enabled" -> {
                val enabled = sharedPrefs?.getBoolean(key, true) ?: true
                setSystemProperty("audioshift.enabled", if (enabled) "1" else "0")
                Log.i(TAG, "AudioShift ${if (enabled) "enabled" else "disabled"}")
            }

            // Pitch shift adjustment
            "audioshift.pitch_cents" -> {
                val cents = sharedPrefs?.getInt(key, -32) ?: -32
                val semitones = cents / 100.0f
                setSystemProperty("audioshift.pitch_semitones", semitones.toString())
                Log.i(TAG, "Pitch set to: $cents cents ($semitones semitones)")
            }

            // WSOLA sequence length
            "audioshift.wsola.sequence_ms" -> {
                val sequence = sharedPrefs?.getInt(key, 40) ?: 40
                setSystemProperty("audioshift.wsola.sequence_ms", sequence.toString())
                Log.i(TAG, "WSOLA sequence: ${sequence}ms")
            }

            // WSOLA seek window
            "audioshift.wsola.seekwindow_ms" -> {
                val seekwindow = sharedPrefs?.getInt(key, 15) ?: 15
                setSystemProperty("audioshift.wsola.seekwindow_ms", seekwindow.toString())
                Log.i(TAG, "WSOLA seekwindow: ${seekwindow}ms")
            }

            // WSOLA overlap
            "audioshift.wsola.overlap_ms" -> {
                val overlap = sharedPrefs?.getInt(key, 8) ?: 8
                setSystemProperty("audioshift.wsola.overlap_ms", overlap.toString())
                Log.i(TAG, "WSOLA overlap: ${overlap}ms")
            }
        }

        // Update performance readouts
        updatePerformanceReadouts()
    }

    override fun onPreferenceTreeClick(preference: Preference?): Boolean {
        return when (preference?.key) {
            "audioshift.verify_installation" -> {
                verifyInstallation()
                true
            }

            "audioshift.help" -> {
                showHelpDialog()
                true
            }

            "audioshift.about" -> {
                showAboutDialog()
                true
            }

            else -> super.onPreferenceTreeClick(preference)
        }
    }

    /**
     * Update live performance readouts
     */
    @SuppressLint("DefaultLocale")
    private fun updatePerformanceReadouts() {
        try {
            // Latency readout
            val latency = SystemProperties.get("audioshift.latency_ms", "0").toFloatOrNull() ?: 0f
            updatePreferenceSummary("audioshift.latency_ms", String.format("Latency: %.1f ms", latency))

            // CPU usage readout
            val cpu = SystemProperties.get("audioshift.cpu_percent", "0").toFloatOrNull() ?: 0f
            updatePreferenceSummary("audioshift.cpu_percent", String.format("CPU: %.1f %%", cpu))

            // Output frequency readout
            val frequency = SystemProperties.get("audioshift.output_frequency", "0").toFloatOrNull() ?: 0f
            updatePreferenceSummary(
                "audioshift.output_frequency",
                String.format("Output: %.1f Hz", frequency)
            )

            // Active audio device
            val device = getActiveAudioDevice()
            updatePreferenceSummary("audioshift.active_device", "Active device: $device")

        } catch (e: Exception) {
            Log.e(TAG, "Error updating readouts: ${e.message}")
        }
    }

    /**
     * Get active audio device name
     */
    private fun getActiveAudioDevice(): String {
        return try {
            // Check which device is active
            when {
                audioManager.isSpeakerphoneOn -> "Speaker"
                audioManager.isBluetoothScoOn || audioManager.isBluetoothOn -> "Bluetooth"
                audioManager.isWiredHeadsetOn -> "Wired Headset"
                else -> "Default"
            }
        } catch (e: Exception) {
            "Unknown"
        }
    }

    /**
     * Verify AudioShift installation
     */
    private fun verifyInstallation() {
        try {
            val version = SystemProperties.get("audioshift.version", "")
            val enabled = SystemProperties.get("audioshift.enabled", "0")

            val status = if (version.isNotEmpty() && enabled == "1") {
                "✓ AudioShift is installed and active (v$version)"
            } else if (version.isNotEmpty()) {
                "✓ AudioShift installed (v$version) but disabled"
            } else {
                "✗ AudioShift module not detected\nInstall via Magisk Manager"
            }

            showSimpleDialog("Verification Result", status)
            Log.i(TAG, "Verification: $status")

        } catch (e: Exception) {
            showSimpleDialog("Error", "Could not verify installation: ${e.message}")
        }
    }

    /**
     * Show help dialog
     */
    private fun showHelpDialog() {
        val help = """
            # AudioShift Help

            ## Pitch Shift
            Adjust pitch in musical cents. Default -31.77 cents converts 440Hz to 432Hz.

            ## WSOLA Parameters (Advanced)
            - Sequence: Analysis window size (larger = more latency)
            - Seek Window: Search range for optimal overlap
            - Overlap: Crossfade length between frames

            ## Performance
            - Latency should be <15ms for real-time feel
            - CPU usage <10% is ideal
            - Output frequency should be ~432Hz

            ## Troubleshooting
            1. Check if module is installed via Magisk Manager
            2. Run "Verify Installation" above
            3. Try disabling other audio apps
            4. Check device supports ARM64 architecture

            ## Support
            GitHub: github.com/iamthegreatdestroyer/audioshift
        """.trimIndent()

        showSimpleDialog("Help & FAQ", help)
    }

    /**
     * Show about dialog
     */
    private fun showAboutDialog() {
        val version = SystemProperties.get("audioshift.version", "1.0")
        val about = """
            # About AudioShift

            ## Version
            Settings App v1.0
            AudioShift Effect v$version

            ## Description
            Real-time 432 Hz audio pitch shift for Android devices

            ## Features
            ✓ System-wide audio effect
            ✓ Adjustable pitch and latency
            ✓ Real-time performance monitoring
            ✓ Works with all audio apps

            ## Built With
            - SoundTouch (WSOLA algorithm)
            - Android AudioFlinger
            - Magisk module framework

            ## Credits
            AudioShift Project
            License: MIT Open Source

            ## Repository
            https://github.com/iamthegreatdestroyer/audioshift
        """.trimIndent()

        showSimpleDialog("About AudioShift", about)
    }

    /**
     * Helper: Set system property via reflection
     */
    private fun setSystemProperty(key: String, value: String) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                // Android 10+: Use reflection for SystemProperties
                val clazz = Class.forName("android.os.SystemProperties")
                val method = clazz.getMethod("set", String::class.java, String::class.java)
                method.invoke(null, key, value)
            }
        } catch (e: Exception) {
            Log.w(TAG, "Could not set system property $key: ${e.message}")
        }
    }

    /**
     * Helper: Update preference summary
     */
    private fun updatePreferenceSummary(key: String, summary: String) {
        findPreference<Preference>(key)?.summary = summary
    }

    /**
     * Helper: Show simple info dialog
     */
    private fun showSimpleDialog(title: String, message: String) {
        // Would be implemented with AlertDialog
        Log.i(TAG, "$title: $message")
    }
}
