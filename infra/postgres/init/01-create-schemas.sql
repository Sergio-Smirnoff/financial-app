-- Create one schema per microservice
-- This script runs automatically when the PostgreSQL container starts for the first time

CREATE SCHEMA IF NOT EXISTS users;
CREATE SCHEMA IF NOT EXISTS finances;
CREATE SCHEMA IF NOT EXISTS cards;
CREATE SCHEMA IF NOT EXISTS notifications;
CREATE SCHEMA IF NOT EXISTS upload;
CREATE SCHEMA IF NOT EXISTS investments;
