"""examples/yajl-orders.rpgle: JSON read with DATA-INTO and YAJLINTO, and
written with YAJL's generator and with DATA-GEN."""
from common import *
import json

args = setup(__doc__)

def post(body):
    status, headers, data = get('/orders', 'Content-Type: application/json',
                                f'Content-Length: {len(body)}', method='POST', body=body)
    try:
        return status, headers, json.loads(data)
    except ValueError:
        return status, headers, data

order = {'customer': 'Jürgen "JJ" O\\Brien',
         'items': [{'sku': 'A1', 'qty': 2, 'price': 9.95}, {'sku': 'B7', 'qty': 1, 'price': 0.5}]}
status, headers, data = post(json.dumps(order).encode())
check('POST /orders: 201, JSON', status == 201 and headers.get('content-type') == 'application/json', (status, headers))
check('the customer comes back exactly: umlaut, quotes and backslash escaped by YAJL',
      isinstance(data, dict) and data.get('customer') == order['customer'], data)
check('items priced, 0.50 as a valid number, and the total',
      isinstance(data, dict) and data.get('id') == 1 and
      [(i['sku'], i['qty'], i['amount']) for i in data.get('items', [])] == [('A1', 2, 19.9), ('B7', 1, 0.5)] and
      data.get('total') == 20.4, data)

status, _, data = post(b'{"Customer": "Bo", "note": "extra fields are ignored", "items": [{"sku": "C3", "qty": 3, "price": 1}]}')
check('case=any and allowextra: "Customer" and an unknown field',
      status == 201 and data.get('customer') == 'Bo' and data.get('id') == 2 and data.get('total') == 3, (status, data))

status, headers, data = post(b'{"customer": "Anna", "items": [')
check('broken JSON: 400 with a JSON error', status == 400 and isinstance(data, dict) and
      'not a valid order' in data.get('error', ''), (status, data))
status, _, data = post(b'{"customer": "Anna", "items": []}')
check('no items: 400', status == 400 and data.get('error') == 'an order needs a customer and items', (status, data))

status, headers, data = get('/status')
try:
    info = json.loads(data)
except ValueError:
    info = data
check('GET /status: DATA-GEN output', status == 200 and isinstance(info, dict) and
      info.get('service') == 'orders' and info.get('orders') == 2 and len(info.get('started', '')) == 19, info)
done()
