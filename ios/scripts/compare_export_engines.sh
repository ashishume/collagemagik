#!/usr/bin/env bash
set -euo pipefail

repo=$(cd "$(dirname "$0")/../.." && pwd)
cd "$repo"
: "${SIM_UDID:?Set SIM_UDID to a booted simulator with the Debug app installed}"
work=${CM_COMPARE_DIR:-/tmp/collagemagik-export-comparison}
report=${CM_COMPARE_REPORT:-"$repo/ios/docs/gpu-export-results.md"}
mode=${1:-compare}
selection=${2:-}
bundle=com.axpo.collagemagik
mkdir -p "$work"
work=$(cd "$work" && pwd)
case "$mode" in baseline|compare|against-baseline|cpu-parity) ;; *) echo "Usage: $0 [baseline|compare|against-baseline|cpu-parity] [case regex]" >&2; exit 2 ;; esac

if [[ ! -e "$report" ]]; then
    printf '| Case | Engine | Resolution/fps | Seconds | Peak MB | SSIM overall | SSIM min frame |\n|---|---|---|---:|---:|---:|---:|\n' > "$report"
fi

ads="$repo/google-ads/output/v5"
pictures="$repo/google-ads/html5/v5/300x600"
land="$ads/collagemagik-mix-ad-landscape-16x9-1920x1080.mp4"
square="$ads/collagemagik-mix-ad-square-1x1-1080x1080.mp4"
portrait="$ads/collagemagik-mix-ad-vertical-9x16-1080x1920.mp4"
fixture() {
    local target=$1 source=$2 start=$3
    shift 3
    [[ -s "$target" ]] && return 0
    # The ad files are only read. All generated fixtures live under the comparison directory.
    ffmpeg -hide_banner -loglevel error -y -ss "$start" -i "$source" -t 5 "$@" \
        -c:a aac "$target.partial.${target##*.}"
    mv "$target.partial.${target##*.}" "$target"
}
a="$work/land.mp4"; b="$work/square.mp4"; c="$work/portrait.mp4"
large="$work/4k.mp4"; small="$work/small.mp4"; hdr="$work/hdr.mov"
fixture "$a" "$land" 4 -c:v libx264 -preset ultrafast
fixture "$b" "$square" 7 -c:v libx264 -preset ultrafast
fixture "$c" "$portrait" 10 -c:v libx264 -preset ultrafast
fixture "$large" "$land" 4 -vf scale=3840:2160 -c:v libx264 -preset ultrafast
fixture "$small" "$square" 7 -vf scale=480:480 -c:v libx264 -preset ultrafast
fixture "$hdr" "$land" 12 \
    -vf 'scale=1920:1080,format=yuv420p10le,setparams=color_primaries=bt2020:color_trc=arib-std-b67:colorspace=bt2020nc' \
    -c:v libx265 -preset ultrafast -crf 22 -tag:v hvc1 \
    -x265-params 'colorprim=bt2020:transfer=arib-std-b67:colormatrix=bt2020nc:log-level=error'

