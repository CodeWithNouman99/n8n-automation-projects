# ElevenLabs Webhook Tools

Both tools are **Webhook** tools, method `POST`, body type `JSON`.
Replace `YOUR_N8N_URL` with your n8n base URL (e.g. an ngrok or hosted URL).

---

## 1. `book_reservation`

**URL:** `YOUR_N8N_URL/webhook/restaurant-reservation`

**Description:**
> Use this tool to save a new table reservation after the caller has confirmed all details: name, phone number, date, time, number of guests and seating. Call it only once per booking. After it returns, tell the caller their reservation ID.

**Body description:** Reservation details collected from the caller during the call.

| Property | Type | Required | Description |
|---|---|---|---|
| `customer_name` | string | yes | Full name of the caller for the booking |
| `phone` | string | yes | Caller's phone number, digits only, e.g. 03001234567 |
| `date` | string | yes | Reservation date in YYYY-MM-DD format |
| `time` | string | yes | Reservation time, e.g. 8:00 PM |
| `guests` | number | yes | Total number of guests |
| `seating` | string (enum) | yes | `Family Hall`, `Rooftop`, `Private Room`, `Any` |
| `special_request` | string | no | Any special request (birthday, high chair etc.). Empty if none |

**Response (from n8n):**
```json
{
  "success": true,
  "reservation_id": "LTH-261118004454",
  "message": "Reservation saved. Tell the caller their reservation ID. Do not call the tool again."
}
```

---

## 2. `update_reservation`

**URL:** `YOUR_N8N_URL/webhook/restaurant-update`

**Description:**
> Use this tool when the caller wants to cancel or change an existing reservation. First ask for the phone number used for the booking. For a change, ask what they want to change (date, time or number of guests) and confirm the new details before calling. Call it only once.

**Body description:** Details of the reservation to cancel or change.

| Property | Type | Required | Description |
|---|---|---|---|
| `phone` | string | yes | Phone number used for the booking, 11 digits |
| `action` | string (enum) | yes | `change` or `cancel`. Use "change" for date/time/guest changes; "cancel" ONLY if the caller clearly wants to cancel the whole booking |
| `new_date` | string | no | New date in YYYY-MM-DD format |
| `new_time` | string | no | New time, e.g. 9:00 PM |
| `new_guests` | number | no | New number of guests |

**Response (found):**
```json
{
  "success": true,
  "reservation_id": "LTH-261118004454",
  "status": "Changed",
  "date": "2026-11-20",
  "time": "21:00",
  "guests": "6",
  "message": "Reservation updated. Confirm the new details to the caller..."
}
```

**Response (not found):**
```json
{
  "success": false,
  "message": "No reservation found for this phone number. Ask the caller to confirm the number they used for booking."
}
```

---

## Agent settings used

- **Voice:** Reva – Warm Urdu Narration (stability ~0.65 to avoid laugh-like artifacts)
- **Language:** Urdu, with English as an additional language
- **Knowledge base:** `knowledge-base.txt` (RAG on)
- **System tools:** End conversation, Detect language
