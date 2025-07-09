import psycopg2
import sys
import os
import json

conn = psycopg2.connect("dbname=linkup_data user=postgres")
cur = conn.cursor()

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Not enough arguments provided! Usage: py UniversityDBMigrationTool.py <University Name> <Path to geojson File>")
        quit()

    universityName = sys.argv[1]
    geojsonPath = sys.argv[2]
    universityID = ""
    if len(sys.argv) == 4:
        universityID = sys.argv[3]
    
    if (not os.path.exists(geojsonPath)):
        print("Path to geojson file does not exist :(")
        quit()
    
    with open(geojsonPath, "r") as geojsonFile:
        jsonData = json.loads(geojsonFile.read())["features"]
        coordinates = [0, 0]
        name = ""

        conn = psycopg2.connect("dbname=linkup_data user=postgres")
        cur = conn.cursor()


        cur.execute("INSERT INTO universities (name) VALUES (%s) RETURNING id;", (universityName,))
        universityID = cur.fetchone()[0]

        for feature in jsonData:
            coordinates[0] = feature["geometry"]["coordinates"][0]
            coordinates[1] = feature["geometry"]["coordinates"][1]
            name = feature["properties"]["name"]

            coordinate = "POINT(" + str(coordinates[0]) + " " + str(coordinates[1]) + ")"
            # print(coordinate)
            cur.execute("INSERT INTO buildings (university_id, name, location) VALUES (%s, %s, %s);", (universityID, name, coordinate,))

        conn.commit()

        cur.close()
        conn.close()

quit()