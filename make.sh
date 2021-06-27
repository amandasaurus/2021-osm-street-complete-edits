#! /bin/bash

set -o nounset -o errexit -o pipefail

wget -N https://planet.openstreetmap.org/planet/changesets-latest.osm.bz2.torrent
aria2c --seed-time 0 changesets-latest.osm.bz2.torrent


DATE=$(ls changesets-*.osm.bz2| sort | tail -n1 | grep -Po "(?<=^changesets-)2\d\d\d\d\d(?=.osm.bz2$)")
osmium cat -f opl changesets-${DATE}.osm.bz2 | pv -s 100M  -l -c -N all | grep -P " T(\S+,)?created_by=Street(%20%)?Complete%20%" | cut -d" " -f1 | cut -c2- | pv -l -c -N out | gzip > ${DATE}-changesets.txt.gz

osm-tag-csv-history -i ireland-and-northern-ireland-internal.osh.pbf -o ie-tags.csv.gz -v

echo -e ".mode csv\n.import \"|zcat ie-tags.csv.gz\" ie_edits\n" | sqlite3 ie-sc.db
echo -e "create table sc_changesets ( id INTEGER );\n.mode csv\n.import \"|zcat ${DATE}-changeset-txt.gz\" sc_changesets\n" | sqlite3 ie-sc.db
echo -e "create view sc_edits AS select ie_edits.* from ie_edits join sc_changesets ON (ie_edits.changeset_id = sc_changesets.id);" | sqlite3 ie-sc.db
echo -e ".headers on\n.mode csv\nselect * from sc_edits order by datetime;" | sqlite3 ie-sc.db > ie-sc-edits.csv



