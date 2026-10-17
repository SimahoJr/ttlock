from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
from cryptography.hazmat.primitives import padding

# ============================================================
# CRYPTO
# ============================================================

def aes_encrypt(data, key):

    padder = padding.PKCS7(128).padder()
    data = padder.update(data) + padder.finalize()

    cipher = Cipher(algorithms.AES(key), modes.CBC(key))
    enc = cipher.encryptor()

    return enc.update(data) + enc.finalize()


def aes_decrypt(data, key):

    cipher = Cipher(algorithms.AES(key), modes.CBC(key))
    dec = cipher.decryptor()

    data = dec.update(data) + dec.finalize()

    unpad = padding.PKCS7(128).unpadder()

    return unpad.update(data) + unpad.finalize()