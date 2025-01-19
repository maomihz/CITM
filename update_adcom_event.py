import json
import requests
import os
from os.path import join
from io import BytesIO
import gzip


save_dir = 'adcom_balance'


if __name__ == '__main__':
    with open('adcom_event_data_save.json', 'r') as f:
        event_data = json.load(f)
    balance_data = event_data['Balance']
    os.makedirs(save_dir, exist_ok=True)
    for name, url in balance_data.items():
        # Check if the file exists
        save = join(save_dir, f'{name}.json')
        print("Loading", save, "...")
        with requests.get(url, stream=True) as r:
            data = json.load(BytesIO(gzip.decompress(r.content)))
        with open(save, 'w') as f:
            json.dump(data, f, indent=2)
    
        
        
            
        
    
