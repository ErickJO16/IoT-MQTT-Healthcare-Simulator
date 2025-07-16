# smart_ac.py

import time
import random
import paho.mqtt.client as mqtt

BROKER ="192.168.50.130"
PORT = 1883
TOPIC = "hospital/liveroom/ac/status"

client = mqtt.Client(client_id="Air_conditioner")

def connect():
    client.connect(BROKER, PORT, 60)

def publish_ac_status():
    try:
        while True:
            temperature = round(random.uniform(18.0, 26.0), 1)
            mode = random.choice(["cool", "heat", "fan", "off"])
            message = {
                    "device": "SmartAC",
                    "temperature": temperature,
                    "mode": mode
            }
            client.publish(TOPIC, str(message))
            time.sleep(1)
    except KeyboardInterrupt:
        client.loop_stop()
        client.disconnect()
        print("[Printer] Air conditioner stopped.")
if __name__ == "__main__":
    connect()
    publish_ac_status()
