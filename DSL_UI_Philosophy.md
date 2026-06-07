# DSL UI Design Philosophy

## The Observer UI
This UI is built on passive observation. It watches, listens, and organises — it does not interrogate, automate, or play for you.

## Core Principles

1. **The main console is sacred.** It shows what is happening right now — local, current, alive. Nothing gets injected into it. Nothing gets removed from it except text that belongs somewhere else.

2. **Other windows are the world around you.** Affects, group, scan, room, stats — these are ambient. They persist, they update quietly, they never demand attention.

3. **Move text, don't replace it.** If the game sends something, we redirect it to the right window. We do not manufacture fake output or inject text that the game didn't send.

4. **Automate to assist, not to play.** Spellup lists, respell reminders, disarm alerts — these help you make decisions faster. They never make decisions for you.

5. **Every module is optional.** Any window, feature, or system can be toggled off without breaking anything else. Nothing is required by anything else at the same layer or above.

6. **Passive observation over active interrogation.** Data is captured when it naturally appears during play. We never send commands just to collect data.

7. **Per-character awareness.** Every character has their own state. Switching characters switches context completely.

8. **Stale data beats spam.** If we don't have current data, we show the last known state. We never flood the server to stay current.

## Living Document
This file evolves as the project teaches us things about itself. When a decision is made that changes or adds to these principles, update this file and commit.
