from enum import IntEnum
import struct
import time
from datetime import datetime

# ============================================================
# COMMANDS
# ============================================================

class Command(IntEnum):
    INITIALIZATION = 0x45           # Pairing step 1
    GET_AES_KEY = 0x19              # Pairing step 2: get lock AES key
    ADD_ADMIN = 0x56                # Pairing step 3: register admin credentials
    CHECK_ADMIN = 0x41              # Auth step 1 (older protocol)
    CHECK_RANDOM = 0x30             # Auth step 2 (older protocol)
    CHECK_USER_TIME = 0x55          # Auth (V3 protocol): send validity window
    SET_ADMIN_KEYBOARD_PWD = 0x53   # Set admin PIN code
    GET_ADMIN_CODE = 0x65           # Read admin PIN code
    UNLOCK = 0x47                   # Unlock
    FUNCTION_LOCK = 0x58            # Lock
    TIME_CALIBRATE = 0x43           # Synchronise lock clock
    MANAGE_KEYBOARD_PASSWORD = 0x03 # Add / edit / delete PIN codes
    PWD_LIST = 0x07                 # List PIN codes
    GET_OPERATE_LOG = 0x25          # Read operation log
    RESET_LOCK = 0x52               # Factory reset
    SEARCH_DEVICE_FEATURE = 0x01    # Query lock capabilities (feature bitmap)
    IC_MANAGE = 0x05                # IC card operations
    FR_MANAGE = 0x06                # Fingerprint operations
    AUTO_LOCK_MANAGE = 0x36         # Get / set auto-lock timeout
    READ_DEVICE_INFO = 0x90         # Read device info string
    CONTROL_REMOTE_UNLOCK = 0x37    # Enable / disable remote unlock
    AUDIO_MANAGE = 0x62             # Enable / disable lock beeps
    CONFIGURE_PASSAGE_MODE = 0x66   # Passage mode management
    SHOW_PASSWORD = 0x59            # Show / hide passcode on keypad
    OPERATE_FINISHED = 0x57         # Signal end of multi-step operation
    SEARCH_BICYCLE_STATUS = 0x14    # Poll lock/unlock status
