#!/bin/bash

echo "Generating certs for KubeCon EU 2024 demo"

rm -rf *.pem
rm -rf rootA
rm -rf rootB

echo "Generate root A"
make -f Makefile.selfsigned.mk root-ca
make -f Makefile.selfsigned.mk intermediateA-cacerts

mkdir rootA
mv root-* rootA
mv intermediateA rootA

echo "Generate root B"
make -f Makefile.selfsigned.mk root-ca
make -f Makefile.selfsigned.mk intermediateB-cacerts

mkdir rootB
mv root-* rootB
rm -rf rootB/intermediateB
mv intermediateB rootB

echo "Combine root A and root B"

cat rootA/root-cert.pem > combined-root.pem
cat rootB/root-cert.pem >> combined-root.pem


cat rootA/root-cert.pem > combined-root2.pem
cat rootB/root-cert.pem >> combined-root2.pem
cat rootB/root-cert.pem >> combined-root2.pem
