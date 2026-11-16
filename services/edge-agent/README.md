# Edge agent shell

The agent currently has no protocol adapters, network endpoints, or device discovery. It starts in simulation mode and rejects physical writes. BACnet, Modbus, KNX, and MQTT adapter implementations are planned for later milestones. Run `python3 -m unittest discover -s tests` from this directory.
