#!/bin/bash

[ "$(id -u)" -ne 0 ] && echo "Run as root" && exit 1
command -v yq >/dev/null || { echo "yq not found"; exit 1; }
[ ! -f "users.yaml" ] && echo "users.yaml not found" && exit 1

groupadd -f g_user
groupadd -f g_author
groupadd -f g_mod
groupadd -f g_admin

for admin in $(yq e '.admins[].username' users.yaml); do
  useradd -m -d "/home/admin/$admin" -G g_admin "$admin" 2>/dev/null || usermod -aG g_admin "$admin"
  chmod 750 "/home/admin/$admin"
done

for user in $(yq e '.users[].username' users.yaml); do
  useradd -m -d "/home/users/$user" -G g_user "$user" 2>/dev/null || usermod -aG g_user "$user"
  chmod 750 "/home/users/$user"
  mkdir -p "/home/users/$user/all_blogs"
  for author in $(yq e '.authors[].username' users.yaml); do
    ln -sf "/home/authors/$author/public" "/home/users/$user/all_blogs/$author" 2>/dev/null
  done
done

for author in $(yq e '.authors[].username' users.yaml); do
  useradd -m -d "/home/authors/$author" -G g_author "$author" 2>/dev/null || usermod -aG g_author "$author"
  mkdir -p "/home/authors/$author/public" "/home/authors/$author/blogs"
  chmod 750 "/home/authors/$author"
  chmod 755 "/home/authors/$author/public"
done

for mod in $(yq e '.mods[].username' users.yaml); do
  useradd -m -d "/home/mods/$mod" -G g_mod "$mod" 2>/dev/null || usermod -aG g_mod "$mod"
  chmod 750 "/home/mods/$mod"
  mkdir -p "/home/mods/$mod/author_access"
  for author in $(yq e ".mods[] | select(.username == \"$mod\") | .authors | join(\" \")" users.yaml); do
    ln -sf "/home/authors/$author/public" "/home/mods/$mod/author_access/$author" 2>/dev/null
  done
done

for admin in $(yq e '.admins[].username' users.yaml); do
  find /home -type d -exec setfacl -m u:"$admin":rwx {} \;
done

echo "all done successfully!"
