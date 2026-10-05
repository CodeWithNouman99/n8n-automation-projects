# DevBuddy: AI Onboarding Buddy for New Developers

DevBuddy looks after a new developer's first week at a software house. It welcomes them on WhatsApp, sends one task a day, answers their questions from the company docs, nudges them when they are stuck, and tells their manager when they need help.

Built for a fictional company, **Nexora Labs**, using n8n, Gemini, the WhatsApp Cloud API and Google Workspace.

## The problem

New developers lose their first week asking the same questions (setup, Git rules, deployment, HR policies) while managers have no easy way to see who is stuck. DevBuddy handles the repetitive part and gives managers a clear signal.

## What it does

- **Welcome:** HR adds a developer and DevBuddy sends a WhatsApp welcome with the Day 1 task.
- **Answers questions:** the developer asks anything about setup, Git, deployment, company or HR. DevBuddy answers only from the company docs and never makes things up.
- **Logs every question:** each question is saved with a flag showing whether the answer was found in the docs, so HR can see which docs are missing something.
- **Tracks tasks:** the developer replies "done" and the task is marked complete.
- **Daily next task:** every morning at 9:00 the next task is sent automatically.
- **Reminders and alerts:** a pending task gets a reminder. After 2 days the manager gets an alert.
- **Weekly report:** every Friday each manager gets a summary of their developers: current day, tasks done, who is stuck, and how many questions were not covered by the docs.
- **Completion:** after Day 7 the developer is marked Completed and congratulated.

## Workflows

| File | Trigger | Purpose |
|---|---|---|
| `devbuddy-main.json` | HR form (webhook) and incoming WhatsApp messages | Welcome flow and the AI buddy |
| `devbuddy-daily.json` | Schedule, every day 9:00 | Next task, reminder, manager alert, completion |
| `devbuddy-weekly-report.json` | Schedule, every Friday 17:00 | Weekly report to managers |

### Main workflow

```
Welcome flow
Webhook -> Append developer -> WhatsApp welcome -> Create Day 1 progress row

AI buddy
WhatsApp Trigger -> Filter -> Get Developer -> Get Progress -> AI Agent -> Send Reply
                                                                |
                                      tools: Read Company Docs, Log Question, Mark Task Done
```

### Daily workflow

```
Schedule -> Active developers -> Current progress -> Task done?
   yes -> Last day? -> yes: Mark Completed -> Congratulate
                    -> no:  Next task -> Add progress -> Update day -> Send task
   no  -> Stuck 2+ days? -> yes: Stuck task -> Alert manager (WhatsApp template)
                         -> no:  Send reminder
```

### Weekly report workflow

```
Schedule -> All developers -> All progress -> All questions -> Build report (Code) -> Send to managers
```

## Tech stack

- **n8n Cloud** for orchestration
- **Google Gemini** (flash model) as the AI agent
- **WhatsApp Cloud API** for messaging (approved template for manager alerts)
- **Google Sheets** as the database and **Google Docs** as the knowledge base

## Data model (Google Sheet)

| Tab | Columns |
|---|---|
| Developers | dev_id, name, whatsapp_number, role, join_date, manager_whatsapp, current_day, status |
| Onboarding_Tasks | task_id, day, role, task_title, description |
| Progress | dev_id, task_id, status, assigned_date, completed_date, progress_id |
| Questions_Log | timestamp, dev_id, question, answer, found_in_docs |

The knowledge base is 5 Google Docs: Company Overview, Dev Setup Guide, Git & Code Review Rules, Deployment Guide, HR FAQ.

## Setup

1. Create the Google Sheet with the 4 tabs above and fill `Onboarding_Tasks` (T1 to T7).
2. Create the 5 Google Docs and note their IDs.
3. In n8n, import the three JSON files (Workflows > Import from file).
4. Create credentials in n8n: Google Sheets, Google Docs, Google Gemini, WhatsApp (access token and phone number ID).
5. Re-select your sheet and docs in the Google nodes, and put your doc IDs in the AI Agent system message.
6. Create and get approved a WhatsApp message template named `devbuddy_stuck_alert` with 3 variables (developer name, task, days).
7. Set the workflow timezone and publish the workflows.

Note: with a single WhatsApp test number, only one workflow with a WhatsApp Trigger can be published at a time.

## Lessons learned

- Gemini can fail with "Bad request" when several tools run at once, so data is fetched with normal nodes first and the agent has only three tools.
- Preview and lite models are less stable. A stable flash model with retry on fail (5 tries, 5 s wait) handles temporary 503 errors.
- WhatsApp only allows free-form messages inside a 24-hour window. Messages outside it (like manager alerts) need an approved template.
- Phone numbers read from Sheets are numbers, so they need `String()` before being sent to WhatsApp.

## Roadmap

- HR portal (React + Tailwind) to add developers
- Manager dashboard
- Templates for all outbound messages in production

## Author

Nouman Aslam · [GitHub](https://github.com/CodeWithNouman99)
