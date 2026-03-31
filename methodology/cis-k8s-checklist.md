# CIS Kubernetes Benchmark — Checklist

Reference: CIS Kubernetes Benchmark v1.8 (generic, not cloud-provider specific)

This checklist covers the core CIS Kubernetes Benchmark sections. For managed Kubernetes (EKS, GKE, AKS), some control plane checks are managed by the provider — mark those as N/A with justification.

---

## 1. Control Plane Components

### 1.1 Control Plane Node Configuration Files

- [ ] 1.1.1: Ensure that the API server pod specification file permissions are set to 600 or more restrictive
- [ ] 1.1.2: Ensure that the API server pod specification file ownership is set to root:root
- [ ] 1.1.3: Ensure that the controller manager pod specification file permissions are set to 600 or more restrictive
- [ ] 1.1.4: Ensure that the controller manager pod specification file ownership is set to root:root
- [ ] 1.1.5: Ensure that the scheduler pod specification file permissions are set to 600 or more restrictive
- [ ] 1.1.6: Ensure that the scheduler pod specification file ownership is set to root:root
- [ ] 1.1.7: Ensure that the etcd pod specification file permissions are set to 600 or more restrictive
- [ ] 1.1.8: Ensure that the etcd pod specification file ownership is set to root:root
- [ ] 1.1.9: Ensure that the Container Network Interface file permissions are set to 600 or more restrictive
- [ ] 1.1.10: Ensure that the Container Network Interface file ownership is set to root:root
- [ ] 1.1.11: Ensure that the etcd data directory permissions are set to 700 or more restrictive
- [ ] 1.1.12: Ensure that the etcd data directory ownership is set to etcd:etcd
- [ ] 1.1.13: Ensure that the admin.conf file permissions are set to 600
- [ ] 1.1.14: Ensure that the admin.conf file ownership is set to root:root
- [ ] 1.1.15: Ensure that the scheduler.conf file permissions are set to 600 or more restrictive
- [ ] 1.1.16: Ensure that the scheduler.conf file ownership is set to root:root
- [ ] 1.1.17: Ensure that the controller-manager.conf file permissions are set to 600 or more restrictive
- [ ] 1.1.18: Ensure that the controller-manager.conf file ownership is set to root:root
- [ ] 1.1.19: Ensure that the Kubernetes PKI directory and file permissions are set to 600
- [ ] 1.1.20: Ensure that the Kubernetes PKI certificate file permissions are set to 600 or more restrictive
- [ ] 1.1.21: Ensure that the Kubernetes PKI key file permissions are set to 600

### 1.2 API Server

- [ ] 1.2.1: Ensure that the --anonymous-auth argument is set to false
- [ ] 1.2.2: Ensure that the --token-auth-file parameter is not set
- [ ] 1.2.3: Ensure that the --DenyServiceExternalIPs is not set
- [ ] 1.2.4: Ensure that the --kubelet-client-certificate and --kubelet-client-key arguments are set as appropriate
- [ ] 1.2.5: Ensure that the --kubelet-certificate-authority argument is set as appropriate
- [ ] 1.2.6: Ensure that the --authorization-mode argument is not set to AlwaysAllow
- [ ] 1.2.7: Ensure that the --authorization-mode argument includes Node
- [ ] 1.2.8: Ensure that the --authorization-mode argument includes RBAC
- [ ] 1.2.9: Ensure that the admission control plugin EventRateLimit is set
- [ ] 1.2.10: Ensure that the admission control plugin AlwaysAdmit is not set
- [ ] 1.2.11: Ensure that the admission control plugin AlwaysPullImages is set
- [ ] 1.2.12: Ensure that the admission control plugin SecurityContextDeny is set if PodSecurityPolicy is not used
- [ ] 1.2.13: Ensure that the admission control plugin ServiceAccount is set
- [ ] 1.2.14: Ensure that the admission control plugin NamespaceLifecycle is set
- [ ] 1.2.15: Ensure that the admission control plugin NodeRestriction is set
- [ ] 1.2.16: Ensure that the --profiling argument is set to false
- [ ] 1.2.17: Ensure that the --audit-log-path argument is set
- [ ] 1.2.18: Ensure that the --audit-log-maxage argument is set to 30 or as appropriate
- [ ] 1.2.19: Ensure that the --audit-log-maxbackup argument is set to 10 or as appropriate
- [ ] 1.2.20: Ensure that the --audit-log-maxsize argument is set to 100 or as appropriate
- [ ] 1.2.21: Ensure that the --request-timeout argument is set as appropriate
- [ ] 1.2.22: Ensure that the --service-account-lookup argument is set to true
- [ ] 1.2.23: Ensure that the --service-account-key-file argument is set as appropriate
- [ ] 1.2.24: Ensure that the --etcd-certfile and --etcd-keyfile arguments are set as appropriate
- [ ] 1.2.25: Ensure that the --tls-cert-file and --tls-private-key-file arguments are set as appropriate
- [ ] 1.2.26: Ensure that the --client-ca-file argument is set as appropriate
- [ ] 1.2.27: Ensure that the --etcd-cafile argument is set as appropriate
- [ ] 1.2.28: Ensure that the --encryption-provider-config argument is set as appropriate
- [ ] 1.2.29: Ensure that encryption providers are appropriately configured (aescbc, aesgcm, kms, or secretbox — not identity)
- [ ] 1.2.30: Ensure that the API Server only makes use of Strong Cryptographic Ciphers

### 1.3 Controller Manager

- [ ] 1.3.1: Ensure that the --terminated-pod-gc-threshold argument is set as appropriate
- [ ] 1.3.2: Ensure that the --profiling argument is set to false
- [ ] 1.3.3: Ensure that the --use-service-account-credentials argument is set to true
- [ ] 1.3.4: Ensure that the --service-account-private-key-file argument is set as appropriate
- [ ] 1.3.5: Ensure that the --root-ca-file argument is set as appropriate
- [ ] 1.3.6: Ensure that the RotateKubeletServerCertificate argument is set to true
- [ ] 1.3.7: Ensure that the --bind-address argument is set to 127.0.0.1

### 1.4 Scheduler

- [ ] 1.4.1: Ensure that the --profiling argument is set to false
- [ ] 1.4.2: Ensure that the --bind-address argument is set to 127.0.0.1

---

## 2. etcd

- [ ] 2.1: Ensure that the --cert-file and --key-file arguments are set as appropriate
- [ ] 2.2: Ensure that the --client-cert-auth argument is set to true
- [ ] 2.3: Ensure that the --auto-tls argument is not set to true
- [ ] 2.4: Ensure that the --peer-cert-file and --peer-key-file arguments are set as appropriate
- [ ] 2.5: Ensure that the --peer-client-cert-auth argument is set to true
- [ ] 2.6: Ensure that the --peer-auto-tls argument is not set to true
- [ ] 2.7: Ensure that a unique Certificate Authority is used for etcd

---

## 3. Control Plane Configuration

### 3.1 Authentication and Authorization

- [ ] 3.1.1: Client certificate authentication should not be used for users
- [ ] 3.1.2: Service account token authentication should not be used for users
- [ ] 3.1.3: Bootstrap token authentication should not be used for users

### 3.2 Logging

- [ ] 3.2.1: Ensure that a minimal audit policy is created
- [ ] 3.2.2: Ensure that the audit policy covers key security concerns (authentication, authorization, secrets access, pod exec, port-forward)

---

## 4. Worker Nodes

### 4.1 Worker Node Configuration Files

- [ ] 4.1.1: Ensure that the kubelet service file permissions are set to 600 or more restrictive
- [ ] 4.1.2: Ensure that the kubelet service file ownership is set to root:root
- [ ] 4.1.3: If proxy kubeconfig file exists ensure permissions are set to 600 or more restrictive
- [ ] 4.1.4: If proxy kubeconfig file exists ensure ownership is set to root:root
- [ ] 4.1.5: Ensure that the --kubeconfig kubelet.conf file permissions are set to 600 or more restrictive
- [ ] 4.1.6: Ensure that the --kubeconfig kubelet.conf file ownership is set to root:root
- [ ] 4.1.7: Ensure that the certificate authorities file permissions are set to 600 or more restrictive
- [ ] 4.1.8: Ensure that the client certificate authorities file ownership is set to root:root
- [ ] 4.1.9: If the kubelet config.yaml configuration file is being used, ensure permissions set to 600 or more restrictive
- [ ] 4.1.10: If the kubelet config.yaml configuration file is being used, ensure file ownership is set to root:root

### 4.2 Kubelet

- [ ] 4.2.1: Ensure that the --anonymous-auth argument is set to false
- [ ] 4.2.2: Ensure that the --authorization-mode argument is not set to AlwaysAllow
- [ ] 4.2.3: Ensure that the --client-ca-file argument is set as appropriate
- [ ] 4.2.4: Verify that the --read-only-port argument is set to 0
- [ ] 4.2.5: Ensure that the --streaming-connection-idle-timeout argument is not set to 0
- [ ] 4.2.6: Ensure that the --make-iptables-util-chains argument is set to true
- [ ] 4.2.7: Ensure that the --hostname-override argument is not set (unless using cloud provider)
- [ ] 4.2.8: Ensure that the eventRecordQPS argument is set to a level which ensures appropriate event capture
- [ ] 4.2.9: Ensure that the --tls-cert-file and --tls-private-key-file arguments are set as appropriate
- [ ] 4.2.10: Ensure that the --rotate-certificates argument is not set to false
- [ ] 4.2.11: Verify that the RotateKubeletServerCertificate argument is set to true
- [ ] 4.2.12: Ensure that the Kubelet only makes use of Strong Cryptographic Ciphers
- [ ] 4.2.13: Ensure that a limit is set on pod PIDs

---

## 5. Policies

### 5.1 RBAC and Service Accounts

- [ ] 5.1.1: Ensure that the cluster-admin role is only used where required
- [ ] 5.1.2: Minimize access to secrets (principle of least privilege for Secret resources)
- [ ] 5.1.3: Minimize wildcard use in Roles and ClusterRoles
- [ ] 5.1.4: Minimize access to create pods (pod creation enables privilege escalation)
- [ ] 5.1.5: Ensure that default service accounts are not actively used (set automountServiceAccountToken: false)
- [ ] 5.1.6: Ensure that Service Account Tokens are only mounted where necessary
- [ ] 5.1.7: Avoid use of system:masters group
- [ ] 5.1.8: Limit use of the Bind, Impersonate, and Escalate permissions in the Kubernetes API
- [ ] 5.1.9: Minimize access to create persistent volumes
- [ ] 5.1.10: Minimize access to the proxy sub-resource of nodes
- [ ] 5.1.11: Minimize access to the approval sub-resource of certificatesigningrequests objects
- [ ] 5.1.12: Minimize access to webhook configuration objects
- [ ] 5.1.13: Minimize access to the service account token creation

### 5.2 Pod Security Standards

- [ ] 5.2.1: Ensure that the cluster has at least one active policy control mechanism in place (Pod Security Admission, OPA Gatekeeper, Kyverno)
- [ ] 5.2.2: Minimize the admission of privileged containers
- [ ] 5.2.3: Minimize the admission of containers wishing to share the host process ID namespace (hostPID)
- [ ] 5.2.4: Minimize the admission of containers wishing to share the host IPC namespace (hostIPC)
- [ ] 5.2.5: Minimize the admission of containers wishing to share the host network namespace (hostNetwork)
- [ ] 5.2.6: Minimize the admission of containers with allowPrivilegeEscalation
- [ ] 5.2.7: Minimize the admission of root containers (runAsNonRoot: true)
- [ ] 5.2.8: Minimize the admission of containers with the NET_RAW capability
- [ ] 5.2.9: Minimize the admission of containers with added capabilities beyond the default set
- [ ] 5.2.10: Minimize the admission of containers with capabilities assigned
- [ ] 5.2.11: Minimize the admission of Windows HostProcess containers
- [ ] 5.2.12: Minimize the admission of HostPath volumes
- [ ] 5.2.13: Minimize the admission of containers which use HostPorts

### 5.3 Network Policies and CNI

- [ ] 5.3.1: Ensure that the CNI in use supports NetworkPolicy
- [ ] 5.3.2: Ensure that all Namespaces have NetworkPolicy defined
- [ ] 5.3.3: Ensure that default deny ingress NetworkPolicy is configured for each namespace
- [ ] 5.3.4: Ensure that default deny egress NetworkPolicy is configured for each namespace
- [ ] 5.3.5: Ensure that NetworkPolicy allows only required traffic between pods/namespaces

### 5.4 Secrets Management

- [ ] 5.4.1: Prefer using Secrets as files over Secrets as environment variables
- [ ] 5.4.2: Consider external secret storage (HashiCorp Vault, AWS Secrets Manager, Azure Key Vault with CSI driver)
- [ ] 5.4.3: Ensure Kubernetes Secrets are encrypted at rest (EncryptionConfiguration with aescbc, aesgcm, kms, or secretbox)
- [ ] 5.4.4: Ensure RBAC policies limit access to Secrets to only those workloads that need them
- [ ] 5.4.5: Ensure that Secrets are not stored in environment variables in pod specs visible via `kubectl describe`

### 5.5 Extensible Admission Control

