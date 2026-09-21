/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import { Disposable } from '../../../../base/common/lifecycle.js';
import { ILogService } from '../../../../platform/log/common/log.js';
import { ICommandService } from '../../../../platform/commands/common/commands.js';
import { IWorkbenchContribution, WorkbenchPhase, registerWorkbenchContribution2 } from '../../../common/contributions.js';
import { ILifecycleService, LifecyclePhase } from '../../../services/lifecycle/common/lifecycle.js';
import { IEditorGroupsService } from '../../../services/editor/common/editorGroupsService.js';
import { gettingStartedInputTypeId } from '../../welcomeGettingStarted/browser/gettingStartedInput.js';

/**
 * On startup, close any welcome editors and open the Axline Chat panel in the
 * center Editor Area by invoking the Axline extension's `axline.openChatPanel`
 * command. That command (Axline >= 0.4.98) creates a `WebviewPanel` hosting the
 * full Axline Chat UI in `ViewColumn.One`. The sidebar `axline.SidebarProvider`
 * view is intentionally not revealed -- Axline lives in the Editor Area per the
 * Option B layout strategy (see .agent/project/research/axline-chat-layout-2026-09.md).
 */
class AxlineStartupContribution extends Disposable implements IWorkbenchContribution {

	static readonly ID = 'workbench.contrib.axlineStartup';

	constructor(
		@ICommandService private readonly commandService: ICommandService,
		@IEditorGroupsService private readonly editorGroupsService: IEditorGroupsService,
		@ILifecycleService lifecycleService: ILifecycleService,
		@ILogService logService: ILogService,
	) {
		super();

		lifecycleService.when(LifecyclePhase.Restored).then(() => {
			this.closeWelcomeEditors();
			this.openAxlineChatPanel(logService);
		});
	}

	private closeWelcomeEditors(): void {
		for (const group of this.editorGroupsService.groups) {
			const welcomeEditors = group.editors.filter(editor => editor.typeId === gettingStartedInputTypeId);
			if (welcomeEditors.length > 0) {
				group.closeEditors(welcomeEditors);
			}
		}
	}

	private async openAxlineChatPanel(logService: ILogService): Promise<void> {
		try {
			// Executing this command activates the Axline extension (which declares
			// `onStartupFinished`) and opens the singleton `WebviewPanel` in the
			// Editor Area. Re-running it only reveals the existing panel.
			await this.commandService.executeCommand('axline.openChatPanel');
		} catch (error) {
			logService.warn('[axline-startup] failed to open Axline Chat panel', error);
		}
	}
}

registerWorkbenchContribution2(AxlineStartupContribution.ID, AxlineStartupContribution, WorkbenchPhase.AfterRestored);