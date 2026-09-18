# Axline Extension Changes Needed for Center-Editor Layout

> **Created**: 2026-09-18
> **For**: Axline extension team
> **From**: AxLines (VS Code fork) dev team

---

## Context

AxLines is restructuring its Workbench layout so that:

- **Left (Primary Side Bar)**: Workspace file explorer
- **Center (Editor Area)**: Axline Chat (full interactive UI)
- **Right (Secondary Side Bar)**: Code Editor, Terminal, Git

Currently the Axline extension only contributes a `WebviewViewProvider` (sidebar-based webview), which cannot occupy the Editor Area. The extension needs to additionally support the `WebviewPanel` API so the chat UI can open in the center.
---

## Required Changes

### 1. Add a `createWebviewPanel` Command

**What**: Register a command `axline.openChatPanel` that creates a `WebviewPanel` hosting the same chat UI as the sidebar.

**Why**: `WebviewPanel` renders in the Editor Area. `WebviewViewProvider` only renders in Side Bar / Panel.

**Implementation sketch**:

```typescript
// In extension activation:
const openPanelCmd = vscode.commands.registerCommand('axline.openChatPanel', () => {
    const panel = vscode.window.createWebviewPanel(
        'axlineChat',           // viewType
        'Axline',               // tab title
        vscode.ViewColumn.One,  // first editor column
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

**Requirements**:

- The host (AxLines) will call `vscode.commands.executeCommand('axline.openChatPanel')` on startup
- Panel must be **singleton** — re-calling reveals existing panel instead of creating duplicate
- Webview content = same React app as sidebar (`webview-ui/build/index.html`)
- Message passing must support the same protocol as sidebar view

### 2. Singleton Panel Management

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
    currentPanel.onDidDispose(
        () => { currentPanel = undefined; },
        null, ctx.subscriptions,
    );
    return currentPanel;
}
```

### 3. Trigger on Activation

**Recommended**: The host (AxLines) calls `executeCommand('axline.openChatPanel')` on startup. The extension just provides the command.

### 4. Message Protocol Compatibility

The panel webview must handle the same `postMessage` protocol as the sidebar:

- [ ] All sidebar message types handled in `onDidReceiveMessage`
- [ ] Configuration (API keys, model settings) passed on creation
- [ ] Task execution results sent back to webview
- [ ] MCP server status updates reach the panel

### 5. Hide Sidebar View When Panel Opens

```typescript
// When panel is created, hide the sidebar Axline view
await vscode.commands.executeCommand('workbench.action.closeSidebar');
```

---

## Non-Goals

- Sidebar view does not need removal — it can remain as fallback
- `package.json` needs only new command registration, no structural changes
- `webview-ui/` needs no modification — same React app works in both modes

---

## Testing Checklist

1. On startup, Axline Chat panel opens in Editor Area
2. Sidebar Axline view is hidden/collapsed
3. Chat UI is fully interactive (typing, sending, receiving)
4. Closing/reopening panel restores state
5. Opening code file opens in new editor group / Secondary Side Bar (does not close chat)

---

## References

- [VS Code Webview Panel API](https://code.visualstudio.com/api/extension-guides/webview)
- AxLines layout research: `.agent/project/research/axline-chat-layout-2026-09.md`