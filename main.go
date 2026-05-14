package main

import (
	"embed"
	"encoding/binary"
	"encoding/json"
	"fmt"
	"io"
	"io/fs"
	"log"
	"net"
	"os"
	"path/filepath"
	"runtime"
	"sync"
	"syscall"
	"unsafe"
)

//go:embed lib/*
var engineFiles embed.FS

const (
	eciSynthMode           = 0
	eciInputType           = 1
	eciSampleRate          = 5
	eciLanguageDialect     = 9
	eciWaveformBuffer      = 0
	samplesPerBuffer       = 3300
	defaultSampleRateIndex = 1 
)

const (
	vSpeed  = 6
	vVolume = 7
	vPitch  = 2
)

type Command struct {
	Cmd   string `json:"cmd"`   
	Text  string `json:"text"`  
	Param string `json:"param"` 
	Value int    `json:"value"` 
}

var (
	user32           = syscall.NewLazyDLL("user32.dll")
	procGetMessage   = user32.NewProc("GetMessageW")
	procDispatch     = user32.NewProc("DispatchMessageW")
	procTranslate    = user32.NewProc("TranslateMessage")

	eciDll         *syscall.LazyDLL
	procEciNewEx   *syscall.LazyProc
	procEciDelete  *syscall.LazyProc
	procEciAddText *syscall.LazyProc
	procEciSynth   *syscall.LazyProc
	procEciStop    *syscall.LazyProc
	procEciSetBuf  *syscall.LazyProc
	procEciRegCb   *syscall.LazyProc
	procEciSetParam *syscall.LazyProc
	procEciSetVParam *syscall.LazyProc

	engineHandle uintptr
	audioBuffer  []int16
	activeConn   net.Conn
	connMutex    sync.Mutex
	tempDir      string
	
	// Keep callback alive
	eciCallbackPtr uintptr
)

func extractEngine() (string, error) {
	dir, err := os.MkdirTemp("", "ibmtts_engine")
	if err != nil {
		return "", err
	}
	err = fs.WalkDir(engineFiles, "lib", func(path string, d fs.DirEntry, err error) error {
		if err != nil || d.IsDir() {
			return err
		}
		data, err := engineFiles.ReadFile(path)
		if err != nil {
			return err
		}
		targetPath := filepath.Join(dir, filepath.Base(path))
		return os.WriteFile(targetPath, data, 0644)
	})
	return dir, err
}

func initDLL() error {
	var err error
	tempDir, err = extractEngine()
	if err != nil {
		return fmt.Errorf("failed to extract: %v", err)
	}
	
	dllPath := filepath.Join(tempDir, "ECI.DLL")
	log.Printf("[DEBUG] Engine Path: %s", tempDir)
	
	eciDll = syscall.NewLazyDLL(dllPath)
	procEciNewEx = eciDll.NewProc("eciNewEx")
	procEciDelete = eciDll.NewProc("eciDelete")
	procEciAddText = eciDll.NewProc("eciAddText")
	procEciSynth = eciDll.NewProc("eciSynthesize")
	procEciStop = eciDll.NewProc("eciStop")
	procEciSetBuf = eciDll.NewProc("eciSetOutputBuffer")
	procEciRegCb = eciDll.NewProc("eciRegisterCallback")
	procEciSetParam = eciDll.NewProc("eciSetParam")
	procEciSetVParam = eciDll.NewProc("eciSetVoiceParam")

	return eciDll.Load()
}

func eciCallbackHandler(h uintptr, msg int32, lp int32, data uintptr) uintptr {
	// Log every callback to see if it fires at all
	if msg == eciWaveformBuffer {
		connMutex.Lock()
		defer connMutex.Unlock()
		if activeConn != nil {
			byteBuf := make([]byte, lp*2)
			for i := 0; i < int(lp); i++ {
				binary.LittleEndian.PutUint16(byteBuf[i*2:], uint16(audioBuffer[i]))
			}
			activeConn.Write(byteBuf)
		}
	} else {
		// log.Printf("[CALLBACK] Msg: %d, Param: %d", msg, lp)
	}
	return 1 
}

