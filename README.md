# Golfex

Golf club booking automation tool. Connect to MiClub-powered golf club websites, browse events, view tee times, and book slots — immediately or on a schedule.

Multi-user, multi-club. Each user adds their own golf clubs with their MiClub credentials.

## Getting Started

**Prerequisites:** Elixir 1.15+, PostgreSQL

```bash
mix setup          # install deps, create DB, run migrations
mix golfex.create_user you@email.com yourpassword   # create an admin user
mix phx.server     # start at localhost:4000
```

No public registration — users are created via the mix task.

## Architecture

Phoenix 1.8 monolith with five contexts:

```
Golfex.Accounts    Auth (phx.gen.auth, scoped)
Golfex.Clubs       Club + UserClub with encrypted credentials
Golfex.MiClub      HTTP client for MiClub golf club APIs
Golfex.Events      Cached events with 12-hour TTL
Golfex.Bookings    Scheduled bookings via Oban
```

All pages are LiveView. Styling uses Sugarcube/CUBE CSS (not Tailwind).

### How It Works

1. Admin creates a user account
2. User logs in, adds a golf club (name, URL, MiClub credentials)
3. MiClub credentials are encrypted at rest with Cloak.Ecto (AES-GCM)
4. User browses events — fetched from MiClub on demand, cached for 12 hours
5. User views event detail — booking sections/groups fetched live from MiClub
6. User can "Book Now" (immediate) or "Schedule Booking" (Oban job at a future time)
7. Scheduled bookings execute automatically via the BookingWorker

### MiClub Integration

MiClub is the platform many Australian golf clubs use for their websites. The integration:

- Authenticates via form POST to `/security/login.msp` (cookie-based session)
- Fetches events via JSON endpoint at `/spring/bookings/events/between/{from}/{to}/{limit}`
- Fetches event detail via XML endpoint at `/spring/bookings/events/{id}`
- Books via form POST to `/members/Ajax` with `doAction=makeBooking`
- Sessions are ephemeral — authenticate per action, no persistent sessions stored

The same client works across all MiClub-powered clubs (different base URLs, same API shape).

### Booking Modes

**Book Now:** Immediate HTTP call to MiClub. Success/failure shown in the UI.

**Schedule Booking:** Creates a `scheduled_booking` record and enqueues an Oban job for a future datetime. The worker authenticates with MiClub and executes the booking at the scheduled time. Retries up to 3 times on failure.

Status state machine: `pending` → `running` → `completed` | `failed`. Users can cancel pending bookings.

The bookings queue has concurrency of 1 to avoid race conditions.

### Event Caching

Events are cached in PostgreSQL, not in-memory. Cache strategy:

- On-demand: fetched when a user views a club's events page
- If cached data < 12 hours old, serve from DB (no MiClub call)
- If stale or empty, fetch fresh from MiClub and upsert
- Manual "Refresh" button bypasses the TTL
- Booking invalidates the cached event (availability changes)

Booking group/section detail is never cached — always fetched live.

## Data Model

All tables use UUID primary keys.

- **users** — email/password auth (phx.gen.auth)
- **clubs** — name + base_url for each golf club
- **user_clubs** — joins users to clubs, stores encrypted MiClub credentials (member_id, username, password)
- **events** — cached event data from MiClub (title, date, availability, status flags, etc.)
- **scheduled_bookings** — booking jobs with status tracking and Oban job linkage
- **oban_jobs** — Oban's internal job table

## Routes

| Path | Description |
|------|-------------|
| `/` | Dashboard — user's clubs |
| `/clubs` | Manage clubs — add/remove |
| `/clubs/new` | Add a new club |
| `/clubs/:club_id/events` | Events list for a club |
| `/clubs/:club_id/events/:event_id` | Event detail with booking groups |
| `/clubs/:club_id/events/:event_id/groups/:group_id` | Booking group — book or schedule |
| `/bookings` | Scheduled bookings — view/cancel |
| `/users/log-in` | Login |
| `/users/settings` | Account settings |

## Tech Stack

| Concern | Choice |
|---------|--------|
| Framework | Phoenix 1.8 + LiveView |
| Database | PostgreSQL + Ecto |
| Auth | phx.gen.auth (scoped, email/password) |
| HTTP Client | Req |
| XML Parsing | SweetXml |
| Job Queue | Oban |
| Credential Encryption | Cloak.Ecto (AES-GCM) |
| CSS | Sugarcube + CUBE CSS |

## Configuration

### Environment Variables (Production)

| Variable | Description |
|----------|-------------|
| `DATABASE_URL` | PostgreSQL connection string |
| `SECRET_KEY_BASE` | Phoenix secret (`mix phx.gen.secret`) |
| `CLOAK_KEY` | Base64-encoded 32-byte key for credential encryption |
| `PHX_HOST` | Production hostname |
| `PORT` | HTTP port (default 4000) |

Generate a Cloak key:

```elixir
:crypto.strong_rand_bytes(32) |> Base.encode64()
```

### Dev/Test

Dev and test environments auto-generate a random Cloak key on startup — no configuration needed.

PostgreSQL is expected on `localhost:54321` (dev) / `localhost:54321` (test) with user `postgres`/`postgres`.

## Testing

```bash
mix test           # 146 tests
mix precommit      # compile warnings check + format + tests
```

- **MiClub HTTP:** Mocked via `Req.Test.expect` — no real HTTP calls in tests
- **Oban jobs:** Inline execution via `Oban.Testing`
- **LiveViews:** `Phoenix.LiveViewTest`
- **Contexts:** Standard Ecto sandbox

Test config sets `config :golfex, :miclub_req_options, plug: {Req.Test, Golfex.MiClub.Client}` to route all MiClub HTTP through the test plug.

## Deployment

Target: Docker release on a Coolify VPS with PostgreSQL as a separate service.

Standard Phoenix multi-stage Dockerfile: build with `mix release`, run the compiled release. The CSS is bundled via esbuild alongside JS.

## Future Work

- **Auto-snipe bookings:** Watch for a slot to become available and book it instantly (polling MiClub until the booking opens)
- **Booking notifications:** Email or push notification when a scheduled booking succeeds/fails
- **Club discovery:** Pre-populate a list of known MiClub clubs so users can pick from a list instead of entering URLs manually
- **Deployment:** Create the Dockerfile and Coolify configuration
- **Admin interface:** UI for managing users (currently mix task only)
