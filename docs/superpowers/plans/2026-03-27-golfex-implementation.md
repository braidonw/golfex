# Golfex Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rewrite the Rust axum-booker golf booking app as a Phoenix LiveView application with multi-user, multi-club support.

**Architecture:** Phoenix monolith with contexts (Accounts, Clubs, MiClub, Events, Bookings). LiveView for all pages. Oban for scheduled bookings. Cloak.Ecto for credential encryption. Sugarcube/CUBE CSS for styling.

**Tech Stack:** Phoenix 1.8+, LiveView, PostgreSQL, Ecto, Oban, Cloak.Ecto, Req, SweetXml, Sugarcube/CUBE CSS

**Spec:** `docs/superpowers/specs/2026-03-27-golfex-rewrite-design.md`

---

## File Structure

### New files to create

**Dependencies & Infrastructure:**
- `lib/golfex/vault.ex` — Cloak vault for credential encryption
- `priv/repo/migrations/*_add_oban_jobs_table.exs` — Oban migration

**Clubs context:**
- `lib/golfex/clubs.ex` — Clubs context module
- `lib/golfex/clubs/club.ex` — Club schema
- `lib/golfex/clubs/user_club.ex` — UserClub schema with encrypted fields
- `lib/golfex/clubs/encrypted_binary.ex` — Cloak encrypted type
- `priv/repo/migrations/*_create_clubs.exs` — clubs table
- `priv/repo/migrations/*_create_user_clubs.exs` — user_clubs table
- `test/golfex/clubs_test.exs` — Clubs context tests
- `test/support/fixtures/clubs_fixtures.ex` — Club test fixtures

**MiClub client:**
- `lib/golfex/miclub.ex` — MiClub public API facade
- `lib/golfex/miclub/client.ex` — HTTP client with cookie/session management
- `lib/golfex/miclub/parser.ex` — JSON/XML response parsing
- `lib/golfex/miclub/booking_event.ex` — BookingEvent struct
- `lib/golfex/miclub/booking_section.ex` — BookingSection struct
- `lib/golfex/miclub/booking_group.ex` — BookingGroup struct
- `lib/golfex/miclub/booking_entry.ex` — BookingEntry struct
- `test/golfex/miclub/parser_test.exs` — Parser unit tests
- `test/golfex/miclub_test.exs` — MiClub client tests

**Events context:**
- `lib/golfex/events.ex` — Events context module
- `lib/golfex/events/event.ex` — Event schema
- `priv/repo/migrations/*_create_events.exs` — events table
- `test/golfex/events_test.exs` — Events context tests
- `test/support/fixtures/events_fixtures.ex` — Event test fixtures

**Bookings context:**
- `lib/golfex/bookings.ex` — Bookings context module
- `lib/golfex/bookings/scheduled_booking.ex` — ScheduledBooking schema
- `lib/golfex/bookings/booking_worker.ex` — Oban worker
- `priv/repo/migrations/*_create_scheduled_bookings.exs` — scheduled_bookings table
- `test/golfex/bookings_test.exs` — Bookings context tests
- `test/golfex/bookings/booking_worker_test.exs` — Worker unit tests

**LiveViews:**
- `lib/golfex_web/live/dashboard_live.ex` — Dashboard page
- `lib/golfex_web/live/club_live/index.ex` — Clubs list/manage
- `lib/golfex_web/live/club_live/form_component.ex` — Club add/edit form
- `lib/golfex_web/live/event_live/index.ex` — Events list for a club
- `lib/golfex_web/live/event_live/show.ex` — Event detail
- `lib/golfex_web/live/booking_group_live/show.ex` — Booking group detail + book/schedule
- `lib/golfex_web/live/booking_live/index.ex` — My scheduled bookings
- `test/golfex_web/live/dashboard_live_test.exs`
- `test/golfex_web/live/club_live_test.exs`
- `test/golfex_web/live/event_live_test.exs`
- `test/golfex_web/live/booking_group_live_test.exs`
- `test/golfex_web/live/booking_live_test.exs`

**Admin seed task:**
- `lib/mix/tasks/golfex.create_user.ex` — Mix task to create admin users

**Styling:**
- `assets/css/app.css` — Main CSS entry point
- Move `assets/js/styles/` → `assets/css/styles/`
- Move `assets/js/components/ui/` → `assets/css/components/ui/`
- Move `assets/js/design-tokens/` → `assets/css/design-tokens/`

### Files to modify

- `mix.exs` — Add deps (oban, cloak_ecto, sweet_xml)
- `lib/golfex/application.ex` — Add Vault, Oban to supervision tree
- `config/config.exs` — Add Oban config, CSS esbuild entry
- `config/dev.exs` — Add CSS watcher
- `config/runtime.exs` — Add CLOAK_KEY
- `config/test.exs` — Add Oban testing config, MiClub Req test plug
- `lib/golfex_web/router.ex` — Add new LiveView routes, remove /users/register
- `lib/golfex_web/components/layouts/root.html.heex` — Update nav layout
- `lib/golfex_web/components/layouts/app.html.heex` — Update app layout

---

## Task 1: Add Dependencies and Configure Infrastructure

**Files:**
- Modify: `mix.exs`
- Modify: `config/config.exs`
- Modify: `config/dev.exs`
- Modify: `config/runtime.exs`
- Modify: `config/test.exs`
- Create: `lib/golfex/vault.ex`
- Modify: `lib/golfex/application.ex`
- Create: Oban migration

- [ ] **Step 1: Add dependencies to mix.exs**

In the `deps` function in `mix.exs`, add:

```elixir
{:oban, "~> 2.18"},
{:cloak_ecto, "~> 1.3"},
{:sweet_xml, "~> 0.7"},
```

Note: `req` is already a dependency.

- [ ] **Step 2: Install dependencies**

Run: `mix deps.get`
Expected: All dependencies resolve and download successfully.

- [ ] **Step 3: Create Cloak Vault module**

Create `lib/golfex/vault.ex`:

```elixir
defmodule Golfex.Vault do
  use Cloak.Vault, otp_app: :golfex
end
```

- [ ] **Step 4: Add Oban config to config.exs**

Add to `config/config.exs` before the `import_config` line:

```elixir
config :golfex, Oban,
  repo: Golfex.Repo,
  queues: [bookings: 1]
```

- [ ] **Step 5: Add Cloak config to runtime.exs**

Add to `config/runtime.exs` inside the `if config_env() == :prod do` block:

```elixir
cloak_key =
  System.get_env("CLOAK_KEY") ||
    raise "environment variable CLOAK_KEY is missing"

config :golfex, Golfex.Vault,
  ciphers: [
    default: {Cloak.Ciphers.AES.GCM, tag: "AES.GCM.V1", key: Base.decode64!(cloak_key)}
  ]
```

At the top of `runtime.exs` (outside the prod block), add a dev/test fallback:
```elixir
if config_env() in [:dev, :test] do
  config :golfex, Golfex.Vault,
    ciphers: [
      default:
        {Cloak.Ciphers.AES.GCM,
         tag: "AES.GCM.V1", key: :crypto.strong_rand_bytes(32)}
    ]
end
```

- [ ] **Step 6: Add Oban testing config and MiClub test plug to test.exs**

Add to `config/test.exs`:

```elixir
config :golfex, Oban, testing: :inline

# Use Req.Test plug for MiClub HTTP client in tests
config :golfex, :miclub_req_options, plug: {Req.Test, Golfex.MiClub.Client}
```

- [ ] **Step 7: Replace esbuild config in config.exs to include CSS entry**

In `config/config.exs`, **replace** the existing `config :esbuild` block entirely with:

```elixir
config :esbuild,
  version: "0.25.4",
  golfex: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ],
  golfex_css: [
    args:
      ~w(css/app.css --bundle --outdir=../priv/static/assets/css),
    cd: Path.expand("../assets", __DIR__)
  ]
```

This replaces the existing block (not adds a second one — two `config :esbuild` calls would override each other).

- [ ] **Step 8: Update mix.exs aliases to include CSS build**

In `mix.exs`, update the `assets.build` and `assets.deploy` aliases to also run the CSS esbuild profile:

```elixir
"assets.build": ["esbuild golfex", "esbuild golfex_css"],
"assets.deploy": ["esbuild golfex --minify", "esbuild golfex_css --minify", "phx.digest"],
```

- [ ] **Step 9: Add CSS watcher to dev.exs**

In `config/dev.exs`, add the CSS esbuild watcher alongside the existing JS one. Find the `watchers` list and add:

```elixir
esbuild_css: {Esbuild, :install_and_run, [:golfex_css, ~w(--watch)]}
```

- [ ] **Step 10: Add Vault and Oban to supervision tree**

In `lib/golfex/application.ex`, add to the `children` list, before the Endpoint:

```elixir
Golfex.Vault,
{Oban, Application.fetch_env!(:golfex, Oban)},
```

- [ ] **Step 11: Generate Oban migration**

Run: `mix ecto.gen.migration add_oban_jobs_table`

Edit the generated migration:

```elixir
defmodule Golfex.Repo.Migrations.AddObanJobsTable do
  use Ecto.Migration

  def up, do: Oban.Migration.up()
  def down, do: Oban.Migration.down(version: 1)
end
```

- [ ] **Step 12: Run migrations and compilation**

Run: `mix ecto.migrate && mix compile`
Expected: No errors. Warnings about unused modules are fine.

- [ ] **Step 13: Commit**

