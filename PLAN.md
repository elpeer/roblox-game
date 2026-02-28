# Brainrot Simulator - Roblox Game Development Plan

## Game Overview
משחק סימולטור לROBLOX שבו כל שחקן מקבל בסיס משלו, עובר משימות (קפיצה מעל תהומות),
אוסף דמויות "ברינרוט", מרוויח כסף ומשדרג הליכונים לקבלת מהירות.

---

## Architecture (מבנה הפרויקט)

```
src/
├── ServerScriptService/
│   ├── GameManager.server.lua        -- ניהול ראשי של המשחק
│   ├── DataManager.server.lua        -- שמירת וטעינת נתוני שחקנים
│   ├── MissionManager.server.lua     -- ניהול משימות (תהומות)
│   ├── EconomyManager.server.lua     -- ניהול כלכלה (כסף, קניות)
│   └── BrainrotManager.server.lua    -- ניהול דמויות ברינרוט
├── StarterPlayerScripts/
│   └── ClientController.client.lua   -- לוגיקה בצד הלקוח
├── StarterGui/
│   ├── MainHUD.lua                   -- ממשק ראשי (כסף, מהירות)
│   ├── ShopGui.lua                   -- חנות הליכונים
│   ├── InventoryGui.lua              -- אינוונטורי (הליכון + ברינרוטים)
│   └── MissionGui.lua                -- הצגת משימות
├── ReplicatedStorage/
│   ├── Modules/
│   │   ├── GameConfig.lua            -- הגדרות משחק (מספרים, מחירים)
│   │   ├── TreadmillData.lua         -- נתוני הליכונים (סוגים, מהירויות)
│   │   └── BrainrotData.lua          -- נתוני דמויות ברינרוט
│   └── RemoteEvents/                 -- תקשורת שרת-לקוח
│       ├── TreadmillClick.lua
│       ├── PurchaseItem.lua
│       └── MissionComplete.lua
└── Workspace/
    ├── SpawnArea/                     -- אזור הכניסה
    ├── PlayerBases/                   -- תבנית בסיס שחקן
    └── MissionArea/                   -- אזור המשימות (תהומות)
```

---

## Phase 1: Foundation (תשתית)
### 1.1 - Project Setup
- [x] אתחול ריפו
- [ ] יצירת מבנה תיקיות הפרויקט
- [ ] הגדרת GameConfig עם כל הפרמטרים של המשחק

### 1.2 - Data System (מערכת נתונים)
- [ ] מודול DataManager לשמירת נתוני שחקן:
  - כסף (coins)
  - מהירות נוכחית (speed)
  - הליכון נוכחי (currentTreadmill)
  - דמויות ברינרוט שנאספו (collectedBrainrots)
  - משימה נוכחית / שלב (currentMissionStage)
- [ ] שמירה אוטומטית עם DataStoreService

### 1.3 - Remote Events
- [ ] הגדרת RemoteEvents לתקשורת שרת-לקוח:
  - TreadmillClick (לקוח → שרת)
  - PurchaseItem (לקוח → שרת)
  - MissionComplete (שרת → לקוח)
  - UpdateStats (שרת → לקוח)

---

## Phase 2: Player Base (בסיס שחקן)
### 2.1 - Base Template
- [ ] יצירת תבנית בסיס שכוללת:
  - משטח ריצפה בסיסי
  - מיקום להליכון
  - אזור הצגת דמויות ברינרוט שנאספו
  - טלפורט לאזור המשימות

### 2.2 - Base Assignment
- [ ] כשחקן מצטרף → שיבוט בסיס חדש ומיקומו
- [ ] כשחקן עוזב → ניקוי הבסיס

---

## Phase 3: Treadmill System (מערכת הליכונים)
### 3.1 - Treadmill Types (סוגי הליכונים)
| שם | מחיר | מהירות לכל לחיצה |
|----|-------|-------------------|
| Basic Treadmill | חינם (התחלתי) | +1 |
| Fast Treadmill | 100 coins | +3 |
| Super Treadmill | 500 coins | +8 |
| Ultra Treadmill | 2000 coins | +20 |
| Mega Treadmill | 10000 coins | +50 |

### 3.2 - Click Mechanic
- [ ] כפתור הליכון באינוונטורי
- [ ] כל לחיצה → שליחת RemoteEvent לשרת
- [ ] שרת מעדכן את המהירות של השחקן לפי סוג ההליכון
- [ ] אנימציה / אפקט ויזואלי בלחיצה
- [ ] הצגת ההליכון הפיזי בבסיס השחקן

---

