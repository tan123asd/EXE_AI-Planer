import 'package:flutter/material.dart';

// Colors
class AppColors {
  // Primary Colors - Orange theme
  static const Color primary = Color(0xFFFF6B35);
  static const Color primaryDark = Color(0xFFE85A2A);
  static const Color primaryLight = Color(0xFFFF8C5F);
  
  // Background Colors
  static const Color background = Color(0xFFF8F9FA);
  static const Color cardBackground = Colors.white;
  
  // Text Colors
  static const Color textPrimary = Color(0xFF2D3142);
  static const Color textSecondary = Color(0xFF9CA3AF);
  
  // Status Colors
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);
  
  // Difficulty Colors
  static const Color easy = Color(0xFF10B981);
  static const Color medium = Color(0xFFF59E0B);
  static const Color hard = Color(0xFFEF4444);
  
  // Timeline Colors
  static const Color timelineBlue = Color(0xFFDEE7F7);
  static const Color timelinePeach = Color(0xFFFFE8DD);
  static const Color timelineGreen = Color(0xFFE0F5E9);
  static const Color timelinePurple = Color(0xFFEFE8F7);
  static const Color timelinePink = Color(0xFFFDE8F0);

  // Subject Colors
  static const Color subjectStudy = Color(0xFFFF6B35);
  static const Color subjectPersonal = Color(0xFF7B61FF);
  static const Color subjectHealth = Color(0xFF2FBF71);
  static const Color subjectSkill = Color(0xFF3B82F6);
  static const Color subjectOther = Color(0xFFF59E0B);

  static Color subjectAccentColor(String? subject) {
    switch ((subject ?? '').toLowerCase()) {
      case 'study':
        return subjectStudy;
      case 'personal':
        return subjectPersonal;
      case 'health':
        return subjectHealth;
      case 'skill':
        return subjectSkill;
      default:
        return subjectOther;
    }
  }

  static Color subjectSurface(String? subject) {
    return subjectAccentColor(subject).withOpacity(0.12);
  }

  static Color subjectBorder(String? subject) {
    return subjectAccentColor(subject).withOpacity(0.35);
  }
  
  // Stats Colors
  static const Color studyColor = Color(0xFFFF6B35);
  static const Color growthColor = Color(0xFF9B59B6);
  static const Color restColor = Color(0xFF10B981);
}

// Text Styles
class AppTextStyles {
  static const TextStyle heading1 = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );
  
  static const TextStyle heading2 = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );
  
  static const TextStyle heading3 = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );
  
  static const TextStyle body = TextStyle(
    fontSize: 16,
    color: AppColors.textPrimary,
  );
  
  static const TextStyle bodySecondary = TextStyle(
    fontSize: 14,
    color: AppColors.textSecondary,
  );
  
  static const TextStyle caption = TextStyle(
    fontSize: 12,
    color: AppColors.textSecondary,
  );
}

// Spacing
class AppSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
}

// Border Radius
class AppRadius {
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
}

// Shadows
class AppShadows {
  static List<BoxShadow> card = [
    BoxShadow(
      color: Colors.black.withOpacity(0.08),
      blurRadius: 10,
      offset: const Offset(0, 2),
    ),
  ];
  
  static List<BoxShadow> cardHover = [
    BoxShadow(
      color: Colors.black.withOpacity(0.12),
      blurRadius: 20,
      offset: const Offset(0, 4),
    ),
  ];
}
