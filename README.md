# exif-database

A bash script to build a sqlite database of all EXIF information in directory.

## Pre-requisites:

exiftool, jq, parallel, sqlite3

**Usage**:
	
	./build_exif_dbv2.sh <directory_with_photos> <output_db_file>

The script will try to use all CPU cores and will display a progressbar with the name of the file currently being processed.
It will try to read all the files recursively, everything recognized by exiftool is going to get indexed.

If ran again with the same arguments, it will skip the files already processed, allowing to resume it if it got interrupted and also only index new files.

DO NOT TRY TO READ OR WRITE FROM THE DATABASE WHILE THE SCRIPT IS RUNNING. This might cause sqlite to error out and some records will fail to INSERT.

# Generating a map

Once the database is generated, you can use

./map.sh

to generate a heatmap of all the files based on GPS Coordinates. The GPS coordinates will be saved to map-data.js.
To view them on a map, open map.html.

# Other uses

This allows to fairly quickly search photos by exif information. For example, find all photos and videos made on Apple devices:

    sqlite3 database.db "SELECT filename FROM exif_data WHERE json_extract(exif_json, '$.Make') = 'Apple';"

It also allows to pull interesting statistics on photos, for example here how you can pull number of files by device model taken each year, using EXIF and falling back to modification date if EXIF is not available:

	sqlite3 database.db "SELECT substr(coalesce(json_extract(exif_json, '$.SubSecDateTimeOriginal'),\
	       json_extract(exif_json, '$.FileModifyDate')), 1, 4) AS Year,\
	       json_extract(exif_json, '$.Make') ||' ' || json_extract(exif_json, '$.Model') AS Model,\
	       count(1)\
	 FROM exif_data\
	 GROUP BY Year, Model\
	 ORDER BY Year, Model;"
