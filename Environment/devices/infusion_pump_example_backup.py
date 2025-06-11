import warnings
warnings.filterwarnings("ignore", category=DeprecationWarning)
import paho.mqtt.client as mqtt
import time
import json
import ssl

BROKER = "127.0.0.1"
PORT = 8883
CMD_TOPIC = "/patients/ward1/bed1/infusion_cmd"
STATUS_TOPIC = "/patients/ward1/bed1/infusion_status"
USERNAME = "myuser"
PASSWORD = "myuser"
DEVICE_ID = "infusion_pump_1"

client = mqtt.Client(client_id=DEVICE_ID)
client.username_pw_set(USERNAME, PASSWORD)

#TLS Config
client.tls_set(ca_certs="/home/erickjo16/TFM/Environment/mosquitto/certs/ca.crt", cert_reqs=ssl.CERT_REQUIRED)
client.tls_insecure_set(False)

#LWT Config
client.will_set(STATUS_TOPIC, "offline", qos=1, retain=True)

def on_connect(client, userdata, flags, rc):
    print(f"[{DEVICE_ID}] Connected:{rc}")
    client.subscribe(CMD_TOPIC)
    client.publish(STATUS_TOPIC, "online", qos=1, retain=True)

def on_message(client, userdata, msg):
    cmd = msg.payload.decode()
    print(f"[{DEVICE_ID}] Received CMD: {cmd}")
    status = {
            "device_id": DEVICE_ID,
            "patient_id": "P001",
            "infusion_status": f"Executed: {cmd}",
            "timestamp": time.time()
            }
    client.publish(STATUS_TOPIC, json.dumps(status), qos=1)
    

client.on_connect = on_connect
client.on_message = on_message
client.connect(BROKER, PORT, 60)
client.loop_forever()
