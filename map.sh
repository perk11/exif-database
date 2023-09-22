#!/bin/bash

DISPLAY_AT_MAX_ZOOM=0

for arg in "$@"; do
    case $arg in
        --display-at-max-zoom)
            DISPLAY_AT_MAX_ZOOM=1
            shift # Remove --display-at-max-zoom from processing
            ;;
        *)
            # Default case: If no option is passed this will just be assigned to DATABASE_FILE
            DATABASE_FILE="$arg"
            ;;
    esac
done

if [[ -z "$DATABASE_FILE" ]]; then
    echo "Usage: $0 [--display-at-max-zoom] <db_file>"
    exit 1
fi

if [[ ! -e "$DATABASE_FILE" ]]; then
    echo "File $DATABASE_FILE not found"
    exit 1
fi

echo "var mediaSettings={'displayAtMaxZoom': " >map-data.js
if [[ $DISPLAY_AT_MAX_ZOOM -eq 1 ]]; then
    echo 'true' >>map-data.js
else
    echo 'false' >>map-data.js
fi
echo '};' >> map-data.js
echo "var exifData=[" >>map-data.js
sqlite3 "$DATABASE_FILE" -cmd ".param set @includeFileName $DISPLAY_AT_MAX_ZOOM" <map.sql >>map-data.js
echo "];" >>map-data.js
