#!/bin/sh

mkdir release

cp -L nixlet-signed/* nixlet-insecure-unsigned/* release

cat nixlet-signed/SHA256SUMS nixlet-insecure-unsigned/SHA256SUMS > release/SHA256SUMS
