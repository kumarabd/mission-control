# Client parity

The information tiers are deliberate: the web and macOS are the verbose consoles; iPad is focused; iPhone is crisp;
CarPlay and watch are very focused. Android is being brought up to the same product model, with parity work scheduled
after the repository consolidation.

| Surface | Web | macOS | iPad | iPhone | CarPlay | Watch | Android |
|---------|-----|-------|------|--------|---------|-------|---------|
| Today | verbose | verbose | focused | crisp | next items | glance | pending |
| Chat | verbose | verbose | full | full | voice | — | pending |
| Goals | verbose | verbose | focused | list | open goals | — | pending |
| Memory | World + filters | World + filters | full-width World | list | — | — | pending |
| Notifications | inbox + filters | inbox + filters | inbox | inbox | — | — | pending |
| Settings | account, agents, models, connections, appearance, advanced | account, agents, models, connections, appearance | limited | limited | — | — | pending |
| Finance / Travel | yes | — | — | — | — | — | — |
| Voice | browser live voice (web-only), text elsewhere | web-only live voice | on-device speech | on-device speech | voice-first | — | on-device speech |

## Rules

- A surface that exists on a client must show the same records and states as the web: loading, empty, error with a
  retry, and the same actions where the platform supports them.
- Information density changes between tiers; the underlying API and semantics do not.
- Web-only surfaces (Finance, Travel, browser live voice) stay explicitly web-only rather than appearing as disabled
  or empty screens on other clients.
- New shared palettes, typography, icons and API fields land in the shared reference (or every client) in the same
  change. Platform-specific UI code stays platform-specific.

## Shared foundations

1. `design/tokens.json` generates the core palette into CSS, Swift and Kotlin; `make foundations` checks for drift.
2. One canonical font set in `design/fonts/` is synced into the Apple bundles and Android by `make fonts`.
3. Shared gateway/Life fixtures, then generated contracts if a machine-readable schema exists.
4. Android parity: Today, Chat, Goals, Memory, Notifications and Settings against the same services.
