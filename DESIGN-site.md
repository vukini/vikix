# The Living Series site — design

Vid's own site in place of Substack: the writing, a landing page per subject, the books sold, the music app subscribed to, every post sent to the list and the feeds; published from the laptop by `vikix publish`, served from the edge, with one small service that knows who paid.

Drafted 2026-10-04 from a conversation with Vid, for TODO item 84. Changed the same day: the server is at Hetzner Cloud, not DigitalOcean (see "The server"). Kept honest like the other designs: what ships is deleted here, what changes is dated. This is the Living Series repo's design as much as Vikix's: Vikix's part is `vikix publish` and the doors to the server; the rest lives in `~/src/living-series`.

---

## The problem

The Vikid Truth is on Substack, which owns the list, the look and the discovery, and can't hold the rest of the work: the interactive sites, the books, the music app, the Esperanto. The Living Series is meant to be one body of work under one roof (`thelivingseries.com` the hub, `theliving.codes` the programming sites, `theliving.studio` the music app; one hub with a landing page per subject, never a site per book), sold by the Ajman company, and richer than posts: animations, live demos, an app. Nothing today does this: `vikix publish` makes an EPUB and a PDF and stops at `out/`; the sites deploy each by hand; there is no list, no store, no account.

## What it is

- **Pages on the edge.** The hub, the writing, the subject pages, the books' pages, the interactive sites and the music app's free tier: static files built by `vikix publish` and served by Cloudflare. They stay up whatever else is down.
- **A gate on a server.** One small service that knows who paid: webhooks from the merchant, login by magic link, "what do I own", stamped downloads of every version of a bought book, list membership. SQLite, one file. In Common Lisp, under conditions (below).
- **Email that is yours.** Listmonk on the server, Amazon SES behind it, the Substack list imported, three lists: readers, buyers, studio subscribers.
- **A fan-out from the feed.** A new post makes a campaign to the readers and a post to X, Mastodon and Bluesky; Facebook by hand. The feed is the only input, so a channel breaking never stops a post.
- **A merchant of record** (Paddle or Lemon Squeezy) for the till: checkout, EU and UK VAT, payouts to the Ajman company. Not raw Stripe at first: Stripe leaves the tax to the seller.

**The rule that organises it:** everything a visitor may see without paying is a static file on the edge; everything that needs to know who you are goes to the server. The server going down stops buying, logging in and reading paid things, nothing else; and checkout is the merchant's, so even buying survives.

## How it is built

```
 you, on the laptop
 ─────────────────────────────────────────────────────────────────────
 SOURCE   ~/src/living-series/     one git repo (below)
 BUILD    vikix publish            pandoc/Typst → pages, EPUB, PDF; checks; the feed
 ─────────────────────────────────────────────────────────────────────
 EDGE     Cloudflare               DNS, TLS, cache, Pages (the static files);
                                   one Worker only if paid pages ever exist
 ─────────────────────────────────────────────────────────────────────
 ORIGIN   the server (Debian,      Caddy → gate (SBCL, SQLite)
          Hetzner Cloud)                  → Listmonk
          set up by infra/,               → fan-out (feed → list, X, Mastodon, Bluesky)
          a tailnet member
 ─────────────────────────────────────────────────────────────────────
 OUTSIDE  Paddle / Lemon Squeezy   checkout, tax, payouts → webhook to the gate
          Amazon SES               Listmonk's sender; the gate's transactional mail
          the tailnet              vikix machines, vikix agent --on web, backups
```

**The repo**, `~/src/living-series`, which `DESIGN-publish.md` already assumes:

```
shared/   house style: CSS, fonts (IBM Plex, Amiri), templates, fix-tables.py, epub.css
hub/      posts/ (Markdown or Org with front matter), pages/, books/<book>/ (publish.yml, chapters)
codes/    one folder per interactive site, as now (single-file HTML)
studio/   the music app made deployable; its landing page
gate/     the Lisp service, its tests, its runbook
infra/    the server's setup script (idempotent, cloud-init or shell), Caddyfile,
          systemd units, Listmonk config, the fan-out script, Cloudflare settings as a file
```

**The build.** `vikix publish` is the one command, extended: `vikix publish hub` builds the pages and the Atom feed and pushes to Pages; `vikix publish book NAME` builds EPUB and PDF, runs epubcheck and the spelling (shipped), and uploads the files to the gate's store as a new version; `vikix publish post NAME` builds, pushes, and the fan-out sees the new feed entry within minutes; `vikix publish --draft` puts anything on a private URL for one reader first. Rich pages are a question of the templates, not of architecture: a post may carry its own script and the house style gives it the components the interactive sites already have (live demos, figures, the terminal transcript). `DESIGN-publish.md`'s "not a storefront" non-goal stands: the pipeline makes the files; the gate sells them.

