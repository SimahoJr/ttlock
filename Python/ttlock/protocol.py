# ============================================================
# PROTOCOL
# ============================================================

import struct
from dataclasses import dataclass

from constants import APP_COMMAND, BLE_MTU, PACKET_END, PACKET_HEADER, crc8
from crypto import aes_decrypt, aes_encrypt


@dataclass
class Protocol:
    protocol_type: int = 5
    version: int = 3
    scene: int = 1
    group: int = 1
    org: int = 1


def build_packet(proto, cmd, payload, aes):

    if aes and payload:
        payload = aes_encrypt(payload, aes)

    header = PACKET_HEADER + bytes([proto.protocol_type, proto.version, proto.scene]) + struct.pack(">HH", proto.group, proto.org) + bytes([cmd, APP_COMMAND, len(payload)])

    frame = header + payload

    return frame + bytes([crc8(frame)]) + PACKET_END


def chunks(data):
    return [data[i:i + BLE_MTU] for i in range(0, len(data), BLE_MTU)]


def parse_response(data, aes):

    data = data.rstrip(PACKET_END)

    if data[:2] != PACKET_HEADER:
        raise Exception("Bad TTLock header")

    cmd = data[9]
    length = data[11]

    payload = data[12:12 + length]

    if aes and payload:
        payload = aes_decrypt(payload, aes)

    if len(payload) >= 2:
        return {"cmd": cmd, "status": payload[1], "data": payload[2:]}

    return {"cmd": cmd, "status": 0, "data": b""}