```bash
git add mix.exs mix.lock lib/golfex/vault.ex lib/golfex/application.ex config/ priv/repo/migrations/
git commit -m "feat: add Oban, Cloak.Ecto, SweetXml deps and configure infrastructure"
```

---

## Task 2: Move Sugarcube Assets and Set Up CSS Pipeline

**Files:**
- Move: `assets/js/styles/` → `assets/css/styles/`
- Move: `assets/js/components/ui/` → `assets/css/components/ui/`
- Move: `assets/js/design-tokens/` → `assets/css/design-tokens/`
- Create: `assets/css/app.css`
- Modify: `lib/golfex_web/components/layouts/root.html.heex`

- [ ] **Step 1: Create assets/css directory and move sugarcube files**

```bash
mkdir -p assets/css
mv assets/js/styles assets/css/styles
mv assets/js/components assets/css/components
mv assets/js/design-tokens assets/css/design-tokens
```

- [ ] **Step 2: Create the main CSS entry point**

Create `assets/css/app.css`:

```css
/* Sugarcube Global Styles */
@import "./styles/global/global.css";

/* Compositions */
@import "./styles/compositions/flow.css";
@import "./styles/compositions/cluster.css";
@import "./styles/compositions/grid.css";
@import "./styles/compositions/repel.css";
@import "./styles/compositions/sidebar.css";
@import "./styles/compositions/switcher.css";
@import "./styles/compositions/wrapper.css";

/* Blocks */
@import "./styles/blocks/prose.css";

/* Utilities */
@import "./styles/utilities/region.css";
@import "./styles/utilities/visually-hidden.css";

/* UI Components */
@import "./components/ui/accordion/accordion.css";
@import "./components/ui/alert/alert.css";
@import "./components/ui/avatar/avatar.css";
@import "./components/ui/badge/badge.css";
@import "./components/ui/button/button.css";
@import "./components/ui/card/card.css";
@import "./components/ui/checkbox/checkbox.css";
@import "./components/ui/dialog/dialog.css";
@import "./components/ui/input/input.css";
@import "./components/ui/radio-group/radio-group.css";
@import "./components/ui/select/select.css";
@import "./components/ui/switch/switch.css";
```

- [ ] **Step 3: Update root layout to include CSS**

In `lib/golfex_web/components/layouts/root.html.heex`, add a `<link>` tag for the CSS bundle in the `<head>`:

```html
<link phx-track-static rel="stylesheet" href={~p"/assets/css/app.css"} />
```

Remove any existing Tailwind/default CSS link if present.

- [ ] **Step 4: Run the CSS build to verify**

Run: `mix esbuild golfex_css`
Expected: `priv/static/assets/css/app.css` is generated with all sugarcube styles bundled.

- [ ] **Step 5: Commit**

```bash
git add assets/css/ lib/golfex_web/components/layouts/root.html.heex config/
git rm -r --cached assets/js/styles assets/js/components assets/js/design-tokens 2>/dev/null || true
git add -A assets/
git commit -m "feat: move sugarcube assets to assets/css and set up CSS build pipeline"
```

---

## Task 3: Clubs Context — Schemas and Migrations

**Files:**
- Create: `lib/golfex/clubs/club.ex`
- Create: `lib/golfex/clubs/user_club.ex`
- Create: `lib/golfex/clubs/encrypted_binary.ex`
- Create: `lib/golfex/clubs.ex`
- Create: `priv/repo/migrations/*_create_clubs.exs`
- Create: `priv/repo/migrations/*_create_user_clubs.exs`
- Create: `test/support/fixtures/clubs_fixtures.ex`
- Create: `test/golfex/clubs_test.exs`

- [ ] **Step 1: Write tests for Clubs context**

Create `test/golfex/clubs_test.exs`:

```elixir
defmodule Golfex.ClubsTest do
  use Golfex.DataCase, async: true

  alias Golfex.Clubs
  alias Golfex.Clubs.{Club, UserClub}

  import Golfex.AccountsFixtures
  import Golfex.ClubsFixtures

  describe "clubs" do
    test "create_club/1 with valid data creates a club" do
      attrs = %{name: "The Ridge Golf Club", base_url: "https://theridgegolf.com.au"}
      assert {:ok, %Club{} = club} = Clubs.create_club(attrs)
      assert club.name == "The Ridge Golf Club"
      assert club.base_url == "https://theridgegolf.com.au"
    end

    test "create_club/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Clubs.create_club(%{name: nil})
    end

    test "list_clubs/0 returns all clubs" do
      club = club_fixture()
      assert Clubs.list_clubs() == [club]
    end

    test "get_club!/1 returns the club" do
      club = club_fixture()
      assert Clubs.get_club!(club.id) == club
    end
  end

  describe "user_clubs" do
    test "add_club_for_user/3 associates a user with a club and encrypts credentials" do
      scope = user_scope_fixture()
      club = club_fixture()

      attrs = %{
        member_id: "12345",
        username: "testuser",
        password: "testpass"
      }

      assert {:ok, %UserClub{} = user_club} = Clubs.add_club_for_user(scope, club, attrs)
      assert user_club.club_id == club.id
      assert user_club.member_id == "12345"
      assert user_club.username == "testuser"
      assert user_club.password == "testpass"
    end

    test "add_club_for_user/3 enforces unique user+club" do
      scope = user_scope_fixture()
      club = club_fixture()
      attrs = %{member_id: "12345", username: "user", password: "pass"}

      assert {:ok, _} = Clubs.add_club_for_user(scope, club, attrs)
      assert {:error, %Ecto.Changeset{}} = Clubs.add_club_for_user(scope, club, attrs)
    end

    test "list_clubs_for_user/1 returns only that user's clubs" do
      scope = user_scope_fixture()
      club = club_fixture()
      _other_club = club_fixture(%{name: "Other Club", base_url: "https://other.com"})

      attrs = %{member_id: "12345", username: "user", password: "pass"}
      {:ok, _} = Clubs.add_club_for_user(scope, club, attrs)

      clubs = Clubs.list_clubs_for_user(scope)
      assert length(clubs) == 1
      assert hd(clubs).club.id == club.id
    end

    test "get_user_club!/2 returns the user_club with club preloaded" do
      scope = user_scope_fixture()
      club = club_fixture()
      attrs = %{member_id: "12345", username: "user", password: "pass"}
      {:ok, user_club} = Clubs.add_club_for_user(scope, club, attrs)

      fetched = Clubs.get_user_club!(scope, user_club.id)
      assert fetched.id == user_club.id
      assert fetched.club.id == club.id
    end

    test "remove_club_for_user/2 deletes the association" do
      scope = user_scope_fixture()
      club = club_fixture()
      attrs = %{member_id: "12345", username: "user", password: "pass"}
      {:ok, user_club} = Clubs.add_club_for_user(scope, club, attrs)

      assert {:ok, _} = Clubs.remove_club_for_user(scope, user_club.id)
      assert Clubs.list_clubs_for_user(scope) == []
    end

    test "update_user_club/2 updates credentials" do
      scope = user_scope_fixture()
      club = club_fixture()
      attrs = %{member_id: "12345", username: "user", password: "pass"}
      {:ok, user_club} = Clubs.add_club_for_user(scope, club, attrs)

      assert {:ok, updated} = Clubs.update_user_club(user_club, %{username: "newuser"})
      assert updated.username == "newuser"
    end
  end

  defp user_scope_fixture do
    user = user_fixture()
    %Golfex.Accounts.Scope{user: user}
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/golfex/clubs_test.exs`
Expected: Compilation errors — modules don't exist yet.

- [ ] **Step 3: Create the Cloak encrypted binary type**

Create `lib/golfex/clubs/encrypted_binary.ex`:

```elixir
defmodule Golfex.Clubs.EncryptedBinary do
  use Cloak.Ecto.Binary, vault: Golfex.Vault
end
```

- [ ] **Step 4: Create the Club schema**

Create `lib/golfex/clubs/club.ex`:

```elixir
defmodule Golfex.Clubs.Club do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "clubs" do
    field :name, :string
    field :base_url, :string

    timestamps(type: :utc_datetime)
  end

  def changeset(club, attrs) do
    club
    |> cast(attrs, [:name, :base_url])
    |> validate_required([:name, :base_url])
    |> validate_format(:base_url, ~r/^https?:\/\//, message: "must start with http:// or https://")
  end
end
```

- [ ] **Step 5: Create the UserClub schema**

Create `lib/golfex/clubs/user_club.ex`:

```elixir
defmodule Golfex.Clubs.UserClub do
  use Ecto.Schema
  import Ecto.Changeset

  alias Golfex.Clubs.{Club, EncryptedBinary}
  alias Golfex.Accounts.User

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "user_clubs" do
    belongs_to :user, User
    belongs_to :club, Club

    field :member_id, EncryptedBinary
    field :username, EncryptedBinary
    field :password, EncryptedBinary

    timestamps(type: :utc_datetime)
  end

  def changeset(user_club, attrs) do
    user_club
    |> cast(attrs, [:member_id, :username, :password, :club_id, :user_id])
    |> validate_required([:member_id, :username, :password, :club_id, :user_id])
    |> unique_constraint([:user_id, :club_id])
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:club_id)
  end
end
```

- [ ] **Step 6: Create migrations**

Run: `mix ecto.gen.migration create_clubs`

Then edit the generated migration:

