# Workflow State (STM + Rules + Log)

This file contains the dynamic state of the project workflow, including current phase, plan, rules, and action log. It is constantly updated during the development process.

## State

* 
**Phase**: **CONSTRUCT** 


* 
**Status**: **READY** 


* **CurrentItem**: `item2` ✅

---

## Plan

Based on your strategy to prioritize the **Farmer View** first and treat each navigation tab as a separate construction item, here is the updated plan for **Muzhir**:

1. **Item 1: Project Initialization & Theme:** Configure the Flutter app with Material 3 and the "Sustainable Agriculture" theme. Set up the Bottom Navigation Bar.


2. 
**Item 2: Farmer Home Dashboard:** Build the overview cards (Stats, Weather, Disease Risk) and the "Recent Scans" list for the farmer role .


3. 
**Item 3: Farmer Diagnose Page:** Implement the image input methods (Camera, Gallery, Drone Import) and the UI for real-time quality feedback .


4. 
**Item 4: Interactive Disease Map:** Integrate Google Maps and generate random coordinates within **Saudi Arabia** for mock markers .


5. 
**Item 5: Scan History & Local Storage:** Build the history log with "Sync Status" indicators and set up the **Hive** persistence layer .


6. 
**Item 6: Admin Dashboard (Future Sprint):** Once the farmer view is validated, implement the conditional view logic to allow the Admin role to monitor system health and improve models from the same login entry .



---

## Rules

### Global Rules

* Always operate based on the current Phase and Status.
* Update the State section after completing each step.
* Follow coding standards and naming conventions in `project_config.md`.
* **Do not proceed to CONSTRUCT** until the user approves the specific plan for the current Item.

### Phase-Specific Rules

* 
**ANALYZE:** Research Flutter packages for background sync and Google Maps integration .


* **BLUEPRINT:** Draft step-by-step logic for the current Item, referencing the farmer-first priority.
* **CONSTRUCT:** Follow the approved blueprint and implement one tab at a time.
* **VALIDATE:** Verify functionality against the "End-to-End Field Diagnosis" storyboard.

---

## Log

* **2026-02-16 22:45** - Phase: ANALYZE complete. Requirements for farmer-first priority confirmed.
* **2026-02-16 23:00** - Transitioned to Phase: BLUEPRINT. Updated `Items` table for iterative tab construction.
* **2026-02-17 00:00** - Plan approved by user. Transitioned to Phase: CONSTRUCT. Beginning Item 1: Project Initialization & Theme.
* **2026-02-17 00:05** - Created `mobile_app/pubspec.yaml` with flutter, google_fonts, provider deps.
* **2026-02-17 00:06** - Created `lib/config/app_theme.dart`: Material 3 theme with full Muzhir palette (#012623, #308C36, #81BF54, #B6D96C, #0D0D0D). Cairo font family. Themed AppBar, BottomNavBar, Cards, Buttons.
* **2026-02-17 00:07** - Created `lib/screens/main_scaffold.dart`: BottomNavigationBar with 4 tabs (Home, Diagnose, Map, History). Uses IndexedStack for state preservation.
* **2026-02-17 00:07** - Created `lib/main.dart`: MuzhirApp root widget with MuzhirTheme.lightTheme.
* **2026-02-17 00:08** - Created 4 placeholder pages: `home_page.dart`, `diagnose_page.dart`, `map_page.dart`, `history_page.dart`.
* **2026-02-17 00:08** - **Item 1 CONSTRUCT complete.** All files created. Ready for validation.
* **2026-02-17 00:15** - Transitioning to BLUEPRINT for Item 2: Farmer Home Dashboard.
* **2026-02-17 00:20** - Item 2 plan approved with modifications: +Source Indicator on scans, -Disease Risk Banner, -Sync icons. English UI. Begin CONSTRUCT.
* **2026-02-17 00:22** - Created `lib/widgets/greeting_header.dart`: Time-aware greeting + date, gradient Midnight Tech Green background.
* **2026-02-17 00:22** - Created `lib/widgets/stat_card.dart`: Reusable card with icon, value, label. Themed shadows.
* **2026-02-17 00:23** - Created `lib/widgets/weather_card.dart`: Mock 28°C Jeddah, humidity 45%, wind 12km/h. Green gradient.
* **2026-02-17 00:23** - Created `lib/widgets/recent_scan_tile.dart`: Plant/disease/confidence + ScanSource enum (mobile/drone) with _SourceIndicator icon. No sync icons per user request.
* **2026-02-17 00:24** - Replaced `home_page.dart` placeholder with full dashboard: GreetingHeader → 3x StatCards → WeatherCard → RecentScans list (4 mock entries). No Disease Risk Banner per user request.
* **2026-02-17 00:24** - **Item 2 CONSTRUCT complete.**

---

## Items

| Item ID | Text to Process | Status |
| --- | --- | --- |
| item1 | **Main Scaffold & Theme:** Material 3, Emerald/Brown Palette, Bottom Nav Bar. | COMPLETED |
| item2 | **Farmer Dashboard Page:** Stat cards, Weather Widget, Recent Scans list. | COMPLETED |
| item3 | **Diagnose Page UI:** Capture/Upload buttons and inference progress state. | PENDING |
| item4 | **Geospatial Map:** Google Maps integration with mock markers in Saudi Arabia. | PENDING |
| item5 | **Scan History & Hive:** Local database setup and history list with sync icons. | PENDING |
| item6 | **Admin-Specific Logic:** RBAC toggle for system monitoring and model logs. | PENDING |

---

## TokenizationResults

| Item ID | Summary | Token Count |
| --- | --- | --- |
| item0 | Initialization of Project Config (LTM) | [Est. 450] |
| item0.5 | Workflow State Setup (STM) | [Est. 500] |
| item1 | Flutter scaffold, Material 3 theme, BottomNav with 4 tabs | [Est. 600] |
| item2 | Farmer Dashboard: 4 widgets + composed home page, mock data | [Est. 750] |

---

### **Status: Item 2 Complete**

Item 2 (Farmer Home Dashboard) has been constructed. Awaiting approval to proceed to **Item 3: Farmer Diagnose Page**.
