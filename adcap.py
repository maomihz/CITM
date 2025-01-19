import json
import re
import time
import gzip
from os.path import splitext, exists
import os
from hashlib import md5
from datetime import datetime, timedelta


# ===========================================

from mitmproxy import http, ctx

adcom_event_data_save = 'adcom_event_data.json'

class Adcap:
    def __init__(self):
        self.timecount = 0
        self.adcap_data_bin = b''
        self.adcom_event_bin = b''
        self.adcom_balance_data = {}
        self.adcom_balance_md5 = {}

        self.timehack = None

    def _load_communist_balance(self, balance):
        balance_file = '{}.json'.format(balance)
        if not exists(balance_file):
            return

        with open(balance_file, 'rb') as f:
            data = f.read()
            hashsum = md5(data).hexdigest()
            self.adcom_balance_data[balance] = data
            self.adcom_balance_md5[balance] = hashsum

        return 'https://hyperhippo.ssl.hwcdn.net/adventure-communist/MyBalance.{}.{}.json.gz'.format(balance, hashsum)

        
    def response(self, flow):
        if self.timehack is not None and flow.request.path.startswith('/Client/GetTime'):
            timenow = datetime.utcnow()
            delta = self.timehack
            mytime = (timenow + delta).strftime('%FT%T.000Z')
            self.timecount += 1
            ctx.log.info("Send time: %s" % mytime)
            flow.response.text = json.dumps({
                "code": 200,
                "data": {
                    "Time": mytime
                },
                "status": "OK"
            })
            
        elif flow.request.path.startswith('/Client/ExecuteCloudScript'):
            resp = flow.response.text
            data = json.loads(resp)
            function_name = data['data']['FunctionName']
            result = json.loads(data['data']['FunctionResult'])


            if function_name == 'DataConfig':
                # Dump communist event data
                with open('adcom_event_data_save.json', 'w') as f:
                    json.dump(result, f, indent=2)
                for balance_name in result['Balance'].keys():
                    url = self._load_communist_balance(balance_name)
                    if url:
                        result['Balance'][balance_name] = url
                data['data']['FunctionResult'] = json.dumps(result)
                flow.response.text = json.dumps(data)

        elif flow.request.path.startswith('/adventure-capitalist-s3/Data.'):
            flow.response.content = gzip.compress(self.adcap_data_bin)
            flow.response.status_code = 200
            
        elif flow.request.path.startswith('/adventure-communist/MyBalance.'):
            m = re.match(r'/adventure-communist/MyBalance.([a-z0-9-]+)\..+', flow.request.path)
            if m:
                balance = m.group(1)
                if balance in self.adcom_balance_data:
                    flow.response.content = gzip.compress(self.adcom_balance_data[balance])
                    flow.response.status_code = 200
addons = [
    Adcap()
]

