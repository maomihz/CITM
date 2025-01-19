import json
import re
import time
import gzip
from os.path import splitext
from hashlib import md5
from datetime import datetime, timedelta


# ===========================================

from mitmproxy import http, ctx

class Adcap:
    def response(self, flow):
        if flow.request.path.startswith('/Client/LoginWithIOSDeviceID'):
            resp = flow.response.text
            data = json.loads(resp)
            data['data']['InfoResultPayload']['UserData'] = {}
            # data['data']['InfoResultPayload']['UserDataVersion'] += 1
            flow.response.text = json.dumps(data)

addons = [
    Adcap()
]