**The four domains.**

- `thelivingseries.com`: the hub. Home, the writing (the Substack's successor), a landing page per subject (Esperanto, computing, maths, physics, music), the books' pages, `/account` (what you own, download again, manage the subscription), `/login`. The feed is here.
- `theliving.codes`: the interactive programming sites, one path each (`/lisp`, `/lambda`, `/haskell`…), free, as now. Could be a path on the hub; a domain of its own only if it should feel like its own place (open question).
- `theliving.studio`: the music app and its brand. Free tier without login; paid tier through the gate; its own landing page and list.
- `vikix.dev` unchanged.

Cloudflare in front of all three: DNS, certificates, cache, Pages for the static files. The server takes HTTPS from Cloudflare's address ranges only, and everything from the tailnet; nothing else is open.

**The gate.** One SBCL image (`save-lisp-and-die`, a systemd unit), Hunchentoot behind Caddy, one SQLite file, five jobs:

1. *Webhook from the merchant:* sale, refund, subscription renewed or lapsed. Verify the signature (timing-safe), record it: `purchases(email, product, kind, status, at, merchant_id)`. Idempotent on `merchant_id`, since merchants replay.
2. *Login by magic link:* `/login` takes an email, sends a link through SES directly (not Listmonk; transactional and marketing never share a queue), the link sets a signed cookie for `.thelivingseries.com`. The studio is another domain, so it logs in by redirect through the hub (one cookie, two domains; proposed) or by a short-lived token the studio exchanges.
3. *Entitlement:* `/me` answers "who is this and what do they own", JSON; the account page, the downloads and the music app's paid tier ask it.
4. *Delivery:* `/download/BOOK/VERSION` streams the EPUB or PDF stamped with the buyer's email and a hash (a line in the colophon; the EPUB's zip rewritten, the PDF through `qpdf` or a Typst pass). DRM-free. Every past version stays downloadable: buy once, get every revision.
5. *Lists:* on purchase, add the email to the right Listmonk list over its API; on refund, remove.