```elixir
defmodule Golfex.Repo.Migrations.CreateClubs do
  use Ecto.Migration

  def change do
    create table(:clubs, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :base_url, :string, null: false

      timestamps(type: :utc_datetime)
    end
  end
end
```

Run: `mix ecto.gen.migration create_user_clubs`

Then edit:

```elixir
defmodule Golfex.Repo.Migrations.CreateUserClubs do
  use Ecto.Migration

  def change do
    create table(:user_clubs, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :club_id, references(:clubs, type: :binary_id, on_delete: :delete_all), null: false
      add :member_id, :binary, null: false
      add :username, :binary, null: false
      add :password, :binary, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:user_clubs, [:user_id, :club_id])
    create index(:user_clubs, [:user_id])
    create index(:user_clubs, [:club_id])
  end
end
```

- [ ] **Step 7: Create the Clubs context module**

Create `lib/golfex/clubs.ex`:

```elixir
defmodule Golfex.Clubs do
  import Ecto.Query

  alias Golfex.Repo
  alias Golfex.Accounts.Scope
  alias Golfex.Clubs.{Club, UserClub}

  def list_clubs do
    Repo.all(Club)
  end

  def get_club!(id) do
    Repo.get!(Club, id)
  end

  def create_club(attrs) do
    %Club{}
    |> Club.changeset(attrs)
    |> Repo.insert()
  end

  def list_clubs_for_user(%Scope{user: user}) do
    UserClub
    |> where(user_id: ^user.id)
    |> preload(:club)
    |> Repo.all()
  end

  def get_user_club!(%Scope{user: user}, id) do
    UserClub
    |> where(user_id: ^user.id, id: ^id)
    |> preload(:club)
    |> Repo.one!()
  end

  def get_user_club_by_club_id!(%Scope{user: user}, club_id) do
    UserClub
    |> where(user_id: ^user.id, club_id: ^club_id)
    |> preload(:club)
    |> Repo.one!()
  end

  def get_user_club_by_id!(id) do
    UserClub
    |> preload(:club)
    |> Repo.get!(id)
  end

  def add_club_for_user(%Scope{user: user}, %Club{} = club, attrs) do
    %UserClub{}
    |> UserClub.changeset(Map.merge(attrs, %{user_id: user.id, club_id: club.id}))
    |> Repo.insert()
  end

  def update_user_club(%UserClub{} = user_club, attrs) do
    user_club
    |> UserClub.changeset(attrs)
    |> Repo.update()
  end

  def remove_club_for_user(%Scope{user: user}, user_club_id) do
    UserClub
    |> where(user_id: ^user.id, id: ^user_club_id)
    |> Repo.one!()
    |> Repo.delete()
  end

  def change_user_club(%UserClub{} = user_club, attrs \\ %{}) do
    UserClub.changeset(user_club, attrs)
  end
end
```

- [ ] **Step 8: Create test fixtures**

Create `test/support/fixtures/clubs_fixtures.ex`:

```elixir
defmodule Golfex.ClubsFixtures do
  alias Golfex.Clubs

  def club_fixture(attrs \\ %{}) do
    {:ok, club} =
      attrs
      |> Enum.into(%{
        name: "Test Golf Club #{System.unique_integer([:positive])}",
        base_url: "https://testgolf-#{System.unique_integer([:positive])}.com.au"
      })
      |> Clubs.create_club()

    club
  end

  def user_club_fixture(scope, club, attrs \\ %{}) do
    {:ok, user_club} =
      Clubs.add_club_for_user(
        scope,
        club,
        Enum.into(attrs, %{
          member_id: "12345",
          username: "testuser",
          password: "testpass"
        })
      )

    user_club
  end
end
```

- [ ] **Step 9: Run migrations and tests**

Run: `mix ecto.migrate && mix test test/golfex/clubs_test.exs`
Expected: All tests pass.

- [ ] **Step 10: Commit**

```bash
git add lib/golfex/clubs/ lib/golfex/clubs.ex priv/repo/migrations/ test/golfex/clubs_test.exs test/support/fixtures/clubs_fixtures.ex
git commit -m "feat: add Clubs context with Club and UserClub schemas"
```

---

## Task 4: MiClub Client — Structs, Parser, and HTTP Client

**Files:**
- Create: `lib/golfex/miclub.ex`
- Create: `lib/golfex/miclub/client.ex`
- Create: `lib/golfex/miclub/parser.ex`
- Create: `lib/golfex/miclub/booking_event.ex`
- Create: `lib/golfex/miclub/booking_section.ex`
- Create: `lib/golfex/miclub/booking_group.ex`
- Create: `lib/golfex/miclub/booking_entry.ex`
- Create: `test/golfex/miclub/parser_test.exs`
- Create: `test/golfex/miclub_test.exs`

- [ ] **Step 1: Create the MiClub structs**

Create `lib/golfex/miclub/booking_entry.ex`:

```elixir
defmodule Golfex.MiClub.BookingEntry do
  defstruct [
    :id,
    :kind,
    :index,
    :person_name,
    :membership_number,
    :gender,
    :handicap,
    :golf_link_no
  ]
end
```

Create `lib/golfex/miclub/booking_group.ex`:

```elixir
defmodule Golfex.MiClub.BookingGroup do
  defstruct [
    :id,
    :time,
    :status_code,
    :active,
    :require_handicap,
    :require_golf_link,
    :visitor_accepted,
    :member_accepted,
    :public_member_accepted,
    :nine_holes,
    :eighteen_holes,
    booking_entries: []
  ]

  def holes(%__MODULE__{nine_holes: true}), do: 9
  def holes(%__MODULE__{eighteen_holes: true}), do: 18
  def holes(_), do: nil
end
```

Create `lib/golfex/miclub/booking_section.ex`:

```elixir
defmodule Golfex.MiClub.BookingSection do
  defstruct [
    :id,
    :active,
    :name,
    booking_groups: []
  ]
end
```

Create `lib/golfex/miclub/booking_event.ex`:

```elixir
defmodule Golfex.MiClub.BookingEvent do
  defstruct [
    :id,
    :active,
    :date,
    :name,
    :last_modified,
    booking_sections: []
  ]

  def get_booking_group(%__MODULE__{booking_sections: sections}, group_id) do
    Enum.find_value(sections, fn section ->
      case Enum.find(section.booking_groups, &(&1.id == group_id)) do
        nil -> nil
        group -> {group, section}
      end
    end)
  end
end
```

- [ ] **Step 2: Write parser tests**

Create `test/golfex/miclub/parser_test.exs`:

