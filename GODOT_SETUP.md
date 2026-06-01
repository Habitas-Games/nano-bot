# Godot Setup Guide

> Complete instructions for getting Godot running and opening the nano-bot project.

---

## What is Godot?

[**Godot**](https://godotengine.org) is a free, open-source game engine. nano-bot uses **Godot 4.6+** to run the simulation, replay viewer, and your strategy code.

**Why Godot for nano-bot?**
- ✅ Free and open-source
- ✅ Cross-platform (Windows, macOS, Linux)
- ✅ GDScript — Python-like language, fast to learn
- ✅ No compilation step — write code, hit Run, see results instantly
- ✅ Built-in scene editor and debugger
- ✅ Small download (~150 MB)

---

## Step 1: Download & Install Godot 4.6

Visit **[godotengine.org/download](https://godotengine.org/download)** and select your OS:

### macOS
```bash
# Download the .dmg file and drag to Applications
# Or use Homebrew:
brew install godot
```

### Windows
- Download the `.exe` installer or portable `.zip`
- Run the installer or extract and run `godot.exe`

### Linux (Ubuntu/Debian)
```bash
# Via package manager (usually latest version)
sudo apt-get install godot

# Or download from godotengine.org
# Extract and run ./Godot_v4.6.1_linux.x86_64
```

---

## Step 2: Verify Installation

Open Godot. You should see the **Project Manager** window.

```bash
# Or from terminal, verify version:
godot --version
# Output: Godot Engine v4.6.1.stable.official
```

---

## Step 3: Clone nano-bot

```bash
git clone https://github.com/Habitas-Games/nano-bot.git
cd nano-bot
```

---

## Step 4: Open in Godot

### Option A: From Project Manager (recommended)

1. **Project Manager** window is already open
2. Click **"Import"** (top-right)
3. Navigate to the `nano-bot/` folder and select it
4. Click **"Select Folder"**
5. Click **"Import & Open"**

The project loads. You're in the **Godot Editor**.

### Option B: From terminal

```bash
cd /path/to/nano-bot
godot --path .
```

---

## Step 5: Open a Test Scene

Once in the editor:

1. **FileSystem** panel (left) → expand `scenes/`
2. Double-click `main_menu.tscn`
3. You should see the main menu UI in the editor viewport

---

## Step 6: Run the Project

1. Click the **Play** button (▶️ top-right of editor)
   - Or press **F5**
2. The game window opens showing the **main menu**

From here:
- **Run Match** — simulates a game and opens the replay viewer
- **Load Replay** — loads a saved match JSON
- **Tournament** — runs multiple strategies against each other

---

## GDScript Basics

Your strategy file (`strategies/my_strategy.gd`) is **GDScript**. Here's the syntax:

```gdscript
# Variables with types
var hp: int = 20
var name: String = "NanoCollector"
var position: Vector2i = Vector2i(5, 10)

# Functions
func my_function(param: int) -> String:
    return "Hello " + str(param)

# Loops
for item in my_array:
    print(item)

# Conditionals
if hp > 0:
    print("Still alive")
else:
    print("Dead")

# Classes (your strategy)
extends NanoStrategy

func choose_injection_point(map_info: MapInfo) -> Vector2i:
    return Vector2i.ZERO

func what_to_do_next(map_info: MapInfo, my_bots: Array) -> void:
    for bot: BotProxy in my_bots:
        if bot.type == "NanoAI":
            bot.stop()
```

---

## Useful Godot Resources

| Topic | Link |
|---|---|
| **GDScript Documentation** | https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/ |
| **Godot Manual** | https://docs.godotengine.org/en/stable/ |
| **GDScript Cheatsheet** | https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/basics.html |
| **Godot YouTube Channel** | https://www.youtube.com/@GodotEngine |
| **Game Jams** | https://itch.io/jams (great for learning Godot) |

---

## Troubleshooting

| Issue | Solution |
|---|---|
| **Godot won't open project** | Ensure you're using Godot 4.6 or later. Check `Project Settings` → **Project Version** |
| **GDScript syntax errors** | Check the **Output** panel (bottom) for error messages with line numbers |
| **Project files are blank** | Make sure you opened the folder containing `project.godot` |
| **Can't find test scenes** | Expand `res://` in the FileSystem panel. Scenes are in `res://scenes/` |
| **Performance is slow** | Lower the editor resolution or run in headless mode: `godot --headless -s test_sim.gd` |

---

## Running Headless (Command-line)

For fast iteration without opening the editor:

```bash
# Run a single match
godot --headless --path . -- \
    --map maps/simple_tissue.json \
    --strategy_a strategies/my_strategy.gd \
    --strategy_b strategies/example_strategy.gd \
    --out replays/test_match.json

# Run tests
godot --headless -s test_sim.gd
godot --headless -s test_full_gui_path.gd
```

Output JSON is written to `replays/` and can be opened in the editor's replay viewer.

---

## Next: Write Your Strategy

Once Godot is running:

1. Open `strategies/example_strategy.gd` in the editor (double-click in FileSystem)
2. Study the two methods you need to override
3. Copy and rename it: `strategies/my_strategy.gd`
4. Edit and hit **Run Match** to test it

See the **[Participant Guide](docs/participant_guide.html)** for the full API reference.

---

## Need Help?

- **Godot docs:** https://docs.godotengine.org
- **nano-bot issues:** https://github.com/Habitas-Games/nano-bot/issues
- **nano-bot guide:** [Participant Guide](docs/participant_guide.html)
