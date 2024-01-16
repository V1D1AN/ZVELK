#!/bin/bash
EXTRACTION_DIR="/extracted/"
/usr/bin/inotifywait -m --format '%f' -e close_write /evtx/ /velociraptor/ | while read FILE
do
    if [[ "$FILE" == *".zip" ]]; then
        unzip -j "/velociraptor/$FILE" -d "$EXTRACTION_DIR"
        find $EXTRACTION_DIR -type f ! -name "*.json" -exec rm {} +
        rm -f /velociraptor/$FILE
    elif [[ "$FILE" == *".evtx" ]]; then
        docker run --rm --name zircolite --network test_zvelk -v test_zircolite:/case/ docker.io/wagga40/zircolite:latest --ruleset rules/rules_windows_sysmon_full.json --evtx /case/ --outfile /case/detected_events.json --remote 'https://es01:9200' --index 'zircolite-whatever' --eslogin "${ZIRCOLITE_USER}" --espass "${ZIRCOLITE_PASSWORD}" --forwardall --remove-events --nolog
    fi
done;

