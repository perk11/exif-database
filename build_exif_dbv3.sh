#!/bin/bash
set -e

DIRECTORY="$1"
DATABASE_FILE="$2"

if [[ -z "$DIRECTORY" || -z "$DATABASE_FILE" ]]; then
    echo "Usage: $0 <directory> <output_db_file>"
    exit 1
fi

if ! command -v curl &> /dev/null; then
    echo "Error: curl not found. Please install it."
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

DIRECTORY=$(realpath "$DIRECTORY")
# Initialize SQLite database
sqlite3 "$DATABASE_FILE" "CREATE TABLE IF NOT EXISTS exif_data (filename TEXT, exif_json TEXT);"
sqlite3 "$DATABASE_FILE" "CREATE TABLE IF NOT EXISTS objects (filename TEXT, object);"

# Get filenames that are already in the database
existing_files=$(sqlite3 "$DATABASE_FILE" "SELECT filename FROM exif_data;")

# Convert list of filenames to a temporary file for efficient filtering
tempfile=$(mktemp)
echo "$existing_files" > "$tempfile"

# Define a function for parallel execution
process_file() {
    file="$1"
    FULL_PATH=$(realpath "$file"  | sed "s/'/''/g")
    JSON_DATA=$(exiftool -json "$file" | jq -c .[0])
    ESCAPED_JSON_DATA=$(echo "$JSON_DATA" | sed "s/'/''/g")
    echo "INSERT INTO exif_data (filename, exif_json) VALUES ('$FULL_PATH', '$ESCAPED_JSON_DATA');"

    OBJECTS=$(curl -X POST http://localhost:8000 -H "Content-Type: application/json" -d "{\"image_path\": \"$file\"}"|jq -r .response)
    if [ $? -ne 0 ]; then
        echo "Error: Failed to read object for file $file." >&2
        exit 1
    fi
    if [ -n "$OBJECTS" ]; then
        IFS=',' read -ra objects <<< "$OBJECTS"
        for object in "${objects[@]}"; do
          # Trim leading and trailing whitespace from each object and escape single quotes
          ESCAPED_OBJECT=$(echo "$object" | sed "s/^[[:space:]]*//;s/[[:space:]]*$//;s/'/''/g")
          echo "INSERT INTO objects(filename, object) VALUES('$FULL_PATH','$ESCAPED_OBJECT');"
        done
    fi
}

export -f process_file

chunk_size=15

{
    echo "BEGIN TRANSACTION;"
    # If existing_files is empty, process all files. Otherwise, exclude existing ones.
    find "$DIRECTORY" -type f | if [ -z "$existing_files" ]; then
        cat
    else
        grep -vFf "$tempfile"
    fi | parallel --bar process_file {} | awk -v size="$chunk_size" 'NR % size == 0 {print "COMMIT; BEGIN TRANSACTION;"} 1'
    echo "COMMIT;"
} | sqlite3 "$DATABASE_FILE"

# Clean up
rm "$tempfile"
