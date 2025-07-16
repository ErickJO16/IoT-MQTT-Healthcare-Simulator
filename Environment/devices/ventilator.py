import warnings 
warnings.filterwarnings("ignore", category=DeprecationWarning)

import paho.mqtt.client as mqtt
import time
import json
import ssl
import numpy as np

# MQTT Configuration
BROKER = "192.168.100.129"
PORT = 8883
DATA_TOPIC = "/patients/ward1/bed1/ventilator/data"
CMD_TOPIC = "/patients/ward1/bed1/ventilator/cmd"
STATUS_TOPIC = "/patients/ward1/bed1/ventilator/status"
USERNAME = "myuser"
PASSWORD = "myuser"
DEVICE_ID = "ventilator_1"

# Breathing settings
FS = 12        # Hz
BPM = 16       # breaths per minute
AMPLITUDE = 1.0
PRESSURE_BASE = 10
PRESSURE_RANGE = 8

# Generate one breath cycle (duration = 60 / BPM seconds)
breath_duration = 60 / BPM  # seconds
t = np.linspace(0, breath_duration, int(FS * breath_duration))

def generate_breath_cycle(t, amplitude=1.0, freq_hz=BPM / 60):
    return amplitude * np.sin(2 * np.pi * freq_hz * t)

breath_waveform = generate_breath_cycle(t)
index = 0

# MQTT client setup
client = mqtt.Client(client_id=DEVICE_ID)
client.username_pw_set(USERNAME, PASSWORD)
client.tls_set(
    ca_certs="/home/debian/IoT/Environment/mosquitto/certs/ca.crt",
    cert_reqs=ssl.CERT_REQUIRED
)
client.tls_insecure_set(False)
client.will_set(STATUS_TOPIC, "offline", qos=1, retain=True)

def on_connect(client, userdata, flags, rc):
    print(f"[{DEVICE_ID}] Connected: {rc}")
    client.subscribe(CMD_TOPIC)
    client.publish(STATUS_TOPIC, "online", qos=1, retain=True)

def on_message(client, userdata, msg):
    cmd = msg.payload.decode()
    print(f"[{DEVICE_ID}] Command received: {cmd}")

client.on_connect = on_connect
client.on_message = on_message
client.connect(BROKER, PORT, 60)
client.loop_start()

try:
    while True:
        if index >= len(breath_waveform):
            index = 0  # loop the waveform

        breath_signal = round(breath_waveform[index] + np.random.normal(0, 0.01), 3)
        pressure = round(PRESSURE_BASE + PRESSURE_RANGE * max(0, breath_signal), 2)  # positive phase only
        rate = BPM  # can be made dynamic later
        index += 1

        payload = {
            "device_id": DEVICE_ID,
            "patient_id": "P001",
            "breath_signal": breath_signal,
            "pressure": pressure,
            "rate": rate,
            "timestamp": time.time()
        }

        client.publish(DATA_TOPIC, json.dumps(payload), qos=1)
        #print(f"[{DEVICE_ID}] Published → breath: {breath_signal}, pressure: {pressure}, rate: {rate}")
        time.sleep(1 / FS)

except KeyboardInterrupt:
    client.publish(STATUS_TOPIC, "offline", qos=1, retain=True)
    client.loop_stop()
    client.disconnect()
    print("Ventilator stopped.")
