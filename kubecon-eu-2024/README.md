# Better Root Cert Rotation

## Prerequisites

- [istioctl](https://istio.io/latest/docs/setup/install/istioctl/)
- [step cli](https://smallstep.com/docs/step-cli/#introduction-to-step): an easy-to-use CLI tool for building, operating, and automating Public Key Infrastructure (PKI) systems and workflows.

## Generate Root Certs

1. Generate Root Certs A

    ```bash
    make -f Makefile.selfsigned.mk root-ca
    make -f Makefile.selfsigned.mk intermediateA-cacerts

    mkdir rootA

    mv root-* rootA
    mv intermediateA rootA
    ```

1. Create Root Certs B

    ```bash
    make -f Makefile.selfsigned.mk root-ca
    make -f Makefile.selfsigned.mk intermediateB-cacerts

    mkdir rootB

    mv root-* rootB
    rm -rf rootB/intermediateB
    mv intermediateB rootB
    ```

1. Combine root certs (`A+B`) into `combined-root.pem`

    ```bash
    cat rootA/root-cert.pem > combined-root.pem
    cat rootB/root-cert.pem >> combined-root.pem
    ```

1. Combine root certs (`A+B+B`) into `combined-root2.pem`

    ```bash
    cat rootA/root-cert.pem > combined-root2.pem
    cat rootB/root-cert.pem >> combined-root2.pem
    cat rootB/root-cert.pem >> combined-root2.pem
    ```

## Installing Istio with RootA IntermediateA

1. Create cacerts

    ```bash
    kubectl create ns istio-system
    ```

    ```bash
    kubectl delete secret cacerts -n istio-system --ignore-not-found && \
    kubectl create secret generic cacerts -n istio-system \
        --from-file=rootA/intermediateA/ca-cert.pem \
        --from-file=rootA/intermediateA/ca-key.pem \
        --from-file=rootA/intermediateA/root-cert.pem \
        --from-file=rootA/intermediateA/cert-chain.pem
    ```

    ```shell
    kubectl get secret cacerts -n istio-system -o jsonpath="{.data['root-cert\.pem']}" | step base64 -d | step certificate inspect --short -
    ```

2. Install istio

    ```bash
    istioctl install -f iop.yaml -y
    # verify ca root cert
    kubectl get cm istio-ca-root-cert -o jsonpath="{.data['root-cert\.pem']}" | step certificate inspect --short -
    ```

   ```shell
   kubectl label ns default istio-injection=enabled --overwrite
   kubectl apply -f manifests.yaml
   ```

   ```shell
   export FORTIO_POD=$(kubectl get pod -l app=fortio -o jsonpath={.items..metadata.name})
   export SLEEP_POD=$(kubectl get pod -l app=sleep -o jsonpath={.items..metadata.name})
   export HTTPBIN_POD=$(kubectl get pod -l app=httpbin -o jsonpath={.items..metadata.name})
   ```

   ```shell
   # check cert
   istioctl pc s $(kubectl get pod -l app=fortio -o jsonpath={.items..metadata.name}) -ojson | jq -r ".dynamicActiveSecrets[0].secret.tlsCertificate.certificateChain.inlineBytes" | base64 -d | step certificate inspect - --short
   istioctl pc s $(kubectl get pod -l app=fortio -o jsonpath={.items..metadata.name}) -ojson | jq -r ".dynamicActiveSecrets[1].secret.validationContext.trustedCa.inlineBytes" | base64 -d | step certificate inspect - --short
   # check stats
   istioctl x es $(kubectl get pod -l app=fortio -o jsonpath={.items..metadata.name}) -oprom | grep istio_requests_total
   kubectl get cm istio-ca-root-cert -o jsonpath="{.data['root-cert\.pem']}" | step certificate inspect - --short
   ```

## Update Cacerts with Combined Root

1. RootA IntermediateA with `combined-root.pem`

    ```bash
    date -u && kubectl delete secret cacerts -n istio-system --ignore-not-found && \
    kubectl create secret generic cacerts -n istio-system \
        --from-file=rootA/intermediateA/ca-cert.pem \
        --from-file=rootA/intermediateA/ca-key.pem \
        --from-file=root-cert.pem=combined-root.pem \
        --from-file=rootA/intermediateA/cert-chain.pem
    ```

    ```shell
    # check cert
    istioctl pc s $(kubectl get pod -l app=fortio -o jsonpath={.items..metadata.name}) -ojson | jq -r ".dynamicActiveSecrets[0].secret.tlsCertificate.certificateChain.inlineBytes" | base64 -d | step certificate inspect - --short
    istioctl pc s $(kubectl get pod -l app=fortio -o jsonpath={.items..metadata.name}) -ojson | jq -r ".dynamicActiveSecrets[1].secret.validationContext.trustedCa.inlineBytes" | base64 -d | step certificate inspect - --short
    # check stats
    istioctl x es $(kubectl get pod -l app=fortio -o jsonpath={.items..metadata.name}) -oprom | grep istio_requests_total
    ```

2. RootB intermediateB with `combined-root2.pem`

    ```bash
    date -u && kubectl delete secret cacerts -n istio-system --ignore-not-found && \
    kubectl create secret generic cacerts -n istio-system \
        --from-file=rootB/intermediateB/ca-cert.pem \
        --from-file=rootB/intermediateB/ca-key.pem \
        --from-file=root-cert.pem=combined-root2.pem \
        --from-file=rootB/intermediateB/cert-chain.pem
    ```

    ```shell
    # check cert
    istioctl pc s $(kubectl get pod -l app=fortio -o jsonpath={.items..metadata.name}) -ojson | jq -r ".dynamicActiveSecrets[0].secret.tlsCertificate.certificateChain.inlineBytes" | base64 -d | step certificate inspect - --short
    istioctl pc s $(kubectl get pod -l app=fortio -o jsonpath={.items..metadata.name}) -ojson | jq -r ".dynamicActiveSecrets[1].secret.validationContext.trustedCa.inlineBytes" | base64 -d | step certificate inspect - --short
    # check stats
    istioctl x es $(kubectl get pod -l app=fortio -o jsonpath={.items..metadata.name}) -oprom | grep istio_requests_total
    ```

3. RootB only

    ```bash
    date -u && kubectl delete secret cacerts -n istio-system --ignore-not-found && \
    kubectl create secret generic cacerts -n istio-system \
        --from-file=rootB/intermediateB/ca-cert.pem \
        --from-file=rootB/intermediateB/ca-key.pem \
        --from-file=rootB/intermediateB/root-cert.pem \
        --from-file=rootB/intermediateB/cert-chain.pem
    ```

    ```shell
    # check cert
    istioctl pc s $(kubectl get pod -l app=fortio -o jsonpath={.items..metadata.name}) -ojson | jq -r ".dynamicActiveSecrets[0].secret.tlsCertificate.certificateChain.inlineBytes" | base64 -d | step certificate inspect - --short
    istioctl pc s $(kubectl get pod -l app=fortio -o jsonpath={.items..metadata.name}) -ojson | jq -r ".dynamicActiveSecrets[1].secret.validationContext.trustedCa.inlineBytes" | base64 -d | step certificate inspect - --short
    # check stats
    istioctl x es $(kubectl get pod -l app=fortio -o jsonpath={.items..metadata.name}) -oprom | grep istio_requests_total
    ```

