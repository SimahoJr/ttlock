import struct
import time
from datetime import datetime

# ============================================================
# COMMAND BUILDERS
# ============================================================
from constants import ICOperate


def cmd_add_ic_card():

    return bytes([
        ICOperate.ADD
    ])


def cmd_list_ic_cards(sequence=0):

    return (
        bytes([ICOperate.IC_SEARCH]) +
        struct.pack(">H", sequence)
    )


def cmd_delete_ic_card(card_number):

    return (
        bytes([ICOperate.DELETE]) +
        struct.pack(">I", int(card_number))
    )


def cmd_clear_ic_cards():

    return bytes([
        ICOperate.CLEAR
    ])

def cmd_init():
    return b""


def cmd_get_key():
    return b"SCIENER"


def cmd_add_admin(admin, unlock):
    return struct.pack(">II", admin, unlock) + b"SCIENER"


def cmd_time():
    now = datetime.now()
    s = now.strftime("%y%m%d%H%M%S")
    return bytes(int(s[i:i+2]) for i in range(0, len(s), 2))


def dt_to_bytes(s):
    return bytes(int(s[i:i+2]) for i in range(0, len(s), 2))

def build_check_admin(admin_ps, lock_flag_pos=0, uid=0):
    admin_ps = int(admin_ps or 0)
    lock_flag_pos = int(lock_flag_pos or 0)
    uid = int(uid or 0)

    # Initialize an 11-byte array with zeros
    data = bytearray(11)

    # Match Lua writeUInt32BE and the exact offsets/overlap
    data[3:7] = lock_flag_pos.to_bytes(4, "big")
    data[0:4] = admin_ps.to_bytes(4, "big")
    data[7:11] = uid.to_bytes(4, "big")

    return bytes(data)

def build_check_random(ps_from_lock: int, unlock_key: int) -> bytes:
    """COMM_CHECK_RANDOM – authenticate step 2: prove knowledge of unlock_key."""
    return struct.pack(">I", ps_from_lock + unlock_key)

def parse_check_admin(data: bytes) -> int:
    """Return psFromLock from a CHECK_ADMIN response."""
    print("CHECK_ADMIN response:", data.hex())
    print("CHECK_ADMIN response length:", len(data))
    if len(data) < 4:
        raise ValueError("CHECK_ADMIN response too short")
    return struct.unpack(">I", data[:4])[0]

def cmd_check_user_time(admin_ps, unlock_key):

    start = dt_to_bytes("2026020000")
    end = dt_to_bytes("9912312359")

    payload = bytearray(17)

    payload[0:5] = start
    payload[5:10] = end

    struct.pack_into(">I", payload, 9, admin_ps)
    struct.pack_into(">I", payload, 13, unlock_key)

    return bytes(payload)


def cmd_unlock(ps, key):
    return struct.pack(">II", ps + key, int(time.time()))


def cmd_lock(ps, key):
    return struct.pack(">II", ps + key, int(time.time()))

def cmd_search_feature():
    return b""


def cmd_device_info():
    return b""


def cmd_status():
    return b""


def cmd_operate_finished():
    return b""


# ============================================================
# IC CARD
# ============================================================

def cmd_add_card():

    return bytes([
        0x01
    ])


def cmd_list_cards():

    return bytes([
        0x02,
        0x00
    ])


def cmd_delete_card(card_id):

    return (
        bytes([0x03]) +
        card_id
    )


def cmd_clear_cards():

    return bytes([
        0x04
    ])


# ============================================================
# IC CARD COMMAND BUILDERS
# ============================================================

def cmd_add_ic_card():

    return bytes([
        0x01
    ])



def cmd_list_ic_cards(sequence=0):

    return bytes([
        0x02,
        sequence
    ])



def cmd_delete_ic_card(card):

    return (
        bytes([0x03]) +
        card
    )



def cmd_clear_ic_cards():

    return bytes([
        0x04
    ])

def cmd_set_admin_code(pin):

    encoded = str(pin).encode("ascii")

    return bytes([len(encoded)]) + encoded


def _dt_to_bytes(dt_str: str) -> bytes:
    """Convert a "YYMMDDHHmm[ss]" string to bytes (one byte per pair)."""
    return bytes(int(dt_str[i:i+2]) for i in range(0, len(dt_str), 2))


def now_yymmddhhmm() -> str:
    d = datetime.now()
    return d.strftime("%y%m%d%H%M")


def now_yymmddhhmmss() -> str:
    d = datetime.now()
    return d.strftime("%y%m%d%H%M%S")
# ---------------------------------------------------------------------------
# PIN codes (keyboard passwords)
# ---------------------------------------------------------------------------

def build_add_passcode(
    # it is important that you follow as it is written in the typescript.
    pwd_type,
    passcode: str,
    start_date: str = "202001010000",
    end_date: str   = "000000000000",
) -> bytes:
    """COMM_MANAGE_KEYBOARD_PASSWORD – add a new passcode."""
    code = passcode.encode("ascii")
    print(end_date[2:12])
    start_b = _dt_to_bytes(start_date[2:12])   # YYMMDDHHmm
    end_b   = _dt_to_bytes(end_date[2:12])

    buf = bytes([2, int(pwd_type), len(code)]) + code + start_b + end_b
    print("build_add_passcode:", buf.hex())
    return buf

def build_update_passcode(
    pwd_type: 2,
    old_passcode: str,
    new_passcode: str,
    start_date: str = "000101000000",
    end_date: str   = "991231235900",
) -> bytes:
    """COMM_MANAGE_KEYBOARD_PASSWORD – change an existing passcode."""
    old_code = old_passcode.encode("ascii")
    new_code = new_passcode.encode("ascii")
    start_b  = _dt_to_bytes(start_date[:10])
    end_b    = _dt_to_bytes(end_date[:10])
    return (
        bytes([3, int(pwd_type), len(old_code)])
        + old_code
        + bytes([len(new_code)])
        + new_code
        + start_b
        + end_b
    )