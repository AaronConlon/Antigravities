# AGENTS.md

Antigravities is a lightweight, high-performance desktop application for managing and switching Antigravity accounts. It maintains Google OAuth 2.0 PKCE authentication, refreshes and monitors model quota/rate-limits in the background, and seamlessly switches credentials across Antigravity IDE, Antigravity Classic, and the `agy` CLI tool.

It is written in pure Go (`CGO_ENABLED=0`) utilizing the **MyGo** desktop framework (`github.com/egoist/mygo`) with native declarative UI (`mygo/ui`) and a persistent system tray.

---

## 📚 Reference Repositories

| Repository | Path | Purpose & What to Reference |
|---|---|---|
| **MyGo** | `/Users/aaron/repos/mygo` | **Technical Stack & Framework**: Purego runtime architecture, zero-CGO desktop runtime, native declarative UI (`mygo/ui`), main-thread event loop, and cross-platform build guidelines. |
| **Antigravity-Manager** | `/Users/aaron/repos/Antigravity-Manager` | **Business Logic Reference**: Port logic directly from Rust modules: OAuth loopback server (`oauth.rs`), quota calculation (`quota.rs`), account storage (`account.rs`), `state.vscdb` SQLite injection (`db.rs`), process management and macOS Keychain sync for `agy` CLI (`integration.rs`). |

---

## ⚡ Hard Rules & Constraints

1. **Strictly Zero Cgo (`CGO_ENABLED=0`)**:
   - Every package and dependency must compile with `CGO_ENABLED=0`.
   - Never write `import "C"`. Native OS interop is handled exclusively via `purego` (macOS/Linux) or `syscall` (Windows).
   - For SQLite operations (`state.vscdb`), use the pure-Go driver (`modernc.org/sqlite`).
2. **Main Thread UI Discipline**:
   - MyGo view evaluations and UI updates must execute on the main OS thread.
   - Background goroutines (OAuth callbacks, quota timers, process watchers) must never touch UI components directly; dispatch through `app.OnMain(...)` or thread-safe channels.
3. **No Web/Node Runtime Required**:
   - UI is drawn directly by MyGo's native declarative UI toolkit (`github.com/egoist/mygo/ui`).
   - Do not add Node.js, Bun, Vite, or webview bundler scripts to the application build pipeline. Deliverable is a single, self-contained native Go binary.
4. **macOS-First Priority**:
   - Primary target is macOS (`darwin/arm64` and `darwin/amd64`), with native macOS Keychain and system notification integration.
   - Windows and Linux support must maintain clean architecture boundaries without breaking the macOS build.
5. **No Silent Auto-Switching**:
   - Quota inspections run in the background to update quota caches and status badges.
   - Account switching **must always be explicitly triggered by the user** in the tray menu or UI window to prevent unexpected editor restarts or state resets during active coding sessions.

---

## 🛠 Commands (Verified)

| Command | Purpose | ~Time |
|---|---|---|
| `go build ./...` | Build all Go packages locally (`CGO_ENABLED=0`) | ~2s |
| `go run .` | Launch Antigravities desktop application with tray and native UI | ~1s |
| `go test -v ./...` | Run unit tests across all internal packages | ~3s |
| `go vet ./...` | Run standard Go static analysis | ~1s |
| `GOOS=darwin GOARCH=arm64 go build -o build/antigravities-darwin-arm64 .` | Compile release binary for Apple Silicon | ~3s |
| `GOOS=darwin GOARCH=amd64 go build -o build/antigravities-darwin-amd64 .` | Compile release binary for Intel Mac | ~3s |
| `GOOS=windows GOARCH=amd64 go build -o build/antigravities-windows.exe .` | Verify Windows cross-compilation | ~3s |
| `GOOS=linux GOARCH=amd64 go build -o build/antigravities-linux .` | Verify Linux cross-compilation | ~3s |

---

## 📂 Architecture & Directory Layout

```text
.
├── AGENTS.md               # Agent guidelines and architectural handbook
├── go.mod                  # Go module definition
├── go.sum                  # Dependency lockfile
├── main.go                 # App entrypoint, MyGo lifecycle, tray initialization
├── internal/
│   ├── account/            # Account entity, accounts.json persistence, file mutex locks
│   ├── config/             # App configuration, paths, polling interval settings
│   ├── integration/        # External app integrations & credential injection
│   │   ├── db.go           # state.vscdb manipulation via modernc.org/sqlite
│   │   ├── keychain.go     # macOS Keychain sync for agy CLI credentials
│   │   ├── process.go      # Antigravity IDE / Classic process detection and restart
│   │   └── protobuf.go     # Unified state sync protobuf payload serialization
│   ├── oauth/              # Google OAuth 2.0 PKCE flow, loopback HTTP server, token refresh
│   ├── quota/              # Quota API client, model rate-limits, tier & remaining quota parser
│   └── ui/                 # MyGo native declarative UI
│       ├── account_card.go # Account row component (email, active indicator, switch button)
│       ├── quota_view.go   # Quota progress bars and model limit statistics
│       ├── tray.go         # System tray icon, menu entries, quick switch actions
│       └── window.go       # Main management flyout / popover window
└── assets/                 # App icon (.png / .icns), tray icons (idle / warning / error)
```

