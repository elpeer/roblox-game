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
    ├── PlayerBases/                   -- תבנית בסיס שחקן (Safe Zone + תהומות)
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

## Phase 2: Player Base & Safe Zone (בסיס שחקן ואזור בטוח)
### 2.1 - Base Template (Safe Zone)
- [ ] יצירת תבנית בסיס שכוללת:
  - משטח ריצפה בסיסי — זהו ה-**SAFE ZONE**
  - מיקום להליכון
  - אזור הצגת דמויות ברינרוט שנאספו
  - **קו גבול ברור** שמסמן את סוף ה-Safe Zone
  - מעבר לקו הגבול → מתחיל אזור התהומות (המשימות)

### 2.2 - Safe Zone Boundary
- [ ] קו גבול ויזואלי (קו צבעוני / גדר / שלט)
- [ ] כשהשחקן חוצה את הגבול → הוא רואה את התהום הראשון ויכול להתחיל לקפוץ
- [ ] חזרה לSafe Zone תמיד אפשרית (ריצה חזרה)
- [ ] נפילה לתהום → טלפורט חזרה ל-Safe Zone

### 2.3 - Base Assignment
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
### 4.1 - Abyss Generation (תהומות בגדלים עולים)
- [ ] התהומות ממוקמות מעבר לגבול ה-Safe Zone, אחת אחרי השנייה
- [ ] כל תהום גדולה יותר מהקודמת
- [ ] רוחב התהומות גדל בהדרגה:
  | תהום # | רוחב (studs) | כמות ברינרוטים שמקבלים |
  |---------|-------------|------------------------|
  | 1 | 8 | 1 |
  | 2 | 10 | 1 |
  | 3 | 12 | 1-2 |
  | 4 | 15 | 1-2 |
  | 5 | 18 | 2 |
  | 6 | 21 | 2 |
  | 7 | 24 | 2-3 |
  | 8 | 28 | 2-3 |
  | 9 | 32 | 3 |
  | 10 | 36 | 3 |
  | 11 | 40 | 3-4 |
  | 12 | 45 | 3-4 |
  | 13 | 50 | 4 |
  | 14 | 55 | 4-5 |
  | 15 | 60 | 5 |
  | 16 | 66 | 5 |
  | 17 | 72 | 5-6 |
  | 18 | 78 | 6 |
  | 19 | 85 | 6-7 |
  | 20 | 92 | 7 |
  | ... | +8 per abyss | ... |

### 4.2 - Brainrot Tier Upgrade (שדרוג סוג ברינרוט כל 5 תהומות)
- [ ] כל 5 תהומות שהשחקן עובר → סוג הברינרוט שמשתגר עולה לטייר הבא
  | תהומות | טייר ברינרוט | דוגמאות |
  |--------|-------------|---------|
  | 1-5 | Common | Noobini Pizzanini, Lirili Larila, Tim Cheesee... |
  | 6-10 | Rare | Trippi Troppi, Boneca Ambalabu, Cacto Hipopotamo... |
  | 11-15 | Epic | Brr Brr Patapim, Cappuccino Assassino, Mangolin... |
  | 16-20 | Legendary | Sigma Boy, Ballerina Cappuccina, Chimpanzini Bananini... |
  | 21-25 | Mythic | Frigo Camelo, Gorillo Subwoofero, Orangutini... |
  | 26-30 | Brainrot God | Tralalero Tralala, Cocofanto Elefanto, Dragoni Canneloni... |
  | 31-35 | Secret | La Vacca Saturno Saturnita, Nuclearo Dinossauro... |
  | 36+ | OG | Skibidi Toilet, Meowl, Strawberry Elephant |
- [ ] בכל תהום מספר הברינרוטים שמקבלים הוא אקראי (לפי הטבלה למעלה)
- [ ] הברינרוט הספציפי שמקבלים הוא אקראי מתוך הטייר הנוכחי

### 4.3 - Jump Mechanics
- [ ] מהירות השחקן משפיעה על מרחק הקפיצה
- [ ] גילוי נפילה לתהום → טלפורט חזרה ל-Safe Zone
- [ ] גילוי הגעה לצד השני → קבלת ברינרוטים + המשך לתהום הבאה
- [ ] אפקטים ויזואליים (חלקיקים, צלילים)

### 4.4 - Speed-Jump Relationship
- [ ] נוסחת קפיצה: JumpPower = BaseJump + (Speed * 0.1)
- [ ] WalkSpeed = BaseWalk + Speed
- [ ] ככל שהמהירות גבוהה יותר → קל יותר לעבור תהומות

---

## Phase 5: Brainrot Collection (אוסף דמויות ברינרוט)
### 5.1 - Brainrot Rarities & Characters (טיירים ודמויות)
בהשראת משחקי ברינרוט פופולריים (Steal a Brainrot, Brainrot Evolution)

#### Common (נפוץ) — הכנסה: 1-14 coins/sec
| # | דמות |
|---|------|
| 1 | Noobini Pizzanini |
| 2 | Lirili Larila |
| 3 | Tim Cheesee |
| 4 | Frurifrura |
| 5 | Talpa Di Fero |
| 6 | Svivina Borbardino |
| 7 | Noobini Santanini |
| 8 | Raccooni Jandelini |
| 9 | Pipi Kiwi |
| 10 | Tartaragno |
| 11 | Pipi Corni |