photos="$pictures/balloons.jpg,$pictures/golden-wave.jpg,$pictures/pizza.jpg,$pictures/positano.jpg"
render() {
    local name=$1 engine=$2 stem=$3
    shift 3
    local output="$work/$name/$stem"
    mkdir -p "$work/$name"
    rm -f "$output.mp4" "$output.log" "$output.metrics" "$output.status"
    xcrun simctl terminate "$SIM_UDID" "$bundle" 2>/dev/null || true
    local vars=(SIMCTL_CHILD_CM_PRO=1 SIMCTL_CHILD_CM_NO_PREVIEW_COPY=1 "SIMCTL_CHILD_CM_OUT=$output" "SIMCTL_CHILD_CM_EXPORT_ENGINE=$engine"
        "SIMCTL_CHILD_CM_EXPORT_METRICS=$output.metrics" "SIMCTL_CHILD_CM_EXPORT_STATUS=$output.status")
    local arg launch pid
    for arg in "$@"; do vars+=("SIMCTL_CHILD_$arg"); done
    launch=$(env "${vars[@]}" xcrun simctl launch --stderr="$output.log" "$SIM_UDID" "$bundle" -AppleLanguages '(en-US)' -cm.tour.seen.v1 YES) || return 1
    pid=${launch##* }
    local started=$SECONDS line='' logs=''
    while (( SECONDS - started < ${CM_COMPARE_TIMEOUT:-600} )); do
        if [[ -s "$output.mp4" ]] && ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of csv=p=0 "$output.mp4" >/dev/null 2>&1; then
            if [[ -s "$output.status" && -s "$output.metrics" ]]; then
                line=$(cat "$output.metrics")
            fi
            if [[ -z "$line" ]]; then
                logs=$(xcrun simctl spawn "$SIM_UDID" log show --last 10m --style compact \
                    --predicate "processIdentifier == $pid AND (eventMessage BEGINSWITH 'CM_EXPORT engine=' OR eventMessage BEGINSWITH 'CM_DEBUG export DONE')")
                if [[ "$logs" == *'CM_DEBUG export DONE'* ]]; then
                    line=$(sed -n 's/.*\(CM_EXPORT engine=.*fps=.*\)/\1/p' <<< "$logs" | tail -1)
                fi
            fi
            [[ -z "$line" ]] || break
        fi
        if [[ -f "$output.status" ]] && rg -q 'CM_DEBUG export FAILED' "$output.status"; then
            cat "$output.status" >&2
            printf '\n' >&2
            return 1
        fi
        sleep 1
    done
    if [[ -z "$line" ]]; then echo "$name $engine timed out, see $output.log" >&2; return 1; fi
    printf '%s\n' "$line" > "$output.metrics"
}

row() {
    local name=$1 stem=$2 overall=${3:--} minimum=${4:--}
    awk -v name="$name" -v all="$overall" -v min="$minimum" '
        { split($2,e,"="); split($4,f,"="); split($6,s,"="); split($7,m,"=")
          printf "| %s | %s | %s/%s | %s | %s | %s | %s |\n", name,e[2],$3,f[2],s[2],m[2],all,min }
    ' "$work/$name/$stem.metrics" >> "$report"
}

quality_failed=0
run_case() {
    local name=$1
    shift
    if [[ -n "$selection" && ! "$name" =~ $selection ]]; then return; fi
    echo "$mode $name"
    local folder="$work/$name" reference=baseline actual=gpu
    case "$mode" in
        baseline) render "$name" cpu baseline "$@" && row "$name" baseline; return ;;
        compare)
            local cpu_ready=0
            reference=cpu
            if render "$name" cpu cpu "$@"; then
                row "$name" "$reference" || return 1
                cpu_ready=1
            fi
            render "$name" gpu gpu "$@" || return 1
            if [[ "$cpu_ready" != 1 ]]; then
                row "$name" gpu
                return 1
            fi
            ;;
        against-baseline) render "$name" gpu gpu "$@" || return 1 ;;
        cpu-parity) actual=cpu; render "$name" cpu cpu "$@" || return 1 ;;
    esac
    local frames_ref frames_actual
    frames_ref=$(ffprobe -v error -select_streams v:0 -show_entries stream=nb_frames -of csv=p=0 "$folder/$reference.mp4") || return 1
    frames_actual=$(ffprobe -v error -select_streams v:0 -show_entries stream=nb_frames -of csv=p=0 "$folder/$actual.mp4") || return 1
    [[ "$frames_ref" = "$frames_actual" && "$frames_actual" =~ ^[0-9]+$ ]] || {
        echo "$name frame count differs ($frames_ref vs $frames_actual)" >&2; return 1;
    }
    (cd "$folder" && ffmpeg -hide_banner -nostats -i "$reference.mp4" -i "$actual.mp4" \
        -lavfi "ssim=stats_file=$mode.ssim" -an -f null - 2>"$mode.ffmpeg.log") || return 1
    local overall minimum
    overall=$(sed -n 's/.* All:\([0-9.]*\).*/\1/p' "$folder/$mode.ffmpeg.log" | tail -1)
    minimum=$(awk -F'All:' 'NF>1 { split($2, a, " "); if (!n++ || a[1]+0<min) min=a[1]+0 }
        END { if (n) printf "%.6f", min; else exit 1 }' "$folder/$mode.ssim") || return 1
    if [[ -z "$overall" || "$(wc -l < "$folder/$mode.ssim" | tr -d ' ')" != "$frames_actual" ]]; then
        echo "$name SSIM did not cover all $frames_actual frames" >&2
        return 1
    fi
    row "$name" "$actual" "$overall" "$minimum" || return 1
    if [[ "$actual" == gpu ]]; then
        if ! awk -v all="$overall" -v min="$minimum" 'BEGIN { exit !(all >= .985 && min >= .96) }' ||
           ! rg -q '^CM_EXPORT engine=gpu ' "$folder/$actual.metrics"; then
            echo "$name missed the SSIM or GPU-engine requirement" >&2
            quality_failed=1
        fi
        if [[ "$name" == 4k60-heavy ]]; then
            if ! awk 'NR==1 { split($6,s,"="); split($7,m,"="); cpuTime=s[2]; cpuMB=m[2]; next }
                { split($6,s,"="); split($7,m,"="); exit !(s[2] <= .4 * cpuTime && m[2] <= .6 * cpuMB) }' \
                "$folder/$reference.metrics" "$folder/$actual.metrics"; then
                echo "$name missed the time or memory target" >&2
                quality_failed=1
            fi
        fi
    elif [[ "$mode" == cpu-parity && ( "$overall" != 1.000000 || "$minimum" != 1.000000 ) ]]; then
        echo "$name CPU output differs from the baseline" >&2
        quality_failed=1
    fi
}

