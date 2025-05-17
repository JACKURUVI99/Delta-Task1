#!/bin/bash

base="/root/DeltaTask"
yaml="$base/Blogs/blogs.yaml"
rep="$base/admin/reports"
logs="$base/logs"
readcount="$logs/readcount.db"

if [ "$(whoami)" != "root" ]; then
  echo "run as root"
  exit 1
fi
start() {
  mkdir -p "$rep"
  mkdir -p "$logs"
  touch "$readcount"
  chmod 600 "$readcount"
  date > "$logs/init.log"
}

track() {
  id="$2"
  if grep -q "^$id " "$readcount"; then
    old=$(grep "^$id " "$readcount" | cut -d' ' -f2)
    new=$((old + 1))
    sed -i "s/^$id .*/$id $new/" "$readcount"
  else
    echo "$id 1" >> "$readcount"
  fi
}
report() {
  file="$rep/report_$(date +%Y%m%d%H%M%S).txt"
  pub=0
  del=0
  echo "BLOG REPORT" > "$file"
  echo "Date: $(date)" >> "$file"
  count=$(yq e '.blogs | length' "$yaml")
  i=0
  while [ $i -lt $count ]; do
    name=$(yq e ".blogs[$i].file_name" "$yaml")
    stat=$(yq e ".blogs[$i].publish_status" "$yaml")
    if [ "$stat" = "true" ]; then
      pub=$((pub + 1))
    else
      del=$((del + 1))
    fi
    i=$((i + 1))
  done
  echo "Published: $pub" >> "$file"
  echo "Deleted: $del" >> "$file"
  echo "Top 3 Articles:" >> "$file"

  if [ -s "$readcount" ]; then
    sort -nrk2 "$readcount" | head -3 >> "$file"
  else
    echo "No read data" >> "$file"
  fi
  echo "Done report: $file"
}

if [ "$1" = "init" ]; then
  start
elif [ "$1" = "track" ]; then
  track "$@"
elif [ "$1" = "report" ]; then
  report
else
  echo "use: $0 init | track filename | report"
fi
