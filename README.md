# Honor Society Hour Tracking App

The Honor Society Hour Tracking App is a comprehensive Flutter application designed to streamline the process of tracking and managing volunteer hours for National Honor Society (NHS) members and other Honor Societies. It offers a robust set of features for both members and administrators to efficiently log, monitor, and organize service activities.

## 👋 Welcome

Thanks for stopping by! Whether you're an member curious about the app, an administrator setting it up for your chapter/Society, or a developer who wants to contribute — you're in the right place.

This is an open-source, multi-tenant app: a single user can belong to multiple honor societies and switch between them. It's built with **Flutter** on the front end and **Supabase** (Postgres + auth + row-level security) on the back end, with no separate API layer.

New here? A quick map of where to go:

* **Just want to try it?** Head to [🚀 Getting Started](#-getting-started).
* **Setting it up for a society?** See [⚙️ Configuration](#️-configuration).
* **Want to contribute?** Read the [Contributing Guide](CONTRIBUTING.md) — it covers local setup, our conventions, and how to open a great pull request.
* **Curious how it's built?** Browse [🏗️ Project Structure](#️-project-structure-lib-folder) and the in-depth notes in [`CLAUDE.md`](CLAUDE.md).

Questions are always welcome — open an [issue](https://github.com/Chase-Fournier/wheeler_nhs/issues) and we'll help out.

## ✨ Features

The app is packed with features to enhance the NHS experience:

**For NHS Members:**
* **Log Service Hours:** Easily log completed service hours with details like event name, date, and duration.
* **Track Progress:** View real-time progress towards required service hour goals for different categories.
* **Event Sign-up:** Discover and sign up for available time slots in upcoming volunteer opportunities.
* **Event Calendar:** View a comprehensive calendar of scheduled events and personal registered time slots.
* **Notifications:** Receive timely notifications for upcoming volunteer opportunities and important announcements.
* **Theme Customization:** Personalize the app's appearance by choosing a custom theme color.
* **Hour Swapping:** Request to swap time slots with other members if unable to attend.

**For Administrators:**
* **Event Management:** Create, manage, and edit volunteer events, including descriptions, dates, and multiple time slots.
* **Attendance Tracking:** Mark and manage member attendance for events and time slots.
* **Hour Management:** View and edit service hour records for members.
* **Member Oversight:** Track total service hours completed by all members and individual progress.
* **Reporting:** Generate reports on member participation and service hour completion (including Excel export).
* **Profile Management:** Manage member profiles and administrator access levels.
* **Join Request Management:** Approve or deny requests from users wishing to join the society.
* **Meeting Notes:** Create and manage meeting notes for members to view.
* **Activity Log:** View a log of important actions performed within the app for auditing.
* **Bulk Operations:** Perform bulk actions such as adding custom hours for multiple users.

**Miscellaneous:**
* **Snake Game:** A fun, classic game included within the app.

## 🚀 Getting Started

Follow these instructions to get a copy of the project up and running on your local machine for development and testing purposes.

### Prerequisites

* [Flutter SDK](https://flutter.dev/docs/get-started/install) (ensure it's added to your PATH)
* A code editor like [VS Code](https://code.visualstudio.com/) or [Android Studio](https://developer.android.com/studio)
* Supabase Account & Project (see Configuration)

### Installation

1.  **Clone the repository:**
    ```sh
    git clone https://github.com/Chase-Fournier/wheeler_nhs.git
    ```

2.  **Navigate to the project directory:**
    ```sh
    cd wheeler_nhs
    ```

3.  **Install dependencies:**
    ```sh
    flutter pub get
    ```

4.  **Run the app:**
    ```sh
    flutter run
    ```

## ⚙️ Configuration

The application requires backend configuration with Supabase.

1.  **Supabase Setup:**
    * Create a project on [Supabase](https://supabase.com/).
    * Obtain your Project URL and Anon Key.
    * Update the following variables in `lib/main.dart`:
        ```dart
        await Supabase.initialize(
          url: 'YOUR_SUPABASE_URL', // Replace with your Supabase Project URL
          anonKey: 'YOUR_SUPABASE_ANON_KEY', // Replace with your Supabase Anon Key
        );
        ```

2.  **Google Sign-In (via Supabase):**
    * To enable Google Sign-In, configure it within your Supabase project dashboard under "Authentication" -> "Providers".
    * Follow the Supabase documentation for setting up Google OAuth, which will involve providing necessary Android (SHA-1 fingerprint) and iOS (Bundle ID, App Store ID) credentials in your Google Cloud Console and then back in Supabase.
    * Ensure you have the necessary platform-specific configurations:
        * For **Android**: Add your `google-services.json` file to `android/app/`.
        * For **iOS**: Configure URL Schemes as per Supabase and Google Sign-In documentation.

## 🏗️ Project Structure (lib folder)

* **`common/`**: Contains shared utilities, design constants (`app_design.dart`), theme configurations (`app_theme.dart`), custom widgets (`app_widgets.dart`), and helper functions (e.g., `iconutils.dart`, `nhsformatutils.dart`).
* **`models/`**: Defines the data structures used throughout the application (e.g., `Event.dart`, `UserProfile.dart`, `HonorSociety.dart`).
* **`providers/`**: Manages the application's state using the Provider package (e.g., `societyprovider.dart`, `themeprovider.dart`).
* **`screens/`**: Contains all the UI screens for different parts of the application.
* **`main.dart`**: The entry point of the application, including Supabase initialization.

## 📦 Dependencies

This project utilizes the following key dependencies (see `pubspec.yaml` for a full list and versions):

* `flutter`: The core Flutter framework.
* `supabase_flutter`: Integration with Supabase for backend services.
* `supabase_auth_ui`: Provides pre-built UI for Supabase authentication.
* `provider`: State management.
* `google_sign_in`: For Google authentication (managed via Supabase Auth UI).
* `intl`: For internationalization and date/time formatting.
* `flutter_colorpicker`: For theme customization.
* `url_launcher`: For opening external links.
* `shared_preferences`: For persistent local storage.
* `add_2_calendar`: For adding events to the device calendar.
* `excel`: For exporting data to Excel format.
* `google_fonts`: For custom fonts.

## 🤝 Contributing

Contributions are welcome — bug reports, feature ideas, docs, and code all help. The fastest way to get started is the **[Contributing Guide](CONTRIBUTING.md)**, which walks through local setup, our coding conventions, and the pull-request workflow.

The short version:

1.  Fork the repository and clone your fork.
2.  Create a branch for your change (`git checkout -b feature/your-feature-name`).
3.  Make your changes, then run `flutter analyze` and `flutter test`.
4.  Commit with a descriptive message and push to your fork.
5.  Open a pull request against `Chase-Fournier/wheeler_nhs` describing what and why.

Found a bug or have a suggestion? Open an [issue](https://github.com/Chase-Fournier/wheeler_nhs/issues).

## 📜 License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

## 📞 Contact

For any questions or feedback please open an issue on the [GitHub repository issues page](https://github.com/Chase-Fournier/wheeler_nhs/issues).

---

Happy Tracking!
