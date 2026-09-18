/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import { Disposable } from '../../../../base/common/lifecycle.js';
import { ILogService } from '../../../../platform/log/common/log.js';
import { IWorkbenchContribution, WorkbenchPhase, registerWorkbenchContribution2 } from '../../../common/contributions.js';
import { ILifecycleService, LifecyclePhase } from '../../../services/lifecycle/common/lifecycle.js';
import { IEditorService } from '../../../services/editor/common/editorService.js';
import { IEditorGroupsService } from '../../../services/editor/common/editorGroupsService.js';
import { gettingStartedInputTypeId } from '../../welcomeGettingStarted/browser/gettingStartedInput.js';
import { AxlineChatEditorInput } from './axlineChatEditorInput.js';

/**
 * On startup, close any welcome editors and open the Axline Chat editor
 * in the center Editor Area. The Axline view sidebar is intentionally
 * not revealed -- Axline now lives in the Editor Area per the Option B
 * layout strategy (see .agent/project/research/axline-chat-layout-2026-09.md).
 */
class AxlineStartupContribution extends Disposable implements IWorkbenchContribution {

	static readonly ID = 'workbench.contrib.axlineStartup';

	constructor(
		@IEditorService private readonly editorService: IEditorService,
		@IEditorGroupsService private readonly editorGroupsService: IEditorGroupsService,
		@ILifecycleService lifecycleService: ILifecycleService,
		@ILogService logService: ILogService,
	) {
		super();

		lifecycleService.when(LifecyclePhase.Restored).then(() => {
			this.closeWelcomeEditors();
			this.openAxlineChatEditor(logService);
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

	private async openAxlineChatEditor(logService: ILogService): Promise<void> {
		try {
			const input = new AxlineChatEditorInput();
			await this.editorService.openEditor(input, { pinned: true, revealIfOpened: true });
		} catch (error) {
			logService.warn('[axline-startup] failed to open Axline Chat editor', error);
		}
	}
}

registerWorkbenchContribution2(AxlineStartupContribution.ID, AxlineStartupContribution, WorkbenchPhase.AfterRestored);