## Phase 4: Mission System - Abyss Jumping (מערכת משימות - קפיצה מעל תהומות)
### 4.1 - Abyss Generation
- [ ] יצירת שלבים עם תהומות בגדלים עולים:
  | שלב | רוחב התהום (studs) | דמות ברינרוט שמקבלים |
  |------|-------------------|----------------------|
  | 1 | 8 | Skibidi Toilet |
  | 2 | 12 | Baby Gronk |
  | 3 | 18 | Sigma Boy |
  | 4 | 25 | Duke Dennis |
  | 5 | 34 | Livvy Dunne |
  | 6 | 45 | Kai Cenat |
  | 7 | 58 | Fanum Tax |
  | 8 | 73 | Ohio Final Boss |

### 4.2 - Jump Mechanics
- [ ] מהירות השחקן משפיעה על מרחק הקפיצה
- [ ] גילוי נפילה לתהום → טלפורט חזרה לתחילת השלב
- [ ] גילוי הגעה לצד השני → מעבר שלב + קבלת דמות ברינרוט
- [ ] אפקטים ויזואליים (חלקיקים, צלילים)

### 4.3 - Speed-Jump Relationship
- [ ] נוסחת קפיצה: JumpPower = BaseJump + (Speed * 0.1)
- [ ] WalkSpeed = BaseWalk + Speed
- [ ] ככל שהמהירות גבוהה יותר → קל יותר לעבור תהומות

---

## Phase 5: Brainrot Collection (אוסף דמויות ברינרוט)
### 5.1 - Brainrot Characters
- [ ] נתוני כל דמות:
  | דמות | הכנסה לדקה | שלב נדרש |
  |------|------------|----------|
  | Skibidi Toilet | 5 coins/min | 1 |
  | Baby Gronk | 12 coins/min | 2 |
  | Sigma Boy | 25 coins/min | 3 |
  | Duke Dennis | 50 coins/min | 4 |
  | Livvy Dunne | 100 coins/min | 5 |
  | Kai Cenat | 200 coins/min | 6 |
  | Fanum Tax | 400 coins/min | 7 |
  | Ohio Final Boss | 1000 coins/min | 8 |

### 5.2 - Passive Income
- [ ] כל דמות שנאספה מייצרת כסף אוטומטית
- [ ] הכסף מצטבר גם כשהשחקן במשימה
- [ ] הצגת סה"כ הכנסה לדקה בHUD

### 5.3 - Display in Base
- [ ] הדמויות שנאספו מוצגות בבסיס השחקן
- [ ] מודלים תלת-ממדיים פשוטים לכל דמות

---

## Phase 6: Economy & Shop (כלכלה וחנות)
### 6.1 - Shop System
- [ ] GUI של חנות עם כל ההליכונים
- [ ] כפתור קנייה → בדיקת יתרה → עדכון הליכון
- [ ] הליכון חדש מחליף את הקודם
- [ ] הודעת הצלחה / כישלון

### 6.2 - Economy Balance
- [ ] וידוא שהכלכלה מאוזנת:
  - שלב 1-2: הליכון בסיסי מספיק
  - שלב 3-4: צריך Fast/Super Treadmill
  - שלב 5-6: צריך Ultra Treadmill
  - שלב 7-8: צריך Mega Treadmill

---

## Phase 7: GUI & UX (ממשק משתמש)
### 7.1 - Main HUD
- [ ] תצוגת כסף (coins)
- [ ] תצוגת מהירות נוכחית
- [ ] תצוגת שלב נוכחי
- [ ] הכנסה לדקה

### 7.2 - Inventory GUI
- [ ] כפתור הליכון (לחיצה = מהירות)
- [ ] רשימת דמויות ברינרוט שנאספו
- [ ] הליכון נוכחי מודגש

### 7.3 - Shop GUI
- [ ] רשימת הליכונים לקנייה
- [ ] מחיר, מהירות לכל לחיצה
- [ ] סימון מה כבר נקנה

### 7.4 - Mission GUI
- [ ] הצגת שלב נוכחי
- [ ] הדמות שאפשר להשיג
- [ ] כפתור "לך למשימה"

---

## Phase 8: Polish & Testing (ליטוש ובדיקות)
- [ ] אפקטים ויזואליים (חלקיקים, אורות)
- [ ] צלילים (קפיצה, לחיצה, קנייה, השגת דמות)
- [ ] בדיקת באגים
- [ ] איזון כלכלי
- [ ] בדיקת מולטיפלייר (מספר שחקנים)

---

## Tech Stack
- **Language**: Luau (Roblox Lua)
- **Platform**: Roblox Studio
- **Data Storage**: Roblox DataStoreService
- **Communication**: RemoteEvents / RemoteFunctions

## Notes
- כל הסקריפטים נכתבים בLuau ומותאמים למבנה של Roblox Studio
- הקבצים מאורגנים לפי שירותי Roblox (ServerScriptService, ReplicatedStorage, etc.)
- הפרויקט ניתן לייבוא לRoblox Studio באמצעות Rojo או העתקה ידנית
