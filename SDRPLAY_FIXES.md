# SDRplay RSP1B - Poprawki dla macOS

Ten plik dokumentuje poprawki potrzebne do obsługi SDRplay RSP1B na macOS.

## Data: 2026-01-10

## Problemy i rozwiązania

### 1. SDRplay nie był w liście urządzeń SoapySDR dla ADS-B

**Plik:** `routes/adsb.py` (linie 262-263)

**Problem:** SDRplay nie był uwzględniony w `has_soapy_sdr`, więc kod próbował użyć dump1090 zamiast readsb.

**Poprawka:**
```python
# Przed:
has_soapy_sdr = any(d.sdr_type in (SDRType.HACKRF, SDRType.LIME_SDR, SDRType.AIRSPY) for d in devices)
soapy_types = [d.sdr_type.value for d in devices if d.sdr_type in (SDRType.HACKRF, SDRType.LIME_SDR, SDRType.AIRSPY)]

# Po:
has_soapy_sdr = any(d.sdr_type in (SDRType.HACKRF, SDRType.LIME_SDR, SDRType.AIRSPY, SDRType.SDRPLAY) for d in devices)
soapy_types = [d.sdr_type.value for d in devices if d.sdr_type in (SDRType.HACKRF, SDRType.LIME_SDR, SDRType.AIRSPY, SDRType.SDRPLAY)]
```

---

### 2. Komenda readsb dla SDRplay miała błędne parametry

**Plik:** `utils/sdr/sdrplay.py` (funkcja `build_adsb_command`)

**Problem:**
- Brakowało `--net-sbs-port=30003` (readsb domyślnie ustawia na 0 = wyłączony)
- Użyty był `--device` zamiast `--soapy-device`
- Brakowało `--soapy-enable-agc`

**Poprawka:**
```python
# Przed:
cmd = [
    'readsb',
    '--net',
    '--device-type', 'soapysdr',
    '--device', device_str,
    '--quiet'
]

# Po:
cmd = [
    'readsb',
    '--net',
    '--net-sbs-port=30003',  # Required - readsb defaults to 0 (disabled)
    '--device-type', 'soapysdr',
    f'--soapy-device={device_str}',
    '--soapy-enable-agc',
    '--quiet'
]
```

---

### 3. SDRplay nie był w UI (Hardware Type dropdown)

**Plik:** `templates/index.html`

**Problem:** Brak opcji SDRplay w dropdown "Hardware Type"

**Poprawka (około linii 321-327):**
```html
<select id="sdrTypeSelect" onchange="onSDRTypeChanged()">
    <option value="rtlsdr">RTL-SDR</option>
    <option value="sdrplay">SDRplay</option>  <!-- DODANE -->
    <option value="limesdr">LimeSDR</option>
    <option value="hackrf">HackRF</option>
    <option value="airspy">Airspy</option>
</select>
```

**Oraz w JavaScript sdrCapabilities (około linii 2668):**
```javascript
const sdrCapabilities = {
    'rtlsdr': { name: 'RTL-SDR', freq_min: 24, freq_max: 1766, gain_min: 0, gain_max: 50 },
    'sdrplay': { name: 'SDRplay', freq_min: 0.001, freq_max: 2000, gain_min: 0, gain_max: 59 },  // DODANE
    'limesdr': { name: 'LimeSDR', freq_min: 0.1, freq_max: 3800, gain_min: 0, gain_max: 73 },
    'hackrf': { name: 'HackRF', freq_min: 1, freq_max: 6000, gain_min: 0, gain_max: 62 },
    'airspy': { name: 'Airspy', freq_min: 24, freq_max: 1800, gain_min: 0, gain_max: 21 }  // DODANE
};
```

---

## Dodatkowe poprawki z poprzedniej wersji (opcjonalne)

### 4. Bluetooth rssi error w nowszej wersji bleak

**Plik:** `routes/bluetooth.py` (około linii 173)

**Problem:** `BLEDevice` nie ma atrybutu `rssi` w nowszych wersjach bleak - jest w `advertisement_data`

**Poprawka:**
```python
# Przed:
rssi = device.rssi

# Po:
rssi = advertisement_data.rssi if hasattr(advertisement_data, 'rssi') else getattr(device, 'rssi', -100)
```

