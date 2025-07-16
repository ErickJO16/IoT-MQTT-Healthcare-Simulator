
import time
import random
import paho.mqtt.client as mqtt

BROKER = "192.168.50.130"
PORT = 1883
TOPIC = "hospital/liveroom/printer/status"

client = mqtt.Client(client_id="Smart_Printer")

def connect():
    client.connect(BROKER, PORT, 60)

def publish_printer_status():
    total_pages = 0
    try:
        while True:
            pages_printed = random.randint(1, 10)
            total_pages += pages_printed
            status = random.choice(["idle", "printing", "low toner", "paper jam"])
            message = {
                    "device": "SmartPrinter",
                    "status": status,
                    "pages_printed": pages_printed,
                    "total_pages": total_pages
                    }
            client.publish(TOPIC, str(message))
            time.sleep(1)

    except KeyboardInterrupt:
        client.loop_stop()
        client.disconnect()
        print("[Printer] Smart printer stopped.")

if __name__ == "__main__":
    connect()
    publish_printer_status()
