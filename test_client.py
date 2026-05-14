import socket
import json
import wave

def test_server():
    server_address = ('127.0.0.1', 5555)
    
    print("Connecting to bridge server...")
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    try:
        sock.connect(server_address)
    except Exception as e:
        print(f"Failed to connect: {e}")
        return

    # 1. Set voice parameters (optional)
    sock.sendall(json.dumps({
        "cmd": "set_param",
        "param": "speed",
        "value": 100
    }).encode())

    # 2. Send speak command
    text = "Hello, this is the Go bridge server. I am speaking through the embedded Eloquence engine."
    print(f"Sending speak command: '{text}'")
    msg = json.dumps({"cmd": "speak", "text": text})
    sock.sendall(msg.encode())

    # 3. Receive audio data
    print("Receiving audio data...")
    pcm_data = bytearray()
    
    # We'll collect until we stop receiving data for a while
    sock.settimeout(2.0) 
    try:
        while True:
            data = sock.recv(8192)
            if not data:
                break
            pcm_data.extend(data)
            print(f"Total received: {len(pcm_data)} bytes", end='\r')
    except socket.timeout:
        print("\nFinished receiving (silence timeout).")
    except Exception as e:
        print(f"\nSocket error: {e}")
    finally:
        sock.close()

    if pcm_data:
        filename = "output_test.wav"
        print(f"Saving {len(pcm_data)} bytes to {filename}...")
        # Save as WAV (Mono, 16-bit, 11025Hz)
        with wave.open(filename, 'wb') as wf:
            wf.setnchannels(1)
            wf.setsampwidth(2)
            wf.setframerate(11025)
            wf.writeframes(pcm_data)
        print("Done! You can now play output_test.wav")
    else:
        print("No audio data received.")

if __name__ == "__main__":
    test_server()
