# Engineering Projects Management Flutter Application

## Project Overview
This application is designed to help manage engineering projects efficiently by providing a user-friendly interface for project tracking, task management, and resource allocation.

## Features
- Project tracking  
- Task management  
- Resource allocation  
- User authentication  
- Integration with Firebase  
- Responsive design for various devices  

## Architecture
The architecture follows the MVVM (Model-View-ViewModel) design pattern, promoting the separation of concerns and enhancing maintainability and testability.

## Tech Stack
- **Flutter**: Framework for building natively compiled applications for mobile.
- **Firebase**: Backend as a service for authentication, real-time database, and hosting solutions.
- **Dart**: Programming language used for Flutter development.

## Installation Instructions
1. Clone the repository:
   ```bash
   git clone https://github.com/HamedBarakat/mangprojects.git
   ```
2. Navigate into the project directory:
   ```bash
   cd mangprojects
   ```
3. Install dependencies:
   ```bash
   flutter pub get
   ```

## Setup Steps for Firebase
1. Create a new project in the Firebase console.
2. Add an Android/iOS app in the Firebase project settings.
3. Download the `google-services.json` for Android or `GoogleService-Info.plist` for iOS and place them in the respective directories.
4. Enable necessary Firebase services (e.g., Firestore, Firebase Authentication).

## Usage Guide
- To run the application:
  ```bash
  flutter run
  ```
- Ensure you have an emulator or physical device connected.

## Contributing Guidelines
1. Fork the repository.
2. Create a new branch for your feature:
   ```bash
   git checkout -b feature-name
   ```
3. Make your changes and commit them:
   ```bash
   git commit -m 'Add some feature'
   ```
4. Push to the branch:
   ```bash
   git push origin feature-name
   ```
5. Create a new Pull Request.

## License
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