---

## 🧩 Business Logic & Technical Implementation Guidelines

### 1. Google OAuth 2.0 & Token Refresh
- **Port source**: `Antigravity-Manager/src-tauri/src/modules/oauth.rs`.
- Standard Google Client ID & Secret matching Antigravity ecosystem.
- Start a local HTTP loopback server (ephemeral port or fixed fallback) to capture OAuth redirect code.
- Compute SHA-256 PKCE challenge & verifier.
- Automatically refresh access tokens `TOKEN_REFRESH_SKEW_SECONDS` (900s) prior to expiration.

### 2. Quota Refresh & Polling
- **Port source**: `Antigravity-Manager/src-tauri/src/modules/quota.rs`.
- Query quota endpoints using the active/stored access tokens.
- Parse model-specific buckets (e.g. `gemini-2.5-pro`, `gemini-2.5-flash`, Claude models).
- Background ticker runs at a configurable interval (e.g. every 10–30 minutes) to update in-memory and on-disk quota caches without disturbing the UI.
- Update tray tooltip / icon badge based on lowest model percentage or exhaustion state.

### 3. Account Persistence (`accounts.json`)
- **Port source**: `Antigravity-Manager/src-tauri/src/modules/account.rs`.
- Path: `mygo.App.UserDataDir() + "/accounts.json"`.
- Use atomic write (`write to temp file + rename`) protected by a process-level `sync.RWMutex`.
- Structure format aligns 1:1 with `Antigravity-Manager`'s JSON schema to ensure bi-directional export/import compatibility.

### 4. System Switching & IDE Injection
- **Port source**: `Antigravity-Manager/src-tauri/src/modules/db.rs` & `integration.rs`.
- Target scopes:
  - `ide`: Antigravity IDE (`Antigravity IDE/User/globalStorage/state.vscdb`)
  - `classic`: Antigravity Classic (`Antigravity/User/globalStorage/state.vscdb`)
  - `agy`: CLI credentials in macOS Keychain (`security add-generic-password -s "antigravity" -a ...`)
- SQLite injection:
  - Write protobuf-encoded base64 payload into `ItemTable` under keys:
    - `antigravityUnifiedStateSync.oauthToken`
    - `antigravityUnifiedStateSync.userStatus`
    - `antigravityOnboarding` (`"true"`)
  - Delete stale `jetskiStateSync.agentManagerInitState` to prevent historical user ID mismatches.
  - Always back up `state.vscdb` to `state.vscdb.bak` before executing updates.
  - Gracefully notify or restart the target application process after injection.

---

## 🧭 Heuristics & Decision Matrix

| Scenario | Action |
|---|---|
| Modifying SQLite database | Always check if the IDE process is alive; create a `.bak` backup before opening connection. |
| Background quota query fails (401/403) | Mark token as expired/invalid, notify via tray badge, do not throw fatal panic. |
| Network offline | Serve cached quota data with timestamp; indicate offline status in UI. |
| Adding third-party Go dependencies | Verify `go test -tags=nowebview` or `CGO_ENABLED=0` builds cleanly; reject CGO packages. |
| UI state change requested from goroutine | Wrap in `app.OnMain(func() { ... })`. |

---

## 🚫 Boundaries & Safety

### Always Do
- Enforce `CGO_ENABLED=0` across all target platforms.
- Atomic file writes for `accounts.json` (tempfile + sync + rename).
- Keep account data backwards and forwards compatible with `Antigravity-Manager`.
- Test Go packages with standard table-driven unit tests.

### Ask First
- Introducing non-standard dependencies or third-party frameworks outside `mygo` / standard library.
- Altering the `state.vscdb` protobuf schema or injecting unexpected keys into VS Code storage.
- Adding destructive process termination (`kill -9`) without prompting user for unsaved workspace files.

### Never Do
- Never add `import "C"` under any circumstances.
- Never silently switch the active account in the background without explicit user click or confirmation.
- Never write plain credentials to log files or unencrypted public repositories.
- Never block the MyGo main event loop with synchronous network requests or heavy file I/O.
