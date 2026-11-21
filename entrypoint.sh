#!/bin/bash
set -e

echo "Waiting for PostgreSQL to be ready..."
until dbt debug > /dev/null 2>&1; do
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
echo "You can now run DBT commands like:"
echo "  dbt run    - Run your models"
echo "  dbt test   - Run tests"
echo "  dbt docs generate && dbt docs serve --host 0.0.0.0 - Generate and serve docs"
echo ""

# Execute the command passed to the container (or bash if none)
exec "$@"
