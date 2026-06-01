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

![Offline JSON log import](https://private-user-images.githubusercontent.com/2098810/600970475-3b8ea77c-a741-4011-b991-f5ee1a46132e.png)

### 2) Kubernetes context switch (minikube / AWS EKS)

You can switch Kubernetes context from the UI. For AWS EKS, local AWS access must already be available.

![Context selector](assets/screenshots/beta-context-selector-eks-minikube.png)

When using EKS, make sure the selected kubeconfig file points to the right `.kube/config`.

![Home context view](assets/screenshots/beta-home-minikube-context.png)

### 3) Add troubleshooting markers in the log

You can add log markers without clearing the current log stream.

![Log marker](https://private-user-images.githubusercontent.com/2098810/599717027-d5745ab3-3e37-4ee9-ba6b-c0c0414d4f56.png)

### 4) Non-JSON log rendering

Logs that are not JSON are still supported and visualized correctly.

![Non-JSON logs](https://private-user-images.githubusercontent.com/2098810/599717417-fe8c449b-2d63-4471-b7ed-7ef7f66dca43.png)

### 5) Deployment and ConfigMap inspection/editing

You can open and edit Deployment and ConfigMap data related to selected pods.

![Deployment and ConfigMap editor](https://private-user-images.githubusercontent.com/2098810/599721888-8993fae3-b05f-4f97-8289-5d6f6b585cfb.png)

### 6) AWS auth flow improvements

- Dedicated AWS settings section for profile, region, cluster, account, and SSO metadata
- Explicit AWS unauthorized guidance in the UI
- Retry flow for expired EKS credentials

![AWS unauthorized guidance](assets/screenshots/beta-aws-unauthorized-guidance.png)

Legacy 401 view (before the updated guidance):

![AWS 401 legacy view](assets/screenshots/beta-aws-401-legacy.png)

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
