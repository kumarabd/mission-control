# Mission Control

Mission Control is a calm, native iOS dashboard for the work that matters today.

## V1 scope

- A live current time and date header.
- Local, SwiftData-backed tasks: add and complete tasks.
- Project cards backed by mock GitHub repository data, showing repository name, description, and activity derived from `pushed_at`.

## Architecture

The app intentionally uses a lightweight, feature-oriented layout:

```
MissionControl/
├── App/                 App entry point and SwiftData container
├── Models/              MissionTask and GitHubRepository
├── Features/
│   ├── Dashboard/       Screen composition and clock
│   ├── Tasks/           Task list, row, and task creation
│   └── Projects/        Repository cards
└── Services/            Repository data provider (mock in V1)
```

`MockGitHubService` is the seam for a future authenticated GitHub API client. Tasks are persisted locally via SwiftData; repository data remains read-only in this version.

## Run

Open `MissionControl.xcodeproj` in Xcode 16 or later, select an iOS 17+ simulator or device, and run the **MissionControl** scheme.

