#!/bin/bash
ADMIN_USER="root"
USER_PREFS="/root/DeltaTask/userFY/userpref.yaml"
BLOGS_DIR="/root/DeltaTask/Blogs/blogs"
USER_HOME_BASE="/home"
LOG_FILE="/root/DeltaTask/userFY/assignment.log"

if [ "$(whoami)" != "$ADMIN_USER" ]; then
    echo "Error: This script can only be run by $ADMIN_USER" >&2
    exit 1
fi

if ! command -v yq &> /dev/null; then
    echo "Error: yq is required. Install with: sudo apt install yq" >&2
    exit 1
fi

log() {
    echo "$(date '+%Y-%m-%d %T') - $1" | tee -a "$LOG_FILE"
}

assign_blogs() {
    log "Starting blog assignment process"

    declare -A user_prefs
    declare -a users
    declare -A blog_assignments
    
    user_count=$(yq e '.users | length' "$USER_PREFS")
    total_blogs=$(find "$BLOGS_DIR" -type f -name "*.txt" | wc -l)
    
    log "Found $user_count users and $total_blogs blogs"
    for ((i=0; i<user_count; i++)); do
        username=$(yq e ".users[$i].username" "$USER_PREFS")
        users+=("$username")
        user_prefs["$username,1"]=$(yq e ".users[$i].pref1" "$USER_PREFS")
        user_prefs["$username,2"]=$(yq e ".users[$i].pref2" "$USER_PREFS")
        user_prefs["$username,3"]=$(yq e ".users[$i].pref3" "$USER_PREFS")
    done
    while IFS= read -r blog; do
        blog_name=$(basename "$blog")
        blog_assignments["$blog_name"]=0
    done < <(find "$BLOGS_DIR" -type f -name "*.txt")

    for username in "${users[@]}"; do
        user_home="$USER_HOME_BASE/$username"
        fy_file="$user_home/FYI.yaml"
        temp_file="$(mktemp)"
        
        echo "blogs: []" > "$temp_file"
        assigned=0
        pref1="${user_prefs["$username,1"]}"
        pref2="${user_prefs["$username,2"]}"
        pref3="${user_prefs["$username,3"]}"
        
        log "Processing user: $username (Preferences: $pref1, $pref2, $pref3)"
        
        while IFS= read -r blog; do
            [ $assigned -ge 3 ] && break
            
            blog_name=$(basename "$blog")
            categories=$(yq e '.categories[]' "$blog" 2>/dev/null)
            score=0
            for cat in $categories; do
                [[ "$cat" == "$pref1" ]] && ((score+=3))
                [[ "$cat" == "$pref2" ]] && ((score+=2))
                [[ "$cat" == "$pref3" ]] && ((score+=1))
            done
            
            if [ $score -gt 0 ]; then
                current_assignments=${blog_assignments["$blog_name"]}
                max_allowed=$(( (user_count * 3 + total_blogs - 1) / total_blogs ))
                
                if [ $current_assignments -lt $max_allowed ]; then
                    yq e ".blogs += [\"$blog_name\"]" -i "$temp_file"
                    ((blog_assignments["$blog_name"]++))
                    ((assigned++))
                    log "Assigned $blog_name to $username (Match Score: $score)"
                fi
            fi
        done < <(find "$BLOGS_DIR" -type f -name "*.txt" | sort)
        
        while [ $assigned -lt 3 ] && [ $assigned -lt $total_blogs ]; do
            least_assigned=""
            min_count=9999
            
            for blog_name in "${!blog_assignments[@]}"; do
                if [ ${blog_assignments["$blog_name"]} -lt $min_count ]; then
                    min_count=${blog_assignments["$blog_name"]}
                    least_assigned="$blog_name"
                fi
            done
            
            if [ -n "$least_assigned" ]; then
                yq e ".blogs += [\"$least_assigned\"]" -i "$temp_file"
                ((blog_assignments["$least_assigned"]++))
                ((assigned++))
                log "Fallback assigned $least_assigned to $username"
            else
                break
            fi
        done
        
        mkdir -p "$user_home"
        chown "$username:$username" "$user_home"
        
        mv "$temp_file" "$fy_file"
        chown "$username:$username" "$fy_file"
        log "Created FYI.yaml for $username with $assigned blogs"
    done

    echo -e "\nBlog Assignment Summary:" | tee -a "$LOG_FILE"
    for blog_name in "${!blog_assignments[@]}"; do
        echo "$blog_name: ${blog_assignments["$blog_name"]} assignments" | tee -a "$LOG_FILE"
    done
    
    log "Blog assignment process completed"
}
mkdir -p "$(dirname "$LOG_FILE")"

assign_blogs
exit 0