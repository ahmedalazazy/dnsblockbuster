#!/bin/sh

# Get the host files.
if [ ! -f "personal-online-hosts-files.txt" ]; then
    online_hosts_list=$(cat online-hosts-files.txt)
else
    online_hosts_list=$(cat personal-online-hosts-files.txt)
fi

# Create a temporary file.
tmpfile=$(mktemp)

# Get all host files and concatenate into one.
echo "$online_hosts_list" | xargs -n 1 wget -O - > "$tmpfile"

# Personal blacklist
if [ ! -f "blacklist.txt" ]; then
    printf "\nNo blacklist.txt found, running without.\n\n"
else
    cat blacklist.txt >> "$tmpfile"
fi

# Whitelist.
if [ ! -f "whitelist.txt" ]; then
    printf "\nNo whitelist.txt found, running without.\n\n"
else
    grep -F -f whitelist.txt -v -- "$tmpfile" > "$tmpfile".tmp
fi

# Make all lower case.
tr '[:upper:]' '[:lower:]' < "$tmpfile.tmp" > "$tmpfile"

# Delete specific lines we don't want, try to fix typos and then cleanup.
sed -i '/^#/d' "$tmpfile"
sed -i '/^=/d' "$tmpfile"
sed -i '/^:/d' "$tmpfile"
sed -i '/^\./d' "$tmpfile"
sed -i '/^127.0.0.1/d' "$tmpfile"
sed -i '/^255.255.255.255/d' "$tmpfile"
sed -i '/^ff0/d' "$tmpfile"
sed -i '/^fe80/d' "$tmpfile"
sed -i '/^0.0.0.0 0.0.0.0$/d' "$tmpfile"
sed -i 's/0.0.0.0 0.0.0.0.//' "$tmpfile"
sed -i 's/0.0.0.0 //' "$tmpfile"

# Delete all empty lines.
sed -i '/^$/d' "$tmpfile"

# Make proper host format.
sed -i '/^0\.0\.0\.0/! s/^/0.0.0.0 /' "$tmpfile"

# Some entries are duplicated because of comments after the domain like this:
# 0.0.0.0 foo.bar
# 0.0.0.0 foo.bar #foo's domain
# This cleans all of that up.
awk '/^0.0.0.0/ { print "0.0.0.0", $2 }' "$tmpfile" > "$tmpfile".tmp

# Remove duplicate entries and create dnsmasq hosts file.
awk '!seen[$0]++' "$tmpfile".tmp > dnsmasq-blocked-hosts.txt

# Create Unbound hosts file from the dnsmasq hosts file.
awk '/^0.0.0.0/ {
    print "local-zone: \""$2"\" always_nxdomain"
}' dnsmasq-blocked-hosts.txt > unbound-blocked-hosts.conf

# Cleanup
rm -f "$tmpfile" "$tmpfile".tmp
