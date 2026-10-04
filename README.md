# n8n Automation Projects

A collection of AI automation workflows built with n8n. Each folder holds one project: the exported workflow (`workflow.json`), a README explaining how it works, and screenshots.

## Projects

| Project | What it does | Tools |
|---|---|---|
| [WhatsApp Doctor Appointment Bot](./whatsapp-doctor-appointment) | Patients book, reschedule and cancel clinic appointments over WhatsApp, with Stripe payments, refunds and daily reminders | n8n, WhatsApp Cloud API, Gemini, Google Sheets, Stripe |
| [Client Onboarding Automation](./client-onboarding-automation) | Onboards a new software-house client from one form submission: Drive workspace, Slack channel, welcome email, kickoff call and a client log for an admin dashboard | n8n, Webhook, Google Sheets, Google Drive, Slack, Gmail, Google Calendar |

## How to use a workflow

1. Open the project folder and download `workflow.json`.
2. In n8n, create a new workflow and choose *Import from File*.
3. Add your own credentials for each service the workflow uses.
4. Replace any `YOUR_...` placeholders with your own values.
5. Follow the setup steps in that project's README.

No API keys or tokens are stored in this repo. Every workflow needs your own credentials to run.

## Repo structure

```
n8n-automation-projects/
├── README.md
├── whatsapp-doctor-appointment/
│   ├── workflow.json
│   ├── README.md
│   └── screenshots/
└── client-onboarding-automation/
    ├── workflow.json
    ├── README.md
    └── screenshots/
```

## Contact

GitHub: [CodeWithNouman99](https://github.com/CodeWithNouman99)