run() {
    if ! run_case "$@"; then
        echo "$1 failed. See $work/$1 for artifacts." >&2
        quality_failed=1
    fi
}

run rounded CM_EXPORT=video "CM_BATCH=$a,$b,$c" CM_LAYOUT_ID=3-big-top CM_GAP=14 CM_RADIUS=18
for frame in torn tape film stamp gallery date neon instant circle heart arch; do
    run "frame-$frame" CM_EXPORT=video "CM_BATCH=$photos,$a" "CM_FRAME=$frame" CM_GAP=18 CM_RADIUS=9
done
run tilt-overlays CM_EXPORT=video "CM_BATCH=$a,$photos" CM_LAYOUT=4 CM_LAYOUT_ID=4-tossed CM_FRAME=instant \
    CM_OVERLAYS=1 CM_OVERLAY_FRAME=torn CM_STICKERS=😍,heart.fill CM_CAPTIONS=1
run fit-looks CM_EXPORT=video "CM_BATCH=$photos,$a" CM_FIT=0 CM_LOOK=film CM_ROTATE=0 CM_FLIP=0 CM_ANGLE=0:12
for backdrop in blur gradient:3 pattern:1; do
    run "backdrop-$backdrop" CM_EXPORT=video "CM_BATCH=$a,$photos" "CM_BACKDROP=$backdrop"
done
while IFS= read -r template; do
    run "$template" CM_EXPORT=video "CM_START_TEMPLATE=$template" "CM_BATCH=$a,$b,$photos"
done < <(sed -n 's/.*id: "\([^"]*\)",.*category: \.motion,.*/\1/p' ios/CollageMagik/CollageMagik/Model/Templates.swift)
run 4k60-heavy CM_EXPORT=ultra CM_FPS=60 CM_START_TEMPLATE=living-night "CM_BATCH=$large,$hdr,$small"
run hdr CM_HDR=1 CM_EXPORT=ultra "CM_BATCH=$hdr,$photos"
if [[ -s "$work/hdr/gpu.mp4" && ( "$mode" == compare || "$mode" == against-baseline ) && ( -z "$selection" || hdr =~ $selection ) ]]; then
    tags=$(ffprobe -v error -select_streams v:0 -show_entries stream=codec_name,pix_fmt,color_transfer,color_primaries \
        -of default=noprint_wrappers=1 "$work/hdr/gpu.mp4")
    printf '%s\n' "$tags"
    for tag in codec_name=hevc pix_fmt=yuv420p10le color_transfer=arib-std-b67 color_primaries=bt2020; do
        [[ "$tags" == *"$tag"* ]] || exit 1
    done
fi
exit "$quality_failed"
