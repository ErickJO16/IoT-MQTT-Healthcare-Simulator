#!/bin/bash

# Start Mosquitto broker in background with custom config
echo "Starting Mosquitto broker..."
mosquitto -c mosquitto/misconfigured_mosquitto.conf -v > mosquitto.log 2>&1 &
BROKER_PID=$!
echo "Mosquitto started with PID $BROKER_PID"

python3 devices/vitals_sensor.py &
VS_PID=$!
echo "vitals_sensor.py started with PID $VS_PID"

python3 devices/ventilator.py &
VENT_PID=$!
echo "ventilator.py started with PID $VENT_PID"

python3 devices/infusion_pump.py &
INF_PID=$!
echo "infusion_pump.py started with PID $INF_PID"

python3 devices/ecg_monitor.py &
ECG_PID=$!
echo "infusion_pump.py started with PID $ECG_PID"

# Trap CTRL+C and kill all child processes
trap "echo 'Stopping all sensors...'; pkill -P $$; exit" SIGINT

# Keep the script running
wait
