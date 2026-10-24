# AI Job Hunter

An AI automation system built with **n8n + Gemini + Supabase (pgvector) + WhatsApp Cloud API**. It finds remote and Pakistan jobs, matches them against my CV using RAG, writes cover letters, and tracks applications.

> ✅ WF0–WF5 are done.

## Problem

Job hunting means checking several job boards every day, reading dozens of descriptions, and guessing which ones actually fit your skills. Most of that time goes to jobs you were never a good match for.

## Solution

A set of n8n workflows that do the boring part:

1. Store the CV as vector embeddings so it can be searched by meaning.
2. Collect new jobs every day from public job APIs (remote jobs + Pakistan jobs).
3. Use RAG to score each job 0–100 against the most relevant parts of the CV.
4. Write cover letters for strong matches, and manage everything from WhatsApp.

## Stack

| Layer | Tool |
| --- | --- |
| Orchestration | [n8n](https://n8n.io) |
| LLM + embeddings | Google Gemini |
| Database + vector store | Supabase (Postgres + pgvector) |
| Chat interface + alerts | WhatsApp Cloud API |
| Job sources | Remotive API, RemoteOK API, JSearch API (RapidAPI) |

## Architecture

```
            ┌──────────────┐
  CV PDF ──▶│ WF0 CV Brain │──▶ cv_chunks (pgvector)
            └──────────────┘          │
                                      │ similarity search
┌───────────────────┐   jobs   ┌──────▼──────────┐ score >= 70 ┌────────────────────┐
│ WF1 Job Collector │────────▶│ WF2 Job Matcher │────────────▶│ WF3 Cover Letter   │
│ (daily 9 AM)      │ triggers │ (RAG + Gemini)  │             │ Writer (daily 10AM)│
└───────────────────┘          └─────────────────┘             └────────────────────┘

  WhatsApp ◀──▶ WF4 WhatsApp Assistant ◀──▶ job_dashboard / cover_letters / applications
  any failure ──▶ WF5 Error Guard ──▶ WhatsApp alert
```

| # | Workflow | What it does | Status |
| --- | --- | --- | --- |
| WF0 | CV Brain | Form upload of the CV PDF → delete old chunks → split into chunks → Gemini embeddings → Supabase vector store (`cv_chunks`) | ✅ Done |
| WF1 | Job Collector | Daily at 9 AM: fetch Remotive + RemoteOK + JSearch (Pakistan jobs) → normalize to one shape → upsert into `jobs` (dedupe on `source, external_id`) → trigger WF2 | ✅ Done |
| WF2 | Job Matcher | Take `new` jobs → skip non-dev roles → find matching CV chunks → Gemini scores 0–100 with structured output (score, verdict, reasoning, matched/missing skills) → save to `job_matches` | ✅ Done |
| WF3 | Cover Letter Writer | Daily at 10 AM: get up to 10 jobs with score >= 70 and no cover letter yet → loop each job → find matching CV chunks (Supabase vector store + Gemini embeddings) → Gemini writes a 150–220 word letter using only real CV facts → upsert into `cover_letters` | ✅ Done |
| WF4 | WhatsApp Assistant | On every WhatsApp message: keep only text from my own number → AI Agent (Gemini + window memory per sender) with 3 HTTP tools: **Get Top Jobs** (`job_dashboard`), **Get Cover Letter** (`cover_letters`), **Mark Applied** (`applications`) → reply on WhatsApp. Commands: `jobs`, `letter <id>`, `applied <id>`, or any question | ✅ Done |
| WF5 | Error Guard | Error Trigger (set as the error workflow of WF3/WF4): build an alert with workflow, node, error message, time (Asia/Karachi) and execution link → send it to me on WhatsApp | ✅ Done |

## Repo structure

```
workflows/
  wf0-cv-brain.json
  wf1-job-collector.json
  wf2-job-matcher.json
  wf3-cover-letter-writer.json
  wf4-whatsapp-assistant.json
  wf5-error-guard.json
database/
  supabase_schema.sql   # all tables, match_cv_chunks function, job_dashboard view
docs/screenshots/
.env.example            # list of the keys you need
```

## Setup

### 1. Supabase

1. Create a Supabase project.
2. Open **SQL Editor → New query**, paste `database/supabase_schema.sql`, and run it. You can run it again safely; it uses `IF NOT EXISTS`.
   It creates `jobs`, `job_matches`, `cover_letters`, `applications`, `workflow_errors`, `cv_chunks` (pgvector, 3072 dims for `gemini-embedding-001`), the `match_cv_chunks` search function, and the `job_dashboard` view. RLS is on for every table with no policies, so only the service role key can read the data.

### 2. n8n credentials

Create these credentials in n8n:

- **Supabase API**: your project URL + service role (secret) key
- **Google Gemini (PaLM) API**: your Gemini API key
- **WhatsApp API**: permanent access token, used by WF4/WF5 to send messages
- **WhatsApp OAuth API**: app ID + secret, used by the WF4 WhatsApp Trigger
- **Header Auth** (name it `JSearch API`): header name `X-RapidAPI-Key`, value = your RapidAPI key. Used by WF1 **Get JSearch Jobs**. Subscribe to **JSearch** on RapidAPI; the free plan gives 200 requests/month, and WF1 uses 1 request per day

See `.env.example` for the full list of keys. Never commit real values.

### 3. Import the workflows

1. In n8n: **Workflows → Import from File**, then import each JSON in `workflows/`.
2. Open each node that shows a credential warning and select your own credentials.
3. In every Supabase HTTP node (WF1–WF4), replace `YOUR_SUPABASE_URL` with your project URL, e.g. `https://xxxx.supabase.co`.
4. In WF4 and WF5, replace `YOUR_WHATSAPP_PHONE_NUMBER_ID` in the WhatsApp send nodes, and `YOUR_WHATSAPP_NUMBER` (your own number with country code, no `+`) in **Only My Text** (WF4) and **Send Alert** (WF5).
5. In WF1, open **Run Job Matcher** and select your imported WF2 (workflow IDs change on import).
6. In WF3 and WF4, open **Settings → Error Workflow** and select your imported WF5.
7. Run WF0 once, upload your CV, then activate WF1, WF3, WF4 and WF5.
