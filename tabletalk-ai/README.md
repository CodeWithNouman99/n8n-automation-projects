# 🎙️ TableTalk AI – Voice Receptionist for Restaurants

An AI voice agent that answers restaurant calls in **Urdu + English**, books tables, changes or cancels reservations, and answers menu questions — while every booking lands live in Google Sheets.

Built for a demo restaurant, **Lahori Tikka House (Faisalabad)**. The agent is **Ayesha**, a warm front-desk receptionist.

---

## ✨ What it does

| Caller says | Ayesha does |
|---|---|
| "Mutton karahi kitne ki hai?" | Answers from the knowledge base (menu, deals, timings, parking, policies) |
| "Mujhe table book karni hai" | Collects name, date, time, guests, seating, phone → saves the booking → reads back a reservation ID |
| "Time change karke 9 baje kar do" | Finds the booking by phone → updates only what changed → status `Changed` |
| "Meri booking cancel kar do" | Confirms first → status `Cancelled` |
| "Koi discount milega?" | Never invents offers — routes to the manager |

---

## 🧱 Architecture

```
 Caller ──► ElevenLabs Agent (Ayesha)
              │  ├─ Knowledge base (RAG): menu, timings, policies
              │  ├─ Tool: book_reservation   ──► n8n webhook ──► Google Sheets (append)
              │  └─ Tool: update_reservation ──► n8n webhook ──► Google Sheets (find → update)
              ◄────────────── JSON response (reservation ID / status) ◄──┘
```

### Workflow 1 – Book Reservation
`Webhook → Append row in sheet → Respond to Webhook`
- Generates a unique ID: `LTH-yyMMddHHmmss`
- Timestamps in Asia/Karachi
- Returns the reservation ID so the agent can read it to the caller

### Workflow 2 – Update Reservation
`Webhook → Get row(s) by phone → IF found → Update row → Respond`
`                                     └─ not found → Respond (ask caller to re-check number)`
- Only overwrites the fields the caller changed (`new_value || old_value`)
- **Safety net:** a booking is marked `Cancelled` only if `action = cancel` **and** no new date/time/guests were sent — so a misheard intent can't wipe a booking

---

## 🛠️ Tech stack

- **ElevenLabs Agents** – voice, STT/TTS, LLM, knowledge base (RAG), webhook tools
- **n8n** (self-hosted) – webhooks, Google Sheets, IF logic, JSON responses
- **Google Sheets** – reservations database
- **ngrok** – exposes local n8n to ElevenLabs

---

## 📊 Google Sheet structure

One tab, `Reservations`, header in row 1:

| Reservation ID | Created At | Customer Name | Phone | Date | Time | Guests | Seating | Special Request | Status | Notes |
|---|---|---|---|---|---|---|---|---|---|---|

- `Status`: Confirmed · Changed · Cancelled · Completed · No-show
- `Seating`: Family Hall · Rooftop · Private Room · Any
- Format the `Phone` column as plain text so the leading `0` is kept

---

## 📁 Folder contents

```
tabletalk-ai/
├── README.md
├── workflows/
│   ├── book-reservation.json      # n8n workflow 1
│   └── update-reservation.json    # n8n workflow 2
└── elevenlabs/
    ├── system-prompt.md           # Ayesha's prompt + first message
    ├── tools.md                   # both webhook tools (params, enums, responses)
    └── knowledge-base.txt         # restaurant info, menu, deals, FAQs
```

---

## 🚀 Setup

1. **Google Sheet** – create a sheet with the columns above.
2. **n8n** – import both JSON files from `workflows/`, then in each Google Sheets node:
   - connect your Google Sheets credential
   - replace `YOUR_SHEET_ID` / `YOUR_SHEET_GID` by picking your sheet from the list
   - activate both workflows
3. **Expose n8n** – e.g. `ngrok http 5678`, and note the URL.
4. **ElevenLabs** – create an agent:
   - paste `elevenlabs/system-prompt.md` (prompt + first message)
   - upload `elevenlabs/knowledge-base.txt` to the knowledge base, RAG on
   - add the two webhook tools from `elevenlabs/tools.md`, with `YOUR_N8N_URL` replaced
   - pick an Urdu voice, set language to Urdu + English, publish
5. Call the agent and watch rows appear in the sheet.

---

## 🐞 Lessons learned while building

- **Duplicate rows:** when the n8n response node failed, ElevenLabs retried the tool and created 3 rows. Fixed by returning a simple JSON built from the previous node only, plus a "call once" rule in the prompt.
- **Missed digits:** the agent once saved a 10-digit number. Fixed with a guardrail: Pakistani mobiles are 11 digits starting with `03`, and the agent reads the number back.
- **Wrong cancel:** an `action` enum with only `cancel` made a time change cancel the booking. Fixed by adding `change` to the enum, a clearer description, and the n8n safety net.

---

> ⚠️ Demo restaurant, menu and prices are fictional. Sheet IDs, credentials and URLs are replaced with placeholders.

Built by **Nouman Aslam** · [GitHub](https://github.com/CodeWithNouman99) · [LinkedIn](https://linkedin.com/in/nouman-aslam-a9a3a2333)
