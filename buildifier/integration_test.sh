#!/bin/bash

# --- begin runfiles.bash initialization ---
# Copy-pasted from Bazel's Bash runfiles library (tools/bash/runfiles/runfiles.bash).
set -euo pipefail
if [[ ! -d "${RUNFILES_DIR:-/dev/null}" && ! -f "${RUNFILES_MANIFEST_FILE:-/dev/null}" ]]; then
  if [[ -f "$0.runfiles_manifest" ]]; then
    export RUNFILES_MANIFEST_FILE="$0.runfiles_manifest"
  elif [[ -f "$0.runfiles/MANIFEST" ]]; then
    export RUNFILES_MANIFEST_FILE="$0.runfiles/MANIFEST"
  elif [[ -f "$0.runfiles/bazel_tools/tools/bash/runfiles/runfiles.bash" ]]; then
    export RUNFILES_DIR="$0.runfiles"
  fi
fi
if [[ -f "${RUNFILES_DIR:-/dev/null}/bazel_tools/tools/bash/runfiles/runfiles.bash" ]]; then
  source "${RUNFILES_DIR}/bazel_tools/tools/bash/runfiles/runfiles.bash"
elif [[ -f "${RUNFILES_MANIFEST_FILE:-/dev/null}" ]]; then
  source "$(grep -m1 "^bazel_tools/tools/bash/runfiles/runfiles.bash " \
            "$RUNFILES_MANIFEST_FILE" | cut -d ' ' -f 2-)"
else
  echo >&2 "ERROR: cannot find @bazel_tools//tools/bash/runfiles:runfiles.bash"
  exit 1
fi
# --- end runfiles.bash initialization ---

die () {
  echo "$1" 1>&2
  exit 1
}