```elixir
defmodule Golfex.MiClub.ParserTest do
  use ExUnit.Case, async: true

  alias Golfex.MiClub.Parser

  describe "parse_events/1" do
    test "parses JSON event list" do
      json = """
      [
        {
          "Id": 100,
          "EventDate": "2024-01-15T00:00:00",
          "Title": "Saturday Comp",
          "Availability": 24,
          "IsOpen": true,
          "IsBallot": false,
          "IsBallotOpen": false,
          "IsLottery": false,
          "HasCompetition": true,
          "IsMatchplay": false,
          "IsResults": false,
          "EventStatusCode": 1,
          "EventStatusCodeFriendly": "Open",
          "EventTypeCode": 2,
          "EventCategoryCode": 3,
          "EventTimeCodeFriendly": "AM"
        }
      ]
      """

      assert {:ok, [event]} = Parser.parse_events(json)
      assert event.id == 100
      assert event.title == "Saturday Comp"
      assert event.availability == 24
      assert event.is_open == true
    end
  end

  describe "parse_event_detail/1" do
    test "parses XML event detail with sections, groups, and entries" do
      xml = """
      <?xml version="1.0" encoding="utf-8"?>
      <BookingEvent>
        <Active>true</Active>
        <Id>100</Id>
        <Date>2024-01-15T07:00:00</Date>
        <Name>Saturday Comp</Name>
        <LastModified>2024-01-10T12:00:00</LastModified>
        <BookingSections>
          <BookingSection>
            <Id>1</Id>
            <Active>true</Active>
            <Name>Morning</Name>
            <BookingGroups>
              <BookingGroup>
                <Id>10</Id>
                <Time>07:00</Time>
                <StatusCode>0</StatusCode>
                <Active>true</Active>
                <RequireHandicap>true</RequireHandicap>
                <RequireGolfLink>false</RequireGolfLink>
                <VisitorAccepted>false</VisitorAccepted>
                <MemberAccepted>true</MemberAccepted>
                <PublicMemberAccepted>false</PublicMemberAccepted>
                <NineHoles>false</NineHoles>
                <EighteenHoles>true</EighteenHoles>
                <BookingEntries>
                  <BookingEntry>
                    <Id>200</Id>
                    <Type>member</Type>
                    <Index>1</Index>
                    <PersonName>John Smith</PersonName>
                    <MembershipNumber>M001</MembershipNumber>
                    <Handicap>15.5</Handicap>
                  </BookingEntry>
                </BookingEntries>
              </BookingGroup>
            </BookingGroups>
          </BookingSection>
        </BookingSections>
      </BookingEvent>
      """

      assert {:ok, event} = Parser.parse_event_detail(xml)
      assert event.id == 100
      assert event.name == "Saturday Comp"

      [section] = event.booking_sections
      assert section.name == "Morning"

      [group] = section.booking_groups
      assert group.time == "07:00"
      assert group.eighteen_holes == true

      [entry] = group.booking_entries
      assert entry.person_name == "John Smith"
      assert entry.handicap == 15.5
    end
  end

  describe "parse_booking_response/1" do
    test "returns :ok for successful booking (no error XML)" do
      assert :ok = Parser.parse_booking_response("<Success/>")
    end

    test "returns error for failed booking" do
      xml = """
      <Error>
        <ErrorText>Booking is full</ErrorText>
      </Error>
      """

      assert {:error, "Booking is full"} = Parser.parse_booking_response(xml)
    end
  end
end
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `mix test test/golfex/miclub/parser_test.exs`
Expected: Compilation errors — Parser module doesn't exist.

- [ ] **Step 4: Implement the Parser module**

Create `lib/golfex/miclub/parser.ex`:

```elixir
defmodule Golfex.MiClub.Parser do
  import SweetXml

  alias Golfex.MiClub.{BookingEvent, BookingSection, BookingGroup, BookingEntry}

  def parse_events(json) do
    case Jason.decode(json) do
      {:ok, events} when is_list(events) ->
        parsed =
          Enum.map(events, fn e ->
            %{
              id: e["Id"],
              title: e["Title"],
              event_date: parse_date(e["EventDate"]),
              availability: e["Availability"],
              is_open: e["IsOpen"],
              is_ballot: e["IsBallot"],
              is_ballot_open: e["IsBallotOpen"],
              is_lottery: e["IsLottery"],
              has_competition: e["HasCompetition"],
              is_matchplay: e["IsMatchplay"],
              is_results: e["IsResults"],
              event_status_code: e["EventStatusCode"],
              event_status_code_friendly: e["EventStatusCodeFriendly"],
              event_type_code: e["EventTypeCode"],
              event_category_code: e["EventCategoryCode"],
              event_time_code_friendly: e["EventTimeCodeFriendly"],
              auto_open_date_time_display: e["AutoOpenDateTimeDisplay"]
            }
          end)

        {:ok, parsed}

      {:ok, _} ->
        {:error, :unexpected_format}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def parse_event_detail(xml) do
    try do
      doc = SweetXml.parse(xml)

      event = %BookingEvent{
        id: doc |> xpath(~x"//BookingEvent/Id/text()"s) |> to_integer(),
        active: doc |> xpath(~x"//BookingEvent/Active/text()"s) |> to_boolean(),
        name: doc |> xpath(~x"//BookingEvent/Name/text()"s),
        date: doc |> xpath(~x"//BookingEvent/Date/text()"s),
        last_modified: doc |> xpath(~x"//BookingEvent/LastModified/text()"s),
        booking_sections: parse_sections(doc)
      }

      {:ok, event}
    rescue
      e -> {:error, Exception.message(e)}
    end
  end

  def parse_booking_response(xml) do
    if String.contains?(xml, "<Error>") do
      try do
        doc = SweetXml.parse(xml)
        error_texts = doc |> xpath(~x"//Error/ErrorText/text()"ls)
        {:error, Enum.join(error_texts, ", ")}
      rescue
        _ -> {:error, "Unknown booking error"}
      end
    else
      :ok
    end
  end

  defp parse_sections(doc) do
    doc
    |> xpath(~x"//BookingSections/BookingSection"l)
    |> Enum.map(fn section ->
      %BookingSection{
        id: section |> xpath(~x"./Id/text()"s) |> to_integer(),
        active: section |> xpath(~x"./Active/text()"s) |> to_boolean(),
        name: section |> xpath(~x"./Name/text()"s),
        booking_groups: parse_groups(section)
      }
    end)
  end

  defp parse_groups(section) do
    section
    |> xpath(~x"./BookingGroups/BookingGroup"l)
    |> Enum.map(fn group ->
      %BookingGroup{
        id: group |> xpath(~x"./Id/text()"s) |> to_integer(),
        time: group |> xpath(~x"./Time/text()"s),
        status_code: group |> xpath(~x"./StatusCode/text()"s) |> to_integer(),
        active: group |> xpath(~x"./Active/text()"s) |> to_boolean(),
        require_handicap: group |> xpath(~x"./RequireHandicap/text()"s) |> to_boolean(),
        require_golf_link: group |> xpath(~x"./RequireGolfLink/text()"s) |> to_boolean(),
        visitor_accepted: group |> xpath(~x"./VisitorAccepted/text()"s) |> to_boolean(),
        member_accepted: group |> xpath(~x"./MemberAccepted/text()"s) |> to_boolean(),
        public_member_accepted: group |> xpath(~x"./PublicMemberAccepted/text()"s) |> to_boolean(),
        nine_holes: group |> xpath(~x"./NineHoles/text()"s) |> to_boolean(),
        eighteen_holes: group |> xpath(~x"./EighteenHoles/text()"s) |> to_boolean(),
        booking_entries: parse_entries(group)
      }
    end)
  end

  defp parse_entries(group) do
    group
    |> xpath(~x"./BookingEntries/BookingEntry"l)
    |> Enum.map(fn entry ->
      %BookingEntry{
        id: entry |> xpath(~x"./Id/text()"s) |> to_integer(),
        kind: entry |> xpath(~x"./Type/text()"s),
        index: entry |> xpath(~x"./Index/text()"s) |> to_integer(),
        person_name: entry |> xpath(~x"./PersonName/text()"s),
        membership_number: entry |> xpath(~x"./MembershipNumber/text()"s) |> nilify(),
        gender: entry |> xpath(~x"./Gender/text()"s) |> nilify(),
        handicap: entry |> xpath(~x"./Handicap/text()"s) |> to_float_or_nil(),
        golf_link_no: entry |> xpath(~x"./GolfLinkNo/text()"s) |> nilify()
      }
    end)
  end

  defp to_integer(s), do: String.to_integer(s)
  defp to_boolean("true"), do: true
  defp to_boolean(_), do: false
  defp nilify(""), do: nil
  defp nilify(s), do: s

  defp to_float_or_nil(""), do: nil

  defp to_float_or_nil(s) do
    case Float.parse(s) do
      {f, _} -> f
      :error -> nil
    end
  end

  defp parse_date(nil), do: nil

  defp parse_date(date_string) do
    case NaiveDateTime.from_iso8601(date_string) do
      {:ok, ndt} -> NaiveDateTime.to_date(ndt)
      _ -> nil
    end
  end
end
```

- [ ] **Step 5: Run parser tests**

Run: `mix test test/golfex/miclub/parser_test.exs`
Expected: All tests pass.

- [ ] **Step 6: Write MiClub client tests**

Create `test/golfex/miclub_test.exs`:

```elixir
defmodule Golfex.MiClubTest do
  use ExUnit.Case

  alias Golfex.MiClub

  setup do
    Req.Test.stub(Golfex.MiClub.Client, fn
      %{url: %URI{path: "/security/login.msp"}} = conn ->
        Req.Test.json(conn, %{})

      %{url: %URI{path: "/spring/bookings/events/between/" <> _}} = conn ->
        Req.Test.json(conn, [
          %{
            "Id" => 1,
            "Title" => "Saturday Comp",
            "EventDate" => "2024-01-15T00:00:00",
            "Availability" => 24,
            "IsOpen" => true,
            "IsBallot" => false,
            "IsBallotOpen" => false,
            "IsLottery" => false,
            "HasCompetition" => true,
            "IsMatchplay" => false,
            "IsResults" => false,
            "EventStatusCode" => 1,
            "EventStatusCodeFriendly" => "Open",
            "EventTypeCode" => 2,
            "EventCategoryCode" => 3,
            "EventTimeCodeFriendly" => "AM"
          }
        ])

      %{url: %URI{path: "/members/Ajax"}} = conn ->
        Req.Test.text(conn, "<Success/>")
    end)

    user_club = %{
      club: %{base_url: "https://testgolf.com.au"},
      username: "testuser",
      password: "testpass",
      member_id: "12345"
    }

    %{user_club: user_club}
  end

  describe "list_events/1" do
    test "fetches and parses events from MiClub", %{user_club: user_club} do
      assert {:ok, [event]} = MiClub.list_events(user_club)
      assert event.title == "Saturday Comp"
    end
  end

  describe "book/4" do
    test "executes a booking via MiClub", %{user_club: user_club} do
      assert :ok = MiClub.book(user_club, 10, 200, "12345")
    end
  end
