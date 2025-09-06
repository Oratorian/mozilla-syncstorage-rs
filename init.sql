-- Create databases if they don't exist
CREATE DATABASE IF NOT EXISTS syncstorage_rs;
CREATE DATABASE IF NOT EXISTS tokenserver_rs;

-- Grant privileges to the sync user
GRANT ALL PRIVILEGES ON syncstorage_rs.* TO 'syncuser'@'%';
GRANT ALL PRIVILEGES ON tokenserver_rs.* TO 'syncuser'@'%';

-- Flush privileges to ensure they take effect
FLUSH PRIVILEGES;
