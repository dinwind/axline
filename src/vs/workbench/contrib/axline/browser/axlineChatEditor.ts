/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import * as DOM from '../../../../base/browser/dom.js';
import { CancellationToken } from '../../../../base/common/cancellation.js';
import { Dimension } from '../../../../base/browser/dom.js';
import { mainWindow } from '../../../../base/browser/window.js';
import { EditorPane } from '../../../browser/parts/editor/editorPane.js';
import { IEditorOpenContext } from '../../../common/editor.js';
import { EditorInput } from '../../../common/editor/editorInput.js';
import { IEditorOptions } from '../../../../platform/editor/common/editor.js';
import { IEditorGroup } from '../../../services/editor/common/editorGroupsService.js';
import { IStorageService } from '../../../../platform/storage/common/storage.js';
import { ITelemetryService } from '../../../../platform/telemetry/common/telemetry.js';
import { IThemeService } from '../../../../platform/theme/common/themeService.js';
import { IWebviewService } from '../../webview/browser/webview.js';
import { AxlineChatEditorInput } from './axlineChatEditorInput.js';

/**
 * Editor pane that hosts an Axline Chat webview in the Workbench Editor Area.
 *
 * Uses the native webview service (IWebviewService.createWebviewElement) to render
 * a welcome page. In a future iteration this will embed the full Axline Chat UI.
 */
export class AxlineChatEditor extends EditorPane {

	static readonly ID = AxlineChatEditorInput.EDITOR_ID;

	private container!: HTMLElement;

	constructor(
		group: IEditorGroup,
		@ITelemetryService telemetryService: ITelemetryService,
		@IThemeService themeService: IThemeService,
		@IStorageService storageService: IStorageService,
		@IWebviewService private readonly webviewService: IWebviewService,
	) {
		super(AxlineChatEditor.ID, group, telemetryService, themeService, storageService);
	}

	protected override createEditor(parent: HTMLElement): void {
		this.container = DOM.$('.axline-chat-editor');
		this.container.style.cssText = 'display:flex;flex-direction:column;height:100%;width:100%';

		// Create a native webview to host Axline Chat
		const webview = this.webviewService.createWebviewElement({
			title: 'Axline',
			options: {
				enableFindWidget: false,
			},
			contentOptions: {
				allowScripts: true,
				localResourceRoots: [],
			},
			extension: undefined,
		});

		webview.mountTo(this.container, mainWindow);
		webview.setHtml(this.getSplashHtml());

		parent.appendChild(this.container);
	}

	private getSplashHtml(): string {
		const css = '*{margin:0;padding:0;box-sizing:border-box}html,body{height:100%;display:flex;align-items:center;justify-content:center;font-family:-apple-system,BlinkMacSystemFont,\'Segoe UI\',Roboto,Helvetica,Arial,sans-serif;background:var(--vscode-editor-background);color:var(--vscode-editor-foreground)}.axline-splash{text-align:center;max-width:400px;padding:2rem}.axline-splash h1{font-size:2rem;font-weight:600;margin-bottom:1rem;color:var(--vscode-textLink-foreground)}.axline-splash p{font-size:.95rem;line-height:1.6;opacity:.8;margin-bottom:.5rem}';
		return `<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<style>${css}</style>
</head>
<body>
<div class="axline-splash">
<h1>Axline</h1>
<p>Axline Chat is now running in the Editor Area.</p>
<p>The Axline extension will load its full UI here.</p>
</div>
</body>
</html>`;
	}

	override async setInput(input: EditorInput, options: IEditorOptions, context: IEditorOpenContext, token: CancellationToken): Promise<void> {
		if (this.input && input.matches(this.input)) {
			return;
		}
		await super.setInput(input, options, context, token);
	}

	override layout(dimension: Dimension): void {
		if (this.container) {
			DOM.size(this.container, dimension.width, dimension.height);
		}
	}

	override focus(): void {
		// Future: focus the webview
	}
}