import json
import re
import time
from os.path import splitext

# General config
config = {
    "clientVersion": 90400,
    "country": "jp",
    "created": 1591501866
}


# ===========================================
class BattleCatsHack:
    def __init__(self, *files):
        # Index the items and cats
        self.item_index = {}

        # Import cat and item list
        self.all_list = []
        count = 0
        for f in files:
            cat_list = self._load_cat_list(f)
            list_name, ext = splitext(f)
            for item in cat_list:
                self.item_index[list_name + ":" + str(item['itemId'])] = count
                count += 1
            self.all_list.extend(cat_list)

        for i, item in enumerate(self.all_list):
            name = item['title'].lower()
            for alias in self._item_alias(name):
                self.item_index[alias] = self.item_index.get(name, i)

    def _item_alias(self, name):
        alias = set()
        name = name.lower()

        # All lowercase
        alias.add(name)

        # Letters & Numbers without space
        alias.add(''.join(c for c in name if re.match('[0-9a-zA-Z]', c)))

        # Without bracket
        alias.add(re.match(r'([^(]*)(\(.*)?', name).group(1).strip())

        return alias

    def _load_cat_list(self, path):
        with open(path, 'r') as f:
            return json.load(f)

    def _load_mailbox(self, path):
        with open(path, 'r') as f:
            mailbox_text = f.read()
        mailbox = []
        packages_text = re.split(r'\n\n+', mailbox_text)
        for package_text in packages_text:
            items_text = package_text.split('\n')
            package = []
            for item in items_text:
                item = item.strip()
                if not item:
                    continue
                m = re.match(r'^(.+?)[ :]?([0-9]*)?$', item)
                name = m.group(1).lower()
                count = m.group(2) or 1
                if not name:
                    continue
                for alias in self._item_alias(name):
                    if alias in self.item_index:
                        item_json = dict(
                            **self.all_list[self.item_index[alias]])
                        item_json['amount'] = int(count)
                        package.append(item_json)
                        break
            mailbox.append(package)
        return mailbox

    def load_mailbox(self, *files):
        self.mailbox = []
        for f in files:
            self.mailbox.extend(self._load_mailbox(f))

    def response(self, request):
        # Process Response
        resp = []
        i = 1
        for package in self.mailbox:
            resp_config = dict(**config)
            title = ', '.join(item['title'] for item in package)
            body = ', '.join('%s(%d)' % (item['title'], item['amount'])
                             for item in package)
            resp_config.update({
                "id": i,
                'accountId': request.query['accountId'],
                "title": title,
                "body": body,
                "accepted": None,
                "created": int(time.time()) - 600,
                "items": package
            })

            resp.append(resp_config)
            i += 1
        return resp

begin_time = time.time()
time_diff = 0

def response(flow):
    from mitmproxy import http
    bc = BattleCatsHack("cat_list.json", 'item_list.json')

    if flow.request.path.startswith('/messages.php?action=list'):
        bc.load_mailbox('mailbox.txt')
        flow.response.text = json.dumps(bc.response(flow.request))
    if flow.request.path.startswith('/messages.php?action=accept'):
        flow.response = http.HTTPResponse.make(200)
    if flow.request.path.startswith('/api/v4/status.php'):
        flow.response.text = json.dumps({"status": True})
    if flow.request.path.startswith('/?action=getTime'):
        global time_diff
        time_diff = (time_diff + 60 * 360) % (60 * 720)
        #time_diff = 0
        flow.response.text = json.dumps({
            "success": True,
            "timestamp": int(time.time() + time_diff)
        })


if __name__ == "__main__":
    bc = BattleCatsHack("cat_list.json", 'item_list.json')
    bc.load_mailbox('mailbox.txt')
    print(bc.mailbox)
    print(bc.item_index)
    # print(bc.item_index)
