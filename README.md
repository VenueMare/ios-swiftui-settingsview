# SwiftUI Settings View - Code Example

This repository contains a single file, `SettingsView.swift`, taken directly from a production iOS/macOS app (Venueflux).

This file is not a complete app, but a **real-world code sample** designed to demonstrate my ability to build complex, feature-rich user interfaces using modern, advanced Swift and SwiftUI techniques.

---

## 💡 Key Skills & Technologies Demonstrated

This single file showcases a wide range of essential skills for modern Apple-plattform development:

* **Advanced SwiftUI Layout & State:**
    * Complex `Form` and `Section` structure.
    * Use of `@EnvironmentObject` to manage global app state (like `SettingsState` and `SubscriptionManager`).
    * Advanced state management with `@State`, `@FocusState`, and custom `Binding`s.
    * Dynamic UI updates based on state (e.g., `isEffectivePremium`).

* **Monetization & StoreKit (High-Value Skill):**
    * Integration with a `SubscriptionManager` EnvironmentObject.
    * Logic to show/hide a `PaywallView` (via `.sheet`).
    * Buttons to "Restore Purchases" (`AppStore.sync()`) and "Manage Subscriptions" (linking to the App Store).

* **Security (Keychain & API Key Handling):**
    * Use of `SecureField` for sensitive input.
    * Integration with a `KeychainService` EnvironmentObject to securely store API keys.
    * Client-side logic to fetch API keys from a remote URL (`KeyFetchService`).

* **Asynchronous Operations:**
    * Use of `.task` modifiers and `Task { ... }` blocks to perform asynchronous work, such as fetching keys and updating user notification settings (`NotificationService`).

* **Localization & Internationalization:**
    * Consistent use of `LocalizedStringKey` and `NSLocalizedString` for all user-facing text.
    * Complex date/time formatting logic that respects user preferences (`reminderLocaleOverride`).

* **Professional & Production-Ready Code:**
    * Clean, readable, and well-commented code.
    * Use of `#if DEBUG` blocks to include developer-only tools without shipping them to production.
    * Custom `@ViewBuilder` methods (`proxySettingsSection`) to organize complex view logic.

## 🛠️ Architectural Context

This view is a component within a larger, decoupled architecture. It relies on several `@EnvironmentObject` properties (like `SubscriptionManager`, `KeychainService`, and `SettingsState`) which are injected at a higher level of the app.

This demonstrates a clean separation of concerns:
* The **View** (`SettingsView.swift`) is responsible for *presentation* and *user interaction*.
* **Services** (`SubscriptionManager`, `NotificationService`, etc.) handle the *business logic*.
* **State Objects** (`SettingsState`) hold the app's data.

This code serves as a practical example of my ability to build and maintain complex, secure, and production-ready features for iOS and macOS.
