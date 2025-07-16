#!/bin/bash

set -e

SCRIPT_PATH="/usr/local/bin/update-docker-hosts"
CRON_FILE="/etc/cron.d/update-docker-hosts"
HOSTS_FILE="/etc/hosts"
START_MARK="# BEGIN DOCKER HOSTNAMES"
END_MARK="# END DOCKER HOSTNAMES"

echo "[*] Létrehozom a frissítő szkriptet: $SCRIPT_PATH"

cat > "$SCRIPT_PATH" << 'EOF'
#!/bin/bash

HOSTS_FILE="/etc/hosts"
START_MARK="\n# BEGIN DOCKER HOSTNAMES"
END_MARK="# END DOCKER HOSTNAMES"
TMP_FILE=$(mktemp)

echo "" > "$TMP_FILE"
echo "" >> "$TMP_FILE"
echo "$START_MARK" > "$TMP_FILE"

docker ps -q | while read -r CONTAINER_ID; do
    IMAGE_NAME=$(docker inspect --format '{{.Config.Image}}' "$CONTAINER_ID")

    # Szűrés image név alapján
    if [[ "$IMAGE_NAME" != *parkervcp* && "$IMAGE_NAME" != *pterodactyl* && "$IMAGE_NAME" != *pelican* ]]; then
        continue
    fi

    # Próbálunk hostname-t kérni a konténertől
    HOSTNAME=$(docker exec "$CONTAINER_ID" hostname 2>/dev/null)

    if [[ -z "$HOSTNAME" ]]; then
        HOSTNAME=$(docker inspect --format '{{.Name}}' "$CONTAINER_ID" | sed 's/^\/\(.*\)/\1/')
    fi

    if [[ -n "$HOSTNAME" ]]; then
        echo "127.0.0.1 $HOSTNAME" >> "$TMP_FILE"
    fi
done

echo "$END_MARK" >> "$TMP_FILE"

# Régi blokk cseréje
sed -i "/$START_MARK/,/$END_MARK/d" "$HOSTS_FILE"
cat "$TMP_FILE" >> "$HOSTS_FILE"
rm "$TMP_FILE"
EOF

chmod +x "$SCRIPT_PATH"

echo "[*] Futtatom a szkriptet egyszeri frissítéshez..."
"$SCRIPT_PATH"

echo "[*] Cron hozzáadása..."
echo "*/5 * * * * root $SCRIPT_PATH" > "$CRON_FILE"
chmod 644 "$CRON_FILE"
echo "Cron beállítva: frissítés 5 percenként."

echo "Kész. A script: $SCRIPT_PATH"
