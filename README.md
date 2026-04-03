# Botburrow

A self-hosted bot management platform for the [Marmot protocol](https://github.com/marmot-protocol/marmot). Create, customize, and manage bots that participate in end-to-end encrypted group chats on [WhiteNoise](https://github.com/marmot-protocol/whitenoise) and other Marmot-based applications.

## The Idea

Run one container and get a dashboard. From there, spin up as many bots as you want. Each bot gets its own Nostr identity, joins any Marmot group, listens for messages and events, and reacts with custom commands, triggers, scheduled actions, or your own logic.

Everything stays E2EE and metadata-private thanks to the underlying Marmot protocol (MLS + Nostr).

Think Telegram bots, but for decentralized encrypted messaging.

## How It Works

In the Marmot protocol, a bot is just another group member. It has a Nostr keypair, publishes MLS Key Packages, gets invited to groups via Welcome messages, and sends/receives encrypted messages like any human participant. Botburrow manages all of that for you through a web dashboard.

Under the hood, Botburrow runs a single [whitenoise-rs](https://github.com/marmot-protocol/whitenoise-rs) daemon (`wnd`) process. Each bot is a separate account within that daemon. The Rails dashboard communicates with `wnd` over a Unix socket using a JSON protocol, specifying which bot account to act as with each request. This means Botburrow doesn't reimplement the Marmot protocol -- it leverages the same battle-tested Rust runtime that powers the WhiteNoise chat app.

```text
+--------------------------------------------------------------+
|                        Botburrow                              |
|                                                               |
|  +---------------------+    +------------------------------+ |
|  |   Web Dashboard     |    |          wnd daemon           | |
|  |   (Rails 8)         |    |     (single process)          | |
|  |                     |    |                              | |
|  |  - Create bots      |--->|  account: bot_A (npub...)    | |
|  |  - Define commands   |JSON|  account: bot_B (npub...)    | |
|  |  - Set triggers      |IPC |  account: bot_C (npub...)    | |
|  |  - View logs         |<---|          ...                 | |
|  |  - Manage groups     |    |                              | |
|  +---------------------+    +----------+-------------------+ |
|           |                            |                      |
+--------------------------------------------------------------+
            |                            |
            v                            v
     +-------------+          +-----------------+
     |  SQLite DB  |          |  Nostr Relays   |
     |  (app data, |          |  (Marmot msgs)  |
     |   configs)  |          |                 |
     +-------------+          +-----------------+
```

### Bot Lifecycle

1. **Create** -- Dashboard creates a new account in `wnd` (generates Nostr keypair), publishes key packages
2. **Configure** -- Define commands, triggers, relay list, and webhook endpoints
3. **Invite** -- Share the bot's `npub` so group admins can add it to Marmot groups
4. **Listen** -- Botburrow subscribes to incoming messages for the bot's account via `wnd` streaming API
5. **React** -- Command engine parses messages and dispatches to handlers, triggers, or webhooks
6. **Respond** -- Bot sends replies back through `wnd` into the encrypted group

### Communication with wnd

Botburrow talks to a single `wnd` process over its Unix socket. The `account` param in each request specifies which bot is acting:

```json
// Send a message as bot_A
{"method": "send_message", "params": {"account": "npub_bot_A...", "group_id": "abc123", "message": "Hello!"}}

// Subscribe to live messages for bot_B (streaming)
{"method": "messages_subscribe", "params": {"account": "npub_bot_B...", "group_id": "abc123"}}

// Incoming message event
{"result": {"trigger": "NewMessage", "message": {"author": "npub...", "content": "/hello", "kind": 9}}}
```

## Features (Planned)

- **Bot Management** -- Create, configure, start/stop bots from a web dashboard
- **Custom Commands** -- Define `/command` handlers with custom logic
- **Triggers** -- React to message patterns, keywords, or events
- **Scheduled Actions** -- Cron-like tasks (reminders, digests, polling)
- **Custom Logic** -- Extend bots with your own scripts or webhook integrations
- **Multi-Group** -- A single bot can participate in multiple Marmot groups
- **Webhook Bridge** -- Forward messages to external HTTP endpoints, receive responses back
- **Logs & Analytics** -- Message history, uptime, activity metrics per bot

## Self-Hosting

Botburrow is designed to be self-hosted. Run it on your own hardware, a VPS, or a home server.

```bash
docker run -d -p 3000:80 -v botburrow_data:/rails/storage botburrow
```

### Packaging Targets

- **Docker** -- Primary distribution format
- **[Umbrel](https://umbrel.com/)** -- Community app store package
- **[Start9](https://start9.com/)** -- s9pk package for StartOS

## Tech Stack

| Layer           | Technology                                                                                      |
| --------------- | ----------------------------------------------------------------------------------------------- |
| Dashboard       | Ruby on Rails 8.1, Hotwire (Turbo + Stimulus)                                                   |
| Bot Runtime     | [whitenoise-rs](https://github.com/marmot-protocol/whitenoise-rs) `wnd` daemon (Rust, uses MDK) |
| IPC             | Unix socket, newline-delimited JSON (single wnd process)                                        |
| Database        | SQLite (app data + MLS state managed by wnd)                                                    |
| Background Jobs | Solid Queue                                                                                     |
| WebSockets      | Solid Cable (dashboard live updates)                                                            |
| Caching         | Solid Cache                                                                                     |
| Deployment      | Docker, Kamal                                                                                   |

## Development

### Prerequisites

- Ruby 4.0.2
- Rust toolchain (to build `wnd` from whitenoise-rs)
- SQLite 3

### Setup

```bash
git clone https://github.com/marmot-protocol/botburrow.git
cd botburrow
bin/setup
bin/dev
```

### Running Tests

```bash
bin/ci
```

## Status

Early development. The project is in the architecture and planning phase.

## License

TBD

## Links

- [Marmot Protocol](https://github.com/marmot-protocol/marmot) -- The messaging protocol
- [whitenoise-rs](https://github.com/marmot-protocol/whitenoise-rs) -- Rust runtime powering each bot (wn/wnd CLI & daemon)
- [MDK](https://github.com/marmot-protocol/mdk) -- Marmot Development Kit (used by whitenoise-rs)
- [WhiteNoise](https://github.com/marmot-protocol/whitenoise) -- Reference chat app (Flutter)
