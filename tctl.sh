#!/bin/bash

set -e

mkdir -p ~/.tctl/bin
curl -Lo ~/.tctl/bin/tctl https://binaries.dl.tetrate.io/public/raw/versions/linux-amd64-1.4.0-EA3/tctl
chmod +x ~/.tctl/bin/tctl
export PATH=$PATH:~/.tctl/bin
