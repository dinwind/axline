# Axline Extension: Dual Webview API Support (Sidebar + Editor Area)

> **Created**: 2026-09-18
> **For**: Axline extension team
> **From**: AxLines (VS Code fork) dev team

---

## Core Principle (Non-Negotiable)

The extension **MUST support both** `WebviewViewProvider` (Side Bar) **and**
`WebviewPanel` (Editor Area) **simultaneously**. These are two distinct,
coexisting VS Code webview host APIs. Supporting one must never break or
degrade the other.

Which surface is active is a **user/host layout preference**, not an extension
capability. The extension exposes both capabilities; the host (or user) decides
where the chat UI appears.

---

## Context

AxLines is restructuring its Workbench layout so that:

- **Left (Primary Side Bar)**: Workspace file explorer
- **Center (Editor Area)**: Axline Chat (full interactive UI)
- **Right (Secondary Side Bar)**: Code Editor, Terminal, Git

Currently the Axline extension only registers `axline.SidebarProvider`
(WebviewViewProvider). For center placement, the extension must additionally
register a `WebviewPanel` command, while keeping the sidebar provider working.
---

## Two Surfaces, One Code Path

Both surfaces must render the **same React app** (`webview-ui/build/index.html`)
and speak the **same `postMessage` protocol**. The only difference is the host
container (`WebviewView` vs `WebviewPanel`).

```
                    +-----------------------------+
                    |   webview-ui/build (React)  |
                    +-----------------------------+
                       |                     |
              postMessage              postMessage
                       |                     |
        +--------------v-----------+  +------v------------------+
        | WebviewViewProvider     |  | WebviewPanel command      |
        | (axline.SidebarProvider)|  | (axline.openChatPanel)    |
        | -> Side Bar / Panel     |  | -> Editor Area            |
        +-------------------------+  +---------------------------+
```

The webview content builder and message dispatcher should be **shared** so the
two surfaces never drift apart.

---

## Required Changes

### 1. Keep Sidebar `WebviewViewProvider` Working

**Requirement**: The existing `axline.SidebarProvider` must continue to
register and function exactly as it does today. No regression allowed.

### 2. Add `createWebviewPanel` Command

**What**: Register `axline.openChatPanel` that creates a `WebviewPanel` hosting
the same chat UI.

**Why**: `WebviewPanel` renders in the Editor Area; `WebviewViewProvider` only
renders in Side Bar / Panel.

**Sketch**:

```typescript
const openPanelCmd = vscode.commands.registerCommand('axline.openChatPanel', () => {
    const panel = vscode.window.createWebviewPanel(
        'axlineChat', vscode.ViewColumn.One,
        {
            enableScripts: true,
            retainContextWhenHidden: true,
            localResourceRoots: [
                vscode.Uri.joinPath(context.extensionUri, 'webview-ui', 'build'),
            ],
        },
    );
    panel.webview.html = getWebviewContent(context.extensionUri, panel.webview);
    panel.webview.onDidReceiveMessage((msg) => handleMessage(msg, panel.webview));
    panel.onDidDispose(() => { /* cleanup */ });
});
context.subscriptions.push(openPanelCmd);
```

### 3. Singleton Panel Management

```typescript
let currentPanel: vscode.WebviewPanel | undefined;

function openChatPanel(ctx: vscode.ExtensionContext): vscode.WebviewPanel {
    if (currentPanel) {
        currentPanel.reveal(vscode.ViewColumn.One);
        return currentPanel;
    }
    currentPanel = vscode.window.createWebviewPanel(
        'axlineChat', 'Axline', vscode.ViewColumn.One,
        { enableScripts: true, retainContextWhenHidden: true },
    );
    currentPanel.onDidDispose(() => { currentPanel = undefined; }, null, ctx.subscriptions);
    return currentPanel;
}
```

### 4. Shared Message Protocol

Both surfaces must use the **same** message protocol. The panel's
`onDidReceiveMessage` handler must invoke the same dispatcher as the sidebar.

- [ ] All sidebar message types handled by the panel dispatcher
- [ ] Configuration (API keys, model settings) passed on creation
- [ ] Task execution results sent back to webview
- [ ] MCP server status updates reach both surfaces

### 5. Coexistence / Surface Selection (Host Controlled)

The host (AxLines) decides which surface is shown. The extension must not
assume one or the other:

- When panel opens, host hides the sidebar view (via
  `workbench.action.closeSidebar` or view container visibility)
- When panel is closed and user prefers sidebar, the sidebar view must still
  be available and functional

```typescript
// Host-side (AxLines) calls, not extension responsibility:
await vscode.commands.executeCommand('axline.openChatPanel');
// and/or
await vscode.commands.executeCommand('axline.SidebarProvider.focus');
```

### 6. `package.json` Contributions

```jsonc
"contributes": {
  "commands": [
    { "command": "axline.openChatPanel", "title": "Axline: Open Chat (Editor)" }
  ]
}
```

The existing `viewsContainers` / `views` entries for `axline.SidebarProvider`
remain unchanged.
---

## Non-Goals

- Neither surface is deprecated or removed — both must remain usable
- `webview-ui/` requires no modification — the same React app serves both
- No auto-switching logic in the extension — surface selection is host-driven

---

## Testing Checklist (Both Surfaces)

**Sidebar (regression)**:
1. `axline.SidebarProvider` still renders and is fully interactive
2. Messages, config, and MCP status work as before

**Editor Area (new)**:
3. `axline.openChatPanel` opens the chat in the Editor Area
4. Re-running the command reveals the existing panel (singleton)
5. Closing the panel allows reopening without state loss

**Coexistence**:
6. Opening the panel and the sidebar view can both work; no double UI clash
7. Which surface is visible follows host layout, not extension state

---

## References

- [VS Code Webview Panel API](https://code.visualstudio.com/api/extension-guides/webview)
- [VS Code Webview View Provider API](https://code.visualstudio.com/api/references/vscode-api#WebviewViewProvider)
- AxLines layout research: `.agent/project/research/axline-chat-layout-2026-09.md`