# Generating Certificates for Bootstrapping Multicluster / Mesh Expansion Chain of Trust

The directory contains two Makefiles for generating new root, intermediate certificates and workload certificates:
- `Makefile.k8s.mk`: Creates certificates based on a root-ca from a k8s cluster. The current context in the default
`kubeconfig` is used for accessing the cluster.
- `Makefile.selfsigned.mk`: Creates certificates based on a generated self-signed root.

The table below describes the targets supported by both Makefiles.

| Make Target        | Makefile                 | Description                                                                                                                                                                                                                                                                                                          |
| ------------------ | ------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `root-ca`          | `Makefile.selfsigned.mk` | Generates a self-signed root CA key and certificate.                                                                                                                                                                                                                                                                 |
| `fetch-root-ca`    | `Makefile.k8s.mk`        | Fetches the Istio CA from the Kubernetes cluster, using the current context in the default `kubeconfig`.                                                                                                                                                                                                             |
| `$NAME-cacerts`    | Both                     | Generates intermediate certificates signed by the root CA for a cluster or VM with `$NAME` (e.g., `us-east`, `cluster01`, etc.). They are stored under `$NAME` directory. To differentiate between clusters, we include a `Location` (`L`) designation in the certificates `Subject` field, with the cluster's name. |
| `$NAMESPACE-certs` | Both                     | Generates intermediate certificates and sign certificates for a virtual machine connected to the namespace `$NAMESPACE` using serviceAccount `$SERVICE_ACCOUNT` using the root cert and store them under `$NAMESPACE` directory.                                                                                     |
| `clean`            | Both                     | Removes any generated root certificates, keys, and intermediate files.                                                                                                                                                                                                                                               |

For example:

```bash
make -f Makefile.selfsigned.mk root-ca
```

Note that the Makefile generates long-lived intermediate certificates. While this might be
acceptable for demonstration purposes, a more realistic and secure deployment would use
short-lived and automatically renewed certificates for the intermediate CAs.

```
make -f Makefile.selfsigned.mk root-ca
make -f Makefile.selfsigned.mk intermediateA-cacerts
make -f Makefile.selfsigned.mk intermediateA-cacerts
```

```bash
kubectl create namespace istio-system && \
kubectl create secret generic cacerts -n istio-system \
    --from-file=intermediateA/ca-cert.pem \
    --from-file=intermediateA/ca-key.pem \
    --from-file=intermediateA/root-cert.pem \
    --from-file=intermediateA/cert-chain.pem
```


```bash
istioctl install -y

kubectl get cm istio-ca-root-cert -o jsonpath="{.data['root-cert\.pem']}" | step certificate inspect -
```

```bash
kubectl exec -it deploy/sleep -- curl httpbin:8000/headers
```

```bash
kubectl delete secret cacerts -n istio-system && \
kubectl create secret generic cacerts -n istio-system \
    --from-file=intermediateB/ca-cert.pem \
    --from-file=intermediateB/ca-key.pem \
    --from-file=intermediateB/root-cert.pem \
    --from-file=intermediateB/cert-chain.pem



kubectl get cm istio-ca-root-cert -o jsonpath="{.data['root-cert\.pem']}" | \
    step certificate inspect -
```

```bash
kubectl logs -l app=istiod -nistio-system --tail=-1 | grep "x509 cert - Issuer"
```

```bash
kubectl rollout restart deploy/istiod -n istio-system
kubectl rollout restart deploy/sleep
```

```bash
cat rootA/root-cert.pem > combined-root.pem
cat rootB/root-cert.pem >> combined-root.pem

# use RootA intermediate certs
kubectl delete secret cacerts -n istio-system && \
kubectl create secret generic cacerts -n istio-system \
    --from-file=rootA/intermediateB/ca-cert.pem \
    --from-file=rootA/intermediateB/ca-key.pem \
    --from-file=rootA/intermediateB/root-cert.pem \
    --from-file=rootA/intermediateB/cert-chain.pem

# change combined-root
kubectl delete secret cacerts -n istio-system && \
kubectl create secret generic cacerts -n istio-system \
    --from-file=rootA/intermediateB/ca-cert.pem \
    --from-file=rootA/intermediateB/ca-key.pem \
    --from-file=combined-root.pem \
    --from-file=rootA/intermediateB/cert-chain.pem

# use RootB intermediate certs
kubectl delete secret cacerts -n istio-system && \
kubectl create secret generic cacerts -n istio-system \
    --from-file=rootB/intermediateB/ca-cert.pem \
    --from-file=rootB/intermediateB/ca-key.pem \
    --from-file=combined-root.pem \
    --from-file=rootB/intermediateB/cert-chain.pem

# change RootB only
kubectl delete secret cacerts -n istio-system && \
kubectl create secret generic cacerts -n istio-system \
    --from-file=rootB/intermediateB/ca-cert.pem \
    --from-file=rootB/intermediateB/ca-key.pem \
    --from-file=rootB/intermediateB/root-cert.pem \
    --from-file=rootB/intermediateB/cert-chain.pem
```