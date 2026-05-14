# IBMTTS Android Bridge (Eloquence for Termux)

A high-performance bridge server that allows running the 32-bit Windows **ETI Eloquence (IBMTTS)** engine on Android devices via Termux, Box86, and Wine.

## 🚀 Overview

This project solves the "No source code" problem for porting legacy Windows TTS engines to Android. It uses a Go-based server to load the 32-bit Windows DLLs and provides a low-latency TCP socket for Android applications to stream real-time audio.

### Features
- **Ultra-Low Latency**: Direct PCM streaming via TCP.
- **Self-Contained**: The Go binary can embed the entire engine (`ECI.DLL` + `.SYN` files).
- **Termux Ready**: Optimized for headless execution in Termux using Box86 and Wine.
- **JSON Protocol**: Simple command structure for `speak`, `stop`, and parameter adjustments (speed, pitch, volume).

---

## 🛠️ Installation (Termux)

1.  Download the `setup_eloquence.sh` script to your Termux home directory.
2.  Make it executable:
    ```bash
    chmod +x setup_eloquence.sh
    ```
3.  Run the setup:
    ```bash
    ./setup_eloquence.sh
    ```
4.  Start the engine:
    ```bash
    start-eloquence
    ```

---

## 💻 Development & Building

### Prerequisites
- [Go](https://golang.org/dl/) (1.16 or higher)
- The engine files (`ECI.DLL` and `.SYN` files) placed in a `lib/` folder.

### Building for 32-bit Windows
To build the server for use in Wine/Termux:
```powershell
# Windows
$env:GOARCH='386'; $env:GOOS='windows'; go build -ldflags='-s -w' -o ibmtts_server_32bit.exe main.go
```

### Testing (Python)
You can test the server using the provided `test_client.py`:
```bash
python test_client.py
```

---

## 📡 API Protocol

The server listens on `127.0.0.1:5555`.

### Speak Command
```json
{
  "cmd": "speak",
  "text": "Hello world"
}
```

### Set Parameters
```json
{
  "cmd": "set_param",
  "param": "speed",
  "value": 100
}
```
*Supported params: `speed`, `pitch`, `volume`, `voice`.*

### Stop Command
```json
{
  "cmd": "stop"
}
```

---

## ⚖️ License
This bridge code is released under the MIT License. Note that the **ETI Eloquence / IBMTTS** engine components are proprietary and are not included in the source code. You must provide your own licensed DLLs.
