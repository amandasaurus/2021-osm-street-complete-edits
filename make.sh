#! /bin/bash

set -o nounset -o errexit -o pipefail

echo "Downloading Changeset file"
wget -N https://planet.openstreetmap.org/planet/changesets-latest.osm.bz2.torrent
aria2c --seed-time 0 --check-integrity changesets-latest.osm.bz2.torrent
DATE=$(find . -name 'changesets-*.osm.bz2' | sort | tail -n1 | grep -Po "(?<=^changesets-)2\d\d\d\d\d(?=.osm.bz2$)")

echo "Extracting StreetComplete changeset ids"
if [ "changesets-${DATE}.osm.bz2" -nt "${DATE}-changesets.txt.gz" ] ; then
	osmium cat -f opl "changesets-${DATE}.osm.bz2" | pv -s 100M  -l -c -N "Input" | grep -P " T(\S+,)?created_by=Street(%20%)?Complete%20%" | cut -d" " -f1 | cut -c2- | pv -l -c -N "Num. output changesets" | gzip > "${DATE}-changesets.txt.gz"
fi

if [ tags.csv.gz -nt ireland-and-northern-ireland-internal.osh.pbf ] ; then
	osm-tag-csv-history -i ireland-and-northern-ireland-internal.osh.pbf -o tags.csv.gz -v
fi

if [ tags.csv.gz -nt osm-edits.db ] ; then
	echo -e ".mode csv\n.import \"|zcat tags.csv.gz\" ie_edits\n" | sqlite3 osm-edits.db
fi
if [ "${DATE}-changesets.txt.gz" -nt osm-edits.db ] ; then
	echo -e "create table sc_changesets ( id INTEGER );\n.mode csv\n.import \"|zcat ${DATE}-changeset.txt.gz\" sc_changesets\n" | sqlite3 osm-edits.db
fi

echo -e "create view sc_edits AS select ie_edits.* from ie_edits join sc_changesets ON (ie_edits.changeset_id = sc_changesets.id);" | sqlite3 osm-edits.db

if [ osm-edits.db -nt sc-edits.csv ] ; then
	echo -e ".headers on\n.mode csv\nselect * from sc_edits order by datetime;" | sqlite3 osm-edits.db > sc-edits.csv
fi

echo "Output to sc-edits.csv"



