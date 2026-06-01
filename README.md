# Kubegrandson

![Kubegrandson](assets/icons/app64.png)

Kubegrandson is a Flutter desktop app for Kubernetes troubleshooting and log analysis.

## Beta status

This is a beta version tested for:

- Ubuntu Linux (Debian-based)
- Windows 11 (also works on Windows 10 for installer flow)

## Main changes in this beta

### 1) Offline JSON log import

You can import an external JSON log file and inspect it offline.

![Offline JSON log import](https://private-user-images.githubusercontent.com/2098810/600970475-3b8ea77c-a741-4011-b991-f5ee1a46132e.png?jwt=eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJnaXRodWIuY29tIiwiYXVkIjoicmF3LmdpdGh1YnVzZXJjb250ZW50LmNvbSIsImtleSI6ImtleTUiLCJleHAiOjE3ODAzNDM3MjAsIm5iZiI6MTc4MDM0MzQyMCwicGF0aCI6Ii8yMDk4ODEwLzYwMDk3MDQ3NS0zYjhlYTc3Yy1hNzQxLTQwMTEtYjk5MS1mNWVlMWE0NjEzMmUucG5nP1gtQW16LUFsZ29yaXRobT1BV1M0LUhNQUMtU0hBMjU2JlgtQW16LUNyZWRlbnRpYWw9QUtJQVZDT0RZTFNBNTNQUUs0WkElMkYyMDI2MDYwMSUyRnVzLWVhc3QtMSUyRnMzJTJGYXdzNF9yZXF1ZXN0JlgtQW16LURhdGU9MjAyNjA2MDFUMTk1MDIwWiZYLUFtei1FeHBpcmVzPTMwMCZYLUFtei1TaWduYXR1cmU9NGRmMmYyZGM0Mjk4NThhYmJjODM5Njk5NjYyODdhNDYzMWVmNzFkNGMwYTE3MGRlYTA3Y2FiNjc1OGY2NDkxNyZYLUFtei1TaWduZWRIZWFkZXJzPWhvc3QmcmVzcG9uc2UtY29udGVudC10eXBlPWltYWdlJTJGcG5nIn0.w-xud2nsccOhQX7wl3BCaJ7JA7_c1oWIEABVccEVFLU)

### 2) Kubernetes context switch (minikube / AWS EKS)

You can switch Kubernetes context from the UI. For AWS EKS, local AWS access must already be available.

![Context selector](assets/screenshots/beta-context-selector-eks-minikube.png)

When using EKS, make sure the selected kubeconfig file points to the right `.kube/config`.

![Home context view](assets/screenshots/beta-home-minikube-context.png)

### 3) Add troubleshooting markers in the log

You can add log markers without clearing the current log stream.

![Log marker](https://private-user-images.githubusercontent.com/2098810/599717027-d5745ab3-3e37-4ee9-ba6b-c0c0414d4f56.png?jwt=eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJnaXRodWIuY29tIiwiYXVkIjoicmF3LmdpdGh1YnVzZXJjb250ZW50LmNvbSIsImtleSI6ImtleTUiLCJleHAiOjE3ODAzNDM3MjAsIm5iZiI6MTc4MDM0MzQyMCwicGF0aCI6Ii8yMDk4ODEwLzU5OTcxNzAyNy1kNTc0NWFiMy0zZTM3LTRlZTktYmE2Yi1jMGMwNDE0ZDRmNTYucG5nP1gtQW16LUFsZ29yaXRobT1BV1M0LUhNQUMtU0hBMjU2JlgtQW16LUNyZWRlbnRpYWw9QUtJQVZDT0RZTFNBNTNQUUs0WkElMkYyMDI2MDYwMSUyRnVzLWVhc3QtMSUyRnMzJTJGYXdzNF9yZXF1ZXN0JlgtQW16LURhdGU9MjAyNjA2MDFUMTk1MDIwWiZYLUFtei1FeHBpcmVzPTMwMCZYLUFtei1TaWduYXR1cmU9ZjM0MjZjMjFjYTllYmY0NjM5NDBkMDM2Y2Q0MTQ4MDllNWRlNTAwYTMxY2E5NGU3MDAzYzcxMTc5ODhhMmY2YiZYLUFtei1TaWduZWRIZWFkZXJzPWhvc3QmcmVzcG9uc2UtY29udGVudC10eXBlPWltYWdlJTJGcG5nIn0.z4TT51a1UTkpVx3yCBbGOmYUb2blfcW9uH1i_5f-Rqk)

### 4) Non-JSON log rendering

Logs that are not JSON are still supported and visualized correctly.

![Non-JSON logs](https://private-user-images.githubusercontent.com/2098810/599717417-fe8c449b-2d63-4471-b7ed-7ef7f66dca43.png?jwt=eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJnaXRodWIuY29tIiwiYXVkIjoicmF3LmdpdGh1YnVzZXJjb250ZW50LmNvbSIsImtleSI6ImtleTUiLCJleHAiOjE3ODAzNDM3MjAsIm5iZiI6MTc4MDM0MzQyMCwicGF0aCI6Ii8yMDk4ODEwLzU5OTcxNzQxNy1mZThjNDQ5Yi0yZDYzLTQ0NzEtYjdlZC03ZWY3ZjY2ZGNhNDMucG5nP1gtQW16LUFsZ29yaXRobT1BV1M0LUhNQUMtU0hBMjU2JlgtQW16LUNyZWRlbnRpYWw9QUtJQVZDT0RZTFNBNTNQUUs0WkElMkYyMDI2MDYwMSUyRnVzLWVhc3QtMSUyRnMzJTJGYXdzNF9yZXF1ZXN0JlgtQW16LURhdGU9MjAyNjA2MDFUMTk1MDIwWiZYLUFtei1FeHBpcmVzPTMwMCZYLUFtei1TaWduYXR1cmU9OTUwM2Q3NzQ1YWU4NzU4MzczMzk4NDQ0Mzk5NzJlOWMyZWRhNTZhNWFlMzI4OTYyNmQyZDFlYjVmY2UyZmI0OCZYLUFtei1TaWduZWRIZWFkZXJzPWhvc3QmcmVzcG9uc2UtY29udGVudC10eXBlPWltYWdlJTJGcG5nIn0.NSA6K4xk_ICrvX1FXI_a5yl_6y8zIiBMTvnnNZkIwTc)

### 5) Deployment and ConfigMap inspection/editing

You can open and edit Deployment and ConfigMap data related to selected pods.

![Deployment and ConfigMap editor](https://private-user-images.githubusercontent.com/2098810/599721888-8993fae3-b05f-4f97-8289-5d6f6b585cfb.png?jwt=eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJnaXRodWIuY29tIiwiYXVkIjoicmF3LmdpdGh1YnVzZXJjb250ZW50LmNvbSIsImtleSI6ImtleTUiLCJleHAiOjE3ODAzNDM3MjAsIm5iZiI6MTc4MDM0MzQyMCwicGF0aCI6Ii8yMDk4ODEwLzU5OTcyMTg4OC04OTkzZmFlMy1iMDVmLTRmOTctODI4OS01ZDZmNmI1ODVjZmIucG5nP1gtQW16LUFsZ29yaXRobT1BV1M0LUhNQUMtU0hBMjU2JlgtQW16LUNyZWRlbnRpYWw9QUtJQVZDT0RZTFNBNTNQUUs0WkElMkYyMDI2MDYwMSUyRnVzLWVhc3QtMSUyRnMzJTJGYXdzNF9yZXF1ZXN0JlgtQW16LURhdGU9MjAyNjA2MDFUMTk1MDIwWiZYLUFtei1FeHBpcmVzPTMwMCZYLUFtei1TaWduYXR1cmU9ZjhkMzhlN2I5Njc5ODY0ZjY5NDNlMDEwZmZiN2RmYzk0NWIzZGNjYjkwZTc0YzUwNWUyOTUzMDM5MTkxNzYwYSZYLUFtei1TaWduZWRIZWFkZXJzPWhvc3QmcmVzcG9uc2UtY29udGVudC10eXBlPWltYWdlJTJGcG5nIn0.qbajczfuuFYQYTy6B6UXPXp-CmPlaLLCzD17qcOmvek)

### 6) AWS auth flow improvements

- Dedicated AWS settings section for profile, region, cluster, account, and SSO metadata
- Explicit AWS unauthorized guidance in the UI
- Retry flow for expired EKS credentials

Legacy 401 view (before the updated guidance):

## Kubernetes and AWS configuration

In **Settings**, configure:

- `Kubeconfig File` (used by the app for initialization and context switching)
- AWS EKS fields (profile, region, cluster, account, SSO URL, SSO region)

Then click **SSO Login & Update kubeconfig** to run the AWS refresh flow from the app.

Security note:

- Do not store or share raw temporary AWS access key/secret/session token values in docs or screenshots.
- Use profile-based SSO where possible.

## Installation

### Ubuntu (Debian-based)

Install with package manager (UI):

![Ubuntu package install](https://private-user-images.githubusercontent.com/2098810/589718108-890dd233-2b84-434e-aec8-7634a247e79d.png)

Install from terminal:

```bash
sudo apt install kubegrandson_0.0.2_amd64.deb
```

Uninstall:

```bash
sudo apt remove kubegrandson
```

### Windows

Run `kubegrandson_setup.exe` to install on Windows 10/11.

Windows SmartScreen can show a warning for unsigned internal builds:

- Click `More info`
- Click `Run anyway`

Uninstall options:

1. Settings -> Apps -> Installed apps -> Kubegrandson -> Uninstall
2. Control Panel -> Programs -> Uninstall a program -> Kubegrandson
3. Start Menu -> Kubegrandson -> Uninstall Kubegrandson

During uninstall, if asked about user data:

| Choice | Result |
| --- | --- |
| No (default) | Removes binaries only, keeps user data under `%LOCALAPPDATA%` / `%APPDATA%` |
| Yes | Removes binaries and user data folders |

## Development

```bash
flutter pub get
flutter run -d windows
```

or

```bash
flutter run -d linux
```
