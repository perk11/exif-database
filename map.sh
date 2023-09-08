#!/bin/bash

DATABASE_FILE="$1"
if [[ -z "$DATABASE_FILE" ]]; then
    echo "Usage: $0 <db_file>"
    exit 1
fi
if [[ ! -e "$DATABASE_FILE" ]]; then
  echo "File $DATABASE_FILE not found";
  exit 1;
fi

echo "var heatLayerData=[">map-data.js
sqlite3 "$DATABASE_FILE" <map.sql >>map-data.js
echo "];">>map-data.js
