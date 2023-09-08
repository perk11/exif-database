#!/bin/bash

DIRECTORY="$1"
DATABASE_FILE="$2"

if [[ -z "$DIRECTORY" || -z "$DATABASE_FILE" ]]; then
    echo "Usage: $0 <directory> <output_db_file>"
    exit 1
fi

if ! command -v exiftool &> /dev/null; then
    echo "Error: exiftool not found. Please install it."
    exit 1
fi

if ! command -v parallel &> /dev/null; then
    echo "Error: parallel not found. Please install it."
    exit 1
fi
if ! command -v jq &> /dev/null; then
    echo "Error: jq not found. Please install it."
    exit 1
fi
if ! command -v sqlite3 &> /dev/null; then
    echo "Error: sqlite not found. Please install it."
    exit 1
fi

# Initialize SQLite database
sqlite3 "$DATABASE_FILE" "CREATE TABLE IF NOT EXISTS exif_data (filename TEXT, exif_json TEXT);"

# Get filenames that are already in the database
existing_files=$(sqlite3 "$DATABASE_FILE" "SELECT filename FROM exif_data;")

# Convert list of filenames to a temporary file for efficient filtering
tempfile=$(mktemp)
echo "$existing_files" > "$tempfile"

# Define a function for parallel execution
process_file() {
    file="$1"
    JSON_DATA=$(exiftool -json "$file" | jq -c .[0])
    # Escape single quotes for SQLite insertion
    ESCAPED_JSON_DATA=$(echo "$JSON_DATA" | sed "s/'/''/g")
    # Return the result as an INSERT statement
    echo "INSERT INTO exif_data (filename, exif_json) VALUES ('$file', '$ESCAPED_JSON_DATA');"
}

export -f process_file

# If existing_files is empty, process all files. Otherwise, exclude existing ones.
if [ -z "$existing_files" ]; then
    sqlite3 "$DATABASE_FILE" < <(find "$DIRECTORY" -type f | parallel --bar process_file {})
else
    sqlite3 "$DATABASE_FILE" < <(find "$DIRECTORY" -type f | grep -vFf "$tempfile" | parallel --bar process_file {})
fi

# Clean up
rm "$tempfile"
