# Remodex Adaptation Plan

Pulse Oscilla is intentionally moving toward the Remodex product model: an iPhone-native chat surface that controls a local development machine through a secure paired bridge. Remodex is ISC-licensed, and any directly copied or substantially derived code must retain its copyright and permission notice.

## Reference Architecture

Remodex separates the system into these major layers:

- `CodexService`: app-owned connection state, sync, incoming event routing, trusted reconnect, and thread/message lifecycle.
- `CodexMessage`: normalized turn timeline model with user, assistant, system, tool, file-change, command, plan, and structured-prompt variants.
- `TurnView`: the feature shell for one conversation.
- `TurnConversationContainerView`: timeline, empty state, pinned plan accessory, and composer slot.
- `TurnTimelineView`: bottom-anchored streaming list with tool-burst grouping.
- `TurnComposerView`: native input, queued drafts, slash/file/skill autocomplete, model/reasoning/access controls, stop/send actions.
- `phodex-bridge`: Node bridge that keeps Codex on the Mac, forwards structured events, handles git/workspace operations, and supports trusted reconnect.

## Pulse Oscilla Mapping

- Remodex `CodexService` maps to `BridgeConnection`.
- Remodex `CodexMessage` maps to `AgentChatMessage` plus `AgentWorkItem`.
- Remodex `TurnView` maps to `WorkspaceChatView`.
- Remodex `TurnConversationContainerView` maps to `WorkspaceConversationContainer`.
- Remodex `TurnTimelineView` maps to `WorkspaceMessageRow` and `WorkspaceWorkItemBurst`.
- Remodex `TurnComposerView` maps to `WorkspaceComposerView`.
- Remodex `AdaptiveGlassModifier` maps to `WorkspaceGlass`.
- Remodex Codex-only bridge maps to Pulse Oscilla `AgentOrchestrator`, with Codex, Claude Code, OpenCode, and custom provider support.

## Implemented In This Pass

- Replaced the tabbed workspace shell with a single conversation-first screen.
- Split the chat UI into Remodex-style primitives: toolbar, conversation container, empty state, composer, tool sheet, message row, work-item burst, and glass modifier.
- Made the UI system-background based, so it is Remodex-light by default and true black in dark mode.
- Kept all major interactive components on adaptive glass surfaces with iOS 26 Liquid Glass support and material fallback.
- Copied Remodex visual assets and bundled the Geist, Geist Mono, and JetBrains Mono font families.
- Added a Remodex-compatible `AppFont` implementation, `adaptiveGlass` APIs, and haptic feedback helper so more reference components can be adapted directly.
- Added Settings appearance controls for font selection and Liquid Glass fallback.
- Promoted assistant text streaming to the main answer area instead of burying it inside shell-output cards.
- Ported the key timeline reducer behavior for multi-item turns: assistant/activity interleaving, thinking-row collapse, command echo removal, user-message dedupe, file-change dedupe, and assistant dedupe.
- Normalized agent launch behavior so Codex, Claude Code, and OpenCode receive prompts as command arguments, while custom agents receive the prompt over stdin.
- Added agent approval response support so the phone can answer host-side approval prompts without leaving the chat.
- Installed the latest physical-device build successfully on the plugged-in iPhone; command-line launch was blocked by a CoreDevice initialization timeout.

## Next Compatibility Targets

- Add persisted conversations and finish the thread list/sidebar equivalent to Remodex `SidebarView`.
- Add queued follow-up prompts and active-run steering equivalent to Remodex queued drafts.
- Add plan mode as a first-class `agent.run` mode with pinned plan accessories.
- Add file mentions, slash commands, and skill references in the composer.
- Add trusted reconnect/session resume so a fresh QR is not required after host restarts.
- Add optional relay/Tailscale mode for non-LAN usage while preserving local-only operation.
