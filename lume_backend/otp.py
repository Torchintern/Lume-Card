import random
import time
otp_store = {}

OTP_EXPIRY_SECONDS = 300  


def generate_otp(phone):
    otp = "123456"
    otp_store[phone] = {
        "otp": otp,
        "expires_at": time.time() + OTP_EXPIRY_SECONDS
    }
    return otp


def verify_otp(phone, entered_otp):
    record = otp_store.get(phone)

    if not record:
        return False, "OTP not requested"

    if time.time() > record["expires_at"]:
        del otp_store[phone]
        return False, "OTP expired"

    if record["otp"] != entered_otp:
        return False, "Invalid OTP"
    
    del otp_store[phone]
    return True, "OTP verified"