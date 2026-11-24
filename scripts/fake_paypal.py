"""Lazni PayPal server za lokalno testiranje (oponasa dio Orders v2 / Payments v2 API-ja).

Pokretanje:  python scripts/fake_paypal.py
API se usmjerava na njega varijablama okruzenja:
  PAYPAL_CLIENT_ID=mockid  PAYPAL_CLIENT_SECRET=mocksecret  PAYPAL_BASE_URL=http://127.0.0.1:5099

Pomocni endpointi za testove:
  POST /_approve/<orderId>   narudzbu "odobrava" kupac
  POST /_decline/<orderId>   PayPal odbija uplatu
  GET  /_latest              Id zadnje napravljene narudzbe
  GET  /_stats               brojaci poziva (provjera idempotentnosti)
"""
import base64
import json
import os
import re
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

PORT = 5099

# Adresa pod kojom kupac (aplikacija/emulator) dohvaca stranicu za odobrenje.
# Iz Android emulatora racunar je dostupan kao 10.0.2.2.
PUBLIC_URL = os.environ.get("FAKE_PAYPAL_PUBLIC_URL", f"http://localhost:{PORT}")
EXPECTED_AUTH = "Basic " + base64.b64encode(b"mockid:mocksecret").decode()

lock = threading.Lock()
orders = {}
captures = {}
stats = {"create": 0, "capture_calls": 0, "capture_ok": 0, "refund_calls": 0, "refund_amounts": [], "tokens": 0}
counter = {"n": 0}


def next_id(prefix):
    counter["n"] += 1
    return f"{prefix}-{counter['n']}"


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def send_json(self, status, body):
        data = json.dumps(body).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def body(self):
        length = int(self.headers.get("Content-Length") or 0)
        raw = self.rfile.read(length) if length else b""
        return raw.decode()

    def capture_response(self, order):
        cap = captures[order["capture_id"]]
        return {
            "id": order["id"],
            "status": "COMPLETED",
            "purchase_units": [{
                "payments": {"captures": [{
                    "id": cap["id"], "status": "COMPLETED",
                    "amount": {"currency_code": "EUR", "value": cap["value"]},
                }]}
            }],
        }

    def authorized(self):
        return self.headers.get("Authorization", "").startswith("Bearer ")

    def do_GET(self):
        with lock:
            if self.path == "/_stats":
                return self.send_json(200, stats)
            if self.path == "/_latest":
                return self.send_json(200, {"orderId": list(orders)[-1] if orders else None})
            m = re.fullmatch(r"/v2/checkout/orders/([\w-]+)", self.path)
            if m:
                order = orders.get(m.group(1))
                if not order:
                    return self.send_json(404, {"name": "RESOURCE_NOT_FOUND"})
                if order["capture_id"]:
                    return self.send_json(200, self.capture_response(order))
                return self.send_json(200, {"id": order["id"], "status": "CREATED"})
            m = re.fullmatch(r"/approve/([\w-]+)", self.path)
            if m and m.group(1) in orders:
                # Kao pravi PayPal: kupac odobrava uplatu pa ga PayPal preusmjerava na povratnu adresu aplikacije.
                order = orders[m.group(1)]
                order["approved"] = True
                self.send_response(302)
                self.send_header("Location", f"{order['return_url']}?token={order['id']}&PayerID=FAKEPAYER")
                self.send_header("Content-Length", "0")
                self.end_headers()
                return
        self.send_json(404, {"name": "NOT_FOUND"})

    def do_POST(self):
        raw = self.body()
        with lock:
            if self.path == "/v1/oauth2/token":
                if self.headers.get("Authorization") != EXPECTED_AUTH:
                    return self.send_json(401, {"error": "invalid_client"})
                stats["tokens"] += 1
                return self.send_json(200, {"access_token": "mock-token", "expires_in": 3600})

            m = re.fullmatch(r"/_approve/([\w-]+)", self.path)
            if m:
                orders[m.group(1)]["approved"] = True
                return self.send_json(200, {"ok": True})
            m = re.fullmatch(r"/_decline/([\w-]+)", self.path)
            if m:
                orders[m.group(1)]["declined"] = True
                return self.send_json(200, {"ok": True})

            if not self.authorized():
                return self.send_json(401, {"name": "AUTHENTICATION_FAILURE"})

            if self.path == "/v2/checkout/orders":
                payload = json.loads(raw)
                unit = payload["purchase_units"][0]
                assert unit["amount"]["currency_code"] == "EUR"
                assert payload["payment_source"]["paypal"]["experience_context"]["return_url"]
                oid = next_id("ORDER")
                context = payload["payment_source"]["paypal"]["experience_context"]
                orders[oid] = {"id": oid, "value": unit["amount"]["value"], "approved": False,
                               "declined": False, "capture_id": None, "capture_req": None,
                               "return_url": context["return_url"]}
                stats["create"] += 1
                return self.send_json(201, {"id": oid, "status": "PAYER_ACTION_REQUIRED", "links": [
                    {"rel": "self", "href": f"{PUBLIC_URL}/v2/checkout/orders/{oid}"},
                    {"rel": "payer-action", "href": f"{PUBLIC_URL}/approve/{oid}"}]})

            m = re.fullmatch(r"/v2/checkout/orders/([\w-]+)/capture", self.path)
            if m:
                stats["capture_calls"] += 1
                order = orders.get(m.group(1))
                if not order:
                    return self.send_json(404, {"name": "RESOURCE_NOT_FOUND"})
                req_id = self.headers.get("PayPal-Request-Id")
                if order["capture_id"]:
                    if req_id and req_id == order["capture_req"]:
                        return self.send_json(201, self.capture_response(order))
                    return self.send_json(422, {"name": "UNPROCESSABLE_ENTITY",
                                                "details": [{"issue": "ORDER_ALREADY_CAPTURED"}]})
                if order["declined"]:
                    return self.send_json(422, {"name": "UNPROCESSABLE_ENTITY",
                                                "details": [{"issue": "INSTRUMENT_DECLINED"}]})
                if not order["approved"]:
                    return self.send_json(422, {"name": "UNPROCESSABLE_ENTITY",
                                                "details": [{"issue": "ORDER_NOT_APPROVED"}]})
                cid = next_id("CAP")
                captures[cid] = {"id": cid, "value": order["value"], "refunded": False}
                order["capture_id"] = cid
                order["capture_req"] = req_id
                stats["capture_ok"] += 1
                return self.send_json(201, self.capture_response(order))

            m = re.fullmatch(r"/v2/payments/captures/([\w-]+)/refund", self.path)
            if m:
                stats["refund_calls"] += 1
                cap = captures.get(m.group(1))
                if not cap:
                    return self.send_json(404, {"name": "RESOURCE_NOT_FOUND"})
                if cap["refunded"]:
                    return self.send_json(422, {"name": "UNPROCESSABLE_ENTITY",
                                                "details": [{"issue": "CAPTURE_FULLY_REFUNDED"}]})
                payload = json.loads(raw)
                cap["refunded"] = True
                stats["refund_amounts"].append(payload["amount"]["value"])
                return self.send_json(201, {"id": next_id("REF"), "status": "COMPLETED"})

        self.send_json(404, {"name": "NOT_FOUND"})


if __name__ == "__main__":
    ThreadingHTTPServer(("127.0.0.1", PORT), Handler).serve_forever()