#### Rare (נדיר) — הכנסה: 15-75 coins/sec
| # | דמות |
|---|------|
| 1 | Trippi Troppi |
| 2 | Gangster Footera |
| 3 | Bandito Bobritto |
| 4 | Boneca Ambalabu |
| 5 | Cacto Hipopotamo |
| 6 | Ta Ta Ta Ta Sahur |
| 7 | Cupkake Koala |
| 8 | Tric Tric Baraboom |
| 9 | Frogo Elfo |
| 10 | Pipi Avocado |
| 11 | Pinealotto Fruttarino |

#### Epic (אפי) — הכנסה: 80-300 coins/sec
| # | דמות |
|---|------|
| 1 | Cappuccino Assassino |
| 2 | Bandito Axolito |
| 3 | Brr Brr Patapim |
| 4 | Avocadini Antilopini |
| 5 | Trullimero Trulicina |
| 6 | Bambini Crostini |
| 7 | Malame Amarele |
| 8 | Bananita Dolphinita |
| 9 | Perochello Lemonchello |
| 10 | Brri Brri Bicus Dicus Bombicus |
| 11 | Avocadini Guffo |
| 12 | Ti Ti Ti Ti Sahur |
| 13 | Mangolin |

#### Legendary (אגדי) — הכנסה: 300-1,800 coins/sec
| # | דמות |
|---|------|
| 1 | Burbaloni Loliloli |
| 2 | Chimpanzini Bananini |
| 3 | Ballerina Cappuccina |
| 4 | Chef Crabracadabra |
| 5 | Lionel Cactuseli |
| 6 | Glorbo Fruttodillo |
| 7 | Blueberrenni Octopusini |
| 8 | Cocosino Mamá |
| 9 | Pandaccini Bananini |
| 10 | Quackula |
| 11 | Sigma Boy |
| 12 | Sigma Girl |
| 13 | Chocco Bunny |
| 14 | Puffaball |
| 15 | Sealo Regalo |
| 16 | Buho De Fuego |
| 17 | Strawberrlli Flamingelli |
| 18 | Clickerino Clabo |

#### Mythic (מיתי) — הכנסה: 1,900-17,000 coins/sec
| # | דמות |
|---|------|
| 1 | Frigo Camelo |
| 2 | Cavallo Virtuoso |
| 3 | Orangutini |
| 4 | Ananassini |
| 5 | Rhino Toasterino |
| 6 | Borbadiro |
| 7 | Cocrodilo |
| 8 | Tigrillini |
| 9 | Watermelini |
| 10 | Gorillo Subwoofero |

#### Brainrot God (אל הברינרוט) — הכנסה: 17,500-295,000 coins/sec
| # | דמות |
|---|------|
| 1 | Cocofanto Elefanto |
| 2 | Giraffa Celeste |
| 3 | Tralalero Tralala |
| 4 | Matteo Tipi Topi Taco |
| 5 | Orcalero Orcala |
| 6 | Tralalita Tralala |
| 7 | Graipuss Medusi |
| 8 | Garamararambraramanmararaman |
| 9 | Dragoni Canneloni |
| 10 | Tung Tung Tung Sahur |

#### Secret (סודי) — הכנסה: 300,000-350,000,000 coins/sec
| # | דמות |
|---|------|
| 1 | La Vacca Saturno Saturnita |
| 2 | Nuclearo Dinossauro |
| 3 | Dragon Gingerini |
| 4 | Baby Gronk |
| 5 | Fanum Tax |

#### OG (מקורי - הכי נדיר) — הכנסה: 400,000,000+ coins/sec
| # | דמות |
|---|------|
| 1 | Skibidi Toilet |
| 2 | Meowl |
| 3 | Strawberry Elephant |

### 5.2 - Passive Income
- [ ] כל דמות שנאספה מייצרת כסף אוטומטית (לפי הטבלאות למעלה)
- [ ] ככל שהטייר גבוה יותר → הכנסה גבוהה יותר
- [ ] הכסף מצטבר גם כשהשחקן במשימה
- [ ] הצגת סה"כ הכנסה לשנייה בHUD
- [ ] אם יש לשחקן כמה עותקים מאותו ברינרוט → ההכנסה מצטברת

### 5.3 - Display in Base
- [ ] הדמויות שנאספו מוצגות בבסיס השחקן
- [ ] מודלים תלת-ממדיים פשוטים לכל דמות
- [ ] צבע זוהר לפי נדירות (Common=לבן, Rare=כחול, Epic=סגול, Legendary=צהוב, Mythic=אדום, God=זהב, Secret=קשת, OG=יהלום)

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
- [ ] הצגת מספר תהום נוכחי
- [ ] הטייר הנוכחי של ברינרוט (Common/Rare/Epic...)
- [ ] כמה תהומות נשארו עד שדרוג טייר
- [ ] הצגת הברינרוטים שהושגו בתהום האחרון

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
