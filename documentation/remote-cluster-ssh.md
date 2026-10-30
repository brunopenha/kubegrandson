# Remote Minikube or k3s over SSH

## Connect from the application

1. Open **Remote cluster over SSH** from the main toolbar or **Settings >
   Kubernetes Configuration**.
2. Enter the **SSH host**, **SSH port**, **SSH username**, **SSH password**,
   and absolute **Remote kubeconfig path**.
3. Enable **Use k3s kubectl** if the server provides kubectl through k3s.
4. Select **Connect**. On the first connection, verify the server fingerprint
   with its administrator, then choose **Trust and connect**.
5. Select **View pods and logs**, choose a namespace, and open the logs.

The app starts a remote Kubernetes proxy, selects available local and remote
ports, and creates the SSH tunnel automatically. The remote account needs
permission to read the kubeconfig, run `kubectl`, list namespaces/pods, and read
logs. SSH TCP forwarding must be enabled on the server. No local SSH client or
local kubectl installation is required for this mode.

Connection details and trusted host fingerprints are remembered. Passwords
are kept in memory only and cleared from the form after each connection
attempt. The app refuses a server whose remembered host key has changed.

The tunnel stays active while navigating between screens. Use **Disconnect**
to stop it and restore your configured local kubeconfig. Closing the desktop
window also stops the remote proxy and tunnel. If the SSH connection drops,
open this screen and reconnect. Local processes with access to the tunnel's
loopback port can use the remote account's Kubernetes permissions while it
is connected.

Common remote kubeconfig paths:

- Minikube: `/home/USERNAME/.kube/config`, using the account that runs Minikube.
- k3s: `/etc/rancher/k3s/k3s.yaml`, provided the remote account can read it.

## Manual terminal alternative

The following alternative uses your system's SSH client and `kubectl` installed on the server.
Kubegrandson accesses the API through a local tunnel; SSH login takes place in
the terminal.

You need the host, SSH port, username, SSH password, and path to the kubeconfig
on the server. The remote user must be able to read that file and run `kubectl`
with permission to list namespaces/pods and read logs.

## 1. Open the tunnel

In a terminal on your machine, replace the example values:

```bash
SSH_HOST='192.168.1.50'
SSH_PORT='22'
SSH_USER='bruno'

ssh -p "$SSH_PORT" \
  -o ExitOnForwardFailure=yes \
  -o ServerAliveInterval=30 \
  -L 127.0.0.1:18001:127.0.0.1:18001 \
  "$SSH_USER@$SSH_HOST" \
  'kubectl --kubeconfig=/home/bruno/.kube/config proxy --address=127.0.0.1 --port=18001'
```

Enter your SSH password when prompted. On the first connection, verify the
server's identity before accepting its host key. Keep this terminal open while
using the application.

In the remote command, replace `/home/bruno/.kube/config` with your environment's
kubeconfig path:

- Minikube: usually `/home/USERNAME/.kube/config`. Use the account that runs
  Minikube so that its certificate paths are accessible.
- k3s: usually `/etc/rancher/k3s/k3s.yaml`. Use a kubeconfig that your account
  can read. If `kubectl` is not in PATH, use `k3s kubectl` instead of `kubectl`.

`kubectl proxy` uses the remote kubeconfig credentials and listens only on the
server's loopback interface. The tunnel also listens only on your local
loopback interface. Your SSH password is not a Kubernetes password and does
not need to be added to the kubeconfig. Local processes with access to port
18001 can use this connection with the remote kubeconfig's permissions;
close the tunnel when finished.

## 2. Create a local kubeconfig for the tunnel

Save the following content in a separate file on your machine, for example
`~/.kube/remote-ssh.yaml`:

```yaml
apiVersion: v1
kind: Config
clusters:
  - name: remote-ssh
    cluster:
      server: http://127.0.0.1:18001
users:
  - name: remote-ssh
    user: {}
contexts:
  - name: remote-ssh
    context:
      cluster: remote-ssh
      user: remote-ssh
      namespace: default
current-context: remote-ssh
```

The HTTP connection above terminates on your machine; traffic to the server
travels through SSH. You do not need to copy certificates or disable the
cluster's TLS verification: the remote `kubectl` handles that connection.

## 3. Read logs in Kubegrandson

1. In **Settings**, select this file under **Kubeconfig File**.
2. If you use a corporate proxy, add `127.0.0.1,localhost` to **No proxy**.
3. Apply the settings, then select the `remote-ssh` context and namespace.
4. Refresh the pod list and open the logs as usual.

To check the connection from your local terminal, if `kubectl` is installed:

```bash
kubectl --kubeconfig="$HOME/.kube/remote-ssh.yaml" get pods
```

When finished, press **Ctrl+C** in the SSH terminal. If port 18001 is already
in use, choose another local port in the first address of `-L` and update the
local kubeconfig's `server` to use the same port.
