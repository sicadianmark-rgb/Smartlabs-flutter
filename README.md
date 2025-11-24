# 🔬 SmartLab - Laboratory Equipment Management System

A comprehensive Flutter mobile application for managing laboratory equipment borrowing, tracking, and analytics in educational institutions. Built with Flutter and Firebase for real-time data management and intelligent equipment recommendations.

## 📋 Table of Contents

- [Overview](#overview)
- [Key Features](#key-features)
- [Tech Stack](#tech-stack)
- [Getting Started](#getting-started)
- [Project Structure](#project-structure)
- [User Roles](#user-roles)
- [Advanced Features](#advanced-features)
- [Firebase Configuration](#firebase-configuration)
- [Contributing](#contributing)

## 🎯 Overview

SmartLab is a modern mobile application designed to streamline laboratory equipment management in educational institutions. It enables students to browse and request equipment, teachers to manage requests and inventory, and provides intelligent recommendations based on borrowing patterns using association rule mining algorithms.

### Why SmartLab?

- **Efficient Equipment Management**: Track equipment availability in real-time
- **Smart Recommendations**: AI-powered suggestions based on borrowing patterns
- **Seamless Workflow**: From request to approval to return tracking
- **Data-Driven Insights**: Analytics dashboard for usage patterns
- **Role-Based Access**: Separate interfaces for students and teachers

## ✨ Key Features

### For Students 👨‍🎓

- 📱 **Browse Equipment**: View all available laboratory equipment by category
- 🛒 **Cart System**: Add multiple items to cart for batch borrowing
- 💡 **Smart Recommendations**: Get AI-powered suggestions for related equipment
- 📝 **Request Management**: Submit and track borrowing requests
- 📊 **Borrowing History**: View complete history with status tracking
- 🔔 **Real-time Notifications**: Get notified about request status changes
- 👤 **Profile Management**: Manage student information and preferences

### For Teachers 👩‍🏫

- ✅ **Request Approval**: Review and approve/reject student requests
- 📦 **Equipment Management**: Add, edit, and delete equipment items
- 🏷️ **Category Management**: Organize equipment into categories
- 📊 **Request Dashboard**: View all pending, approved, and rejected requests
- 🔔 **Notification System**: Stay updated on new requests
- 📈 **Equipment Tracking**: Monitor equipment usage and availability

### Advanced Analytics 📊

- **Association Rule Mining**: Discover patterns in equipment borrowing
  - Support, Confidence, and Lift metrics
  - Frequently borrowed together patterns
  - Real-time pattern updates
- **Usage Statistics**: Track most popular equipment
- **Recent Activity**: Monitor borrowing trends
- **Request Analytics**: Comprehensive request statistics

## 🛠️ Tech Stack

### Frontend

- **Flutter** - Cross-platform mobile framework
- **Dart** - Programming language
- **Material Design 3** - Modern UI components

### Backend

- **Firebase Authentication** - User authentication and authorization
- **Firebase Realtime Database** - Real-time data synchronization
- **Firebase Cloud Messaging** - Push notifications (ready for implementation)

### Algorithms

- **Association Rule Mining** - Apriori-like algorithm for pattern discovery
- **Recommendation Engine** - Intelligent equipment suggestions

### State Management

- **Provider Pattern** - For cart and service management
- **ChangeNotifier** - Reactive state updates

## 🚀 Getting Started

### Prerequisites

- Flutter SDK (3.0.0 or higher)
- Dart SDK (3.0.0 or higher)
- Android Studio / VS Code with Flutter extensions
- Firebase account

### Installation

1. **Clone the repository**

   ```bash
   git clone https://github.com/yourusername/smartlab.git
   cd smartlab
   ```

2. **Install dependencies**

   ```bash
   flutter pub get
   ```

3. **Configure Firebase**

   - Create a new Firebase project at [Firebase Console](https://console.firebase.google.com)
   - Add Android/iOS apps to your Firebase project
   - Download `google-services.json` (Android) and place in `android/app/`
   - Download `GoogleService-Info.plist` (iOS) and place in `ios/Runner/`
   - Update Firebase Database URL in the code (see [Firebase Configuration](#firebase-configuration))

4. **Run the app**
   ```bash
   flutter run
   ```

### First Time Setup

1. Launch the app
2. Register a new account
3. Select your role (Student or Teacher)
4. Complete profile setup
5. Start using SmartLab!

## 📁 Project Structure

```
lib/
├── auth/                          # Authentication screens
│   ├── login_page.dart           # Login interface
│   ├── register_page.dart        # Registration interface
│   └── profile_setup.dart        # Role selection and profile setup
│
├── home/                         # Main application screens
│   ├── home_page.dart           # Main dashboard
│   ├── equipment_page.dart      # Equipment browsing
│   ├── cart_page.dart           # Shopping cart with recommendations
│   ├── category_items_page.dart # Category-specific items
│   ├── form_page.dart           # Borrowing request form
│   ├── batch_borrow_form_page.dart # Batch borrowing
│   ├── request_page.dart        # Request management (teacher)
│   ├── borrowing_history_page.dart # Student borrowing history
│   ├── analytics_page.dart      # Analytics dashboard
│   ├── profile_page.dart        # User profile
│   ├── equipment_management_page.dart # Equipment CRUD
│   ├── bottomnavbar.dart        # Role-based navigation
│   ├── announcement_card.dart   # System announcements
│   ├── notification_modal.dart  # Notification center
│   │
│   ├── models/                  # Data models
│   │   └── equipment_models.dart
│   │
│   ├── service/                 # Business logic and services
│   │   ├── equipment_service.dart           # Equipment operations
│   │   ├── cart_service.dart                # Cart management
│   │   ├── notification_service.dart        # Notifications
│   │   ├── teacher_service.dart             # Teacher-specific services
│   │   ├── form_service.dart                # Request submission
│   │   └── association_mining_service.dart  # AI recommendations
│   │
│   └── widgets/                 # Reusable widgets
│       └── [custom widgets]
│
├── services/                    # Global services
│   └── auth_gate.dart          # Authentication routing
│
├── main.dart                    # Application entry point
└── firebase_options.dart        # Firebase configuration

```

## 👥 User Roles

### Student Role

**Capabilities:**

- Browse and search equipment
- Add items to cart
- Submit borrowing requests
- View borrowing history
- Receive recommendations
- Track request status
- Manage profile

**Dashboard Tabs:**

- Home
- Equipment
- History
- Profile

### Teacher Role

**Capabilities:**

- All student capabilities
- Approve/reject requests
- Add/edit/delete equipment
- Manage categories
- View all requests
- Send notifications
- Access analytics

**Dashboard Tabs:**

- Home
- Equipment
- Requests
- Profile

## 🤖 Advanced Features

### Association Rule Mining

SmartLab uses a sophisticated association rule mining algorithm to discover patterns in equipment borrowing behavior.

#### How It Works

1. **Data Collection**: Analyzes historical borrowing data
2. **Pattern Discovery**: Identifies frequently co-borrowed items
3. **Metric Calculation**:
   - **Support**: Frequency of item pairs
   - **Confidence**: Probability of borrowing item B given item A
   - **Lift**: Strength of association (>1 indicates positive correlation)

#### Practical Example

```
Pattern Found: Beaker → Test Tube
├─ Support: 45.2% (borrowed together in 45% of cases)
├─ Confidence: 78.5% (78.5% of Beaker borrowers also get Test Tubes)
└─ Lift: 2.3 (strong positive correlation)

Result: When a student adds Beaker to cart,
        Test Tube is recommended with high confidence
```

#### Implementation

```dart
// Get recommendations based on cart items
final recommendations = await AssociationMiningService.getRecommendations(
  currentCartItems,
  maxRecommendations: 5,
);
```

#### Tunable Parameters

```dart
minSupport: 0.02      // Minimum 2% occurrence rate
minConfidence: 0.3    // Minimum 30% confidence
minLift: 1.0          // Only positive correlations
```

### Smart Cart System

The cart intelligently suggests related items as you add equipment:

```
Your Cart:
├─ Beaker (x2)
├─ Bunsen Burner (x1)
│
└─ 💡 You might also need:
   ├─ ✨ Test Tube
   ├─ ✨ Pipette
   └─ ✨ Thermometer

   Based on borrowing patterns
```

### Real-time Notifications

- Request approval/rejection alerts
- Equipment availability updates
- Due date reminders
- System announcements

## 🔥 Firebase Configuration

### Database Structure

```
smartlab-database/
├── users/
│   └── {userId}
│       ├── name
│       ├── email
│       ├── role (student/teacher)
│       ├── course (student only)
│       ├── yearLevel (student only)
│       └── section (student only)
│
├── equipment_categories/
│   └── {categoryId}
│       ├── title
│       ├── availableCount
│       ├── totalCount
│       ├── icon
│       └── equipments/
│           └── {itemId}
│               ├── name
│               ├── description
│               ├── quantity
│               ├── status
│               └── laboratory
│
├── borrow_requests/
│   └── {requestId}
│       ├── userId
│       ├── userEmail
│       ├── itemId
│       ├── itemName
│       ├── categoryId
│       ├── quantity
│       ├── status (pending/approved/rejected)
│       ├── dateToBeUsed
│       ├── dateToReturn
│       ├── adviserName
│       ├── adviserId
│       └── requestedAt
│
├── notifications/
│   └── {userId}
│       └── {notificationId}
│           ├── title
│           ├── message
│           ├── type
│           ├── isRead
│           └── createdAt
│
└── system_notifications/
    └── {announcementId}
        ├── title
        ├── message
        ├── priority
        └── createdAt
```

### Database URL Configuration

Update the Firebase Realtime Database URL in multiple files:

```dart
// In lib/home/home_page.dart, lib/home/equipment_page.dart, etc.
FirebaseDatabase.instance.databaseURL =
    'https://YOUR-PROJECT-ID-default-rtdb.YOUR-REGION.firebasedatabase.app';
```

### Security Rules

Update `database.rules.json`:

```json
{
  "rules": {
    ".read": "auth != null",
    ".write": "auth != null",
    "users": {
      "$uid": {
        ".write": "$uid === auth.uid"
      }
    },
    "borrow_requests": {
      ".indexOn": ["userId", "status", "requestedAt"]
    },
    "equipment_categories": {
      ".indexOn": ["title"]
    }
  }
}
```

## 📱 Screenshots & Features

### Student Experience

- Clean, intuitive interface
- Material Design 3 components
- Smooth animations and transitions
- Real-time data updates

### Teacher Dashboard

- Request management interface
- Equipment CRUD operations
- Analytics and reporting
- Batch operations support

## 🧪 Testing

Run tests:

```bash
flutter test
```

Run with coverage:

```bash
flutter test --coverage
```

## 🔐 Security

- Firebase Authentication for secure login
- Role-based access control
- Secure data transmission
- Input validation and sanitization
- Database security rules

## 📈 Future Enhancements

- [ ] QR code scanning for equipment
- [ ] Equipment reservation system
- [ ] Maintenance scheduling
- [ ] Export reports (PDF/Excel)
- [ ] Multi-language support
- [ ] Push notifications
- [ ] Equipment location tracking
- [ ] Image uploads for equipment
- [ ] Advanced search filters
- [ ] Calendar integration

## 🤝 Contributing

Contributions are welcome! Please follow these steps:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

### Code Style

- Follow [Effective Dart](https://dart.dev/guides/language/effective-dart) guidelines
- Use meaningful variable names
- Comment complex logic
- Write widget documentation

## 🙏 Acknowledgments

- Flutter team for the amazing framework
- Firebase for backend infrastructure
- Material Design team for UI guidelines
- All contributors and testers

## 📞 Support

For support, email [dev.bimrochee@gmail.com] or open an issue in the repository.

---

<p align="center">
  Made with ❤️ using Flutter
</p>

<p align="center">
  <strong>SmartLab</strong> - Making Laboratory Management Smart and Simple
</p>
```
