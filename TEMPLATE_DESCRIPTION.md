## Template Titles

**Railway Title:** `Mautic` (plain name only, this field controls the URL slug)
**Railway Description:** `Mautic [Aug '26] (Marketing Automation Platform) Self Host`
**Spreadsheet Title:** `Mautic (Open-Source Marketing Automation & Campaign Platform)`
**GitHub Description:** `Mautic: open-source marketing automation platform, a HubSpot and Mailchimp alternative. Deploy on Railway with one click.`

---

![Mautic campaign builder showing a visual email automation flow](https://res.cloudinary.com/dt8h4kuxe/image/upload/v1746791300/mautic-banner.png "Hosting Mautic on Railway")

# Deploy and Host Self-Hosted Mautic (Open-Source Marketing Automation) on Railway

Mautic is the open-source marketing automation platform that replaces HubSpot and Mailchimp for email campaigns, lead scoring, and multi-channel automation. Build visual campaigns, score leads by behavior, and send personalized emails at scale, all on infrastructure you control.

## About Hosting Mautic Open-Source Software on Railway (Self-Hosted Mautic Template)

Self-hosting Mautic means your contact data, campaign logic, and email history stay on infrastructure you control, with no per-contact metered fee. Railway provisions the real three-service Mautic architecture (web, worker, cron) alongside MySQL, wired together automatically, so campaigns actually execute, not just display in a dashboard.

## Why Deploy Mautic, the HubSpot Alternative on Railway (Railway Free Trial)

HubSpot's Marketing Hub Professional plan runs $800-890/month for 3 seats and 2,000 marketing contacts, plus a mandatory one-time $3,000 onboarding fee. Growing past 2,000 contacts adds hundreds more per month. Self-hosted Mautic on Railway costs a flat infrastructure fee regardless of contact count or campaign volume. Railway's $5 free trial covers your first month.

### Railway vs Other Hosting Providers and VPS for Mautic Self Hosting

| Provider          | What You Get with Railway           | What You Get with the Other Provider     |
| ----------------- | ------------------------------------ | ----------------------------------------- |
| **DigitalOcean**  | Auto-provisioned databases, zero server maintenance | Raw droplets you patch, secure, and back up yourself |
| **AWS**           | Simple usage-based billing, no RDS maze | Manual instance sizing, security groups, surprise egress fees |
| **Hetzner**       | One-click deploy, instant rollback | Cheap hardware but you own the OS, backups, and TLS |

## Common Use Cases for Hosted Mautic

- **Email marketing campaigns**: Build and send personalized email campaigns with a visual drag-and-drop builder, no per-contact SaaS fee.
- **Lead scoring and nurturing**: Score contacts by behavior and automatically move them through nurture sequences.
- **Multi-channel automation**: Combine email, SMS, and social touchpoints into a single campaign flow.
- **CRM integration**: Sync with your existing CRM via Mautic's API and plugin ecosystem instead of paying for a bundled one.
- **Agencies managing multiple client accounts**: Self-hosted means no per-contact overage bill eating into client margins as their lists grow.

![Mautic lead scoring dashboard showing contact behavior tracking](https://res.cloudinary.com/dt8h4kuxe/image/upload/v1746791301/mautic-features.png "Mautic lead tracking and scoring")

## Dependencies for Mautic Docker Hosted on Railway

Mautic needs MySQL for contacts, campaigns, and email data, plus a dedicated worker process for queued email/campaign jobs and a dedicated cron process for scheduled tasks (segment updates, campaign triggers, reports), both distinct from the web server.

### Deployment Dependencies for Managed Mautic Service (Marketing Automation Platform)

This template provisions three Mautic services (web, worker, cron) from one shared image, plus a Railway-managed MySQL database, all wired together over the private network. This matches Mautic's own real recommended architecture, not a simplified single-container shortcut that leaves campaigns unable to actually send.

### Implementation Details for Mautic (Using Mautic Official Docker Image)

The template deploys `mautic/mautic:7.1.3-apache`, Mautic's own official image, pinned to a specific numbered version verified against Docker Hub's tags API as matching the current release. The web service runs Mautic's real install process automatically on boot (safe to run on every restart, Mautic's own install command checks the database and no-ops if already installed). Since Railway doesn't support sharing one volume across services, each service's local configuration is derived deterministically from the same shared environment variables rather than a shared file, confirmed working via real deploy testing.

## Environment Variables Reference for Mautic on Railway

| Variable | Description | Value |
|----------|-------------|-------|
| `DOCKER_MAUTIC_ROLE` | Which process this service runs. | `mautic_web` / `mautic_worker` / `mautic_cron` |
| `MAUTIC_DB_HOST` / `MAUTIC_DB_PORT` / `MAUTIC_DB_DATABASE` / `MAUTIC_DB_USER` / `MAUTIC_DB_PASSWORD` | MySQL connection details. | From Railway's MySQL plugin |
| `MAUTIC_URL` | Public URL of your instance, identical across all three services. | `https://${{RAILWAY_PUBLIC_DOMAIN}}` |
| `MAUTIC_ADMIN_EMAIL` | Admin account email created on first install. | User-provided |
| `MAUTIC_ADMIN_PASSWORD` | Admin account password created on first install. | `${{secret(32)}}` |
| `MAUTIC_SECRET_KEY` | Encryption key, must be identical across web, worker, and cron. | `${{secret(32)}}` |

## How Does Mautic Compare Against Other Marketing Automation Platforms

### Mautic vs HubSpot
* **Pricing:** Mautic self-hosted has no per-contact or per-seat fee; HubSpot's Professional plan starts at $800-890/month plus a $3,000 onboarding fee.
* **Data ownership:** Mautic keeps all contact and campaign data on infrastructure you control; HubSpot stores everything on their platform.

### Mautic vs Mailchimp
* **Automation depth:** Mautic includes full campaign branching logic and lead scoring built in; Mailchimp's automation is comparatively basic outside its higher paid tiers.
* **Cost at scale:** Mautic's cost stays flat as your list grows; Mailchimp's pricing scales directly with subscriber count.

### Mautic vs ActiveCampaign
* **Openness:** Mautic is fully open source with complete customization via its plugin system; ActiveCampaign is closed-source SaaS only.
* **Self-hosting:** Mautic can run entirely on infrastructure you control; ActiveCampaign has no self-hosted option.

## How to Use Mautic (the Open-Source Marketing Automation Platform)?

Deploy the template, log in with your admin credentials, build a campaign in the visual editor, and send a test email to confirm the worker is processing jobs correctly.

## How to Self Host Mautic on Other VPS Services (Mautic Self Hosting Guide)

### Clone the Repository
Clone `github.com/mautic/docker-mautic` for official Docker Compose examples.

### Install Dependencies
Docker, plus a MySQL database. Web, worker, and cron all need to run for campaigns to actually execute.

### Configure Environment Variables
Set the `MAUTIC_DB_*` variables, `MAUTIC_URL`, and admin credentials before starting the containers.

### Start the Mautic Application
Run all three service roles (web, worker, cron) pointed at the same database, and expose the web service's port behind a reverse proxy with TLS.

## Official Pricing of Mautic (Mautic Pricing)

Mautic's core is GPL-3.0 licensed and free to self-host, with no contact or campaign limits. Mautic also offers Mautic Cloud as a separate managed hosting option.

## Mautic Cloud vs Self Hosted Comparison (Pricing, Features, Costs, and More)

Mautic Cloud handles infrastructure and updates for a subscription fee. Self-hosting on Railway gives you the same open-source engine at a flat cost, with full control over your contact data and email deliverability setup.

### Monthly Cost of Self Hosting Mautic on Railway

Typical cost: $15-30/month for all four services (web, worker, cron, MySQL) together, scaling up with contact volume and campaign frequency.

### System Requirements for Hosting Mautic on a VPS

Minimum: 1 shared vCPU, 1GB RAM per service. The worker benefits most from extra CPU during high email-send volume.

## Frequently Asked Questions (FAQs)

### What is Mautic self hosted?
An open-source marketing automation platform for email campaigns, lead scoring, and multi-channel automation, deployed on infrastructure you control instead of HubSpot or Mailchimp.

### Is Mautic free to use?
Yes, the core is GPL-3.0 open source and free to self-host indefinitely, with no contact or campaign limits.

### Why does this template deploy 3 Mautic services instead of 1?
Because campaigns genuinely need them. The worker processes queued email and campaign jobs, and cron runs Mautic's scheduled tasks, without either, campaigns silently never execute even though the web dashboard looks fully functional.

### Do I need to configure SMTP separately?
Yes, add your SMTP provider's settings in the web service after deploying to actually send emails, this template handles installation and infrastructure, not your email delivery provider.

### Where can I download Mautic?
Source code is at `github.com/mautic/mautic`, with Docker images published to Docker Hub under `mautic/mautic`. This template pulls a specific verified version automatically.
