#!/bin/bash

FILE="/root/DeltaTask/subscriptionModel/subscriptions.yaml"
AUTHORS="/home/authors"
USERS="/home/users"
[ ! -f "$FILE" ] && echo "subscriptions:" > "$FILE"

subscribe() {
  u=$1; a=$2
  grep -q "user: $u" "$FILE" || {
    echo "  - user: $u" >> "$FILE"
    echo "    authors:" >> "$FILE"
  }
  grep -q "user: $u" -A5 "$FILE" | grep -q "  - $a" && {
    echo "Already subscribed"; return
  }
  awk -v user="$u" -v author="$a" '
    { print }
    $0 ~ "user: " user { f=1 }
    f && /authors:/ { print "    - " author; f=0 }
  ' "$FILE" > tmp && mv tmp "$FILE"
  mkdir -p "$USERS/$u/subscribed_blogs/$a"
  chown "$u:g_user" "$USERS/$u/subscribed_blogs/$a"
  chmod 750 "$USERS/$u/subscribed_blogs/$a"
  echo "Subscribed"
}

unsubscribe() {
  u=$1; a=$2
  awk -v user="$u" -v author="$a" '
    BEGIN {f=0; afound=0}
    $0 ~ "user: " user {f=1; print; next}
    f && /authors:/ { print; next }
    f && /^[[:space:]]+- / {
      if ($1 == "-" && $2 == author) { afound=1; next }
      else print; next
    }
    /^[[:space:]]*[^-]/ {f=0}
    { print }
    END {
      if (afound == 0) print "User or author not found"
    }
  ' "$FILE" > tmp && mv tmp "$FILE"
  awk '/user:/ {u=$2} /authors:/ {getline; if ($0 !~ "-") next} 1' tmp > "$FILE"
  rm -rf "$USERS/$u/subscribed_blogs/$a"
  echo "Unsubscribed"
}

list() {
  cat "$FILE"
}

case "$1" in
  subscribe) subscribe "$2" "$3" ;;
  unsubscribe) unsubscribe "$2" "$3" ;;
  list) list ;;
  *) echo "Usage: $0 {subscribe|unsubscribe|list}" ;;
esac