func setupEngine() error {
	res, _, _ := procEciNewEx.Call(uintptr(0x00010000))
	engineHandle = res
	if engineHandle == 0 {
		return fmt.Errorf("failed to create engine instance")
	}

	eciCallbackPtr = syscall.NewCallback(eciCallbackHandler)
	procEciRegCb.Call(engineHandle, eciCallbackPtr, 0)

	audioBuffer = make([]int16, samplesPerBuffer)
	procEciSetBuf.Call(engineHandle, uintptr(samplesPerBuffer), uintptr(unsafe.Pointer(&audioBuffer[0])))

	procEciSetParam.Call(engineHandle, eciSynthMode, 1)
	procEciSetParam.Call(engineHandle, eciInputType, 1)
	procEciSetParam.Call(engineHandle, eciSampleRate, defaultSampleRateIndex)
	
	return nil
}

func handleClient(conn net.Conn) {
	defer conn.Close()
	log.Printf("[INFO] Client connected: %s", conn.RemoteAddr())

	connMutex.Lock()
	activeConn = conn
	connMutex.Unlock()

	decoder := json.NewDecoder(conn)
	for {
		var cmd Command
		err := decoder.Decode(&cmd)
		if err == io.EOF {
			break
		}
		if err != nil {
			break
		}

		switch cmd.Cmd {
		case "speak":
			log.Printf("[INFO] Speaking: %s", cmd.Text)
			textPtr, _ := syscall.BytePtrFromString(cmd.Text)
			procEciStop.Call(engineHandle) 
			procEciAddText.Call(engineHandle, uintptr(unsafe.Pointer(textPtr)))
			procEciSynth.Call(engineHandle)

		case "stop":
			procEciStop.Call(engineHandle)

		case "set_param":
			switch cmd.Param {
			case "speed":
				procEciSetVParam.Call(engineHandle, 0, vSpeed, uintptr(cmd.Value))
			case "pitch":
				procEciSetVParam.Call(engineHandle, 0, vPitch, uintptr(cmd.Value))
			case "volume":
				procEciSetVParam.Call(engineHandle, 0, vVolume, uintptr(cmd.Value))
			case "voice":
				procEciSetParam.Call(engineHandle, eciLanguageDialect, uintptr(cmd.Value))
			}
		}
	}

	connMutex.Lock()
	if activeConn == conn {
		activeConn = nil
	}
	connMutex.Unlock()
}

type MSG struct {
	HWND    uintptr
	Message uint32
	WParam  uintptr
	LParam  uintptr
	Time    uint32
	Pt      struct{ X, Y int32 }
}

func main() {
	runtime.LockOSThread()
	log.Println("[SYSTEM] IBMTTS Bridge Server Starting...")

	if err := initDLL(); err != nil {
		log.Fatalf("[FATAL] %v", err)
	}

	if err := setupEngine(); err != nil {
		log.Fatalf("[FATAL] %v", err)
	}

	// Start TCP server in a separate goroutine
	go func() {
		ln, err := net.Listen("tcp", ":5555")
		if err != nil {
			log.Fatalf("[FATAL] %v", err)
		}
		log.Println("[SYSTEM] Server ready on port 5555")

		for {
			conn, err := ln.Accept()
			if err != nil {
				continue
			}
			go handleClient(conn)
		}
	}()

	// Cleanup on exit
	defer os.RemoveAll(tempDir)

	// --- Windows Message Loop (Critical for Callbacks) ---
	var msg MSG
	for {
		res, _, _ := procGetMessage.Call(uintptr(unsafe.Pointer(&msg)), 0, 0, 0)
		if res == 0 {
			break
		}
		procTranslate.Call(uintptr(unsafe.Pointer(&msg)))
		procDispatch.Call(uintptr(unsafe.Pointer(&msg)))
	}
}
