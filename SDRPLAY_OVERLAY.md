# SDRPlay RSP1B — Upstream Merge Overlay Guide

When pulling from upstream (`smittix/intercept`), this guide tells you exactly what to re-check or fix for each of the 9 RSP1B patches. If the rebase in `update-from-upstream.sh` produces conflicts, look up the affected file below.

---

## Patch 1 — `routes/adsb.py`: SDRPlay in SoapySDR device list

**What changed:** `SDRType.SDRPLAY` added to `has_soapy_sdr` check and `soapy_types` list so readsb is used instead of dump1090.

**Watch for:** Upstream modifying the `has_soapy_sdr` variable or `soapy_types` list — always ensure `SDRType.SDRPLAY` is included.

```python
# Both of these must include SDRType.SDRPLAY:
has_soapy_sdr = any(d.sdr_type in (SDRType.HACKRF, SDRType.LIME_SDR, SDRType.AIRSPY, SDRType.SDRPLAY) for d in devices)
soapy_types = [d.sdr_type.value for d in devices if d.sdr_type in (SDRType.HACKRF, SDRType.LIME_SDR, SDRType.AIRSPY, SDRType.SDRPLAY)]
```

---

## Patch 2 — `utils/sdr/sdrplay.py`: Correct readsb command flags

**What changed:** `build_adsb_command()` uses `--soapy-device=` (not `--device`), `--net-sbs-port=30003`, and `--soapy-enable-agc`.

**Watch for:** Upstream changing the readsb command builder. The three critical flags:

```python
cmd = [
    'readsb',
    '--net',
    '--net-sbs-port=30003',          # Required — readsb defaults to 0 (disabled)
    '--device-type', 'soapysdr',
    f'--soapy-device={device_str}',  # Must be --soapy-device=, NOT --device
    '--soapy-enable-agc',
    '--quiet'
]
```

---

## Patch 3 — `utils/sdr/sdrplay.py`: IFGR gain inversion

**What changed:** `SDRPlayCommandBuilder` inverts the gain value: `ifgr = 59 - gain` because the RSP1B IFGR control works inversely (higher value = lower gain).

**Watch for:** Upstream touching gain handling in the sdrplay builder. Must keep the inversion.

```python
ifgr = max(0, min(59, 59 - int(gain)))  # Inverted: 0=max gain, 59=min gain
```

---

## Patch 4 — `utils/sdr/sdrplay.py`: WFM demodulation support

**What changed:** `build_fm_demod_command()` supports `--wfm` flag for wide FM (broadcast).

**Watch for:** Upstream adding their own WFM handling that conflicts. Preserve the `wfm` branch.

```python
if modulation.lower() in ('wfm', 'wbfm'):
    cmd += ['--wfm']
else:
    cmd += ['--fm']
```

---

## Patch 5 — `utils/sdr/__init__.py`: SDRFactory registers sdrplay

**What changed:** `SDRType.SDRPLAY` is registered in `SDRFactory` so `SDRFactory.create_default_device('sdrplay')` works.

**Watch for:** Upstream adding their own partial SDRPlay registration that conflicts with ours.

```python
SDRFactory.register(SDRType.SDRPLAY, SDRPlayCommandBuilder)
```

---

## Patch 6 — `routes/listening_post.py`: Scanner routing for SDRPlay

**What changed:** `scanner_loop()` checks `sdr_type` and uses `rx_fm` (SoapySDR) instead of `rtl_fm` for non-RTL-SDR devices. `_stop_audio_stream_internal()` pkills `rx_fm` as well.

**Watch for:** Upstream refactoring `scanner_loop()` — the `use_soapy` branch must be preserved.

```python
sdr_type_str = scanner_config.get('sdr_type', 'rtlsdr')
sdr_type = SDRType(sdr_type_str)
use_soapy = sdr_type != SDRType.RTL_SDR

if use_soapy:
    rx_fm_path = find_rx_fm()
    # ... rx_fm command for SDRPlay
else:
    rtl_fm_path = find_rtl_fm()
    # ... rtl_fm command for RTL-SDR
```

And in cleanup:
```python
subprocess.run(['pkill', '-9', 'rx_fm'], capture_output=True, timeout=0.5)
```

---

## Patch 7 — `templates/index.html`: SDRPlay in Hardware Type dropdown

**What changed:** SDRPlay added as first/selected option in `#sdrTypeSelect`, and added to the `sdrCapabilities` JS object.

**Watch for:** Upstream touching the hardware dropdown or `sdrCapabilities` object.

In the `<select id="sdrTypeSelect">`:
```html
<option value="sdrplay" selected>SDRplay</option>
```

In `sdrCapabilities`:
```javascript
'sdrplay': { name: 'SDRplay', freq_min: 0.001, freq_max: 2000, gain_min: 0, gain_max: 59 },
```

Default ADS-B gain set to 49 (from 40):
```html
<input type="text" id="adsbGain" value="49" placeholder="49">
```

---

## Patch 8 — `static/js/modes/listening-post.js`: sdr_type sent in scanner API calls

**What changed:** `startScanner()` and `_startDirectListenInternal()` both include `sdr_type: getSelectedSDRTypeForScanner()` in their POST bodies.

**Watch for:** Upstream modifying the scanner start API payload and removing or overriding this field.

```javascript
body: JSON.stringify({
    // ... other fields ...
    sdr_type: getSelectedSDRTypeForScanner(),  // Must be present
})
```

---

## Patch 9 — macOS: Bluetooth rssi compatibility (bleak)

**What changed:** `routes/bluetooth.py` reads RSSI from `advertisement_data.rssi` with fallback, because newer bleak versions removed `BLEDevice.rssi`.

**Watch for:** Upstream changing bluetooth scan callbacks. Preserve the safe attribute access.

```python
rssi = advertisement_data.rssi if hasattr(advertisement_data, 'rssi') else getattr(device, 'rssi', -100)
```

---

## Quick conflict checklist after `./update-from-upstream.sh`

```
[ ] routes/adsb.py          — Patch 1: SDRType.SDRPLAY in soapy lists
[ ] utils/sdr/sdrplay.py    — Patch 2: readsb flags, Patch 3: gain inversion, Patch 4: WFM
[ ] utils/sdr/__init__.py   — Patch 5: SDRFactory.register(SDRType.SDRPLAY, ...)
[ ] routes/listening_post.py— Patch 6: use_soapy branch + rx_fm pkill
[ ] templates/index.html    — Patch 7: dropdown option + sdrCapabilities + gain default
[ ] static/js/modes/listening-post.js — Patch 8: sdr_type in POST bodies
[ ] routes/bluetooth.py     — Patch 9: rssi fallback
```
