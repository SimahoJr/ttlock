import asyncio

from TTLockClient import TTLock
from command_builder import build_add_passcode
# # ============================================================
# # MAIN PROGRAM
# # ============================================================

async def main():
    lock=TTLock()
    lock.load()
    await lock.connect()
    try:
        if lock.admin_ps == 0:
            print("No pairing data found")
            await lock.pair()
        else:
            print("Existing credentials loaded")
        print("Changing password...")
        

        await lock.add_passcode("1234")
        # # print("Unlocking...")
        # await lock.unlock()
        # print("Battery:",lock.battery)
        # await asyncio.sleep(10)
        # print("Locking...")
        # await lock.lock()
    except:
        pass
    # finally:
    #     await lock.disconnect()

if __name__=="__main__":
    asyncio.run(main())



# 02033232320001010000630C1F173B