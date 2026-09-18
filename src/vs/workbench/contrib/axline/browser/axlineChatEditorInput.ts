/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import { ThemeIcon } from '../../../../base/common/themables.js';
import { URI } from '../../../../base/common/uri.js';
import { EditorInputCapabilities, IUntypedEditorInput, Verbosity } from '../../../common/editor.js';
import { EditorInput } from '../../../common/editor/editorInput.js';
import { Codicon } from '../../../../base/common/codicons.js';
import { localize } from '../../../../nls.js';

/**
 * Singleton editor input that hosts the Axline Chat webview in the
 * Workbench Editor Area so it occupies the center screen position.
 */
export class AxlineChatEditorInput extends EditorInput {

	static readonly ID = 'workbench.input.axline.chat';
	static readonly EDITOR_ID = 'workbench.editor.axline.chat';

	override get typeId(): string {
		return AxlineChatEditorInput.ID;
	}

	override get editorId(): string | undefined {
		return AxlineChatEditorInput.EDITOR_ID;
	}

	override get resource(): URI | undefined {
		return undefined;
	}

	override get capabilities(): EditorInputCapabilities {
		return super.capabilities
			| EditorInputCapabilities.Singleton
			| EditorInputCapabilities.Readonly
			| EditorInputCapabilities.ExcludeFromEditorLimit;
	}

	override getName(): string {
		return localize('axlineChatEditor.name', 'Axline');
	}

	override getTitle(_verbosity?: Verbosity): string {
		return this.getName();
	}

	override getIcon(): ThemeIcon {
		return Codicon.commentDiscussion;
	}

	override matches(otherInput: EditorInput | IUntypedEditorInput): boolean {
		return otherInput === this || otherInput instanceof AxlineChatEditorInput;
	}

	override canReopen(): boolean {
		return true;
	}
}