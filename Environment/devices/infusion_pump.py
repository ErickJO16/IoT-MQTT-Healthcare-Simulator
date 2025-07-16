import warnings
warnings.filterwarnings("ignore", category=DeprecationWarning)

import paho.mqtt.client as mqtt
import time
import json
import ssl
import random

# MQTT Configuration
BROKER = "192.168.100.129"
PORT = 8883
DATA_TOPIC = "/patients/ward1/bed1/infusion/data"
CMD_TOPIC = "/patients/ward1/bed1/infusion/cmd"
STATUS_TOPIC = "/patients/ward1/bed1/infusion/status"
USERNAME = "myuser"
PASSWORD = "myuser"
DEVICE_ID = "infusion_pump_1"

# Infusion parameters
TOTAL_VOLUME = 1000       # ml
FLOW_RATE_MEAN = 10     # ml/h
FLOW_RATE_STD = 2        # small variation
TIME_STEP = 1            # seconds
infused_volume = 0.0

client = mqtt.Client(client_id=DEVICE_ID)
client.username_pw_set(USERNAME, PASSWORD)

client.tls_set(
    ca_certs="/home/debian/IoT/Environment/mosquitto/certs/ca.crt",
    cert_reqs=ssl.CERT_REQUIRED
)
client.tls_insecure_set(False)

client.will_set(STATUS_TOPIC, "offline", qos=1, retain=True)

# Control flag to start/stop infusion
infusing = True

def on_connect(client, userdata, flags, rc):
    print(f"[{DEVICE_ID}] Connected: {rc}")
    client.subscribe(CMD_TOPIC)
    client.publish(STATUS_TOPIC, "online", qos=1, retain=True)

def on_message(client, userdata, msg):
    global infusing
    cmd = msg.payload.decode().strip().lower()
    print(f"[{DEVICE_ID}] Received CMD: {cmd}")
    
    if cmd == "start":
        infusing = True
    elif cmd == "stop":
        infusing = False

    status = {
        "device_id": DEVICE_ID,
        "patient_id": "P001",
        "infusion_status": f"Infusion {'started' if infusing else 'paused'}",
        "timestamp": time.time()
    }
    client.publish(STATUS_TOPIC, json.dumps(status), qos=1)

client.on_connect = on_connect
client.on_message = on_message
client.connect(BROKER, PORT, 60)
client.loop_start()

try:
    while True:
        if infusing and infused_volume < TOTAL_VOLUME:
            flow_rate = round(random.normalvariate(FLOW_RATE_MEAN, FLOW_RATE_STD), 2)
            delivered_ml = flow_rate / 3600  # per second
            infused_volume += delivered_ml
            infused_volume = min(infused_volume, TOTAL_VOLUME)
            remaining_volume = TOTAL_VOLUME - infused_volume
            time_remaining = (remaining_volume / flow_rate) * 60 if flow_rate > 0 else 0

            payload = {
                "device_id": DEVICE_ID,
                "patient_id": "P001",
                "flow_rate": flow_rate,
                "infused_volume": round(infused_volume, 2),
                "time_remaining": round(time_remaining, 2),
                "timestamp": time.time()
            }
            client.publish(DATA_TOPIC, json.dumps(payload), qos=1)
            #print(f"[{DEVICE_ID}] Published infusion data: {payload}")

        time.sleep(TIME_STEP)

except KeyboardInterrupt:
    client.publish(STATUS_TOPIC, "offline", qos=1, retain=True)
    client.loop_stop()
    client.disconnect()
    print("Infusion pump stopped.")
