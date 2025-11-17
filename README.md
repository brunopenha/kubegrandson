# Kubegrandson

![Kubegrandson](https://github.com/brunopenha/kubegrandson/raw/main/assets/icons/app64.png)

**Kubegrandson** is a modern Flutter-based Kubernetes log viewer - the proud grandson of **Kubeson**! 🎉

Built with Flutter and Dart, Kubegrandson brings the powerful features of Kubeson to a cross-platform, modern UI framework while maintaining the same intuitive interface developers love.

## 🌟 Features

Kubegrandson inherits all the great features from its grandfather Kubeson:

- ✅ Select Kubernetes namespace
- ✅ Log level filters (TRACE, DEBUG, INFO, WARN, ERROR, FATAL)
- ✅ Multiple tabs to visualize multiple pods simultaneously
- ✅ Multiple pods in a single tab
- ✅ Search engine with text highlight
- ✅ Logs by APP Label (automatic log restart when pod restarts)
- ✅ Logs colored by log level
- ✅ JSON viewer with collapsible arrays and objects
- ✅ JSON viewer automatically collapses arrays with more than 4 elements
- ✅ Escaped JSON strings are automatically parsed and displayed as JSON
- ✅ Clear logs button
- ✅ Stop log feed button
- ✅ Stop log feed and continue in a new tab (for easy comparison)
- ✅ Big JSON fields are hidden (configurable threshold)
- ✅ Export all log lines
- ✅ Export searched log lines
- ✅ Drag and drop log files

## 🆕 New Features in Kubegrandson

- 🎨 Modern Material Design 3 UI
- 🖥️ Enhanced desktop experience
- ⚡ Improved performance with Flutter
- 🔄 Better state management
- 📱 Potential for mobile support in the future

## 🚀 Getting Started

### Prerequisites

- Flutter SDK 3.0 or higher
- Dart SDK 3.0 or higher
- Access to a Kubernetes cluster (minikube, kind, or remote cluster)
- Valid kubeconfig file in `~/.kube/config`

### Installation

1. Clone the repository: