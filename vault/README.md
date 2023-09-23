# Vault on Kubernetes deployment guide


## Setup Helm Repo

To access the Vault Helm chart, add the Hashicorp Helm repository.

```bash
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo update
```

Check that you have access to the chart.

```bash
helm search repo hashicorp/vault
```

## Install Vault


```bash
helm install vault hashicorp/vault --namespace vault --create-namespace
```

## Configure PKI secrets engine

https://developer.hashicorp.com/vault/tutorials/kubernetes/kubernetes-cert-manager#configure-pki-secrets-engine

## Install Cert-manager

```bash
helm install -n cert-manager cert-manager jetstack/cert-manager --set installCRDs=true --create-namespace
```

## Create Token Secret

```bash
apiVersion: v1
kind: Secret
type: Opaque
metadata:
  name: cert-manager-vault-token
  namespace: vault
data:
  token: "<token from Vault>"
```
