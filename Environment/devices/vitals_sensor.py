import warnings 
warnings.filterwarnings("ignore", category=DeprecationWarning)

import paho.mqtt.client as mqtt
import time
import json
import random
import ssl

BROKER = "127.0.0.1"
PORT = 8883
TOPIC = "/patients/ward1/bed1/vitals"
STATUS_TOPIC = "/patients/ward1/bed1/vitals/status"
USERNAME = "myuser"
PASSWORD = "myuser"
DEVICE_ID = "vitals_sensor_1"

# Normal baselines
HEART_RATE_BASE = 75           # bpm
TEMP_BASE = 36.7               # °C
OXYGEN_BASE = 98               # % SpO2

# Std deviation for fluctuation
HR_STD = 3
TEMP_STD = 0.2
O2_STD = 1

client = mqtt.Client(client_id=DEVICE_ID)
client.username_pw_set(USERNAME, PASSWORD)

# TLS Config
client.tls_set(ca_certs="/home/erickjo16/TFM/Environment/mosquitto/certs/ca.crt", cert_reqs=ssl.CERT_REQUIRED)
client.tls_insecure_set(False)

# LWT Config
client.will_set(STATUS_TOPIC, "offline", qos=1, retain=True)

def on_connect(client, userdata, flags, rc):
    print(f"[{DEVICE_ID}] Connected: {rc}")
    client.publish(STATUS_TOPIC, "online", qos=1, retain=True)

client.on_connect = on_connect
client.connect(BROKER, PORT, 60)
client.loop_start()

try:
    while True:
        heart_rate = round(random.normalvariate(HEART_RATE_BASE, HR_STD))
        temperature = round(random.normalvariate(TEMP_BASE, TEMP_STD), 1)
        oxygen_saturation = round(random.normalvariate(OXYGEN_BASE, O2_STD))

        # Clamp to valid ranges
        heart_rate = max(50, min(heart_rate, 110))
        temperature = max(35.5, min(temperature, 39.0))
        oxygen_saturation = max(90, min(oxygen_saturation, 100))

        payload = {
            "device_id": DEVICE_ID,
            "patient_id": "P001",
            "heart_rate": heart_rate,
            "temperature": temperature,
            "oxygen_saturation": oxygen_saturation,
            "timestamp": time.time()
        }

        client.publish(TOPIC, json.dumps(payload), qos=1)
        #print(f"[{DEVICE_ID}] Published vitals:", payload)
        time.sleep(2)

except KeyboardInterrupt:
    client.publish(STATUS_TOPIC, "offline", qos=1, retain=True)
    client.loop_stop()
    client.disconnect()
    print("Vitals sensor stopped.")
