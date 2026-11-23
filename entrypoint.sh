#!/bin/bash
set -e

echo "Waiting for PostgreSQL to be ready..."
attempts=0
until dbt debug > /dev/null 2>&1; do
  attempts=$((attempts + 1))
  if [ "$attempts" -ge 60 ]; then
    # Not always the database: dbt debug also fails on config or file permissions.
    echo "dbt debug still failing after 2 minutes:"
    dbt debug || true
    exit 1
  fi
  echo "PostgreSQL is unavailable - sleeping"
  sleep 2
done

echo "PostgreSQL is ready!"

# Run DBT setup if not already done
if [ ! -d "dbt_packages" ] || [ ! "$(ls -A dbt_packages 2>/dev/null)" ]; then
  echo "Installing DBT dependencies..."
  dbt deps
fi

# Always run seed to ensure data is fresh (seeds are idempotent)
echo "Loading seed data..."
dbt seed

echo "DBT environment is ready!"
echo "From the host: make build, make insights, make docs (see make help)."
echo ""

# Execute the command passed to the container (or bash if none)
exec "$@"
