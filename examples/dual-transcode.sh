#!/usr/bin/env bash

set -Eeuo pipefail

if (($# < 2)); then
  printf 'Usage: %s OUTPUT_DIRECTORY INPUT...\n' "${0##*/}" >&2
  exit 2
fi

output_dir=$1
shift

command -v ffmpeg >/dev/null 2>&1 || {
  printf 'error: ffmpeg is required\n' >&2
  exit 1
}

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
if command -v macpro61-gpu >/dev/null 2>&1; then
  utility=macpro61-gpu
else
  utility="$script_dir/../bin/macpro61-gpu"
fi

mapfile -t devices < <("$utility" devices)
if ((${#devices[@]} < 2)); then
  printf 'error: two internal Mac Pro render nodes were not found\n' >&2
  exit 1
fi

mkdir -p "$output_dir"
pids=()
labels=()
temps=()
inputs=("$@")
outputs=()
device_index=0
declare -A seen_outputs=()

cleanup() {
  local pid temp

  for pid in "${pids[@]}"; do
    kill "$pid" >/dev/null 2>&1 || true
    wait "$pid" >/dev/null 2>&1 || true
  done
  for temp in "${temps[@]}"; do
    rm -f "$temp"
  done
}

interrupt() {
  cleanup
  exit 130
}

trap cleanup EXIT
trap interrupt INT TERM HUP

for input in "${inputs[@]}"; do
  [[ -f "$input" ]] || {
    printf 'error: input does not exist: %s\n' "$input" >&2
    exit 1
  }

  base=${input##*/}
  output="$output_dir/${base%.*}.h264.mp4"
  [[ -z "${seen_outputs[$output]+x}" ]] || {
    printf 'error: multiple inputs map to the same output: %s\n' "$output" >&2
    exit 1
  }
  [[ ! -e "$output" ]] || {
    printf 'error: output already exists: %s\n' "$output" >&2
    exit 1
  }
  seen_outputs[$output]=1
  outputs+=("$output")
done

wait_for_batch() {
  local index status=0

  for index in "${!pids[@]}"; do
    if wait "${pids[$index]}"; then
      printf 'Finished: %s\n' "${labels[$index]}"
    else
      printf 'Failed: %s\n' "${labels[$index]}" >&2
      rm -f "${temps[$index]}"
      status=1
    fi
  done

  pids=()
  labels=()
  temps=()
  return "$status"
}

for index in "${!inputs[@]}"; do
  input=${inputs[$index]}
  output=${outputs[$index]}
  device=${devices[$((device_index % 2))]}
  temp="${output%.mp4}.tmp.$$.${device_index}.mp4"
  printf 'Starting on %s: %s\n' "$device" "$input"

  (
    ffmpeg -hide_banner -n -vaapi_device "$device" -i "$input" \
      -map 0:v:0 -map '0:a?' -vf 'format=nv12,hwupload' \
      -c:v h264_vaapi -qp 22 -c:a aac -b:a 192k "$temp"
    mv "$temp" "$output"
  ) &

  pids+=("$!")
  labels+=("$input")
  temps+=("$temp")
  ((device_index += 1))

  if ((${#pids[@]} == 2)); then
    wait_for_batch
  fi
done

((${#pids[@]} == 0)) || wait_for_batch
trap - EXIT INT TERM HUP
