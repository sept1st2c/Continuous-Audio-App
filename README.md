
A simple yet powerful Flutter application that allows users to record and play audio effortlessly. The app is theme-aware (light/dark mode), supports offline storage, and features real-time audio visualizations.

✨ Features
🎧 Record & Play Audio
Record high-quality audio using the record package and play it back with the just_audio package.

🌗 Adaptive Theming
The UI automatically adapts to the system's light or dark mode.

🔍 Search Functionality
Easily search through saved recordings by filename.

💾 Persistent Storage
Recordings are saved locally using shared_preferences for quick access and state management.

📂 File Management
Utilizes path_provider to manage recording storage within app directories.

📊 Live Visualizer
Real-time waveform visualization for both recording and playback powered by mini_music_visualizer.


📦 Dependencies

Package	Description
just_audio:	Audio playback
record:	Audio recording
shared_preferences:	Local storage for saved data
path_provider:	Access to device storage paths
mini_music_visualizer:	Waveform visualizer during audio


🚀 Getting Started
Clone the repository

git clone https://github.com/your-username/flutter-audio-recorder-player.git
cd flutter-audio-recorder-player

Install dependencies

flutter pub get
Run the app
flutter run


📂 Folder Structure (Brief)

lib/
│
├── main.dart                    # App entry point
├── widgets/                     # Custom widgets (e.g., build body)
├── screen/                      # App screens
└── theme/                      # Light & dark mode themes

![Screenshot_20250419_161158](https://github.com/user-attachments/assets/a6e5695a-a889-4e0c-8d7e-ec4a4c88398e)
![Screenshot_20250419_161305](https://github.com/user-attachments/assets/cb3570ed-909a-4699-8560-afc810ffead4)

![Screenshot_20250419_161710](https://github.com/user-attachments/assets/bdd60600-b334-43f3-a091-2bc9afbf529d)
![Screenshot_20250419_161804](https://github.com/user-attachments/assets/3acae691-5c07-46eb-9714-ee7bce183826)


🙌 Contribution
Pull requests are welcome. For major changes, please open an issue first to discuss what you would like to change.

📄 License
This project is open-sourced under the MIT License.