**Conditions on Lisp** (the pros and cons were weighed with Vid, 2026-10-04; the decision is Lisp): the gate stays under a thousand lines on purpose (bigger means the merchant or Listmonk should be doing the job); it is a library with a test suite run without a server, not an image that is poked; the runbook (restart, restore the SQLite file, replay sales from the merchant's API, rotate the cookie key) is written on day one. Swank on the tailnet address only, through the door module (`DESIGN-security.md`, item 3). The boring parts are where the risk is, and are done plainly: CSRF on the two forms, signed cookies (Ironclad HMAC), timing-safe compares, SQL with parameters only.

**Why not Rails or Django:** they solve an application where most pages differ per visitor and come from a database, with a team. Here the pages are static, the data is three tables that barely change, there is one permission ("owns X") and one person. The moment the music app grows user data (saved songs, progress, sharing) is the moment to notice the ground has shifted, and decide again rather than bolt onto the gate.

**Where the paid check runs.** For the music app's paid tier the browser asks `/me` and the paid features need the gate's data anyway; for books the files are only on the gate. Paid *pages*, if they ever exist, can't be hidden by a static site (the HTML is readable), so they render on the gate or a Cloudflare Worker checks the cookie before serving the file. Decided when there is a paid page.

**Email.** Listmonk on the server, SES as the sender (over SMTP on port 587, which the host must leave open: see "The server"), three lists (readers; buyers, by product; studio). Two writers: the fan-out (a new post is a campaign to the readers, from the post's own HTML, so the email and the page are the same words) and the gate (buyers). Day one: the Substack CSV imported, double opt-in on, unsubscribe in every footer, SPF, DKIM and DMARC for the sending domain at Cloudflare before the first send. A second transactional sender (Postmark, say) configured and the gate falling back to it, because SES suspends new senders over a bad import, and a login must never wait on marketing's reputation.

**The fan-out.** A script on a timer on the server: read the feed, compare with what it has seen, and for each new entry make the Listmonk campaign and post to X, Mastodon and Bluesky (a title, a line, the link). Facebook by hand (the Pages API needs Meta's app review; personal profiles can't be posted to), or Buffer. What went where is written to a table the gate's admin page shows and sent to the laptop's record store, so "did Tuesday's post reach the list?" has an answer. X's free API tier is write-only with low limits: one post per article, nothing richer.

**The server.** One small Hetzner Cloud server (2 GB of memory is enough; Falkenstein or Nuremberg, beside SES's Frankfurt region), Debian stable (not Void: nobody lives on this box, and every Caddy, Listmonk and SES guide assumes Debian; Caddy, Listmonk and Tailscale publish apt repositories, so the versions that matter are current). Set up by `infra/`, idempotent like a Vikix stage: a fresh server from nothing in ten minutes is the test. Its address is a Primary IP of its own, kept when a server is deleted, so the rebuild needs no change at Cloudflare. Hetzner's Cloud Firewall, set in its panel, is the outer wall (HTTPS from Cloudflare's ranges; SSH only until the tailnet is up, then closed), so a mistake on the box can't lock Vid out, and the panel's console is the way in when SSH isn't. `unattended-upgrades` on. Tailscale makes it a member of the tailnet (`DESIGN-machines.md`): `vikix machines` lists it, `vikix agent --on web` is `ssh` over the tailnet, `vikix doctor --on web` runs a small script there (certificate age, disk, last webhook, last backup, Listmonk alive) and shows the lines. Backups two ways: restic on the server nightly to an S3-compatible bucket with another company than the server's (Cloudflare R2 proposed, since the domains are there already; its own encrypted repository), and the laptop's `vikix backup` pulling the SQLite file and the book files over the tailnet. The merchant holds the canonical sales record besides.

*Why Hetzner (2026-10-04).* DigitalOcean was the first choice, and blocks outgoing mail on ports 25, 465 and 587 on every droplet, a Reserved IP included; Listmonk speaks SMTP to SES, so the list couldn't send. Hetzner blocks 25 and 465 on new accounts and leaves 587 open, which is the port SES is used on. Vultr does the same and is the fallback; Linode blocks all three until a support ticket lifts it. One lesson from the old droplet stays whatever the host: the laptop's SSH key goes in when the server is made, and SSH is closed to the internet once the tailnet works, so there are no failed logins to be banned for.

## Goals

1. **One home for the whole body of work**, with the writing where Substack was and a page per subject, in the house style, with live demos and animation where a piece wants them.
2. **A post is one command away from every reader.** `vikix publish post NAME`: the page, the email, the feeds, within minutes, without a hand on any dashboard.
3. **A book bought once is owned for good.** Every revision downloadable, DRM-free, stamped.
4. **The list is yours**, exportable, double opt-in, and never shares a queue with a login.
5. **The server may die on a Sunday and nobody notices until Monday.** Pages, free app and checkout all survive it.
6. **Nothing is spent on what the merchant already does**: tax, invoices, card handling, refunds.

## Non-goals (this version)

- **Not a framework application.** No Rails, Django, or their Lisp equivalents; see above.
- **Not paid pages or a paid newsletter yet.** Books and the app are the products; a paid tier of the writing is a product and a list away when wanted.
- **Not comments.** Isso or Remark42 on the server later if wanted; the first version has none.
- **Not Facebook automation.** By hand, or Buffer.
- **Not Substack's network.** Recommendations and the app feed are lost and accepted; what readers come from them is checked before Substack is retired, and a teaser cross-posted there for a while.
- **Not raw Stripe.** Later, if volume makes its smaller cut worth taking the tax on.
- **Not a Vikix `server` bundle.** The server is Debian and plain software; Vikix reaches it, it doesn't run it.

## User stories

- As a reader, I want a new post in my inbox the morning it's published, with the same words as the page, and an unsubscribe link that works.
- As a buyer, I want to pay once, get the EPUB and the PDF, and come back a year later for the revised edition without asking.
- As a studio subscriber, I want to try the app without an account and pay only when I want the full thing.
- As Vid, I want `vikix publish post NAME` to be the whole of publishing, and `vikix publish --draft` to show one friend first.
- As Vid, I want `vikix doctor --on web` to tell me the certificate is fine, last night's backup ran, and yesterday's sale arrived.
- As the Ajman company, I want every sale taxed and invoiced by someone whose job it is.
- As the agent, I want the fan-out's table and the gate's `/me` as data, so "did it go out?" and "who owns what?" are answered from records.

## Requirements

### Must have (P0)

1. **The hub, static**: the repo laid out as above, the house style, `vikix publish hub` to Pages, the writing imported from Substack (its export is HTML; a one-time conversion), the Atom feed, a landing page per subject.
   - [ ] The whole hub rebuilds and deploys from a clean checkout in one command
2. **Listmonk and the list**: on the server, SES, the Substack CSV imported, double opt-in, the fan-out making a campaign from each new feed entry.
   - [ ] A test post reaches a test subscriber with the page's own words and a working unsubscribe
3. **The gate, Phase 1**: webhook, magic link, `/me`, stamped download of every version; its tests run without a server; its runbook.
   - [ ] A replayed webhook records one purchase, not two
   - [ ] A stamped EPUB passes epubcheck and names the buyer in the colophon
4. **One book on sale** through the merchant, paid out to the Ajman company.
5. **The server from `infra/`**: Debian, Caddy, Listmonk, the gate, Tailscale, firewall (Cloudflare ranges and the tailnet only), `unattended-upgrades`, restic to its bucket; `vikix machines` lists it.
   - [ ] A new server from the script serves the gate within ten minutes

### Should have (P1)

6. The studio: the music app deployed with a free tier; the paid tier through `/me`; login by redirect through the hub.
7. The fan-out to X, Mastodon and Bluesky; the "what went where" table, and its line in the record store.
8. `vikix publish --draft` (a private URL, one reader), `vikix doctor --on web`, `vikix agent --on web`.
9. The second transactional sender and the gate's fallback to it.
10. Substack retired: the teaser cross-posts stop, the publication points here.

### Later (P2)

11. Comments (Isso or Remark42, self-hosted).
12. Paid pages or a paid tier of the writing, and with them the Worker or gate-rendered pages.
13. Stripe behind the merchant, if the cut ever justifies owning the tax.
14. The music app's user data, if it comes, and the decision it brings.

## What runs where (to check before Phase 1)

| Piece | Where | Note |
|---|---|---|
| Caddy, Listmonk, Tailscale | the server, from each project's apt repository | current versions; Debian's own are old or absent |
| SBCL, Quicklisp | the server; Debian's `sbcl` or a pinned binary with its checksum, as `30-lisp` does | the gate's image is built on the server or copied from the laptop |
| `qpdf` | the server, Debian | PDF stamping |
| restic | the server, Debian; the laptop has it already | two backups, two directions |
| Paddle or Lemon Squeezy | outside | payout to a UAE bank account, and the Ajman licence accepted: both to confirm |
| Amazon SES | outside | out of the sandbox needs a request; do it in Phase 0. Reached on port 587: open from the Hetzner server, tested 2026-10-04 |
| Hetzner Cloud | outside | the server, its firewall and its Primary IP. The account and the server exist (2026-10-04: Debian 13, key login only; its address is kept out of this public repo) |
| Cloudflare R2 | outside | the server's nightly restic repository (proposed) |
| Cloudflare Pages, DNS, a Worker if ever | outside | the domains are already there |

## Open questions

Blocking:
- **The merchant.** (Vid, the Ajman company's accountant) Paddle or Lemon Squeezy; whether either pays to a UAE account and accepts the licence type; UAE VAT on the company's own sales is the accountant's.
- **How many readers come from Substack's network rather than from Vid.** (Vid, from Substack's stats) Decides how long the teaser cross-posting runs before Substack is retired.
- **The codes: a domain or a path.** (Vid) Proposed: keep the domain, since it was bought to feel like its own place; it costs one more Pages project.

Non-blocking:
- Login on the studio: redirect through the hub (proposed) or a token exchange.
- Whether a paid tier of the writing ever exists; it decides whether a Worker is ever needed.
- The stamp's wording in the colophon, and whether the hash also goes into the EPUB's metadata.
- Which Lisp libraries: Hunchentoot and Ironclad are settled; cl-sqlite or sqlite through CFFI; Dexador for the merchant's and Listmonk's APIs; Jzon for JSON. Settled in the gate's first spike.

## Phasing

**Phase 0, a week of evenings:** the repo, the house style over the hub, `vikix publish hub`, Pages, the feed, the Substack writing imported; Listmonk on a server from `infra/` with the SES request in; the fan-out to Listmonk only. Substack stays up with a teaser pointing here.

**Phase 1, two or three weeks, the book most of it:** the merchant account, the gate (webhook, magic link, `/me`, stamped download), one book on sale. P0 done.

**Phase 2:** the studio, then the rest of P1; Substack retired when the list has moved and a month of sends has gone cleanly.

**Phase 3:** P2 as wanted.

## Risks

- **Deliverability.** A fresh sender with an imported list is how SES suspensions happen. Warm up: the first campaigns to the most engaged readers, the records set before any send, the second sender ready.
- **The gate is yours alone.** If it breaks, the fix is Vid's or the agent's, in Lisp. Mitigated by its size, its tests, its runbook, and by every other part surviving its absence.
- **Two domains, one login.** Cookies don't cross domains; the redirect is simple but every "why am I logged out?" will trace to it. Decide once, document it in the account page's help.
- **The merchant changes terms or rejects the licence.** Both are known to happen with UAE companies. Keep the gate's merchant adapter one file, so the other merchant, or Stripe, is a swap.
- **Rich pages drift from the house style.** Each animated or scripted post is a page someone has to keep working. The components live in `shared/` and a post uses them; a one-off is a one-off and says so in its front matter.
- **Scope.** "The site is an app" is how a publishing site becomes a product with a backend. The non-goals and the thousand-line gate are the fence.
