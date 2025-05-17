#!/bin/bash

AUTHOR_HOME="/home/authors/$(whoami)"
BLOGS_DIR="$AUTHOR_HOME/blogs"
PUBLIC_DIR="$AUTHOR_HOME/public"
BLOGS_YAML="$AUTHOR_HOME/blogs.yaml"
SUBSCRIPTIONS_FILE="/root/DeltaTask/subscriptionModel/subscriptions.yaml"

# Verify author home exists
if [[ ! -d "$AUTHOR_HOME" ]]; then
    echo "Error: Author home directory not found"
    exit 1
fi

# Initialize blogs.yaml if it doesn't exist
if [[ ! -f "$BLOGS_YAML" ]]; then
    cat > "$BLOGS_YAML" <<EOF
categories:
  1: Sports
  2: Cinema
  3: Technology
  4: Travel
  5: Food
  6: Lifestyle
  7: Finance
blogs: []
EOF
    chmod 600 "$BLOGS_YAML"
fi

# Create directories if they don't exist
mkdir -p "$BLOGS_DIR" "$PUBLIC_DIR"
chmod 700 "$BLOGS_DIR"
chmod 755 "$PUBLIC_DIR"

show_categories() {
    echo "Available categories:"
    yq e '.categories' "$BLOGS_YAML"
}

publish_blog() {
    local filename=$1
    [[ ! -f "$BLOGS_DIR/$filename" ]] && echo "Error: Blog file not found" && return 1
    
    show_categories
    echo "Enter category numbers (comma-separated, e.g., 1,3,5):"
    read -r categories
    
    # Ask for publication type
    echo "Publish as:"
    echo "1) Public (all users can view)"
    echo "2) Subscribers only"
    read -r -p "Choice [1-2]: " pub_choice
    
    # Add to YAML
    yq e ".blogs += [{
        \"filename\": \"$filename\",
        \"publish_status\": true,
        \"categories\": [${categories}],
        \"subscriber_only\": $([[ "$pub_choice" == "2" ]] && echo "true" || echo "false"),
        \"publish_date\": \"$(date +%Y-%m-%d)\"
    }]" -i "$BLOGS_YAML"
    
    # Handle publication based on type
    if [[ "$pub_choice" == "1" ]]; then
        # Public blog
        ln -sf "$BLOGS_DIR/$filename" "$PUBLIC_DIR/$filename"
        chmod 644 "$PUBLIC_DIR/$filename"
        echo "Published '$filename' publicly"
    else
        # Subscriber-only blog
        author=$(whoami)
        subscribers=$(yq e ".subscriptions[] | select(.authors[] == \"$author\") | .user" "$SUBSCRIPTIONS_FILE")
        
        for user in $subscribers; do
            user_dir="/home/users/$user/subscribed_blogs/$author"
            mkdir -p "$user_dir"
            ln -sf "$BLOGS_DIR/$filename" "$user_dir/$filename"
            chown "$user:g_user" "$user_dir"
            chmod 750 "$user_dir"
        done
        echo "Published '$filename' for subscribers only"
    fi
}

archive_blog() {
    local filename=$1
    local subscriber_only=$(yq e ".blogs[] | select(.filename == \"$filename\") | .subscriber_only" "$BLOGS_YAML")
    
    # Update YAML
    yq e "(.blogs[] | select(.filename == \"$filename\") | .publish_status) = false" -i "$BLOGS_YAML"
    
    if [[ "$subscriber_only" == "true" ]]; then
        # Remove from subscribers
        author=$(whoami)
        subscribers=$(yq e ".subscriptions[] | select(.authors[] == \"$author\") | .user" "$SUBSCRIPTIONS_FILE")
        
        for user in $subscribers; do
            rm -f "/home/users/$user/subscribed_blogs/$author/$filename"
        done
    else
        # Remove from public
        rm -f "$PUBLIC_DIR/$filename"
    fi
    
    echo "Archived '$filename'"
}

delete_blog() {
    local filename=$1
    local subscriber_only=$(yq e ".blogs[] | select(.filename == \"$filename\") | .subscriber_only" "$BLOGS_YAML")
    
    # Remove from YAML
    yq e "del(.blogs[] | select(.filename == \"$filename\"))" -i "$BLOGS_YAML"
    
    # Remove all files
    rm -f "$BLOGS_DIR/$filename"
    rm -f "$PUBLIC_DIR/$filename"
    
    # Remove from subscribers if needed
    if [[ "$subscriber_only" == "true" ]]; then
        author=$(whoami)
        subscribers=$(yq e ".subscriptions[] | select(.authors[] == \"$author\") | .user" "$SUBSCRIPTIONS_FILE")
        
        for user in $subscribers; do
            rm -f "/home/users/$user/subscribed_blogs/$author/$filename"
        done
    fi
    
    echo "Deleted '$filename' completely"
}

edit_categories() {
    local filename=$1
    [[ -z $(yq e ".blogs[] | select(.filename == \"$filename\")" "$BLOGS_YAML") ]] && \
        echo "Error: Blog not found" && return 1
    
    echo "Current categories:"
    yq e ".blogs[] | select(.filename == \"$filename\") | .categories" "$BLOGS_YAML"
    
    show_categories
    echo "Enter new category numbers (comma-separated):"
    read -r new_categories
    
    yq e "(.blogs[] | select(.filename == \"$filename\")).categories = [${new_categories}]" -i "$BLOGS_YAML"
    echo "Updated categories for '$filename'"
}

show_help() {
    echo "Usage: $0 { -p | -a | -d | -e } filename"
    echo "Options:"
    echo "  -p filename   Publish a blog"
    echo "  -a filename   Archive a blog"
    echo "  -d filename   Delete a blog completely"
    echo "  -e filename   Edit blog categories"
}

# Main command handling
case "$1" in
    -p) publish_blog "$2" ;;
    -a) archive_blog "$2" ;;
    -d) delete_blog "$2" ;;
    -e) edit_categories "$2" ;;
    *) show_help ;;
esac