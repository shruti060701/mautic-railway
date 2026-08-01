# Deploy and Host Mautic Self-Hosted on Railway

Mautic is the open-source marketing automation platform that replaces HubSpot and Mailchimp for email campaigns, lead scoring, and multi-channel automation. Build visual campaigns, score leads by behavior, and send personalized emails at scale, all on infrastructure you control instead of a per-contact metered SaaS.

## About Hosting Mautic-Self-Hosted

HubSpot's Marketing Hub Professional plan runs $800-890/month for 3 seats and 2,000 marketing contacts, plus a mandatory one-time $3,000 onboarding fee. Growing past 2,000 contacts adds hundreds more per month, and the bill keeps climbing as your list grows, exactly when your marketing is working. Self-hosted Mautic on Railway costs a flat infrastructure fee regardless of contact count or campaign volume.

The bigger reason to self-host marketing automation specifically isn't only the pricing curve. Your contact list, campaign logic, and email history are some of the most valuable data a growing business has, and every major marketing platform's business model depends on making that data hard to fully export or move. Self-hosting Mautic means that data lives on infrastructure you actually control from day one.

It's worth being direct about something most simplified Mautic templates get wrong: they run a single web container and call it done. Mautic's real architecture needs a dedicated worker to process queued email and campaign jobs, and a dedicated cron process to run scheduled tasks like segment updates and campaign triggers, without either, campaigns look fully configured in the dashboard but silently never actually execute. This template runs the real three-service architecture Mautic itself recommends.

This isn't a small or unproven project either. Mautic has real production adoption, with an active plugin ecosystem and a genuine open-source community behind it, not a solo maintainer project. That matters for infrastructure this central to how a business talks to its customers.

## Common Use Cases

- **Email marketing campaigns**: Build and send personalized email campaigns with a visual drag-and-drop builder, no per-contact fee eating into the margin on every campaign you run.
- **Lead scoring and nurturing**: Score contacts by behavior and automatically move them through nurture sequences based on real engagement, not guesswork.
- **Multi-channel automation**: Combine email, SMS, and social touchpoints into a single campaign flow.
- **CRM integration**: Sync with your existing CRM via Mautic's API and plugin ecosystem instead of paying for a bundled CRM you don't need.
- **Agencies managing multiple client accounts**: Self-hosted means no per-contact overage bill eating into client margins as their lists grow.

## Dependencies for Mautic-Self-Hosted Hosting

- MySQL for contacts, campaigns, segments, and email data.
- A dedicated worker process for queued email and campaign jobs.
- A dedicated cron process for scheduled tasks, distinct from both the web server and the worker.

### Deployment Dependencies

This template provisions three Mautic services (web, worker, cron) from one shared image, plus a Railway-managed MySQL database, wired together over the private network. Reference: [Mautic GitHub Repository](https://github.com/mautic/mautic), [Official Docker Image Repository](https://github.com/mautic/docker-mautic), [Mautic Documentation](https://docs.mautic.org).

### Implementation Details

This template runs `mautic/mautic:7.1.3-apache`, Mautic's own official image, confirmed via Docker Hub's tags API as matching the current release's digest at authoring time, not a stale or unofficial rebuild. The existing popular Railway Mautic template bakes database credentials and the admin password in as Docker build-time arguments, which embed them directly in image layers (inspectable via `docker history`) and require a full image rebuild just to rotate a password, a real security and operability gap avoided here by using genuine runtime environment variables instead. A more fundamental problem this template solves: Railway doesn't support sharing one volume across multiple services, confirmed directly via Railway's own community help station, but Mautic's own Docker image normally expects web, worker, and cron to share one config file that records install state and a shared encryption key. This template works around that by generating each service's configuration deterministically from the same shared environment variables instead of a shared file, and by explicitly re-syncing the encryption key after install so all three services can decrypt the same data, verified working via real deploy testing, not just designed on paper.

## How Mautic Compares to the Alternatives

**Vs. HubSpot**: HubSpot bundles marketing, sales, and service tools into one expensive platform with a mandatory five-figure onboarding fee at the tiers most growing businesses actually need. Mautic gives you the marketing automation core, at a flat infrastructure cost regardless of contact count, without the rest of the bundle.

**Vs. Mailchimp**: Mailchimp's automation logic is comparatively basic outside its higher paid tiers, and pricing scales directly with subscriber count. Mautic includes full campaign branching and lead scoring at every tier, since there are no tiers, just the software.

**Vs. ActiveCampaign**: ActiveCampaign is a capable closed-source SaaS platform with no self-hosted option at all. Mautic is fully open source, self-hostable, and extensible via its own plugin system if you need functionality it doesn't ship with by default.

## Getting Started

After deploying, give the web service real time before assuming something's wrong, first boot runs Mautic's actual install process (schema creation, admin account, initial configuration), which takes noticeably longer than a typical app's first boot.

Once healthy, log in at your Railway domain with the admin email and password you configured. Add your SMTP provider's credentials in Mautic's own settings, this template handles infrastructure and installation, not email deliverability, you'll still want a real transactional email provider behind it.

Build a small test campaign rather than importing your full contact list on day one. Add yourself as a test contact, trigger the campaign, and confirm you actually receive the email, that's the real proof the worker service is processing queued jobs correctly, not just that the web dashboard loads.

Check that scheduled tasks are actually running by watching a segment with a scheduled rebuild, or a time-based campaign trigger, fire on schedule. That's the cron service's job specifically, worth confirming directly rather than assuming it's working just because the container shows as healthy.

One thing worth expecting rather than being alarmed by: worker and cron may show a few early restarts right after a brand new deploy, since they start trying to do real work as soon as their own configuration is ready, which can be moments before the web service actually finishes creating the database schema. Railway's restart policy handles this automatically, confirmed as expected, self-healing behavior, not a real bug.

## Why Deploy Mautic-Self-Hosted on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying Mautic-self-hosted on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.

## Frequently Asked Questions

### Why does this template deploy 3 Mautic services instead of a simpler single container?
Because campaigns genuinely need all three. The worker processes queued email and campaign jobs, and cron runs Mautic's own scheduled tasks. A single-container setup looks complete in the dashboard but campaigns silently never actually fire without the other two.

### How does this template handle Mautic's shared-config requirement when Railway doesn't support shared volumes?
Each service generates its own configuration deterministically from the same shared environment variables at boot, instead of depending on a config file written by one service and read by another. The encryption key specifically gets explicitly re-synced after install so all three services can decrypt the same data, verified via real deploy testing.

### Do I need to run the install process myself?
No, the web service runs Mautic's real install command automatically on every boot. It's safe to run repeatedly, Mautic's own install command checks the database and does nothing if already installed.

### Is my admin password or database credentials baked into a Docker image anywhere?
No. Unlike the existing popular Railway Mautic template, this one passes all credentials as genuine runtime environment variables, never as build-time arguments embedded in image layers.

### Where can I download Mautic?
Source code is at `github.com/mautic/mautic`, with Docker images published to Docker Hub under `mautic/mautic`. This template pulls a specific verified version automatically.
