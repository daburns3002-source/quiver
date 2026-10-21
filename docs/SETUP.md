# Setup — current state

Repo: https://github.com/daburns3002-source/quiver (public)
Local: `C:\Dev\ArcheroRoblox`

## Done

- Git repo created, two commits pushed to `main`
- Rokit pins Rojo 7.7.1, Wally 0.3.2, Selene 0.32.0, StyLua 2.6.0
- Rojo project maps `src/{shared,server,client}` into the DataModel; `rojo build` succeeds
- GitHub Actions CI green on first run: Selene, StyLua `--check`, `rojo build`, artifact upload
- Branch protection on `main`, enforced for admins too — verified by a rejected direct push
- `CLAUDE.md` / `AGENTS.md` written — builder and reviewer share one rulebook
- PR template points the reviewer at exploitability, the projectile pipeline and run state
- `.gitattributes` pins LF so local and CI format checks agree
- Docs: Archero teardown, eight-phase roadmap, architecture

Already on the machine and verified: Git 2.55, GitHub CLI 2.102 (authenticated as
`daburns3002-source`), Node 24.20, Python 3.12.10, uv 0.13.1, Roblox Studio,
`%LOCALAPPDATA%\Roblox\mcp.bat`.

## Branch protection on `main`

| Rule | Setting |
|---|---|
| Changes must go through a PR | yes |
| Required approving reviews | 0 — Codex reviews by comment, and GitHub won't let you approve your own PR |
| Required status check | `Lint, format and build`, strict (branch must be up to date) |
| Conversation resolution | required — **Codex's comments must be resolved before merge** |
| Linear history | required |
| Force pushes / deletions | blocked |
| Applies to admins | **yes** — verified by a rejected direct push as the repo owner |

Merges are squash-only and the branch is deleted on merge.

This means *you cannot push to `main` directly*, by design — it's what keeps Codex in the loop.
To bypass in an emergency:

```bash
gh api -X DELETE repos/daburns3002-source/quiver/branches/main/protection/enforce_admins
```

Re-enable it with `-X POST` on the same path.

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

### 2. Codex

Confirm access, and whether you will run the CLI locally or connect Codex to the GitHub repo.
The GitHub route is better — reviews land as PR comments I can read and act on directly.

## Deferred

**Blender** — Phase 5. Installing it before the game is validated is wasted setup.
When we get there: `winget install BlenderFoundation.Blender`, then
`claude mcp add blender uvx blender-mcp`, then enable the *Interface: Blender MCP* add-on and
start the server from the N-panel in the viewport.
