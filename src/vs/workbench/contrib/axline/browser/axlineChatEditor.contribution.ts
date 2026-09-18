/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import { Registry } from '../../../../platform/registry/common/platform.js';
import { EditorPaneDescriptor, IEditorPaneRegistry } from '../../../browser/editor.js';
import { EditorExtensions } from '../../../common/editor.js';
import { SyncDescriptor } from '../../../../platform/instantiation/common/descriptors.js';
import { AxlineChatEditorInput } from './axlineChatEditorInput.js';
import { AxlineChatEditor } from './axlineChatEditor.js';

// Register the Axline Chat editor pane so it can host AxlineChatEditorInput
// in a Workbench Editor Part (the center area of the layout).
Registry.as<IEditorPaneRegistry>(EditorExtensions.EditorPane).registerEditorPane(
	EditorPaneDescriptor.create(AxlineChatEditor, AxlineChatEditor.ID, 'Axline'),
	[new SyncDescriptor(AxlineChatEditorInput)],
);