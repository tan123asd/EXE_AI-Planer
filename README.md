# AI Planner

> 🇻🇳 [Xem bản Tiếng Việt](README.vi.md)

An AI-powered scheduler for students, built with Flutter. Uses AI to generate study plans, manage deadlines, and track personal activities.

## Features

### Free
- Create deadline-based tasks with AI auto-scheduling (15 AI calls/day)
- Chat with AI Agent to plan your schedule
- Weekly calendar, progress tracking
- Pomodoro reminders (50 min work / 10 min break)
- Multi-device sync via Firestore
- Google Sign-In

### Pro (79,000 VND/month or 790,000 VND/year)
- Unlimited AI Agent chat
- 100 AI calls/day
- Priority responses, early access to new features

## Architecture

```
lib/
├── main.dart
├── models/
│   ├── task.dart                   # Task, ScheduleItem, Activity
│   ├── schedule_item.dart
│   ├── chat_models.dart            # ChatMessage, ConversationContext, AiToolCall
│   └── scheduler_models.dart       # AiTaskPlan, ScheduledSlot, ProductivityWindow
├── screens/
│   ├── home_screen.dart            # Main dashboard
│   ├── chat_planner_screen.dart    # AI Agent chat
│   ├── calendar_screen.dart        # Day/week calendar
│   ├── payment_screen.dart         # Pro upgrade (VietQR)
│   ├── profile_screen.dart         # Settings, productivity hours
│   ├── new_task_input_screen.dart  # Create new task
│   └── ai_schedule_screen.dart     # View AI-generated schedule
├── services/
│   ├── ai_service.dart             # Gemini API → AiTaskPlan
│   ├── scheduler_service.dart      # Scheduling algorithm (deadline + activity)
│   ├── chat_ai_service.dart        # GPT-4o-mini Function Calling
│   ├── chat_planner_service.dart   # Tool call executor
│   ├── payment_service.dart        # payment_request creation, VietQR
│   ├── subscription_service.dart   # Free/Pro tier management + expiry
│   ├── firestore_service.dart      # Firestore ↔ local sync
│   ├── storage_service.dart        # SharedPreferences CRUD
│   ├── auth_service.dart           # Firebase Auth
│   └── notification_service.dart   # Local push notifications
├── widgets/
│   ├── chat_message_bubble.dart
│   ├── chat_plan_preview_card.dart # Plan preview + Approve/Reject
│   ├── upgrade_dialog.dart         # Pro upgrade dialog
│   └── ...
└── utils/
    └── constants.dart              # Design system (colors, typography)

vercel-backend/
└── api/
    └── webhook.js                  # Receives Sepay webhook, updates Firestore
```

## Setup

### Requirements
- Flutter SDK `>=3.0.0`
- Dart SDK `>=3.0.0`
- Firebase project (Auth + Firestore)
- OpenAI API key (GPT-4o-mini)

### Run locally

```bash
flutter pub get
flutter run --dart-define=OPENAI_API_KEY=sk-...
```

### Build release

```bash
# Android
flutter build apk --release --dart-define=OPENAI_API_KEY=sk-...

# iOS
flutter build ios --release --dart-define=OPENAI_API_KEY=sk-...
```

## Firebase Configuration

`lib/firebase_options.dart` is generated automatically by the FlutterFire CLI:

```bash
flutterfire configure
```

`android/app/google-services.json` is downloaded from Firebase Console → Project Settings → Android app.

## Payment Webhook (Vercel)

Handles Sepay transaction notifications and auto-activates Pro subscriptions.

### Deploy

```bash
cd vercel-backend
vercel --prod
```

### Vercel Environment Variables

| Variable | Description |
|---|---|
| `FIREBASE_PROJECT_ID` | Firebase project ID |
| `FIREBASE_CLIENT_EMAIL` | Service account email |
| `FIREBASE_PRIVATE_KEY` | Service account private key |
| `SEPAY_API_KEY` | Webhook auth key from Sepay |

### Sepay Configuration

Webhook URL (use the alias — never a specific deployment URL):
```
https://vercel-backend-zeta-one.vercel.app/api/webhook
```

## Payment Flow

```
User selects plan → Flutter creates payment_request in Firestore
→ Shows VietQR code + ref code (e.g. AP84YZYH)
→ User transfers via Sacombank (MUST include ref code in transfer note)
→ Sepay detects transaction → POST to webhook
→ Webhook validates, updates subscription_tier + subscription_expire_at
→ App receives Firestore snapshot → shows "Payment successful"
```

## Design System

Defined in `lib/utils/constants.dart`.

| Token | Value |
|---|---|
| Primary | `#FF6B35` (orange) |
| Background | `#F8F9FA` |
| Success | `#10B981` |
| Warning | `#F59E0B` |
| Danger | `#EF4444` |

## Support

Contact: **0935457152**
