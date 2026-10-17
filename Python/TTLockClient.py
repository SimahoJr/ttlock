# ============================================================
# TTLOCK BLE CLIENT
# ============================================================
import asyncio
from imaplib import Commands
import json
import os
import random
import struct

from bleak import BleakClient

from constants import DEFAULT_AES_KEY, LOCK_MAC, NOTIFY_UUID, PACKET_END, WRITE_UUID
from protocol import Protocol, build_packet, chunks, parse_response
from commands import Command
from command_builder import cmd_lock, cmd_unlock
import struct
from command_builder import cmd_check_user_time
from command_builder import cmd_init, cmd_get_key, cmd_add_admin
from command_builder import *


class TTLock:

    def __init__(self):
        self.client = None
        self.proto = Protocol()
        self.rx_buffer = bytearray()
        self.responses = asyncio.Queue()

        self.db_file = "ttlock.json"
        self.aes_key = DEFAULT_AES_KEY
        self.admin_ps = 0
        self.unlock_key = 0
        self.battery = -1


    # --------------------------------------------------------
    # Persistent storage
    # --------------------------------------------------------

    def load(self):
        if not os.path.exists(self.db_file):
            return

        with open(self.db_file) as f:
            d = json.load(f)

        self.aes_key = bytes.fromhex(d["aes_key"])
        self.admin_ps = d["admin_ps"]
        self.unlock_key = d["unlock_key"]


    def save(self):
        with open(self.db_file, "w") as f:
            json.dump({"aes_key": self.aes_key.hex(), "admin_ps": self.admin_ps, "unlock_key": self.unlock_key}, f, indent=4)


    # ============================================================
    # AUTHENTICATION
    # ============================================================
    async def _auth_admin_login(self) -> int:
        """Older-protocol auth: verify admin identity, get psFromLock."""

        resp = await self.send(
            Command.CHECK_ADMIN,
            build_check_admin(self.admin_ps),
            self.aes_key,
        )

        data = resp["data"]
        b = data[:4]

        ps_from_lock = 0

        if len(b) >= 4:
            ps_from_lock = struct.unpack(">I", b[:4])[0]
        elif len(b) == 1:
            ps_from_lock = b[0]
        elif len(b) == 2:
            ps_from_lock = struct.unpack(">H", b[:2])[0]

        payload = build_check_random(ps_from_lock, self.unlock_key)

        resp = await self.send(
            Command.CHECK_RANDOM,
            payload,
            self.aes_key,
        )

        return ps_from_lock


    async def authenticate(self):

        response = await self.send(Command.CHECK_USER_TIME, cmd_check_user_time(self.admin_ps, self.unlock_key), self.aes_key)

        if response["status"] != 1:
            raise Exception("Authentication failed")

        ps_from_lock = struct.unpack(">I", response["data"][:4])[0]

        return ps_from_lock


    async def pair(self):

        print("Starting pairing")

        await self.send(Command.INITIALIZATION, cmd_init(), None)

        response = await self.send(Command.GET_AES_KEY, cmd_get_key(), DEFAULT_AES_KEY)
        print("GET AES KEY RESPONSE:", response)
        if len(response["data"]) < 16:
            raise Exception("AES key missing")

        self.aes_key = response["data"][:16]

        print("AES KEY:", self.aes_key.hex())

        
        def random_key(length=7):
            return int("".join(random.choice("1234567") for _ in range(length)))

        self.admin_ps = 123456
        self.unlock_key = 123456

        response = await self.send(
            Command.ADD_ADMIN,
            cmd_add_admin(self.admin_ps, self.unlock_key),
            self.aes_key
        )

        print("ADD ADMIN:", response)

    

        await self.send(
            Command.OPERATE_FINISHED,
            b"",
            self.aes_key
        )

        self.save()

        print("Pairing completed")
        
    # --------------------------------------------------------
    # BLE
    # --------------------------------------------------------

    async def connect(self):

        self.client = BleakClient(LOCK_MAC)

        await self.client.connect()
        await asyncio.sleep(1)
        print("Connected:", self.client.is_connected)

        await self.client.start_notify(NOTIFY_UUID, self.notification)


    async def disconnect(self):
        if self.client:
            await self.client.disconnect()


    def notification(self, handle, data):

        self.rx_buffer.extend(data)

        if self.rx_buffer.endswith(PACKET_END):

            frame = bytes(self.rx_buffer)

            self.rx_buffer.clear()

            self.responses.put_nowait(frame)


    async def send(self, command, payload=b"", aes=None):
        # Explicit check before sending
        connected = False
        if self.client:
            try:
                connected = self.client.is_connected
            except Exception:
                connected = False

        if not connected:
            print("Connection lost or inactive. Reconnecting...")
            await self.connect()

        # Clear out any stale/leftover responses in the queue
        while not self.responses.empty():
            try:
                self.responses.get_nowait()
            except asyncio.QueueEmpty:
                break

        packet = build_packet(self.proto, command, payload, aes)

        try:
            for part in chunks(packet):
                await self.client.write_gatt_char(WRITE_UUID, part, response=False)

            response = await asyncio.wait_for(self.responses.get(), timeout=5)
            
        except Exception as e:
            # If writing or waiting times out/fails, force a reconnect and retry once
            print(f"Communication error ({e}). Reconnecting and retrying...")
            await self.connect()
            
            # Resend packet after reconnecting
            for part in chunks(packet):
                await self.client.write_gatt_char(WRITE_UUID, part, response=False)
            
            response = await asyncio.wait_for(self.responses.get(), timeout=5)

        return parse_response(response, aes)

    async def unlock(self):
        ps = await self.authenticate()

        response = await self.send(Command.UNLOCK, cmd_unlock(ps, self.unlock_key), self.aes_key)

        print("UNLOCK RESPONSE", response)

        if len(response["data"]):
            self.battery = response["data"][0]

    async def lock(self):

        ps = await self.authenticate()

        response = await self.send(Command.LOCK, cmd_lock(ps, self.unlock_key), self.aes_key)

        # ============================================================
    # DEVICE INFORMATION
    # ============================================================

    async def get_device_info(self):

        response = await self.send(
            Command.READ_DEVICE_INFO,
            cmd_device_info(),
            self.aes_key
        )

        print("DEVICE INFO:", response)

        return response


    async def search_features(self):

        response = await self.send(
            Command.SEARCH_DEVICE_FEATURE,
            cmd_search_feature(),
            self.aes_key
        )

        print("FEATURES:", response)

        return response


    # ============================================================
    # TIME
    # ============================================================

    async def calibrate_time(self):
        self.admin_ps = await self._auth_admin_login()
        response = await self.send(
            Command.TIME_CALIBRATE,
            cmd_time(),
            self.aes_key
        )

        print("TIME RESPONSE:", response)

        return response


    # ============================================================
    # STATUS
    # ============================================================

    async def get_status(self):

        response = await self.send(
            Command.SEARCH_BICYCLE_STATUS,
            cmd_status(),
            self.aes_key
        )

        print("STATUS:", response)

        if response["status"] == 1 and response["data"]:
            self.locked_status = response["data"][0]

        return response


    # ============================================================
    # RESET
    # ============================================================

    async def reset(self):

        await self.authenticate()

        response = await self.send(
            Command.RESET_LOCK,
            b"",
            self.aes_key
        )

        print("RESET RESPONSE:", response)

        return response


    # ============================================================
    # ADMIN PIN
    # ============================================================

    async def set_admin_pin(self, pin):

        response = await self.send(
            Command.SET_ADMIN_KEYBOARD_PWD,
            pin.encode(),
            self.aes_key
        )

        print("SET ADMIN PIN:", response)

        return response


    async def get_admin_pin(self):
        await self._auth_admin_login()
        response = await self.send(
            Command.GET_ADMIN_CODE,
            b"",
            self.aes_key
        )

        print("ADMIN PIN:", response)

        return response


    # ============================================================
    # FINISH OPERATION
    # ============================================================

    async def operate_finished(self):

        response = await self.send(
            Command.OPERATE_FINISHED,
            b"",
            self.aes_key
        )

        print("OPERATE FINISHED:", response)

        return response

    # ============================================================
    # IC CARDS
    # ============================================================
    async def add_ic_card(self):

        print("Starting card registration")


        # Enter card adding mode
        response = await self.send(
            Command.IC_MANAGE,
            bytes([0x01]),      # ICOperate.ADD
            self.aes_key
        )


        print(
            "ADD CARD RESPONSE:",
            response
        )


        print("Place card on lock...")


        # WAIT FOR CARD SCAN NOTIFICATION
        try:

            frame = await asyncio.wait_for(
                self.responses.get(),
                timeout=30
            )


            print(
                "CARD EVENT:",
                frame.hex(" ")
            )


        except asyncio.TimeoutError:

            print(
                "No card detected"
            )

            return


    async def get_ic_cards(self):

        await self.authenticate()

        cards = []

        sequence = 0


        while True:

            response = await self.send(
                Command.IC_MANAGE,
                cmd_list_ic_cards(sequence),
                self.aes_key
            )


            print(
                "CARD LIST:",
                response
            )


            if not response["data"]:
                break


            cards.append(
                response["data"]
            )


            sequence += 1


        return cards



    async def delete_ic_card(self, card):

        await self.authenticate()


        response = await self.send(
            Command.IC_MANAGE,
            cmd_delete_ic_card(card),
            self.aes_key
        )


        print(
            "DELETE CARD:",
            response
        )


        return response



    async def clear_ic_cards(self):

        await self.authenticate()


        response = await self.send(
            Command.IC_MANAGE,
            cmd_clear_ic_cards(),
            self.aes_key
        )


        print(
            "CLEAR CARDS:",
            response
        )


        return response

    # ============================================================
    # CHANGE KEYPAD ADMIN PASSWORD
    # ============================================================

    async def change_admin_password(self, new_password):

        await self._auth_admin_login()

        payload = str(new_password).encode()

        response = await self.send(
            Command.SET_ADMIN_KEYBOARD_PWD,
            payload,
            self.aes_key
        )

        print(
            "CHANGE PASSWORD RESPONSE:",
            response
        )

        return response


    async def get_admin_password(self, pin):

        await self._auth_admin_login()
        response = await self.send(
            Command.GET_ADMIN_CODE,
            b"",
            self.aes_key
        )

        print("GET ADMIN CODE RESPONSE:",  response)
        # response = await self.send(
        #     Command.SET_ADMIN_KEYBOARD_PWD,
        #     cmd_set_admin_code(pin),
        #     self.aes_key
        # )

  

    async def add_passcode(self, passcode: str):
        """Add a PIN code."""

        await self._auth_admin_login()

        response = await self.send(
            Command.MANAGE_KEYBOARD_PASSWORD,
            build_add_passcode(1, passcode),
            self.aes_key
        )
        print("ADD PASSCODE RESPONSE:", response)
        return response

    async def update_passcode(
        self,
        old_passcode: str,
        new_passcode: str,
        pwd_type: 1,
        start_date: str = "000101000000",
        end_date: str   = "991231235900",
    ) -> None:
        """Update an existing PIN code."""
        await self._send_command(
            Command.MANAGE_KEYBOARD_PASSWORD,
            build_update_passcode(pwd_type, old_passcode, new_passcode,
                                      start_date, end_date),
            self.aes_key
        )
        