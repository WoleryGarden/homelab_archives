#!/bin/bash

git config --global --unset-all credential.helper
git config --global credential.helper '!f() { "$HOME/github-gen.sh"; }; f'
git config --global credential.useHttpPath true
git config --global --get-all credential.helper
