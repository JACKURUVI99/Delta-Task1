#!/bin/bash

BASE_DIR="/root/DeltaTask/Blogs"
BLOGS_DIR="$BASE_DIR/blogs"
PUBLIC_DIR="$BASE_DIR/public"
BLACKLIST="/root/DeltaTask/blogFilter/blacklist.txt"
LOG_FILE="/root/DeltaTask/blogFilter/censorship.log"

verify_files() {
    if [ ! -f "$BLACKLIST" ]; then
        echo "Blacklist not found"
        exit 1
    fi
    if [ ! -s "$BLACKLIST" ]; then
        echo "Blacklist is empty"
        exit 1
    fi
    mkdir -p "$(dirname "$LOG_FILE")"
    echo "=== Log $(date '+%Y-%m-%d %T') ===" > "$LOG_FILE"
}
censor_file() {
    file="$1"
    name="$(basename "$file")"
    out="$PUBLIC_DIR/$name"
    total=0
    declare -A found
    [ ! -f "$out" ] && cp "$file" "$out"
    [ "$file" -nt "$out" ] && cp -f "$file" "$out"
    echo "Checking: $name" | tee -a "$LOG_FILE"
    while IFS= read -r word; do
        [ -z "$word" ] && continue
        count=$(grep -oi "\b${word}\b" "$out" | wc -l)
        if [ "$count" -gt 0 ]; then
            stars=$(printf '%*s' "${#word}" | tr ' ' '*')
            sed -i "s/\b${word}\b/${stars}/gi" "$out"
            found["$word"]=$count
            ((total+=count))
            echo "[$(date '+%H:%M:%S')] $word -> $count" >> "$LOG_FILE"
        fi
    done < "$BLACKLIST"

    if [ "$total" -gt 0 ]; then
        echo "Words found: $total" | tee -a "$LOG_FILE"
        for w in "${!found[@]}"; do
            echo "$w: ${found[$w]}" | tee -a "$LOG_FILE"
        done
    else
        echo "Clean file" | tee -a "$LOG_FILE"
    fi
    echo "" >> "$LOG_FILE"
}

main() {
    verify_files
    echo "Starting..."
    find "$BLOGS_DIR" -type f -name "*.txt" | while read -r file; do
        censor_file "$file"
    done
    echo "Done. Log: $LOG_FILE"
}
main