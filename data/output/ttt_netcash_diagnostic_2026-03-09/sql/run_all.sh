#!/bin/bash
# Run all BQ queries and save results
export CLOUDSDK_PYTHON="/c/Users/loc.tu/AppData/Local/Programs/Python/Python313/python.exe"
PROJECT="momovn-bu-fi-shared"
SQL_DIR="$(dirname "$0")"
OUT_DIR="$SQL_DIR/../results"
mkdir -p "$OUT_DIR"

MAX_BYTES=850000000000

submit_query() {
  local name="$1"
  local sql_file="$SQL_DIR/${name}.sql"
  echo "=== Submitting $name ==="

  # Dry run first
  DR=$(bq query --dry_run --project_id=$PROJECT --use_legacy_sql=false < "$sql_file" 2>&1)
  echo "  Dry run: $DR"

  # Submit async
  JOB_OUTPUT=$(bq query --nosync --project_id=$PROJECT --use_legacy_sql=false --maximum_bytes_billed=$MAX_BYTES --format=csv < "$sql_file" 2>&1)
  JOB_ID=$(echo "$JOB_OUTPUT" | grep -oE 'bqjob_[a-zA-Z0-9_]+' | head -1)

  if [ -z "$JOB_ID" ]; then
    echo "  ERROR: Could not extract job ID from: $JOB_OUTPUT"
    return 1
  fi

  echo "  Job: $JOB_ID"

  # Wait for job
  bq wait "$PROJECT:US.$JOB_ID" 300 2>&1

  # Get destination table
  DEST=$(bq show --format=json -j "$PROJECT:US.$JOB_ID" 2>/dev/null | /c/Users/loc.tu/AppData/Local/Programs/Python/Python313/python.exe -c "
import sys, json
j = json.load(sys.stdin)
c = j['configuration']['query']['destinationTable']
print(f\"{c['projectId']}:{c['datasetId']}.{c['tableId']}\")
" 2>/dev/null)

  if [ -z "$DEST" ]; then
    echo "  ERROR: Could not get destination table"
    return 1
  fi

  echo "  Dest: $DEST"

  # Get results
  bq head -n 500 "$DEST" > "$OUT_DIR/${name}.csv" 2>&1
  echo "  Saved to $OUT_DIR/${name}.csv"
  echo ""
}

# Submit all queries
for sql_file in "$SQL_DIR"/q*.sql; do
  name=$(basename "$sql_file" .sql)
  submit_query "$name"
done

echo "=== ALL DONE ==="
