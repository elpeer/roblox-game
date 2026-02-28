# מדריך התקנה - Brainrot Simulator
## איך להכניס את המשחק ל-Roblox Studio ולפרסם אותו (בלי Rojo)

---

## שלב 1: פתיחת פרויקט חדש

1. פתח את **Roblox Studio**
2. לחץ על **New** (חדש)
3. בחר **Baseplate** (המפה הבסיסית עם ריצפה אפורה)
4. המתן שהפרויקט ייפתח

---

## שלב 2: פתיחת Explorer ו-Properties

אם לא רואים את חלונות **Explorer** ו **Properties** בצד ימין:

1. לחץ למעלה על לשונית **View** (תצוגה)
2. סמן V על **Explorer**
3. סמן V על **Properties**

עכשיו אתה אמור לראות בצד ימין רשימת כל האובייקטים במשחק.

---

## שלב 3: מחיקת ה-Baseplate

ב-Explorer (בצד ימין):
1. פתח את **Workspace** (לחץ על החץ שליד)
2. לחץ ימני על **Baseplate**
3. לחץ **Delete**

(הבסיס שלנו נבנה אוטומטית ע"י הקוד)

---

## שלב 4: הוספת הסקריפטים (3 מודולים ב-ReplicatedStorage)

### 4.1 - יצירת תיקיית Modules

1. ב-Explorer, לחץ ימני על **ReplicatedStorage**
2. בחר **Insert Object** → **Folder**
3. שנה את השם ל: **Modules**

### 4.2 - GameConfig

1. לחץ ימני על תיקיית **Modules** שיצרת
2. בחר **Insert Object** → **ModuleScript**
3. שנה את השם ל: **GameConfig**
4. לחץ עליו פעמיים כדי לפתוח את העורך
5. **מחק את כל הטקסט** שבתוכו
6. פתח את הקובץ: `src/ReplicatedStorage/Modules/GameConfig.lua`
7. **העתק** את כל התוכן שלו (Ctrl+A ואז Ctrl+C)
8. **הדבק** ב-Studio (Ctrl+V)

### 4.3 - TreadmillData

1. לחץ ימני על תיקיית **Modules**
2. בחר **Insert Object** → **ModuleScript**
3. שנה את השם ל: **TreadmillData**
4. לחץ עליו פעמיים
5. מחק את כל הטקסט
6. העתק והדבק את התוכן מ: `src/ReplicatedStorage/Modules/TreadmillData.lua`

### 4.4 - BrainrotData

1. לחץ ימני על תיקיית **Modules**
2. בחר **Insert Object** → **ModuleScript**
3. שנה את השם ל: **BrainrotData**
4. לחץ עליו פעמיים
5. מחק את כל הטקסט
6. העתק והדבק את התוכן מ: `src/ReplicatedStorage/Modules/BrainrotData.lua`

---

## שלב 5: הוספת סקריפטי השרת (5 סקריפטים ב-ServerScriptService)

### לכל סקריפט תעשה את אותו הדבר:

1. ב-Explorer, לחץ ימני על **ServerScriptService**
2. בחר **Insert Object** → **Script** (סקריפט רגיל, לא LocalScript!)
3. שנה את השם בדיוק לפי הרשימה למטה
4. לחץ פעמיים, מחק הכל, והדבק את התוכן מהקובץ המתאים

| שם הסקריפט ב-Studio | קובץ מקור |
|---------------------|-----------|
| DataManager | `src/ServerScriptService/DataManager.server.lua` |
| GameManager | `src/ServerScriptService/GameManager.server.lua` |
| MissionManager | `src/ServerScriptService/MissionManager.server.lua` |
| EconomyManager | `src/ServerScriptService/EconomyManager.server.lua` |
| BrainrotManager | `src/ServerScriptService/BrainrotManager.server.lua` |

**חשוב:** הסדר לא משנה, הסקריפטים מסנכרנים את עצמם אוטומטית.

---

## שלב 6: הוספת סקריפט לקוח (StarterPlayerScripts)

1. ב-Explorer, פתח את **StarterPlayer**
2. לחץ ימני על **StarterPlayerScripts**
3. בחר **Insert Object** → **LocalScript** (חשוב: LocalScript ולא Script!)
4. שנה את השם ל: **ClientController**
5. לחץ פעמיים, מחק הכל, והדבק את התוכן מ: `src/StarterPlayerScripts/ClientController.client.lua`

---

## שלב 7: הוספת ה-GUI (StarterGui)

1. ב-Explorer, לחץ ימני על **StarterGui**
2. בחר **Insert Object** → **LocalScript** (שוב: LocalScript!)
3. שנה את השם ל: **MainGui**
4. לחץ פעמיים, מחק הכל, והדבק את התוכן מ: `src/StarterGui/MainGui.client.lua`

---

## שלב 8: הגדרות עולם (אופציונלי אבל מומלץ)

1. ב-Explorer, לחץ ימני על **ServerScriptService**
2. בחר **Insert Object** → **Script**
3. שנה את השם ל: **WorldSetup**
4. לחץ פעמיים, מחק הכל, והדבק את התוכן מ: `src/Workspace/init.server.lua`

---

## שלב 9: בדיקה שהכל במקום

ב-Explorer אתה צריך לראות את המבנה הזה:

```
game
├── Workspace
│   (ריק - בלי Baseplate)
│
├── ServerScriptService
│   ├── DataManager         (Script)
│   ├── GameManager         (Script)
│   ├── MissionManager      (Script)
│   ├── EconomyManager      (Script)
│   ├── BrainrotManager     (Script)
│   └── WorldSetup          (Script)
│
├── ReplicatedStorage
│   └── Modules (Folder)
│       ├── GameConfig      (ModuleScript)
│       ├── TreadmillData   (ModuleScript)
│       └── BrainrotData    (ModuleScript)
│
├── StarterPlayer
│   └── StarterPlayerScripts
│       └── ClientController (LocalScript)
│
└── StarterGui
    └── MainGui             (LocalScript)
```

---

## שלב 10: בדיקת המשחק

1. לחץ על כפתור **Play** (המשולש הירוק למעלה) או F5
2. אתה אמור לראות:
   - בסיס ירוק (Safe Zone) עם הליכון
   - קו אדום זוהר בקצה (הגבול)
   - מעבר לגבול - פלטפורמה ותהום לקפיצה
   - HUD למעלה (כסף, מהירות, תהום, הכנסה)
   - כפתורי Inventory ו-Shop למטה
3. לחץ על **Inventory** → לחץ על **CLICK TREADMILL** להוסיף מהירות
4. לך לכיוון הקו האדום, קפוץ מעל התהום!
5. אם נפלת → חוזר ל-Safe Zone
6. אם הצלחת → מקבל ברינרוטים!

**לעצור:** לחץ שוב על Stop (ריבוע אדום) או Shift+F5

---

## שלב 11: פרסום המשחק ל-Roblox!

1. למעלה לחץ על **File** (קובץ)
2. לחץ **Publish to Roblox** (פרסם ל-Roblox)
3. בחלון שנפתח:
   - **Name**: Brainrot Simulator (או כל שם שתרצה)
   - **Description**: כתוב תיאור קצר של המשחק
   - **Creator**: בחר אם לפרסם תחת השם שלך או גרופ
   - **Genre**: בחר "All" או "Adventure"
4. לחץ **Create**

המשחק עכשיו נשמר בענן של Roblox!

---

## שלב 12: הפיכת המשחק לציבורי

1. למעלה לחץ על **File** → **Game Settings**
2. בצד שמאל לחץ על **Permissions**
3. שנה את **Playability** ל-**Public** (ציבורי)
4. לחץ **Save** (שמור)

**זהו! המשחק שלך באוויר!** 🎮

אפשר למצוא אותו דרך הפרופיל שלך ב-roblox.com → Creations

---

## טיפים:

- **שמירה:** לאחר שינויים לחץ File → Publish to Roblox (או Ctrl+Shift+P)
- **אם משהו לא עובד:** פתח את חלון **Output** (View → Output) ותבדוק הודעות שגיאה
- **שמות סקריפטים:** חשוב ששמות הסקריפטים יהיו בדיוק כמו שכתוב במדריך!