- [ ] 5.5.1: Configure Image Provenance using ImagePolicyWebhook admission controller or equivalent
- [ ] 5.5.2: Ensure admission controllers are configured to enforce security policies

### 5.7 General Policies

- [ ] 5.7.1: Create administrative boundaries between resources using namespaces
- [ ] 5.7.2: Ensure that the seccomp profile is set to docker/default in your Pod definitions (or RuntimeDefault)
- [ ] 5.7.3: Apply SecurityContext to your Pods and Containers (runAsNonRoot, readOnlyRootFilesystem, capabilities drop ALL)
- [ ] 5.7.4: The default namespace should not be used for workloads

---

## 6. Additional Security Hardening

### 6.1 Container Image Security

- [ ] 6.1.1: Ensure container images use a minimal base image (distroless, alpine, scratch)
- [ ] 6.1.2: Ensure container images are scanned for vulnerabilities before deployment
- [ ] 6.1.3: Ensure container images are pulled from trusted registries only
- [ ] 6.1.4: Ensure container images are signed and signatures are verified
- [ ] 6.1.5: Ensure container images do not run as root (USER directive in Dockerfile)
- [ ] 6.1.6: Ensure container images do not include unnecessary tools (curl, wget, nc, bash in production)

### 6.2 Logging and Monitoring

- [ ] 6.2.1: Ensure Kubernetes audit logging is enabled and configured
- [ ] 6.2.2: Ensure audit logs capture authentication failures, authorization failures, and secret access
- [ ] 6.2.3: Ensure audit logs are shipped to external storage (not stored only on the control plane)
- [ ] 6.2.4: Ensure a log aggregation solution is deployed (EFK, Loki, Datadog, etc.)
- [ ] 6.2.5: Ensure runtime security monitoring is deployed (Falco, Sysdig, Aqua, etc.)
- [ ] 6.2.6: Ensure alerts are configured for:
  - [ ] Privileged container creation
  - [ ] Container escape attempts
  - [ ] Unexpected process execution in containers
  - [ ] Network connections to suspicious destinations
  - [ ] Secret access anomalies
  - [ ] RBAC policy changes
  - [ ] Node-level security events

### 6.3 Supply Chain Security

- [ ] 6.3.1: Ensure a private container registry is used
- [ ] 6.3.2: Ensure container image tags are immutable (use digests or enforce tag immutability)
- [ ] 6.3.3: Ensure Helm charts and Kubernetes manifests are version-controlled and reviewed
- [ ] 6.3.4: Ensure GitOps practices are used for cluster configuration (ArgoCD, Flux)
- [ ] 6.3.5: Ensure admission controllers validate image sources and signatures

### 6.4 Node Security

- [ ] 6.4.1: Ensure worker node OS is hardened (CIS benchmark for the base OS)
- [ ] 6.4.2: Ensure SSH access to nodes is restricted and audited
- [ ] 6.4.3: Ensure node auto-updates or patch management is configured
- [ ] 6.4.4: Ensure container runtime is up to date (containerd, CRI-O)
- [ ] 6.4.5: Ensure nodes are in private subnets (not directly internet-accessible)

---

## Audit Notes

**How to use this checklist:**
1. Copy this file and rename for the engagement
2. Mark items: `[x]` passed, `[!]` finding raised, `[-]` N/A (with justification)
3. For managed K8s (EKS/GKE/AKS): mark provider-managed items as `[-]` with note "managed by provider"
4. For each `[!]`, create a finding using finding-template.md with framework reference `CIS-K8S-{section}`

**Assessment approach:**
1. **Automated scan** — Run kube-bench against the cluster for CIS benchmark checks
2. **RBAC review** — Export all Roles, ClusterRoles, RoleBindings, ClusterRoleBindings and analyze
3. **Pod security review** — Audit all workload specs for security context, capabilities, host access
4. **Network policy review** — Verify NetworkPolicy coverage across all namespaces
5. **Secret audit** — Check encryption at rest config, RBAC for secrets, env var usage
6. **Image audit** — Review image sources, scanning pipeline, admission control

**Common tools:**
- CIS scanning: kube-bench, kube-hunter
- RBAC analysis: rbac-lookup, rakkess, kubectl-who-can
- Policy enforcement: OPA Gatekeeper, Kyverno, Pod Security Admission
- Runtime security: Falco, Sysdig Secure, Aqua
- Network: Cilium, Calico, kubectl + NetworkPolicy viewer
- Vulnerability scanning: Trivy, Grype, Snyk
- Configuration audit: kubeaudit, kubesec, Polaris
