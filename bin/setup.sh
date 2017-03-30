#!/bin/sh

set -eu

. ./bin/helpers.sh

log 'Cloning the Swift repo...'

if [ ! -d "$(swift_dir)" ]; then
  git clone git@github.com:apple/swift.git "$(swift_dir)"
fi

# Copy Swift repo over to buildspace for the first time
log 'Copying the Swift repo over to ./buildspace'
rsync -aHEq "$(swift_dir)/" "$(buildspace_dir)/swift"

# Checking out adjacent dependencies
log 'Checking out adjacent dependencies'
TPWD="$PWD"
cd "$(buildspace_dir)/swift"
./utils/update-checkout --clone-with-ssh
cd $TPWD

log 'Building and testing the master branch for the first time...'
build_current_branch

log 'All done!'
