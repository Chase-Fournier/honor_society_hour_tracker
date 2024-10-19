# NHS Hour Tracking App

The NHS Hour Tracking App is a Flutter application designed to help track and manage volunteer hours for National Honor Society (NHS) members. It provides features for both NHS members and administrators to efficiently log and organize service hours.

## Features

### NHS Member Features
- Log completed service hours, including event name, date, and duration
- View progress towards required service hour goals
- Receive notifications for upcoming volunteer opportunities
- Sign up for available time slots in upcoming events
- View a calendar of scheduled events and registered time slots
- Customize the app's theme color

### Administrator Features
- Create and manage volunteer events with multiple time slots
- View and edit event details, including name, description, date, and time slots
- Track total service hours completed by all members
- Generate reports on member participation and service hour completion
- Manage member profiles and administrator access

## Installation

1. Clone the repository:
   ```
   git clone https://github.com/wheeler_nhs/nhs-hour-tracking-app.git
   ```

2. Navigate to the project directory:
   ```
   cd nhs-hour-tracking-app
   ```

3. Install the dependencies:
   ```
   flutter pub get
   ```

4. Run the app:
   ```
   flutter run
   ```

Note: Make sure you have Flutter and Dart installed on your machine before running the app.

## Dependencies

The NHS Hour Tracking App utilizes the following dependencies:

- `flutter`: The Flutter framework for building the app
- `supabase_flutter`: Integration with Supabase for backend services
- `provider`: State management library for Flutter
- `table_calendar`: A customizable calendar widget for Flutter
- `shared_preferences`: Persistent storage for user preferences
- `intl`: Internationalization and localization support
- `url_launcher`: A Flutter plugin for launching URLs
- `flutter_colorpicker`: A color picker widget for Flutter

For a complete list of dependencies and their versions, please refer to the `pubspec.yaml` file.

## Configuration

The app requires certain configurations to function properly:

1. Supabase Configuration:
   - Set up a Supabase project and obtain the project URL and anonymous key.
   - Update the `supabase_url` and `supabase_anon_key` variables in the `lib/main.dart` file with your Supabase project's URL and anonymous key.

2. Google Sign-In Configuration:
   - Set up Google Sign-In for your Firebase project and obtain the Google web client ID.
   - Update the `google_client_id` variable in the `lib/main.dart` file with your Google web client ID.

## Contributing

Contributions to the NHS Hour Tracking App are welcome! If you encounter any issues or have suggestions for improvements, please open an issue on the GitHub repository.

If you would like to contribute code to the project, please follow these steps:

1. Fork the repository
2. Create a new branch for your feature or bug fix
3. Make your changes and commit them with descriptive commit messages
4. Push your changes to your forked repository
5. Open a pull request detailing your changes

## License

The NHS Hour Tracking App is open-source software licensed under the [MIT License](https://opensource.org/licenses/MIT). You are free to use, modify, and distribute the app as per the terms of the license.

## Contact

If you have any questions, suggestions, or feedback regarding the NHS Hour Tracking App, please contact the project maintainer at forgedwar5@gmail.com.

Happy tracking!
