import warnings 
warnings.filterwarnings("ignore", category=DeprecationWarning)

import paho.mqtt.client as mqtt
import time
import json
import ssl
import numpy as np

# Configuration
BROKER = "192.168.100.129"
PORT = 8883
TOPIC = "/patients/ward1/bed1/ecg"
STATUS_TOPIC = "/patients/ward1/bed1/ecg/status"
USERNAME = "myuser"
PASSWORD = "myuser"
DEVICE_ID = "ecg_monitor_1"
FS = 35 # Sampling frequency in Hz

# Generate one synthetic ECG heartbeat (PQRST waveform)
def generate_ecg_beat(fs=500):
    t = np.linspace(0, 1, fs)
    beat = (
        0.1 * np.sin(2 * np.pi * 1.0 * t) +       # baseline
        -0.15 * np.exp(-((t - 0.2) ** 2) / 0.001) +  # Q
        1.0 * np.exp(-((t - 0.3) ** 2) / 0.0005) +   # R
        -0.3 * np.exp(-((t - 0.35) ** 2) / 0.0008) + # S
        0.4 * np.exp(-((t - 0.6) ** 2) / 0.01)       # T
    )
    return beat

ecg_beat = generate_ecg_beat(FS)
index = 0

# MQTT setup
client = mqtt.Client(client_id=DEVICE_ID)
client.username_pw_set(USERNAME, PASSWORD)


#TLS Config
client.tls_set(
    ca_certs="/home/debian/IoT/Environment/mosquitto/certs/ca.crt",
    cert_reqs=ssl.CERT_REQUIRED
)
client.tls_insecure_set(False)

#LWT Config
client.will_set(STATUS_TOPIC, "offline", qos=1, retain=True)

def on_connect(client, userdata, flags, rc):
    print(f"[{DEVICE_ID}] Connected: {rc}")
    client.publish(STATUS_TOPIC, "online", qos=1, retain=True)

client.on_connect = on_connect
client.connect(BROKER, PORT, 60)
client.loop_start()

try:
    while True:
        # Loop over ECG beat values
        if index >= len(ecg_beat):
            index = 0  # restart beat
        sample_value = round(ecg_beat[index] + np.random.normal(0, 0.02), 3)  # add noise
        index += 1

        payload = {
            "device_id": DEVICE_ID,
            "patient_id": "P001",
            "ecg_signal": sample_value,  # one value only
            "timestamp": time.time()
        }
        client.publish(TOPIC, json.dumps(payload), qos=1)
        #print(f"[{DEVICE_ID}] Sent ECG value: {sample_value}")
        time.sleep(1 / FS)  # real-time pacing (500 samples per second)

except KeyboardInterrupt:
    print("ECG monitor stopped.")
    client.publish(STATUS_TOPIC, "offline", qos=1, retain=True)
    client.disconnect()
    client.loop_stop()
