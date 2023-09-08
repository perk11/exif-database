WITH ExtractedData AS (
    SELECT
        Latitude,
        Longitude,
        CAST(SUBSTR(Latitude, 1, INSTR(Latitude, ' deg') - 1) AS FLOAT) AS LatDeg,
        CAST(SUBSTR(Latitude, INSTR(Latitude, ' deg ') + 5, INSTR(Latitude, '''') - INSTR(Latitude, ' deg ') - 5) AS FLOAT) AS LatMin,
        CAST(SUBSTR(Latitude, INSTR(Latitude, ''' ') + 2, INSTR(Latitude, '"') - INSTR(Latitude, ''' ') - 2) AS FLOAT) AS LatSec,
        SUBSTR(Latitude, -1) AS LatHemisphere,

        CAST(SUBSTR(Longitude, 1, INSTR(Longitude, ' deg') - 1) AS FLOAT) AS LonDeg,
        CAST(SUBSTR(Longitude, INSTR(Longitude, ' deg ') + 5, INSTR(Longitude, '''') - INSTR(Longitude, ' deg ') - 5) AS FLOAT) AS LonMin,
        CAST(SUBSTR(Longitude, INSTR(Longitude, ''' ') + 2, INSTR(Longitude, '"') - INSTR(Longitude, ''' ') - 2) AS FLOAT) AS LonSec,
        SUBSTR(Longitude, -1) AS LonHemisphere

    FROM (
        SELECT
            json_extract(exif_json, '$.GPSLatitude') AS Latitude,
            json_extract(exif_json, '$.GPSLongitude') AS Longitude
        FROM exif_data
    )
    WHERE Latitude IS NOT NULL AND Longitude IS NOT NULL
)

SELECT
        '[' ||
        CASE WHEN LatHemisphere = 'S' THEN '-' ELSE '' END || (LatDeg + LatMin/60 + LatSec/3600) || ',' ||
        CASE WHEN LonHemisphere = 'W' THEN '-' ELSE '' END || (LonDeg + LonMin/60 + LonSec/3600) || ',' || '1' ||
        '],' AS ConvertedCoords
FROM ExtractedData;