end
```

- [ ] **Step 7: Implement the MiClub Client**

Create `lib/golfex/miclub/client.ex`:

```elixir
defmodule Golfex.MiClub.Client do
  @login_path "security/login.msp"
  @events_path "spring/bookings/events/between"
  @event_path "spring/bookings/events"
  @ajax_path "members/Ajax"

  def login(base_url, username, password) do
    req = build_req(base_url)

    form_data = [
      user: username,
      password: password,
      action: "login",
      Submit: "Login"
    ]

    case Req.post(req, url: @login_path, form: form_data) do
      {:ok, %Req.Response{status: status}} when status in 200..399 ->
        {:ok, req}

      {:ok, %Req.Response{status: status}} ->
        {:error, {:login_failed, status}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def get_events(req) do
    date_from = Calendar.strftime(Date.utc_today(), "%d-%m-%Y")
    date_to = Calendar.strftime(Date.add(Date.utc_today(), 60), "%d-%m-%Y")
    url = "#{@events_path}/#{date_from}/#{date_to}/3000000"

    case Req.get(req, url: url) do
      {:ok, %Req.Response{status: 200, body: body}} when is_binary(body) ->
        {:ok, body}

      {:ok, %Req.Response{status: 200, body: body}} when is_list(body) ->
        {:ok, Jason.encode!(body)}

      {:ok, %Req.Response{status: status}} ->
        {:error, {:http_error, status}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def get_event(req, event_id) do
    case Req.get(req, url: "#{@event_path}/#{event_id}") do
      {:ok, %Req.Response{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %Req.Response{status: status}} ->
        {:error, {:http_error, status}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def book(req, booking_group_id, row_id, member_id) do
    form_data = [
      doAction: "makeBooking",
      rowId: to_string(row_id),
      memberId: to_string(member_id),
      myGroup: to_string(booking_group_id),
      findAlternative: "false"
    ]

    case Req.post(req, url: @ajax_path, form: form_data) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %Req.Response{status: status}} ->
        {:error, {:http_error, status}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp build_req(base_url) do
    opts = [
      base_url: base_url,
      redirect: false,
      receive_timeout: 30_000
    ]

    # In test, use the Req.Test plug; in prod/dev, make real HTTP requests
    test_opts = Application.get_env(:golfex, :miclub_req_options, [])
    Req.new(Keyword.merge(opts, test_opts))
  end
end
```

- [ ] **Step 8: Implement the MiClub facade**

Create `lib/golfex/miclub.ex`:

```elixir
defmodule Golfex.MiClub do
  alias Golfex.MiClub.{Client, Parser}

  def login(user_club) do
    Client.login(user_club.club.base_url, user_club.username, user_club.password)
  end

  def list_events(user_club) do
    with {:ok, req} <- Client.login(user_club.club.base_url, user_club.username, user_club.password),
         {:ok, body} <- Client.get_events(req),
         {:ok, events} <- Parser.parse_events(body) do
      {:ok, events}
    end
  end

  def get_event(user_club, event_id) do
    with {:ok, req} <- Client.login(user_club.club.base_url, user_club.username, user_club.password),
         {:ok, body} <- Client.get_event(req, event_id),
         {:ok, event} <- Parser.parse_event_detail(body) do
      {:ok, event}
    end
  end

  def book(user_club, booking_group_id, row_id, member_id) do
    with {:ok, req} <- Client.login(user_club.club.base_url, user_club.username, user_club.password),
         {:ok, body} <- Client.book(req, booking_group_id, row_id, member_id) do
      Parser.parse_booking_response(body)
    end
  end
end
```

- [ ] **Step 9: Run all MiClub tests**

Run: `mix test test/golfex/miclub/`
Expected: All tests pass.

- [ ] **Step 10: Commit**

```bash
git add lib/golfex/miclub/ lib/golfex/miclub.ex test/golfex/miclub/
git commit -m "feat: add MiClub HTTP client with JSON/XML parsing"
```

---

## Task 5: Events Context — Schema, Migration, and Cache Logic

**Files:**
- Create: `lib/golfex/events/event.ex`
- Create: `lib/golfex/events.ex`
- Create: `priv/repo/migrations/*_create_events.exs`
- Create: `test/golfex/events_test.exs`
- Create: `test/support/fixtures/events_fixtures.ex`

- [ ] **Step 1: Write Events context tests**

Create `test/golfex/events_test.exs`:

```elixir
defmodule Golfex.EventsTest do
  use Golfex.DataCase, async: true

  alias Golfex.Events
  alias Golfex.Events.Event

  import Golfex.ClubsFixtures
  import Golfex.EventsFixtures

  describe "upsert_events/2" do
    test "inserts new events for a club" do
      club = club_fixture()

      miclub_events = [
        %{
          id: 100, title: "Saturday Comp", event_date: ~D[2024-01-15],
          availability: 24, is_open: true, is_ballot: false, is_ballot_open: false,
          is_lottery: false, has_competition: true, is_matchplay: false,
          is_results: false, event_status_code: 1, event_status_code_friendly: "Open",
          event_type_code: 2, event_category_code: 3, event_time_code_friendly: "AM",
          auto_open_date_time_display: nil
        }
      ]

      assert {:ok, 1} = Events.upsert_events(club, miclub_events)
      assert [%Event{title: "Saturday Comp"}] = Events.list_events_for_club(club)
    end

    test "updates existing events on re-sync" do
      club = club_fixture()

      events = [%{
        id: 100, title: "Old Title", event_date: ~D[2024-01-15],
        availability: 24, is_open: true, is_ballot: false,
        is_ballot_open: false, is_lottery: false, has_competition: true,
        is_matchplay: false, is_results: false, event_status_code: 1,
        event_status_code_friendly: "Open", event_type_code: nil,
        event_category_code: nil, event_time_code_friendly: nil,
        auto_open_date_time_display: nil
      }]

      {:ok, 1} = Events.upsert_events(club, events)

      updated = [%{hd(events) | title: "New Title", availability: 20}]
      {:ok, 1} = Events.upsert_events(club, updated)

      assert [%Event{title: "New Title", availability: 20}] = Events.list_events_for_club(club)
    end
  end

  describe "list_events_for_club/1" do
    test "returns events ordered by date" do
      club = club_fixture()
      event_fixture(club, %{miclub_event_id: 1, title: "Later", event_date: ~D[2024-02-01]})
      event_fixture(club, %{miclub_event_id: 2, title: "Earlier", event_date: ~D[2024-01-01]})

      events = Events.list_events_for_club(club)
      assert [%{title: "Earlier"}, %{title: "Later"}] = events
    end
  end

  describe "cache_stale?/1" do
    test "returns true when no events exist for club" do
      club = club_fixture()
      assert Events.cache_stale?(club)
    end

    test "returns false when events were cached recently" do
      club = club_fixture()
      event_fixture(club, %{miclub_event_id: 1, cached_at: DateTime.utc_now()})
      refute Events.cache_stale?(club)
    end

    test "returns true when events are older than 12 hours" do
      club = club_fixture()
      old_time = DateTime.add(DateTime.utc_now(), -13, :hour)
      event_fixture(club, %{miclub_event_id: 1, cached_at: old_time})
      assert Events.cache_stale?(club)
    end
  end

  describe "invalidate_event/1" do
    test "marks a specific event as stale" do
      club = club_fixture()
      event = event_fixture(club, %{miclub_event_id: 1, cached_at: DateTime.utc_now()})

      Events.invalidate_event(event)

      updated = Events.get_event!(event.id)
      assert DateTime.diff(DateTime.utc_now(), updated.cached_at, :hour) > 12
    end
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `mix test test/golfex/events_test.exs`
Expected: Compilation errors.

- [ ] **Step 3: Create the Event schema**

Create `lib/golfex/events/event.ex`:

```elixir
defmodule Golfex.Events.Event do
  use Ecto.Schema
  import Ecto.Changeset

  alias Golfex.Clubs.Club

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "events" do
    belongs_to :club, Club

    field :miclub_event_id, :integer
    field :title, :string
    field :event_date, :date
    field :event_status_code, :integer
    field :event_status_code_friendly, :string
    field :availability, :integer
    field :is_open, :boolean, default: false
    field :is_ballot, :boolean, default: false
    field :is_ballot_open, :boolean, default: false
    field :is_lottery, :boolean
    field :has_competition, :boolean
    field :is_matchplay, :boolean, default: false
    field :is_results, :boolean, default: false
    field :event_type_code, :integer
    field :event_category_code, :integer
    field :event_time_code_friendly, :string
    field :auto_open_date_time_display, :string
    field :cached_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  def changeset(event, attrs) do
    event
    |> cast(attrs, [
      :club_id, :miclub_event_id, :title, :event_date, :event_status_code,
      :event_status_code_friendly, :availability, :is_open, :is_ballot,
      :is_ballot_open, :is_lottery, :has_competition, :is_matchplay,
      :is_results, :event_type_code, :event_category_code,
      :event_time_code_friendly, :auto_open_date_time_display, :cached_at
    ])
    |> validate_required([:club_id, :miclub_event_id, :title, :cached_at])
    |> unique_constraint([:club_id, :miclub_event_id])
  end
end
```

- [ ] **Step 4: Create migration**

Run: `mix ecto.gen.migration create_events`

Edit the migration:

```elixir
defmodule Golfex.Repo.Migrations.CreateEvents do
  use Ecto.Migration

  def change do
    create table(:events, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :club_id, references(:clubs, type: :binary_id, on_delete: :delete_all), null: false
      add :miclub_event_id, :integer, null: false
      add :title, :string, null: false
      add :event_date, :date
      add :event_status_code, :integer
      add :event_status_code_friendly, :string
      add :availability, :integer
      add :is_open, :boolean, default: false
      add :is_ballot, :boolean, default: false
      add :is_ballot_open, :boolean, default: false
      add :is_lottery, :boolean
      add :has_competition, :boolean
      add :is_matchplay, :boolean, default: false
      add :is_results, :boolean, default: false
      add :event_type_code, :integer
      add :event_category_code, :integer
      add :event_time_code_friendly, :string
      add :auto_open_date_time_display, :string
      add :cached_at, :utc_datetime, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:events, [:club_id, :miclub_event_id])
    create index(:events, [:club_id])
  end
end
```

- [ ] **Step 5: Create Events context**

Create `lib/golfex/events.ex`:

```elixir
defmodule Golfex.Events do
  import Ecto.Query

  alias Golfex.Repo
  alias Golfex.Events.Event
  alias Golfex.Clubs.Club

  @cache_ttl_hours 12

  def list_events_for_club(%Club{} = club) do
    Event
    |> where(club_id: ^club.id)
    |> order_by(:event_date)
    |> Repo.all()
  end

  def get_event!(id) do
    Repo.get!(Event, id)
  end

  def cache_stale?(%Club{} = club) do
    cutoff = DateTime.add(DateTime.utc_now(), -@cache_ttl_hours, :hour)

    query =
      from e in Event,
        where: e.club_id == ^club.id and e.cached_at >= ^cutoff,
        select: count(e.id)

    Repo.one(query) == 0
  end

  def upsert_events(%Club{} = club, miclub_events) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    entries =
      Enum.map(miclub_events, fn e ->
        %{
          id: Ecto.UUID.generate(),
          club_id: club.id,
          miclub_event_id: e.id,
          title: e.title,
          event_date: e[:event_date],
          event_status_code: e[:event_status_code],
          event_status_code_friendly: e[:event_status_code_friendly],
          availability: e[:availability],
          is_open: e[:is_open] || false,
          is_ballot: e[:is_ballot] || false,
          is_ballot_open: e[:is_ballot_open] || false,
          is_lottery: e[:is_lottery],
          has_competition: e[:has_competition],
          is_matchplay: e[:is_matchplay] || false,
          is_results: e[:is_results] || false,
          event_type_code: e[:event_type_code],
          event_category_code: e[:event_category_code],
          event_time_code_friendly: e[:event_time_code_friendly],
          auto_open_date_time_display: e[:auto_open_date_time_display],
          cached_at: now,
          inserted_at: now,
          updated_at: now
        }
      end)

    {count, _} =
      Repo.insert_all(Event, entries,
        on_conflict: {:replace_all_except, [:id, :club_id, :inserted_at]},
        conflict_target: [:club_id, :miclub_event_id]
      )

    {:ok, count}
  end

  def invalidate_event(%Event{} = event) do
    stale_time = DateTime.add(DateTime.utc_now(), -(@cache_ttl_hours + 1), :hour)

    event
    |> Event.changeset(%{cached_at: stale_time})
    |> Repo.update()
  end

  def invalidate_events(%Club{} = club) do
    stale_time = DateTime.add(DateTime.utc_now(), -(@cache_ttl_hours + 1), :hour)

    from(e in Event, where: e.club_id == ^club.id)
    |> Repo.update_all(set: [cached_at: stale_time])
  end
end
```

- [ ] **Step 6: Create test fixtures**

Create `test/support/fixtures/events_fixtures.ex`:

```elixir
defmodule Golfex.EventsFixtures do
  alias Golfex.Repo
  alias Golfex.Events.Event

  def event_fixture(club, attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        miclub_event_id: System.unique_integer([:positive]),
        title: "Test Event",
        event_date: ~D[2024-01-15],
        availability: 24,
        is_open: true,
        is_ballot: false,
        is_ballot_open: false,
        is_matchplay: false,
        is_results: false,
        cached_at: DateTime.utc_now() |> DateTime.truncate(:second)
      })

    %Event{}
    |> Event.changeset(Map.put(attrs, :club_id, club.id))
    |> Repo.insert!()
  end
end
```

- [ ] **Step 7: Run migrations and tests**

Run: `mix ecto.migrate && mix test test/golfex/events_test.exs`
Expected: All tests pass.

- [ ] **Step 8: Commit**

```bash
git add lib/golfex/events/ lib/golfex/events.ex priv/repo/migrations/ test/golfex/events_test.exs test/support/fixtures/events_fixtures.ex
git commit -m "feat: add Events context with caching and upsert logic"
```

---

## Task 6: Bookings Context — Schema, Oban Worker, and Scheduling

**Files:**
- Create: `lib/golfex/bookings/scheduled_booking.ex`
- Create: `lib/golfex/bookings/booking_worker.ex`
- Create: `lib/golfex/bookings.ex`
- Create: `priv/repo/migrations/*_create_scheduled_bookings.exs`
- Create: `test/golfex/bookings_test.exs`
- Create: `test/golfex/bookings/booking_worker_test.exs`

- [ ] **Step 1: Write Bookings context tests**

Create `test/golfex/bookings_test.exs`:

```elixir
defmodule Golfex.BookingsTest do
  use Golfex.DataCase, async: true
  use Oban.Testing, repo: Golfex.Repo

  alias Golfex.Bookings
  alias Golfex.Bookings.ScheduledBooking

  import Golfex.AccountsFixtures
  import Golfex.ClubsFixtures

  describe "schedule_booking/1" do
    test "creates a scheduled booking and enqueues an Oban job" do
      {scope, user_club} = setup_user_with_club()
      scheduled_for = DateTime.add(DateTime.utc_now(), 3600, :second)

      attrs = %{
        user_id: scope.user.id,
        user_club_id: user_club.id,
        miclub_event_id: 100,
        miclub_group_id: 10,
        miclub_row_id: 200,
        miclub_member_id: 12345,
        scheduled_for: scheduled_for
      }

      assert {:ok, %ScheduledBooking{} = booking} = Bookings.schedule_booking(attrs)
      assert booking.status == "pending"
      assert booking.miclub_event_id == 100

      assert_enqueued(worker: Golfex.Bookings.BookingWorker)
    end
  end

  describe "book_now/4" do
    test "delegates to MiClub.book" do
      # This test requires Req.Test stub — see MiClub tests for integration coverage
      # book_now is a thin wrapper around MiClub.book
    end
  end

  describe "cancel_booking/1" do
    test "cancels a pending booking" do
      {scope, user_club} = setup_user_with_club()
      booking = create_booking(scope, user_club)

      assert {:ok, %ScheduledBooking{status: "cancelled"}} = Bookings.cancel_booking(booking)
    end

    test "cannot cancel a completed booking" do
      {scope, user_club} = setup_user_with_club()
      booking = create_booking(scope, user_club, %{status: "completed"})

      assert {:error, :not_cancellable} = Bookings.cancel_booking(booking)
    end
  end

  describe "list_bookings_for_user/1" do
    test "returns bookings for the user ordered by scheduled_for desc" do
      {scope, user_club} = setup_user_with_club()
      _booking = create_booking(scope, user_club)

      bookings = Bookings.list_bookings_for_user(scope)
      assert length(bookings) == 1
    end
  end

  defp setup_user_with_club do
    user = user_fixture()
    scope = %Golfex.Accounts.Scope{user: user}
    club = club_fixture()
    user_club = user_club_fixture(scope, club)
    {scope, user_club}
  end

  defp create_booking(scope, user_club, extra_attrs \\ %{}) do
    attrs =
      Map.merge(
        %{
          user_id: scope.user.id,
          user_club_id: user_club.id,
          miclub_event_id: 100,
          miclub_group_id: 10,
          miclub_row_id: 200,
          miclub_member_id: 12345,
          scheduled_for: DateTime.add(DateTime.utc_now(), 3600, :second),
          status: "pending"
        },
        extra_attrs
      )

    %ScheduledBooking{}
    |> ScheduledBooking.changeset(attrs)
    |> Golfex.Repo.insert!()
  end
end
```

- [ ] **Step 2: Write BookingWorker test**

Create `test/golfex/bookings/booking_worker_test.exs`:

```elixir
defmodule Golfex.Bookings.BookingWorkerTest do
  use Golfex.DataCase, async: false
  use Oban.Testing, repo: Golfex.Repo

  alias Golfex.Bookings
  alias Golfex.Bookings.{BookingWorker, ScheduledBooking}

  import Golfex.AccountsFixtures
  import Golfex.ClubsFixtures

  setup do
    Req.Test.stub(Golfex.MiClub.Client, fn
      %{url: %URI{path: "/security/login.msp"}} = conn ->
        Req.Test.json(conn, %{})

      %{url: %URI{path: "/members/Ajax"}} = conn ->
        Req.Test.text(conn, "<Success/>")
    end)

    :ok
  end

  test "perform/1 executes booking and updates status to completed" do
    user = user_fixture()
    scope = %Golfex.Accounts.Scope{user: user}
    club = club_fixture()
    user_club = user_club_fixture(scope, club)

    booking =
      %ScheduledBooking{}
      |> ScheduledBooking.changeset(%{
        user_id: user.id,
        user_club_id: user_club.id,
        miclub_event_id: 100,
        miclub_group_id: 10,
        miclub_row_id: 200,
        miclub_member_id: 12345,
        scheduled_for: DateTime.utc_now(),
        status: "pending"
      })
      |> Repo.insert!()

    assert :ok = perform_job(BookingWorker, %{booking_id: booking.id})

    updated = Bookings.get_scheduled_booking!(booking.id)
    assert updated.status == "completed"
  end
end
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `mix test test/golfex/bookings_test.exs test/golfex/bookings/booking_worker_test.exs`
Expected: Compilation errors.

- [ ] **Step 4: Create ScheduledBooking schema**

Create `lib/golfex/bookings/scheduled_booking.ex`:

```elixir
defmodule Golfex.Bookings.ScheduledBooking do
  use Ecto.Schema
  import Ecto.Changeset

  alias Golfex.Accounts.User
  alias Golfex.Clubs.UserClub
  alias Golfex.Events.Event

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @statuses ~w(pending running completed failed cancelled)

  schema "scheduled_bookings" do
    belongs_to :user, User
    belongs_to :user_club, UserClub
    belongs_to :event, Event

    field :miclub_event_id, :integer
    field :miclub_group_id, :integer
    field :miclub_row_id, :integer
    field :miclub_member_id, :integer
    field :scheduled_for, :utc_datetime
    field :status, :string, default: "pending"
    field :oban_job_id, :integer
    field :last_error, :string

    timestamps(type: :utc_datetime)
  end

  def changeset(booking, attrs) do
    booking
    |> cast(attrs, [
      :user_id, :user_club_id, :event_id, :miclub_event_id, :miclub_group_id,
      :miclub_row_id, :miclub_member_id, :scheduled_for, :status, :oban_job_id,
      :last_error
    ])
    |> validate_required([
      :user_id, :user_club_id, :miclub_event_id, :miclub_group_id,
      :miclub_row_id, :miclub_member_id, :scheduled_for
    ])
    |> validate_inclusion(:status, @statuses)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:user_club_id)
  end

  def cancellable?(%__MODULE__{status: status}), do: status in ~w(pending)
end
```

- [ ] **Step 5: Create migration**

Run: `mix ecto.gen.migration create_scheduled_bookings`

Edit:

```elixir
defmodule Golfex.Repo.Migrations.CreateScheduledBookings do
  use Ecto.Migration

  def change do
    create table(:scheduled_bookings, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :user_club_id, references(:user_clubs, type: :binary_id, on_delete: :delete_all), null: false
      add :event_id, references(:events, type: :binary_id, on_delete: :nilify_all)
      add :miclub_event_id, :integer, null: false
      add :miclub_group_id, :integer, null: false
      add :miclub_row_id, :integer, null: false
      add :miclub_member_id, :integer, null: false
      add :scheduled_for, :utc_datetime, null: false
      add :status, :string, null: false, default: "pending"
      add :oban_job_id, :integer
      add :last_error, :text

      timestamps(type: :utc_datetime)
    end

    create index(:scheduled_bookings, [:user_id, :status])
    create index(:scheduled_bookings, [:status, :scheduled_for])
  end
end
```

- [ ] **Step 6: Create BookingWorker**

Create `lib/golfex/bookings/booking_worker.ex`:

```elixir
defmodule Golfex.Bookings.BookingWorker do
  use Oban.Worker, queue: :bookings, max_attempts: 3

  alias Golfex.Bookings
  alias Golfex.Clubs
  alias Golfex.MiClub

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    booking = Bookings.get_scheduled_booking!(args["booking_id"])
    user_club = Clubs.get_user_club_by_id!(booking.user_club_id)

    Bookings.update_booking_status(booking, "running")

    case MiClub.book(user_club, booking.miclub_group_id, booking.miclub_row_id, to_string(booking.miclub_member_id)) do
      :ok ->
        Bookings.update_booking_status(booking, "completed")
        :ok

      {:error, reason} ->
        error_msg = if is_binary(reason), do: reason, else: inspect(reason)
        Bookings.update_booking_status(booking, "failed", error_msg)
        {:error, reason}
    end
  end
end
```

- [ ] **Step 7: Create Bookings context**

Create `lib/golfex/bookings.ex`:

```elixir
defmodule Golfex.Bookings do
  import Ecto.Query

  alias Golfex.Repo
  alias Golfex.Accounts.Scope
  alias Golfex.Bookings.{ScheduledBooking, BookingWorker}
  alias Golfex.MiClub

  def book_now(user_club, booking_group_id, row_id, member_id) do
    MiClub.book(user_club, booking_group_id, row_id, member_id)
  end

  def schedule_booking(attrs) do
    changeset = ScheduledBooking.changeset(%ScheduledBooking{}, attrs)

    Ecto.Multi.new()
    |> Ecto.Multi.insert(:booking, changeset)
    |> Ecto.Multi.run(:oban_job, fn _repo, %{booking: booking} ->
      job =
        %{booking_id: booking.id}
        |> BookingWorker.new(scheduled_at: booking.scheduled_for)
        |> Oban.insert!()

      {:ok, job}
    end)
    |> Ecto.Multi.run(:update_job_id, fn _repo, %{booking: booking, oban_job: job} ->
      booking
      |> ScheduledBooking.changeset(%{oban_job_id: job.id})
      |> Repo.update()
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{update_job_id: booking}} -> {:ok, booking}
      {:error, _step, changeset, _changes} -> {:error, changeset}
    end
  end

  def cancel_booking(%ScheduledBooking{} = booking) do
    if ScheduledBooking.cancellable?(booking) do
      if booking.oban_job_id, do: Oban.cancel_job(booking.oban_job_id)

      booking
      |> ScheduledBooking.changeset(%{status: "cancelled"})
      |> Repo.update()
    else
      {:error, :not_cancellable}
    end
  end

  def list_bookings_for_user(%Scope{user: user}) do
    ScheduledBooking
    |> where(user_id: ^user.id)
    |> order_by(desc: :scheduled_for)
    |> preload(:user_club)
    |> Repo.all()
  end

  def get_scheduled_booking!(id) do
    Repo.get!(ScheduledBooking, id)
  end

  def update_booking_status(%ScheduledBooking{} = booking, status, error \\ nil) do
    attrs = %{status: status}
    attrs = if error, do: Map.put(attrs, :last_error, error), else: attrs

    booking
    |> ScheduledBooking.changeset(attrs)
    |> Repo.update()
  end
end
```

- [ ] **Step 8: Run migrations and tests**

Run: `mix ecto.migrate && mix test test/golfex/bookings_test.exs test/golfex/bookings/booking_worker_test.exs`
Expected: All tests pass.

- [ ] **Step 9: Commit**

```bash
git add lib/golfex/bookings/ lib/golfex/bookings.ex priv/repo/migrations/ test/golfex/bookings_test.exs test/golfex/bookings/
git commit -m "feat: add Bookings context with Oban worker for scheduled bookings"
```

---

## Task 7: Admin User Creation Mix Task

**Files:**
- Create: `lib/mix/tasks/golfex.create_user.ex`

Since the `/users/register` route will be removed, we need a way to create the initial admin user.

- [ ] **Step 1: Create the mix task**

Create `lib/mix/tasks/golfex.create_user.ex`:

```elixir
defmodule Mix.Tasks.Golfex.CreateUser do
  @shortdoc "Creates a new user account"
  @moduledoc "Creates a new user: mix golfex.create_user email password"

  use Mix.Task

  @impl Mix.Task
  def run([email, password]) do
    Mix.Task.run("app.start")

    case Golfex.Accounts.register_user(%{email: email, password: password}) do
      {:ok, user} ->
        # Auto-confirm the user
        user
        |> Ecto.Changeset.change(confirmed_at: DateTime.utc_now() |> DateTime.truncate(:second))
        |> Golfex.Repo.update!()

        Mix.shell().info("User created: #{email}")

      {:error, changeset} ->
        errors = Ecto.Changeset.traverse_errors(changeset, fn {msg, _} -> msg end)
        Mix.shell().error("Failed to create user: #{inspect(errors)}")
    end
  end

  def run(_) do
    Mix.shell().error("Usage: mix golfex.create_user EMAIL PASSWORD")
  end
end
```

- [ ] **Step 2: Test it compiles**

Run: `mix compile`
Expected: No errors.

- [ ] **Step 3: Commit**

```bash
git add lib/mix/tasks/
git commit -m "feat: add mix task for creating admin users"
```

---

## Task 8: Router and Layout Updates

**Files:**
- Modify: `lib/golfex_web/router.ex`
- Modify: `lib/golfex_web/components/layouts/root.html.heex`
- Modify: `lib/golfex_web/components/layouts/app.html.heex`
- Create stub LiveView modules (to avoid compilation errors)

- [ ] **Step 1: Create stub LiveView modules**

Create minimal stub modules so the router can compile. These will be replaced in later tasks:

`lib/golfex_web/live/dashboard_live.ex`:
```elixir
defmodule GolfexWeb.DashboardLive do
  use GolfexWeb, :live_view
  def render(assigns), do: ~H"<p>Dashboard</p>"
end
```

`lib/golfex_web/live/club_live/index.ex`:
```elixir
defmodule GolfexWeb.ClubLive.Index do
  use GolfexWeb, :live_view
  def render(assigns), do: ~H"<p>Clubs</p>"
end
```

`lib/golfex_web/live/event_live/index.ex`:
```elixir
defmodule GolfexWeb.EventLive.Index do
  use GolfexWeb, :live_view
  def render(assigns), do: ~H"<p>Events</p>"
end
```

`lib/golfex_web/live/event_live/show.ex`:
```elixir
defmodule GolfexWeb.EventLive.Show do
  use GolfexWeb, :live_view
  def render(assigns), do: ~H"<p>Event</p>"
end
```

`lib/golfex_web/live/booking_group_live/show.ex`:
```elixir
defmodule GolfexWeb.BookingGroupLive.Show do
  use GolfexWeb, :live_view
  def render(assigns), do: ~H"<p>Booking Group</p>"
end
```

`lib/golfex_web/live/booking_live/index.ex`:
```elixir
defmodule GolfexWeb.BookingLive.Index do
  use GolfexWeb, :live_view
  def render(assigns), do: ~H"<p>Bookings</p>"
end
```

- [ ] **Step 2: Update router with new routes**

Modify `lib/golfex_web/router.ex`:

Remove `live "/users/register", UserLive.Registration, :new` from the `:current_user` live_session.

Remove `get "/", PageController, :home` from the unauthenticated scope.

Add new authenticated routes inside the `:require_authenticated_user` live_session:

```elixir
live_session :require_authenticated_user,
  on_mount: [{GolfexWeb.UserAuth, :require_authenticated}] do
  live "/users/settings", UserLive.Settings, :edit
  live "/users/settings/confirm-email/:token", UserLive.Settings, :confirm_email

  live "/", DashboardLive, :index
  live "/clubs", ClubLive.Index, :index
  live "/clubs/new", ClubLive.Index, :new
  live "/clubs/:club_id/events", EventLive.Index, :index
  live "/clubs/:club_id/events/:event_id", EventLive.Show, :show
  live "/clubs/:club_id/events/:event_id/groups/:group_id", BookingGroupLive.Show, :show
  live "/bookings", BookingLive.Index, :index
end
```

- [ ] **Step 3: Update the root layout nav**

Update `lib/golfex_web/components/layouts/root.html.heex`:
- Remove the "Register" link
- Add nav links for authenticated users: Dashboard, Clubs, My Bookings
- Keep Settings and Log out links

- [ ] **Step 4: Verify compilation**

Run: `mix compile`
Expected: No errors.

- [ ] **Step 5: Commit**

```bash
git add lib/golfex_web/router.ex lib/golfex_web/components/layouts/ lib/golfex_web/live/
git commit -m "feat: update router and nav layout for clubs, events, and bookings"
```

---

## Task 9: Dashboard LiveView

**Files:**
- Modify: `lib/golfex_web/live/dashboard_live.ex` (replace stub)
- Create: `test/golfex_web/live/dashboard_live_test.exs`

- [ ] **Step 1: Write dashboard test**

Create `test/golfex_web/live/dashboard_live_test.exs`:

```elixir
defmodule GolfexWeb.DashboardLiveTest do
  use GolfexWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Golfex.AccountsFixtures
  import Golfex.ClubsFixtures

  describe "dashboard" do
    test "redirects to login if not authenticated", %{conn: conn} do
      assert {:error, {:redirect, _}} = live(conn, ~p"/")
    end

    test "shows clubs for authenticated user", %{conn: conn} do
      user = user_fixture()
      scope = %Golfex.Accounts.Scope{user: user}
      club = club_fixture(%{name: "The Ridge Golf Club"})
      _user_club = user_club_fixture(scope, club)

      conn = log_in_user(conn, user)
      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "The Ridge Golf Club"
    end

    test "shows message when no clubs configured", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)
      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "Add a club"
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/golfex_web/live/dashboard_live_test.exs`
Expected: FAIL — stub render doesn't show expected content.

- [ ] **Step 3: Implement DashboardLive (replace stub)**

Replace `lib/golfex_web/live/dashboard_live.ex` with:

```elixir
defmodule GolfexWeb.DashboardLive do
  use GolfexWeb, :live_view

  alias Golfex.Clubs

  @impl true
  def mount(_params, _session, socket) do
    user_clubs = Clubs.list_clubs_for_user(socket.assigns.current_scope)

    socket =
      socket
      |> assign(:page_title, "Dashboard")
      |> assign(:user_clubs, user_clubs)

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flow">
      <h1>Dashboard</h1>

      <div :if={@user_clubs == []}>
        <p>You haven't added any golf clubs yet.</p>
        <.link navigate={~p"/clubs/new"} class="sc-button">Add a club</.link>
      </div>

      <div :if={@user_clubs != []} class="flow">
        <h2>Your Clubs</h2>
        <div class="grid">
          <div :for={uc <- @user_clubs} class="sc-card">
            <h3>{uc.club.name}</h3>
            <.link navigate={~p"/clubs/#{uc.club_id}/events"} class="sc-button">
              View Events
            </.link>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
```

- [ ] **Step 4: Run tests**

Run: `mix test test/golfex_web/live/dashboard_live_test.exs`
Expected: All tests pass.

- [ ] **Step 5: Commit**

```bash
git add lib/golfex_web/live/dashboard_live.ex test/golfex_web/live/dashboard_live_test.exs
git commit -m "feat: implement Dashboard LiveView showing user's clubs"
```

---

## Task 10: Clubs LiveView — List and Add Clubs

**Files:**
- Modify: `lib/golfex_web/live/club_live/index.ex` (replace stub)
- Create: `lib/golfex_web/live/club_live/form_component.ex`
- Create: `test/golfex_web/live/club_live_test.exs`

- [ ] **Step 1: Write club management tests**

Create `test/golfex_web/live/club_live_test.exs` with tests for listing clubs and adding a new club via the form.

- [ ] **Step 2: Implement ClubLive.Index and FormComponent**

Replace the stub `lib/golfex_web/live/club_live/index.ex` with the full implementation: list user's clubs, remove button, link to add new.

Create `lib/golfex_web/live/club_live/form_component.ex`: form with club name, base_url, and MiClub credentials fields. On save, creates the club and user_club association.

- [ ] **Step 3: Run tests**

Run: `mix test test/golfex_web/live/club_live_test.exs`
Expected: All tests pass.

- [ ] **Step 4: Commit**

```bash
git add lib/golfex_web/live/club_live/ test/golfex_web/live/club_live_test.exs
git commit -m "feat: add Clubs LiveView for managing golf club associations"
```

---

## Task 11: Events LiveView — List and Detail

**Files:**
- Modify: `lib/golfex_web/live/event_live/index.ex` (replace stub)
- Modify: `lib/golfex_web/live/event_live/show.ex` (replace stub)
- Create: `test/golfex_web/live/event_live_test.exs`

- [ ] **Step 1: Write events tests**

Create `test/golfex_web/live/event_live_test.exs` with tests for:
- Listing cached events for a club
- Showing event detail page (with MiClub stub via `Req.Test.stub`)

- [ ] **Step 2: Implement EventLive.Index**

Replace stub. Shows events table for a club. "Refresh" button triggers MiClub sync. Auto-syncs if cache is stale on mount (uses `Events.cache_stale?/1`).

- [ ] **Step 3: Implement EventLive.Show**

Replace stub. Shows event detail with booking sections and groups fetched live from MiClub. Links to booking group detail pages.

- [ ] **Step 4: Run tests**

Run: `mix test test/golfex_web/live/event_live_test.exs`
Expected: All tests pass.

- [ ] **Step 5: Commit**

```bash
git add lib/golfex_web/live/event_live/ test/golfex_web/live/event_live_test.exs
git commit -m "feat: add Events LiveViews for listing and viewing event details"
```

---

## Task 12: Booking Group LiveView — View Details and Book

**Files:**
- Modify: `lib/golfex_web/live/booking_group_live/show.ex` (replace stub)
- Create: `test/golfex_web/live/booking_group_live_test.exs`

- [ ] **Step 1: Write booking group tests**

Create `test/golfex_web/live/booking_group_live_test.exs` with tests for:
- Showing booking group detail with entries
- "Book Now" button executes an immediate booking
- "Schedule Booking" form creates a scheduled booking

- [ ] **Step 2: Implement BookingGroupLive.Show**

Replace stub. Shows group metadata (time, holes, member/visitor accepted, handicap required). Shows entries table with each entry's name, handicap, membership number, and a "Book" button per entry (not hardcoded to first entry). Schedule booking form with datetime picker and row/entry selector.

Key: the "Book" button passes the specific entry's `row_id` — user chooses which slot to book.

- [ ] **Step 3: Run tests**

Run: `mix test test/golfex_web/live/booking_group_live_test.exs`
Expected: All tests pass.

- [ ] **Step 4: Commit**

```bash
git add lib/golfex_web/live/booking_group_live/ test/golfex_web/live/booking_group_live_test.exs
git commit -m "feat: add BookingGroupLive for viewing details and booking slots"
```

---

## Task 13: Bookings LiveView — View and Cancel Scheduled Bookings

**Files:**
- Modify: `lib/golfex_web/live/booking_live/index.ex` (replace stub)
- Create: `test/golfex_web/live/booking_live_test.exs`

- [ ] **Step 1: Write bookings list test**

Create `test/golfex_web/live/booking_live_test.exs` with tests for:
- Listing scheduled bookings for user
- Cancel button on pending bookings

- [ ] **Step 2: Implement BookingLive.Index**

Replace stub. Shows table of scheduled bookings: event ID, scheduled time, status, error, cancel button (for pending only).

- [ ] **Step 3: Run tests**

Run: `mix test test/golfex_web/live/booking_live_test.exs`
Expected: All tests pass.

- [ ] **Step 4: Commit**

```bash
git add lib/golfex_web/live/booking_live/ test/golfex_web/live/booking_live_test.exs
git commit -m "feat: add BookingLive for viewing and cancelling scheduled bookings"
```

---

## Task 14: Run Full Test Suite and Clean Up

**Files:**
- Potentially modify any files with issues

- [ ] **Step 1: Run the full test suite**

Run: `mix test`
Expected: All tests pass.

- [ ] **Step 2: Run compilation with warnings as errors**

Run: `mix compile --warnings-as-errors`
Expected: No warnings.

- [ ] **Step 3: Run formatter**

Run: `mix format`

- [ ] **Step 4: Delete unused PageController and related files**

Remove `lib/golfex_web/controllers/page_controller.ex` and `lib/golfex_web/controllers/page_html.ex` (and its template directory if present) since `/` is now handled by DashboardLive. Update tests accordingly — remove `test/golfex_web/controllers/page_controller_test.exs`.

- [ ] **Step 5: Final test run**

Run: `mix test`
Expected: All tests pass.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "chore: clean up unused files and ensure all tests pass"
```
