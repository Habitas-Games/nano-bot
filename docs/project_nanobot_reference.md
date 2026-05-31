# nano-bot — Microsoft Imagine Cup Reference

Source material for replicating the nano-bot competition in Godot.

---

## Origins

A **"Programming Battle"** category in Microsoft's Imagine Cup (2005–2008). Students programmed AI strategies in **C# or VB.NET** for a team of nanobots navigating inside the human body. Players didn't control the game in real time — they wrote code; the game simulated the strategy turn-by-turn in a 3D environment.

---

## The Map

- **200×200 cell grid** representing human tissue
- Cell types determine movement cost (turns to traverse):
  - **Low-density tissue** (red): 2 turns/step
  - **Medium-density** (blue): 3 turns/step
  - **High-density** (green): 4 turns/step
  - **Bone cells** (black): impassable
- **Bloodstreams** — directional currents crossing the map:
  - Moving against the current: +2 turns penalty
  - Moving with the current: −2 turns (minimum 1 turn/step)
- **Habitas Points** — fixed target locations (scoring objectives)
- **AZN Points** — collectible resource nodes scattered on the map

---

## Nanobot Types

| Type | HP | Scan | AZN Capacity | Transfer | Notes |
|---|---|---|---|---|---|
| **NanoAI** | 20 | 5 | — | — | One per player. If destroyed, all other bots stop acting. |
| **NanoExplorer** | 20 | 30 | — | — | Not slowed by blood density. |
| **NanoCollector** | 50 | — | 20 AZN | 5/turn | Can attack (MaxDmg 5, Range 12). |
| **NanoContainer** | 60 | — | 60 AZN | 5/turn | Cannot attack. |
| **NanoNeedle** | 150 | — | 100 AZN | — | Stationary; placed on Habitas Points; scores points. |
| **NanoIPCreator** | 20 | 30 | — | — | Creates new injection points; self-destructs after 500 turns. |
| **NanoBlocker** | 90 | — | — | — | Adds +6 turn penalty to any enemy crossing it. |
| **NanoWall** | 100 | — | — | — | Physical barrier; destroyed after 50 turns. |

---

## Core Game Loop

1. Player picks an **injection point** (spawn location) — once, before the match starts.
2. `WhatToDoNext()` is called **1500 times** — one invocation per game turn.
3. Each bot executes one action per turn.
4. Enemies (white blood cells) roam the map and kill bots on contact.

### Bot Actions

| Action | Description |
|---|---|
| `MoveTo(x, y)` | Navigate toward a target cell |
| `CollectFrom(entity)` | Gather AZN molecules from an AZN node |
| `TransferTo(entity)` | Deposit AZN into a NanoNeedle or NanoContainer |
| `DefendTo(target)` | Attack an enemy bot |
| `Build(type)` | Spawn a new nanobot |
| `OpenIP` | NanoIPCreator creates a new injection point (then starts 500-turn countdown) |
| `StopMoving` | Halt movement |
| `ForceAutoDestruction` | Self-destruct |

---

## Distance & Pathfinding

- **Euclidean distance** — used to check attack range.
- **Manhattan distance** — used for practical turn-count pathfinding.

---

## Scoring

NanoNeedle placed on a Habitas Point:
- No AZN deposited: **5 points**
- With AZN: **20 points base + 2 points per AZN molecule**

---

## Enemies

- Static and mobile (white blood cells) patrol the map.
- Kill bots on contact or within attack range.
- NanoCollector can fight back; NanoContainer cannot.

---

## Competition Rounds (Original Format)

| Round | Mode | Description |
|---|---|---|
| **Round 1** | Discovery Mode | GUI-based strategy editor, map fully visible, simple navigation objectives. |
| **Round 2** | Intermediate Mode | Code-only, map hidden at runtime, one enemy team competing simultaneously. |
| **Finals** | Expert Mode | 24-hour coding marathon, top 6 teams per country in Paris. |

---

## Original SDK Architecture (C# / VB.NET)

```
PH.Common.Player       — base player class
  ├── ChooseInjectionPoint()   — called once at start
  └── WhatToDoNext()           — called each of 1500 turns

PH.Common.NanoBot      — base bot class
  └── State property

PH.Map.Tissue          — the 200×200 map
  ├── Entities         — all objects on map (AZN, bots, Habitas Points)
  └── BloodStreams      — directional current collection

[Characteristics]      — attribute to define bot stat budget
```

Each nanobot assembly was compiled and dropped into a `/players` folder for the engine to load.

---

## Godot Replication Notes

| Original | Godot Equivalent |
|---|---|
| 200×200 tissue grid | `TileMap` node or custom `GridMap` |
| Blood density cells | Tile types with movement cost metadata |
| Bloodstream currents | Directional vectors per cell row/column |
| Turn-based loop (1500 turns) | `_physics_process` stepped simulation |
| C# strategy assembly | GDScript files loaded at runtime via `load()` |
| 3D visualizer | 2D top-down (simpler), or 3D scene |
| Habitas Points | Marked `Area2D` nodes on the map |
| AZN resources | `Node2D` collectibles with quantity |

**Key design challenge**: sandboxing user-submitted GDScript strategies so they can only call allowed bot actions and cannot access the full scene tree.

**Suggested grid size for prototyping**: 50×50 (scale up later).

---

## Sources

- [Guide to The Imagine Cup; nano-bot (AI) | Microsoft Learn](https://learn.microsoft.com/en-us/archive/blogs/edunhill/guide-to-the-imagine-cup-project-hoshimi-ai-competition)
- [Take the nano-bot challenge | GamesRadar+](https://www.gamesradar.com/take-the-project-hoshimi-challenge/)
- [ImagineCup2005 Visual Gaming 3D Engine · Aras Pranckevičius](https://aras-p.info/projHoshimi.html)
- [nano-bot · nesnausk!](https://nesnausk.org/projects/2004-hoshimi/)
- [DeCode.net Salta: Mi Explicacion de una .dll del nano-bot](https://decodesalta.blogspot.com/2009/04/mi-explicacion-de-una-dll-del-project.html)
- ['nano-bot' Student Gaming Deadlines Announced | Game Developer](https://www.gamedeveloper.com/game-platforms/-project-hoshimi-student-gaming-deadlines-announced)
- [Testing, tracing and debugging in nano-bot | CodeProject](https://www.codeproject.com/Articles/18752/Testing-tracing-and-debugging-in-Project-Hoshimi)
