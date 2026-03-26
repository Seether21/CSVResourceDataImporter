# CSVResourceDataImporter

UID-aware editor plugin for Godot 4 that allows developers to export and import **Resources** to and from **CSV** files. This tool is designed to streamline data-heavy workflows like balancing RPG items, managing loot tables, or mass-editing game constants using external tools like Excel or Google Sheets.

---

## 🚀 Features

**Two-Way Sync:** Export existing `.tres` files to CSV and import them back with updates.
**UID-Aware:** Uses Godot's Unique Identifier (UID) system to track resources. If you move or rename a resource in Godot, the CSV bridge will still find and update it.
**Type-Safe Reflection:** Automatically detects `@export` variables in your scripts to determine the correct data types (Int, Float, Color, Vector, etc.).
**Complex Data Support:** Handles nested Dictionaries and Arrays using JSON serialization.
**Smart Naming:** Automatically suggests filenames based on your script variables (e.g., `item_name` or `id`).
**Editor Integration:** Docks into the bottom panel of the Godot Editor for a seamless workflow.
**Auto Handle csv import** Creates a .import file that has keep or skip to prevent Godot from treating your exported csv as a translation file.

---

## 🛠 Installation

1.  Download or clone this repository.
2.  Copy the `addons/resource_management` folder into your project's `res://addons/` directory.
3.  Go to **Project -> Project Settings -> Plugins**.
4.  Find **CSV Resource Data Importer** and check the **Enabled** box.

---

## 📖 How to Use

### Exporting Resources
1.  Open the **CSV Data** tab in the bottom panel.
2.  **Resource Script:** Select the `.gd` script (or a `.tres` file using that script) that defines your data structure.
3.  **Target Directory:** Select the folder containing the resources you want to export.
4.  Click **Export to CSV** and choose a save location.
    * *Note: An `.import` file will be created alongside the CSV to prevent Godot from treating it as a translation file.*

### Importing/Updating Resources
1.  Ensure your **Resource Script** and **Target Directory** are set.
2.  **CSV File:** Select the spreadsheet you wish to import.
3.  **Naming Property:** Select which column should be used for the filename (e.g., `name`).
4.  Click **Import from CSV**.
    * If a row has a valid `uid`, the existing resource will be updated **in its current folder**.
    * If no `uid` is present, a new resource will be created in the **Target Directory**.

---

## 📋 CSV Format Guidelines

The plugin expects the first row to be headers matching your script's `@export` variable names. 

| uid | name | stat_changes | modifier_color | is_prefix |
| :--- | :--- | :--- | :--- | :--- |
| `uid://...` | Sharp | `{"atk": 5}` | `#ff0000ff` | `true` |

**Dictionaries/Arrays:** Should be formatted as JSON strings: `{"key": value}` or `[1, 2, 3]`.
**Colors:** Supports Hex strings (`#ffffff`) or Godot string format `(1, 1, 1, 1)`.
**Resources:** Use the full path `res://path/to/icon.png` or a `uid://` string to link other resources.

---

## ⚠️ Requirements
* **Godot 4.x** (Standard or Mono/C# versions supported for `.gd` and `.cs` scripts).
*Scripts must use the `@export` keyword for variables to be recognized by the bridge.
