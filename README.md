# BMS - Battery Management System

A specialized inventory management system for batteries, built with Flutter.

## 🌟 Key Features

*   **Inventory Management:** Easily add, edit, and track batteries in your inventory.
*   **Barcode Scanning:** Quickly scan battery barcodes to find them in the inventory.
*   **Reporting:** Generate reports in PDF and CSV format.
*   **Firebase Integration:** Uses Firebase for authentication, database, and storage.
*   **State Management:** Built with Riverpod for robust and scalable state management.
*   **Cross-Platform:** Works on Android, iOS, Web, and Desktop.


## 🚀 Getting Started

To get a local copy up and running, follow these simple steps.

### Prerequisites

*   You need to have Flutter installed. For instructions, see the [official Flutter documentation](https://flutter.dev/docs/get-started/install).
*   A Firebase project.

### Installation

1.  **Clone the repo**
    ```sh
    git clone https://github.com/polarxpression/bms.git
    ```
2.  **Install packages**
    ```sh
    flutter pub get
    ```
3.  **Firebase Setup**
    *   Follow the instructions to add Firebase to your Flutter app for [Android](https://firebase.google.com/docs/flutter/setup?platform=android), [iOS](https://firebase.google.com/docs/flutter/setup?platform=ios), and [Web](https://firebase.google.com/docs/flutter/setup?platform=web).
    *   You will need to add your own `google-services.json` file for Android and `GoogleService-Info.plist` for iOS.
    *   For the web, you'll need to initialize Firebase in `web/index.html`.

4.  **Run the app**
    ```sh
    flutter run
    ```

## 📁 Project Structure

The project is structured as follows:

```
lib/
├── core/
│   ├── models/         # Core data models (e.g., Battery)
│   └── utils/          # Utility functions
├── src/
│   ├── data/
│   │   ├── models/     # Data models for Firestore
│   │   └── services/   # Services for interacting with APIs (e.g., Firebase)
│   ├── presentation/
│   │   ├── screens/    # UI for each screen
│   │   └── widgets/    # Reusable UI widgets
│   └── providers/      # Riverpod providers
├── state/              # Application state management
└── ui/                 # General UI components and layouts
```

---

Built with ❤️ by [Polar](https://github.com/polarxpression)
<img src="https://polar.is-a.dev/images/logo-white.svg" width="20px" style="position:relative; top: 4px">