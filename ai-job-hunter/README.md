# AI Job Hunter

An AI automation system built with **n8n + Gemini + Supabase (pgvector) + WhatsApp Cloud API**. It finds remote jobs, matches them against my CV using RAG, writes cover letters, and tracks applications.

> 🚧 Work in progress. WF0–WF2 are done, WF3–WF5 are planned.

## Problem

Job hunting means checking several job boards every day, reading dozens of descriptions, and guessing which ones actually fit your skills. Most of that time goes to jobs you were never a good match for.

## Solution

A set of n8n workflows that do the boring part:

1. Store the CV as vector embeddings so it can be searched by meaning.
2. Collect new remote jobs every day from public job APIs.
3. Use RAG to score each job 0–100 against the most relevant parts of the CV.
4. Write cover letters for strong matches, and manage everything from WhatsApp (planned).

## Stack

| Layer | Tool |
| --- | --- |
| Orchestration | [n8n](https://n8n.io) |
| LLM + embeddings | Google Gemini |
| Database + vector store | Supabase (Postgres + pgvector) |
| Chat interface + alerts | WhatsApp Cloud API |
| Job sources | Remotive API, RemoteOK API |

## Architecture

```
            ┌──────────────┐
  CV PDF ──▶│ WF0 CV Brain │──▶ cv_chunks (pgvector)
            └──────────────┘          │
                                      │ similarity search
┌───────────────────┐   jobs   ┌──────▼──────────┐ score >= 70 ┌────────────────────┐
│ WF1 Job Collector │────────▶│ WF2 Job Matcher │────────────▶│ WF3 Cover Letter   │
│ (daily 9 AM)      │ triggers │ (RAG + Gemini)  │             │ Writer (planned)   │
└───────────────────┘          └─────────────────┘             └────────────────────┘

  WhatsApp ◀──▶ WF4 WhatsApp Assistant (planned) ◀──▶ job_dashboard / applications
  any failure ──▶ WF5 Error Guard (planned) ──▶ workflow_errors + WhatsApp alert
```

| # | Workflow | What it does | Status |
| --- | --- | --- | --- |
| WF0 | CV Brain | Form upload of the CV PDF → delete old chunks → split into chunks → Gemini embeddings → Supabase vector store (`cv_chunks`) | ✅ Done |
| WF1 | Job Collector | Daily at 9 AM: fetch Remotive + RemoteOK → normalize to one shape → upsert into `jobs` (dedupe on `source, external_id`) → trigger WF2 | ✅ Done |
| WF2 | Job Matcher | Take `new` jobs → skip non-dev roles → find matching CV chunks → Gemini scores 0–100 with structured output (score, verdict, reasoning, matched/missing skills) → save to `job_matches` | ✅ Done |
| WF3 | Cover Letter Writer | Write a tailored cover letter for every job with score >= 70 → save to `cover_letters` | ⏳ Planned |
| WF4 | WhatsApp Assistant | AI agent on WhatsApp: list top `jobs`, mark one with `applied <id>`, answer questions about jobs and applications | ⏳ Planned |
| WF5 | Error Guard | n8n error workflow: log failures to `workflow_errors` and send a WhatsApp alert | ⏳ Planned |

## Repo structure

```
workflows/
  wf0-cv-brain.json
  wf1-job-collector.json
  wf2-job-matcher.json
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
- **WhatsApp Cloud API**: needed for WF4/WF5 later

See `.env.example` for the full list of keys. Never commit real values.

### 3. Import the workflows

1. In n8n: **Workflows → Import from File**, then import each JSON in `workflows/`.
2. Open each node that shows a credential warning and select your own credentials.
3. In the **Save to Supabase** (WF1) and **Save Score** (WF2) HTTP nodes, replace `YOUR_SUPABASE_URL` with your project URL, e.g. `https://xxxx.supabase.co`.
4. In WF1, open **Run Job Matcher** and select your imported WF2 (workflow IDs change on import).
5. Run WF0 once, upload your CV, then activate WF1.
