# AI Study Planner

An AI-powered student life scheduler mobile app built with Flutter. This app helps students manage study deadlines and personal development activities with a modern, minimal UI design.

## Features

- **Splash Screen**: Welcome screen with app branding
- **Daily Check-in**: Quick check-in to update daily tasks
- **Home Dashboard**: 
  - Personalized greeting
  - Today's progress tracker
  - Task list with priority indicators
  - Weekly calendar view
  - Personal growth activities
- **Task Management**: Add tasks with details like difficulty, deadline, and estimated time
- **AI Schedule Generation**: View AI-generated personalized schedules
- **Bottom Navigation**: Easy access to Home, Tasks, Calendar, and Profile

## Project Structure

```
lib/
├── main.dart                    # App entry point
├── models/
│   ├── task.dart               # Task data model
│   └── schedule_item.dart      # Schedule item data model
├── screens/
│   ├── splash_screen.dart      # Welcome/splash screen
│   ├── daily_check_screen.dart # Daily check-in screen
│   ├── home_screen.dart        # Main dashboard
│   ├── task_input_screen.dart  # Add new task screen
│   ├── ai_schedule_screen.dart # AI generated schedule
│   ├── tasks_screen.dart       # All tasks view (placeholder)
│   ├── calendar_screen.dart    # Calendar view (placeholder)
│   └── profile_screen.dart     # User profile screen
├── widgets/
│   ├── task_card.dart          # Reusable task card widget
│   ├── growth_activity_card.dart # Personal growth activity card
│   └── schedule_card.dart      # Schedule item card widget
└── utils/
    └── constants.dart          # App constants (colors, text styles, spacing)
```

## Design System

### Color Palette
- **Primary**: #4A90E2 (Blue)
- **Primary Dark**: #2E5C8A
- **Primary Light**: #6FA8E8
- **Background**: #F5F7FA
- **Card Background**: White
- **Success**: #2ECC71 (Easy tasks)
- **Warning**: #F39C12 (Medium tasks)
- **Danger**: #E74C3C (Hard tasks)

### Design Principles
- Modern minimal UI
- Soft shadows for depth
- Rounded corners on all cards
- Consistent spacing
- Clean typography
- Student-friendly interface

## Getting Started

### Prerequisites
- Flutter SDK (>=2.19.0)
- Dart SDK
- Android Studio or VS Code with Flutter extensions
- Android/iOS device or emulator

### Installation

1. Clone the repository or navigate to the project directory:
```bash
cd EXE
```

2. Install dependencies:
```bash
flutter pub get
```

3. Run the app:
```bash
flutter run
```

### Building

**Android:**
```bash
flutter build apk --release
```

**iOS:**
```bash
flutter build ios --release
```

## Screens Overview

### 1. Splash Screen
- App logo and branding
- Tagline: "Balance Study, Life, and Growth"
- "Get Started" button

### 2. Daily Check Screen
- Centered card with question: "Do you have any updates for today?"
- YES/NO buttons for quick check-in

### 3. Home Screen
- **Top Section**: Greeting and progress bar
- **Tasks Section**: Today's tasks with checkboxes and priority indicators
- **Calendar Section**: Weekly calendar widget showing the current week
- **Growth Activities**: Horizontal scrollable cards for Gym, Reading, Meditation, and Skill Learning
- **Floating Action Button**: Quick add task button

### 4. Task Input Screen
- Form fields for:
  - Task name
  - Subject
  - Difficulty (Easy/Medium/Hard)
  - Deadline (date picker)
  - Estimated time (hours)
  - Category (Study/Personal Development)
- "Generate AI Schedule" button

### 5. AI Schedule Screen
- Grouped schedule by day
- Time slots with visual indicators
- Schedule cards with difficulty markers
- "Regenerate" and "Save Schedule" buttons

### 6. Navigation Screens
- **Tasks**: All tasks view (placeholder)
- **Calendar**: Full calendar view (placeholder)
- **Profile**: User profile with settings options

## Architecture

The app follows a clean architecture approach:
- **Models**: Data classes for Task and ScheduleItem
- **Screens**: Full-screen views with state management
- **Widgets**: Reusable UI components
- **Utils**: Constants and shared utilities

## Customization

### Colors
Edit colors in [lib/utils/constants.dart](lib/utils/constants.dart):
```dart
class AppColors {
  static const Color primary = Color(0xFF4A90E2);
  // ... other colors
}
```

### Text Styles
Modify text styles in [lib/utils/constants.dart](lib/utils/constants.dart):
```dart
class AppTextStyles {
  static const TextStyle heading1 = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );
  // ... other styles
}
```

### Spacing & Radius
Adjust spacing and border radius in [lib/utils/constants.dart](lib/utils/constants.dart):
```dart
class AppSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  // ... other spacings
}
```

## Future Enhancements

- Backend integration for data persistence
- Real AI-powered schedule generation
- Push notifications for tasks
- Task completion statistics
- Study streak tracking
- Dark mode support
- Multi-language support
- Calendar integration
- Task sharing and collaboration

## Notes

This is a **UI prototype** without backend functionality. All data is currently hardcoded for demonstration purposes. To add backend functionality:
1. Integrate a state management solution (Provider, Riverpod, Bloc, etc.)
2. Add a backend API (Firebase, REST API, etc.)
3. Implement data persistence (SQLite, Hive, etc.)
4. Add authentication
5. Implement real AI scheduling algorithms

## License

This project is open source and available for educational purposes.

## Author

Created as a mobile UI prototype for an AI-powered student scheduler application.
