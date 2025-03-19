#!/bin/bash

# check for mise
if ! command -v mise &>/dev/null; then
    echo "Please install mise first (run 'curl https://mise.run | sh')"
    exit 1
else
    mise activate 1>/dev/null
fi

# install the dependencies
mise install --yes
uv sync

# check if docker command is available
if ! command -v docker &>/dev/null; then
    echo "Please install docker desktop to build this image locally."
fi

echo "Run \`task\` for more that can be executed"
