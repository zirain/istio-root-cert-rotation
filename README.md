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

## Generate Root Certs

1. Generate Root Certs A

```bash
make -f Makefile.selfsigned.mk root-ca
make -f Makefile.selfsigned.mk intermediateA-cacerts
make -f Makefile.selfsigned.mk intermediateB-cacerts

mkdir rootA

mv root-* rootA
mv intermediateA rootA
mv intermediateB rootA
```

## Installing Istio with RootA IntermediateA


1. Create cacerts

    ```bash
    kubectl delete secret cacerts -n istio-system && \
    kubectl create secret generic cacerts -n istio-system \
        --from-file=rootA/intermediateA/ca-cert.pem \
        --from-file=rootA/intermediateA/ca-key.pem \
        --from-file=rootA/intermediateA/root-cert.pem \
        --from-file=rootA/intermediateA/cert-chain.pem
    ```

1. Install istio

    ```bash
    istioctl install -y
    # verify ca root cert
    kubectl get cm istio-ca-root-cert -o jsonpath="{.data['root-cert\.pem']}" | step certificate inspect -
    ```

1. Verify Mesh traffic 
   
    ```bash
    kubectl exec -it deploy/sleep -- curl httpbin:8000/headers
    ```

## Update cacets with IntermediateB

1. Recreate cacert with IntermediateB

    ```bash
    kubectl delete secret cacerts -n istio-system && \
    kubectl create secret generic cacerts -n istio-system \
        --from-file=rootA/intermediateB/ca-cert.pem \
        --from-file=rootA/intermediateB/ca-key.pem \
        --from-file=rootA/intermediateB/root-cert.pem \
        --from-file=rootA/intermediateB/cert-chain.pem
    # verify ca root cert
    kubectl get cm istio-ca-root-cert -o jsonpath="{.data['root-cert\.pem']}" | step certificate inspect -
    ```

1. Verify istiod's log

    ```bash
    kubectl logs -l app=istiod -nistio-system --tail=-1 | grep "x509 cert - Issuer"
    ```

1. Rollout deployment

    ```bash
    kubectl rollout restart deploy/istiod -n istio-system
    kubectl rollout restart deploy/sleep
    ```

## Update Cacerts with Combined Root

1. Create new root cert

    ```bash
    make -f Makefile.selfsigned.mk root-ca
    make -f Makefile.selfsigned.mk intermediateB-cacerts

    mkdir rootB

    mv root-* rootB
    mv intermediateB rootB
    ```

1. Combine two root certs into `combined-root.pem`

    ```bash
    cat rootA/root-cert.pem > combined-root.pem
    cat rootB/root-cert.pem >> combined-root.pem
    ```

2. RootA IntermediateB with `combined-root.pem`

    ```bash
    kubectl delete secret cacerts -n istio-system && \
    kubectl create secret generic cacerts -n istio-system \
        --from-file=rootA/intermediateB/ca-cert.pem \
        --from-file=rootA/intermediateB/ca-key.pem \
        --from-file=root-cert.pem=combined-root.pem \
        --from-file=rootA/intermediateB/cert-chain.pem
    ```
    
    **Rollout istiod**
    
    **Rollout all workloads**

3. use RootB intermediate certs with `combined-root.pem`

    ```bash
    kubectl delete secret cacerts -n istio-system && \
    kubectl create secret generic cacerts -n istio-system \
        --from-file=rootB/intermediateB/ca-cert.pem \
        --from-file=rootB/intermediateB/ca-key.pem \
        --from-file=root-cert.pem=combined-root.pem \
        --from-file=rootB/intermediateB/cert-chain.pem
    ```
    
    **Rollout istiod**

    **Rollout all workloads**

4. change RootB only

    ```bash
    kubectl delete secret cacerts -n istio-system && \
    kubectl create secret generic cacerts -n istio-system \
        --from-file=rootB/intermediateB/ca-cert.pem \
        --from-file=rootB/intermediateB/ca-key.pem \
        --from-file=rootB/intermediateB/root-cert.pem \
        --from-file=rootB/intermediateB/cert-chain.pem
    ```

    **Rollout istiod**

    **Rollout all workloads**