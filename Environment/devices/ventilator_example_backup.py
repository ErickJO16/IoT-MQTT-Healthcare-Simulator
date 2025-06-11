import paho.mqtt.client as mqtt
import time
import json
import random
import ssl

BROKER = "127.0.0.1"
PORT = 8883
DATA_TOPIC = "/patients/ward1/bed1/ventilator/data"
CMD_TOPIC = "/patients/ward1/bed1/ventilator/cmd"
STATUS_TOPIC = "/patients/ward1/bed1/ventilator/status"
USERNAME = "myuser"
PASSWORD = "myuser"
DEVICE_ID = "ventilator_1"

client = mqtt.Client(client_id=DEVICE_ID)
client.username_pw_set(USERNAME, PASSWORD)

#TLS Config
client.tls_set(ca_certs="/home/erickjo16/TFM/Environment/mosquitto/certs/ca.crt", cert_reqs=ssl.CERT_REQUIRED)
client.tls_insecure_set(False)

#LWT Config
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
        payload = {
            "device_id": DEVICE_ID,
            "patient_id": "P001",
            "pressure": random.randint(10, 20),
            "rate": random.randint(12, 18),
            "timestamp": time.time()
        }
        client.publish(DATA_TOPIC, json.dumps(payload), qos=1)
        print(f"[{DEVICE_ID}] Published ventilator data")
        time.sleep(3)

except KeyboardInterrupt:
    client.loop_stop()
    client.disconnect()
    print("Ventilator stopped.")