[[ "$1" =~ external/* ]] && buildifier="${{1#external/}}" || buildifier="$TEST_WORKSPACE/$1"
[[ "$2" =~ external/* ]] && buildifier2="${{2#external/}}" || buildifier2="$TEST_WORKSPACE/$2"
[[ "$3" =~ external/* ]] && buildozer="${{3#external/}}" || buildozer="$TEST_WORKSPACE/$3"
buildifier="$(rlocation "$buildifier")"
buildifier2="$(rlocation "$buildifier2")"
buildozer="$(rlocation "$buildozer")"

function assert_equal_files() {
  if ! diff $1 $2 > /dev/null;
  then
    echo "## Comparing $1 and $2: Assertion failed, files are not equal"
    echo "## First:"
    cat $1
    echo "## Second:"
    cat $2
    echo "## Diff:"
    diff $1 $2
  fi
}

touch WORKSPACE

# Public visibility on original always wins
mkdir -p public
cat > public/BUILD <<EOF
filegroup(
    name = "original",
    visibility = ["//visibility:public"],
)

filegroup(
    name = "copy",
    visibility = ["//visibility:private"],
)
EOF

cat > public/BUILD.expected <<EOF
filegroup(
    name = "original",
    visibility = ["//visibility:public"],
)

filegroup(
    name = "copy",
    visibility = ["//visibility:public"],
)
EOF

$buildozer 'copy visibility original' //public:copy
assert_equal_files public/BUILD public/BUILD.expected

# Private visibility on original is noop
mkdir -p private
cat > private/BUILD <<EOF
filegroup(
    name = "original",
    visibility = ["//visibility:private"],
)

filegroup(
    name = "copy",
    visibility = ["//visibility:yolo"],
)
EOF

cat > private/BUILD.expected <<EOF
filegroup(
    name = "original",
    visibility = ["//visibility:private"],
)

filegroup(
    name = "copy",
    visibility = ["//visibility:yolo"],
)
EOF

$buildozer 'copy visibility original' //private:copy || [[ $? -eq 3 ]]
assert_equal_files private/BUILD private/BUILD.expected

# Public visibility on copy is noop
mkdir -p public_copy
cat > public_copy/BUILD <<EOF
filegroup(
    name = "original",
    visibility = ["//visibility:private"],
)

filegroup(
    name = "copy",
    visibility = ["//visibility:public"],
)
EOF

cat > public_copy/BUILD.expected <<EOF
filegroup(
    name = "original",
    visibility = ["//visibility:private"],
)

filegroup(
    name = "copy",
    visibility = ["//visibility:public"],
)
EOF

$buildozer 'copy visibility original' //public_copy:copy || [[ $? -eq 3 ]]
assert_equal_files public_copy/BUILD public_copy/BUILD.expected

# Private visibility on copy - we take original
mkdir -p private_copy
cat > private_copy/BUILD <<EOF
filegroup(
    name = "original",
    visibility = ["//visibility:yolo"],
)

filegroup(
    name = "copy",
    visibility = ["//visibility:private"],
)
EOF

cat > private_copy/BUILD.expected <<EOF
filegroup(
    name = "original",
    visibility = ["//visibility:yolo"],
)

filegroup(
    name = "copy",
    visibility = ["//visibility:yolo"],
)
EOF

$buildozer 'copy visibility original' //private_copy:copy || [[ $? -eq 3 ]]
assert_equal_files private_copy/BUILD private_copy/BUILD.expected

# copy retains its own custom labels
mkdir -p custom_copy
cat > custom_copy/BUILD <<EOF
filegroup(
    name = "original",
    visibility = ["//bubu:bar"],
)

filegroup(
    name = "copy",
    visibility = ["//yolo:a"],
)
EOF

cat > custom_copy/BUILD.expected <<EOF
filegroup(
    name = "original",
    visibility = ["//bubu:bar"],
)

filegroup(
    name = "copy",
    visibility = [
        "//bubu:bar",
        "//yolo:a",
    ],
)
EOF

$buildozer 'copy visibility original' //custom_copy:copy || [[ $? -eq 3 ]]
assert_equal_files custom_copy/BUILD custom_copy/BUILD.expected

# copy retains its own custom labels, no duplicates
mkdir -p custom_nodups
cat > custom_nodups/BUILD <<EOF
filegroup(
    name = "original",
    visibility = [
        "//bubu:bar",
        "//bubu:baz",
    ],
)

filegroup(
    name = "copy",
    visibility = ["//yolo:a", "//bubu:baz"],
)
EOF

cat > custom_nodups/BUILD.expected <<EOF
filegroup(
    name = "original",
    visibility = [
        "//bubu:bar",
        "//bubu:baz",
    ],
)

filegroup(
    name = "copy",
    visibility = [
        "//bubu:bar",
        "//bubu:baz",
        "//yolo:a",
    ],
)
EOF

$buildozer 'copy visibility original' //custom_nodups:copy || [[ $? -eq 3 ]]
assert_equal_files custom_nodups/BUILD custom_nodups/BUILD.expected

# copy retains its own custom labels, no duplicates
mkdir -p custom_nodups
cat > custom_nodups/BUILD <<EOF
filegroup(
    name = "original",
    visibility = [
        "//bubu:bar",
        "//bubu:baz",
    ],
)

filegroup(
    name = "copy",
    visibility = ["//yolo:a", "//bubu:baz"],
)
EOF

cat > custom_nodups/BUILD.expected <<EOF
filegroup(
    name = "original",
    visibility = [
        "//bubu:bar",
        "//bubu:baz",
    ],
)

filegroup(
    name = "copy",
    visibility = [
        "//bubu:bar",
        "//bubu:baz",
        "//yolo:a",
    ],
)
EOF

$buildozer 'copy visibility original' //custom_nodups:copy || [[ $? -eq 3 ]]
assert_equal_files custom_nodups/BUILD custom_nodups/BUILD.expected

# copy retains its own custom labels, creates list if needed
mkdir -p missing_list
cat > missing_list/BUILD <<EOF
filegroup(
    name = "original",
    visibility = visibilities,
)

filegroup(
    name = "copy",
    visibility = ["//yolo:a", "//bubu:baz"],
)
EOF

cat > missing_list/BUILD.expected <<EOF
filegroup(
    name = "original",
    visibility = visibilities,
)

filegroup(
    name = "copy",
    visibility = (visibilities + [
        "//yolo:a",
        "//bubu:baz",
    ]),
)
EOF

$buildozer 'copy visibility original' //missing_list:copy || [[ $? -eq 3 ]]
assert_equal_files missing_list/BUILD missing_list/BUILD.expected


# differring variables - bail out
mkdir -p diffing_variables
cat > diffing_variables/BUILD <<EOF
filegroup(
    name = "original",
    visibility = visibilities,
)

filegroup(
    name = "copy",
    visibility = other_stuff,
)
EOF

cat > diffing_variables/BUILD.expected <<EOF
filegroup(
    name = "original",
    visibility = visibilities,
)

filegroup(
    name = "copy",
    visibility = other_stuff,
)
EOF

$buildozer 'copy visibility original' //diffing_variables:copy || [[ $? -eq 2 ]]
assert_equal_files diffing_variables/BUILD diffing_variables/BUILD.expected

# variables are taken from original
mkdir -p original_variables
cat > original_variables/BUILD <<EOF
filegroup(
    name = "original",
    visibility = visibilities,
)

filegroup(
    name = "copy",
    visibility = ["//yolo:a", "//bubu:baz"],
)
EOF

cat > original_variables/BUILD.expected <<EOF
filegroup(
    name = "original",
    visibility = visibilities,
)

filegroup(
    name = "copy",
    visibility = (visibilities + [
        "//yolo:a",
        "//bubu:baz",
    ]),
)
EOF

$buildozer 'copy visibility original' //original_variables:copy || [[ $? -eq 3 ]]
assert_equal_files original_variables/BUILD original_variables/BUILD.expected

# we bail out on function calls
mkdir -p funcalls
cat > funcalls/BUILD <<EOF
filegroup(
    name = "original",
    visibility = visibilities(),
)

filegroup(
    name = "copy",
    visibility = ["//yolo:a", "//bubu:baz"],
)
EOF

cat > funcalls/BUILD.expected <<EOF
filegroup(
    name = "original",
    visibility = visibilities(),
)

filegroup(
    name = "copy",
    visibility = ["//yolo:a", "//bubu:baz"],
)
EOF

$buildozer 'copy visibility original' //funcalls:copy || [[ $? -eq 2 ]]
assert_equal_files funcalls/BUILD funcalls/BUILD.expected

# error out when original visibility is missing
mkdir -p missing_original
cat > missing_original/BUILD <<EOF
filegroup(
    name = "original",
)

filegroup(
    name = "copy",
    visibility = ["//yolo:a", "//bubu:baz"],
)
EOF

cat > missing_original/BUILD.expected <<EOF
filegroup(
    name = "original",
)

filegroup(
    name = "copy",
    visibility = ["//yolo:a", "//bubu:baz"],
)
EOF

$buildozer 'copy visibility original' //missing_original:copy || [[ $? -eq 2 ]]
assert_equal_files missing_original/BUILD missing_original/BUILD.expected

# error out when copy visibility is missing
mkdir -p missing_copy
cat > missing_copy/BUILD <<EOF
filegroup(
    name = "original",
    visibility = ["//yolo:a", "//bubu:baz"],
)

filegroup(
    name = "copy",
)
EOF

cat > missing_copy/BUILD.expected <<EOF
filegroup(
    name = "original",
    visibility = ["//yolo:a", "//bubu:baz"],
)

filegroup(
    name = "copy",
)
EOF

$buildozer 'copy visibility original' //missing_copy:copy || [[ $? -eq 2 ]]
assert_equal_files missing_copy/BUILD missing_copy/BUILD.expected
