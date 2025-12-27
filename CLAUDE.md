# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Raining is a full-stack application built with Phoenix (Elixir) backend and React Router frontend, featuring user authentication via Bearer tokens and OpenAPI specification with Swagger UI.

## Development Commands

### Elixir/Phoenix Backend

```bash
# Initial setup
mix setup  # Install deps, create DB, run migrations, setup & build assets

# Development server
mix phx.server  # Start Phoenix at localhost:4000
iex -S mix phx.server  # Start with IEx console

# Database
mix ecto.create  # Create database
mix ecto.migrate  # Run migrations
mix ecto.reset  # Drop, create, and migrate database
mix ecto.setup  # Create, migrate, and seed database

# Testing
mix test  # Run all tests
mix test test/path/to/test.exs  # Run specific test file
mix test test/path/to/test.exs:42  # Run test at specific line

# Code quality
mix format  # Format Elixir code
mix compile --warnings-as-errors  # Compile with strict warnings
mix precommit  # Run full pre-commit check (compile, format, deps unlock, test)

# Assets
mix assets.setup  # Install Tailwind and esbuild
mix assets.build  # Build assets
mix assets.deploy  # Build and minify assets for production
```

### React Frontend

```bash
cd frontend

# Development
npm run dev  # Start React Router dev server

# Build & Quality
npm run build  # TypeScript compile and Vite build
npm run lint  # Run ESLint
npm run preview  # Preview production build
```

## Architecture

### Backend Structure

**Context-Based Architecture**: The application follows Phoenix's context pattern for organizing business logic:

- `Raining.Accounts` - User management context
  - User registration, authentication, and session management
  - Token-based authentication (UserToken) for API access
  - Magic link login support
  - Sudo mode for sensitive operations (20-minute window)

- `Raining.Accounts.Scope` - Caller scope abstraction
  - Carries information about the current user/caller
  - Used for authorization, logging, and PubSub scoping
  - Designed to be extended with additional privilege fields as needed

**Authentication System**:
- Bearer token authentication for API endpoints
- Session tokens are base64-url-encoded and stored in database
- `RainingWeb.UserAuth` plug handles token verification via `Authorization: Bearer <token>` header
- Token verification happens in `:auth` pipeline (router.ex:13-16)
- Tokens can be magic links or session tokens

**API Design**:
- OpenAPI specification via `open_api_spex` library
- Swagger UI available at `/swagger` in development
- API spec served at `/api/openapi`
- Schema definitions in `RainingWeb.Schemas`
- Spec module: `RainingWeb.ApiSpec`

**Routing Pipelines** (lib/raining_web/router.ex):
- `:browser` - HTML responses with CSRF protection
- `:api` - JSON API with OpenAPI spec injection
- `:auth` - Authenticated JSON API (requires Bearer token)

### Frontend Structure

**React Router 7** setup with:
- TypeScript configuration
- Tailwind CSS v4 with Vite plugin
- Source files in `frontend/src/`
- Pages: Home, Auth
- Component: Nav

**Code Style**:
- Prettier configured: semicolons, single quotes, trailing commas, 100 char width

### Database

- PostgreSQL via Ecto
- Repository: `Raining.Repo`
- Test mode uses SQL Sandbox (`:manual` mode)
- Migration files in `priv/repo/migrations/`

### Configuration

**Scopes Configuration** (config/config.exs:10-21):
The app uses a configurable scope system for multi-tenancy/user scoping:
- Default scope type: `:user`
- Scope module: `Raining.Accounts.Scope`
- Scoped by `user_id` on schemas
- Test fixtures available via `Raining.AccountsFixtures`

### Development Tools

- **Tidewave**: MCP server for Elixir development (dev-only dependency)
- **Phoenix LiveDashboard**: Available at `/dev/dashboard` in development
- **Swoosh Mailbox**: Email preview at `/dev/mailbox` in development
- **Phoenix LiveReload**: Automatic browser refresh on code changes

## Important Patterns

### Formatter Configuration

Elixir formatter includes:
- Import deps: `:open_api_spex`, `:ecto`, `:ecto_sql`, `:phoenix`
- HTMLFormatter for `.heex` files
- Subdirectory formatting for migrations

### Mix Aliases

Key shortcuts defined in mix.exs:
- `mix setup` - Complete project setup from scratch
- `mix precommit` - Full quality check before committing
- `mix ecto.reset` - Reset database to clean state

### Testing

- Tests in `test/` directory with parallel structure to `lib/`
- Support modules in `test/support/`
- ExUnit configuration in `test/test_helper.exs`
- Database sandbox ensures test isolation

## Key Files

- `lib/raining_web/router.ex` - Route definitions and pipeline configuration
- `lib/raining_web/endpoint.ex` - HTTP endpoint with Tidewave, LiveReload, static serving
- `lib/raining_web/user_auth.ex` - Bearer token authentication logic
- `lib/raining/accounts.ex` - User management and authentication functions
- `config/config.exs` - Application configuration including scope system
- `mix.exs` - Dependencies and mix aliases
