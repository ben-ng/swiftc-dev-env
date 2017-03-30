#!/bin/sh

function log() {
  local TURTLE="\xf0\x9f\x90\xa2"
  printf '%b  %s\n' "$TURTLE" "$1"
}

# Returns the project's root directory
function project_dir() {
  # Gets the current directory of this script (./bin)
  local HERE="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

  printf '%s' "$(dirname $HERE)"
}

# Returns the directory with the swift repository
function swift_dir() {
  printf '%s/swift' "$(project_dir)"
}

# Returns the directory where the build script is run
function buildspace_dir() {
  printf '%s/buildspace' "$(project_dir)"
}

# Returns the directory where the build script puts Swift
function swift_built_dir() {
  printf '%s/build/Ninja-ReleaseAssert/swift-macosx-x86_64' "$(buildspace_dir)"
}

# Returns the directory where the Swift output for $BRANCH is
function branch_built_dir() {
  local BRANCH=$1

  printf '%s/built/%s' "$(project_dir)" "$BRANCH"
}

function get_current_branch() {
  local BRANCH="$(git -C $(swift_dir) rev-parse --abbrev-ref HEAD)"
  printf '%s' "$BRANCH"
}

function sync_dirs() {
  rsync -aHEhi --stats "$1" "$2" | grep -E '^[^.]|^$'
}

function prep_for_build() {
  local BRANCH="$(get_current_branch)"
  local BRANCH_BUILT_DIR="$(branch_built_dir "$BRANCH")"

  # Create the output directories
  mkdir -p "$BRANCH_BUILT_DIR"
  mkdir -p "$(swift_built_dir)"
  mkdir -p "$(buildspace_dir)"

  # Update the adjacent dependencies
  log 'Updating adjacent dependencies'
  local TPWD="$PWD"
  cd "$(buildspace_dir)/swift"
  ./utils/update-checkout --skip-repository swift --match-timestamp
  cd $TPWD

  # rsync over the Swift repo
  log 'Copying Swift changes to ./buildspace'
  sync_dirs "$(swift_dir)/" "$(buildspace_dir)/swift"

  # rsync back any changes to the dev swift repo
  # log 'Copying Swift changes back to ./swift'
  # sync_dirs "$(buildspace_dir)/swift/" "$(swift_dir)"

  log 'Continuing where this branch left off'
  sync_dirs "$BRANCH_BUILT_DIR/" "$(swift_built_dir)"
}

function build_current_branch() {
  local BRANCH="$(get_current_branch)"
  local BRANCH_BUILT_DIR="$(branch_built_dir "$BRANCH")"

  prep_for_build

  local TPWD="$PWD"
  cd "$(buildspace_dir)/swift"
  ./utils/build-script --release --assertions
  cd $TPWD

  # Save the output for this branch in the built directory so we
  # can continue where we left off on subsequent builds
  log "Moving build results back to ./built/$BRANCH"
  sync_dirs "$(swift_built_dir)/" "$BRANCH_BUILT_DIR"
}

function run_branch_benchmark() {
  local BRANCH=$1

  $(branch_built_dir "$BRANCH")/bin/Benchmark_Driver run -o O \
  --output-dir $(branch_built_dir "$BRANCH")/benchmark/logs \
  --swift-repo "$SWIFT_SOURCE_ROOT" --iterations 3
}
