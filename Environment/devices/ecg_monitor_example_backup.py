import warnings
warnings.filterwarnings("ignore", category=DeprecationWarning)
import paho.mqtt.client as mqtt
import time
import json
import random
import ssl

BROKER = "127.0.0.1"
PORT = 8883
TOPIC = "/patients/ward1/bed1/ecg"
STATUS_TOPIC = "/patients/ward1/bed1/ecg/status"
USERNAME = "myuser"
PASSWORD = "myuser"
DEVICE_ID = "ecg_monitor_1"

client = mqtt.Client(client_id=DEVICE_ID)
client.username_pw_set(USERNAME, PASSWORD)

#TLS Config
client.tls_set(ca_certs="/home/erickjo16/TFM/Environment/mosquitto/certs/ca.crt", cert_reqs=ssl.CERT_REQUIRED)
client.tls_insecure_set(False)

#LWT config
client.will_set(STATUS_TOPIC, "offline", qos=1, retain=True)

def on_connect(client, userdata, flags, rc):
    print(f"[{DEVICE_ID}] Connected: {rc}")
    client.publish(STATUS_TOPIC, "online", qos=1, retain=True)

client.on_connect = on_connect
client.connect(BROKER, PORT, 60)
client.loop_start()

try:
    while True:
        payload = {
            "device_id": DEVICE_ID,
            "patient_id": "P001",
            "ecg_signal": [round(random.uniform(-0.5, 0.5), 2) for _ in range(10)],
            "timestamp": time.time()
        }
        client.publish(TOPIC, json.dumps(payload), qos=1)
        print(f"[{DEVICE_ID}] Published ECG data")
        time.sleep(1)

except KeyboardInterrupt:
    client.loop_stop()
    client.disconnect()
    print("ECG monitor stopped.")
