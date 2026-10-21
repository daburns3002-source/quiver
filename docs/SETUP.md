# Setup — current state

Repo: https://github.com/daburns3002-source/quiver (private)
Local: `C:\Dev\ArcheroRoblox`

## Done

- Git repo created, two commits pushed to `main`
- Rokit pins Rojo 7.7.1, Wally 0.3.2, Selene 0.32.0, StyLua 2.6.0
- Rojo project maps `src/{shared,server,client}` into the DataModel; `rojo build` succeeds
- GitHub Actions CI green on first run: Selene, StyLua `--check`, `rojo build`, artifact upload
- `CLAUDE.md` / `AGENTS.md` written — builder and reviewer share one rulebook
- PR template points the reviewer at exploitability, the projectile pipeline and run state
- `.gitattributes` pins LF so local and CI format checks agree
- Docs: Archero teardown, eight-phase roadmap, architecture

Already on the machine and verified: Git 2.55, GitHub CLI 2.102 (authenticated as
`daburns3002-source`), Node 24.20, Python 3.12.10, uv 0.13.1, Roblox Studio,
`%LOCALAPPDATA%\Roblox\mcp.bat`.

## Blocked on you

### 1. Connect the Studio MCP server

This is the only thing standing between here and Phase 1. `mcp.bat` exists, so the server has
been switched on before, but it is not wired to this Claude Code session.

1. Open Roblox Studio, sign in, open any place.
2. **Assistant → `…` → Manage MCP Servers → enable "Enable Studio as MCP server"**.
3. In the same panel, expand **Quick connect** and turn on **Claude Code**.
4. Restart Studio and Claude Code.
5. Back in **Manage MCP Servers**, confirm the green connected-clients indicator.

Manual fallback if Quick connect does not list Claude Code:

```json
{
  "mcpServers": {
    "Roblox_Studio": {
      "command": "cmd.exe",
      "args": ["/c", "%LOCALAPPDATA%\\Roblox\\mcp.bat"]
    }
  }
}
```

### 2. Decide: private or public

Branch protection on a private repo needs GitHub Pro — the API refused it with
*"Upgrade to GitHub Pro or make this repository public to enable this feature."*

Options: make the repo public (free branch protection, and Codex's GitHub integration is
simpler), pay for Pro, or run without protection and rely on the PR workflow by convention.
Running without protection is survivable for now; CI still runs on every PR, it just is not
enforced as a merge gate.

### 3. Codex

Confirm access, and whether you will run the CLI locally or connect Codex to the GitHub repo.
The GitHub route is better — reviews land as PR comments I can read and act on directly.

## Deferred

**Blender** — Phase 5. Installing it before the game is validated is wasted setup.
When we get there: `winget install BlenderFoundation.Blender`, then
`claude mcp add blender uvx blender-mcp`, then enable the *Interface: Blender MCP* add-on and
start the server from the N-panel in the viewport.