---

### 5. Endpoint restartu SDRplay service (opcjonalne)

**Plik:** `app.py`

Można dodać endpointy `/sdrplay/status` i `/sdrplay/restart` do zarządzania usługą SDRplay na macOS gdy się zawiesi.

Wymaga uruchomienia serwera z `sudo` dla funkcji restartu.

---

## SDRplay Service na macOS

Gdy SoapySDRUtil się wiesza ("device may be busy"), restart usługi:

```bash
sudo launchctl unload /Library/LaunchDaemons/com.sdrplay.service.plist
sudo launchctl load /Library/LaunchDaemons/com.sdrplay.service.plist
```

---

## Wymagane narzędzia

- `readsb` z obsługą SoapySDR (dla ADS-B z SDRplay)
- `rx_fm` z SoapySDR (dla pager/listening post z SDRplay)
- `rtl_433` (natywnie obsługuje SoapySDR)
- SDRplay API 3.x zainstalowane w `/Library/SDRplayAPI/`
- SoapySDRPlay moduł (`brew install soapysdrplay`)

---

---

### 6. SDRplay jako domyślny hardware type

**Plik:** `templates/index.html` (linia ~322)

**Zmiana:** SDRplay jako pierwsza opcja z `selected`:
```html
<select id="sdrTypeSelect" onchange="onSDRTypeChanged()">
    <option value="sdrplay" selected>SDRplay</option>
    <option value="rtlsdr">RTL-SDR</option>
    ...
</select>
```

---

### 7. Zwiększony domyślny gain dla ADS-B

**Plik:** `templates/index.html` (linia ~753)

**Zmiana:** Gain z 40 na 49 dB dla lepszego odbioru przy słabszych sygnałach:
```html
<input type="text" id="adsbGain" value="49" placeholder="49">
```

---

### 8. Skaner radiowy nie działał z SDRplay

**Plik:** `routes/listening_post.py` (funkcja `scanner_loop`)

**Problem:** Funkcja `scanner_loop()` używała tylko `rtl_fm`, nie obsługiwała SDRplay przez `rx_fm`.

**Poprawka:**
```python
# Dodano na początku scanner_loop():
sdr_type_str = scanner_config.get('sdr_type', 'rtlsdr')
sdr_type = SDRType(sdr_type_str)
use_soapy = sdr_type != SDRType.RTL_SDR

if use_soapy:
    rx_fm_path = find_rx_fm()
    # ... obsługa rx_fm dla SDRplay
else:
    rtl_fm_path = find_rtl_fm()
    # ... obsługa rtl_fm dla RTL-SDR

# W pętli skanowania - budowanie komendy dla obu typów SDR
if use_soapy:
    device_obj = SDRFactory.create_default_device(sdr_type, index=device)
    builder = SDRFactory.get_builder(sdr_type)
    sdr_cmd = builder.build_fm_demod_command(...)
else:
    sdr_cmd = [rtl_fm_path, '-M', mod, '-f', ...]
```

**Również w `_stop_audio_stream_internal()`:**
```python
# Dodano pkill dla rx_fm:
subprocess.run(['pkill', '-9', 'rx_fm'], capture_output=True, timeout=0.5)
```

---

### 9. Frontend nie wysyłał sdr_type do API skanera

**Plik:** `static/js/modes/listening-post.js`

**Problem:** Funkcje `startScanner()` i `_startDirectListenInternal()` nie wysyłały `sdr_type` w żądaniach API, więc backend zawsze używał domyślnego RTL-SDR.

**Poprawka w `startScanner()` (~linia 196):**
```javascript
body: JSON.stringify({
    start_freq: startFreq,
    // ... inne parametry
    sdr_type: getSelectedSDRTypeForScanner(),  // DODANE
    bias_t: ...
})
```

**Poprawka w `_startDirectListenInternal()` (~linia 1769):**
```javascript
body: JSON.stringify({
    frequency: freq,
    modulation: currentModulation,
    squelch: squelch,
    gain: gain,
    sdr_type: getSelectedSDRTypeForScanner()  // DODANE
})
```

---

## Autor
Poprawki wykonane przy pomocy Claude Code, 2026-01-10
