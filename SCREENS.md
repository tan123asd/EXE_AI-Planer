# Screen Descriptions & Features

## 1. Splash Screen (`splash_screen.dart`)

### Design Elements:
- **Background**: Full blue gradient (primary color)
- **Logo**: White circular container with school icon in center
- **App Name**: "AI Study Planner" in large white bold text
- **Tagline**: "Balance Study, Life, and Growth" in lighter white text
- **Button**: White "Get Started" button at bottom

### Navigation:
- Tapping "Get Started" → Daily Check Screen

---

## 2. Daily Check Screen (`daily_check_screen.dart`)

### Design Elements:
- **Background**: Light background (#F5F7FA)
- **Card**: Centered white card with rounded corners and shadow
- **Icon**: Calendar icon in light blue circular container
- **Title**: "Do you have any updates for today?" in bold
- **YES Button**: Blue filled button
- **NO Button**: Outlined gray button

### Navigation:
- Both YES and NO → Home Screen

---

## 3. Home Screen (`home_screen.dart`)

### Sections:

#### A. Header Section
- **Greeting**: Dynamic "Good Morning/Afternoon/Evening, Tan"
- **Progress Card**: 
  - Blue gradient background
  - "Today's Progress" title
  - Progress bar showing task completion
  - Percentage text

#### B. Today's Tasks
- **Section Header**: "Today's Tasks" with "View All" button
- **Task Cards**: Four sample tasks
  - Math Assignment (Hard, 09:00 AM)
  - Study Data Structures (Medium, 02:00 PM, ✓ Completed)
  - Gym (Easy, 05:00 PM)
  - Read 20 pages (Easy, 08:00 PM)
- Each card shows:
  - Checkbox
  - Task name and subject
  - Time and difficulty tag (color-coded)

#### C. Weekly Calendar
- **Section Header**: "This Week"
- **Calendar Widget**: 
  - 7-day horizontal view (Mon-Sun)
  - Current day (Wed) highlighted in blue
  - Date numbers below each day

#### D. Personal Growth Activities
- **Section Header**: "Personal Growth"
- **Horizontal Scrollable Cards**:
  - Gym (red icon)
  - Reading (orange icon)
  - Meditation (green icon)
  - Skill Learning (blue icon)
- Each card has icon and label

### UI Elements:
- **Floating Action Button**: Blue "+" button (bottom right)
- **Bottom Navigation**: Home, Tasks, Calendar, Profile

### Interactions:
- Tap task checkbox → Toggle completion
- Tap "View All" → Switch to Tasks tab
- Tap "+" button → Task Input Screen
- Tap growth activity card → (Can be extended)

---

## 4. Task Input Screen (`task_input_screen.dart`)

### Form Fields:

1. **Task Name**
   - Text input field
   - Placeholder: "Enter task name"
   - Required field

2. **Subject**
   - Text input field
   - Placeholder: "Enter subject"
   - Required field

3. **Difficulty**
   - Three-option selector (Easy/Medium/Hard)
   - Color-coded backgrounds when selected
   - Easy: Green, Medium: Orange, Hard: Red

4. **Deadline**
   - Tappable field with calendar icon
   - Opens date picker
   - Displays selected date

5. **Estimated Time**
   - Shows hours (e.g., "1 hour", "2 hours")
   - Plus/Minus buttons to adjust
   - Minimum: 1 hour

6. **Category**
   - Two-option selector
   - Study / Personal Development
   - Blue highlight when selected

### Actions:
- **Back Button**: Return to previous screen
- **Generate AI Schedule Button**: Navigate to AI Schedule Screen

---

## 5. AI Schedule Screen (`ai_schedule_screen.dart`)

### Design Elements:

#### A. Info Card
- Blue gradient background
- Star icon with message
- Text: "Your personalized schedule has been generated..."

#### B. Schedule by Day
- Grouped by days (Monday, Tuesday, Wednesday)
- Each day has:
  - Day header with blue accent bar
  - Multiple schedule cards

#### C. Schedule Cards
- **Left side**: Time range in blue box (e.g., "08:00 - 09:30")
- **Center**: Task title and subject
- **Right side**: Colored dot for difficulty
- **Left border**: Colored bar matching difficulty

#### Sample Schedule:
**Monday:**
- 08:00-09:30: Study Math (Hard)
- 14:00-15:00: Gym (Easy)
- 20:00-21:00: Data Structures (Medium)

**Tuesday:**
- 09:00-10:30: Physics Lab (Medium)
- 16:00-17:00: Reading Time (Easy)

**Wednesday:**
- 08:00-09:30: Chemistry Assignment (Hard)
- 15:00-16:00: Meditation (Easy)

### Actions:
- **Regenerate Button**: Outlined button (regenerate schedule)
- **Save Schedule Button**: Blue filled button (return to home)

---

## 6. Tasks Screen (`tasks_screen.dart`) - Placeholder

### Design:
- **Header**: "All Tasks" title
- **Center Content**: 
  - Large task icon (gray)
  - Text: "Tasks view coming soon"

### Purpose:
- Placeholder for future all-tasks view
- Accessible via bottom navigation

---

## 7. Calendar Screen (`calendar_screen.dart`) - Placeholder

### Design:
- **Header**: "Calendar" title
- **Center Content**: 
  - Large calendar icon (gray)
  - Text: "Calendar view coming soon"

### Purpose:
- Placeholder for future calendar view
- Accessible via bottom navigation

---

## 8. Profile Screen (`profile_screen.dart`)

### Design Elements:

#### A. Profile Header
- **Avatar**: Large circular container with person icon
- **Name**: "Tan" in large bold text
- **Role**: "Student" in gray text

#### B. Profile Options (Cards)
- Edit Profile (person icon)
- Notifications (bell icon)
- Settings (gear icon)
- Help & Support (question icon)
- About (info icon)

Each option card:
- Left: Blue icon
- Center: Option name
- Right: Chevron arrow

#### C. Logout Button
- Red outlined button at bottom
- Text: "Logout"

### Interactions:
- Tap any option card → (Can be extended)
- Tap logout → (Can be extended)

---

## Color Coding Reference

### Difficulty Levels:
- **Easy**: Green (#2ECC71)
- **Medium**: Orange (#F39C12)
- **Hard**: Red (#E74C3C)

### Task Status:
- **Completed**: Checkmark visible, text has strikethrough
- **Pending**: Empty checkbox, normal text

### UI States:
- **Selected**: Blue background (#4A90E2)
- **Unselected**: White/Gray background
- **Active**: Blue accent
- **Inactive**: Gray

---

## Navigation Flow

```
Splash Screen
    ↓
Daily Check Screen
    ↓
Home Screen ←→ [Bottom Nav] ←→ Tasks/Calendar/Profile
    ↓ (+ button)
Task Input Screen
    ↓ (Generate AI Schedule)
AI Schedule Screen
    ↓ (Save or Back)
Home Screen
```

---

## Responsive Design Notes

- All cards have consistent padding (16dp)
- Rounded corners (12dp) on all cards
- Soft shadows for depth
- Minimum touch target: 48x48dp
- Text scales appropriately
- Scrollable content where needed
- Safe area padding for notched devices
- Bottom navigation always accessible

---

## Accessibility Features

- Clear text hierarchy
- Color is not the only indicator (icons + text)
- Adequate touch targets
- High contrast between text and background
- Semantic widget structure
- Screen reader compatible

---

## Animation Opportunities (Future)

- Splash screen fade-in
- Card tap ripple effects
- Progress bar animation
- Page transitions
- Button press feedback
- Task completion celebration
- Schedule item swipe actions

---

## Customization Points

1. **User Name**: Change "Tan" in HomeScreen widget
2. **Demo Tasks**: Modify `_todayTasks` list in HomeScreen
3. **Schedule Items**: Edit `scheduleItems` list in AIScheduleScreen
4. **Growth Activities**: Modify GrowthActivityCard widgets in HomeScreen
5. **Colors**: Edit AppColors class in constants.dart
6. **Spacing**: Adjust AppSpacing values in constants.dart
7. **Text Styles**: Modify AppTextStyles in constants.dart
