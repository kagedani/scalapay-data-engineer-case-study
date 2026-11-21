-- Initialize the database with any required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create a schema for raw data if needed
CREATE SCHEMA IF NOT EXISTS raw_data;

-- Grant permissions
GRANT ALL PRIVILEGES ON DATABASE funnel_analysis TO postgres;
GRANT ALL PRIVILEGES ON SCHEMA public TO postgres;
GRANT ALL PRIVILEGES ON SCHEMA raw_data TO postgres;
