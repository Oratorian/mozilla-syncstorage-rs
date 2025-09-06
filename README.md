# Syncstorage-RS Docker Image

Mozilla Sync Storage Server (syncstorage-rs) with full tokenserver support and Python 3.13.

## ⚠️ Requirements

- **MySQL/MariaDB is REQUIRED** - This server needs a MySQL database to function
- Docker and Docker Compose
- 64-character secret keys (generate with `openssl rand -hex 32`)
- For multi-user setup: Tokenserver must be enabled

## Quick Start

### Step 1: Create Required MySQL Databases

```sql
CREATE DATABASE syncstorage_rs;
CREATE DATABASE tokenserver_rs;
CREATE USER 'syncuser'@'%' IDENTIFIED BY 'your-secure-password';
GRANT ALL PRIVILEGES ON syncstorage_rs.* TO 'syncuser'@'%';
GRANT ALL PRIVILEGES ON tokenserver_rs.* TO 'syncuser'@'%';
FLUSH PRIVILEGES;
```

### Step 2: Using Docker Compose (Recommended)

Create a `docker-compose.yml`:

```yaml
version: '3.8'

services:
  mysql:
    image: mysql:8.0
    container_name: syncstorage-mysql
    environment:
      MYSQL_ROOT_PASSWORD: your-root-password
      MYSQL_DATABASE: syncstorage_rs
      MYSQL_USER: syncuser
      MYSQL_PASSWORD: your-secure-password
    volumes:
      - mysql_data:/var/lib/mysql
      - ./init.sql:/docker-entrypoint-initdb.d/init.sql
    ports:
      - "3306:3306"
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost"]
      timeout: 20s
      retries: 10

  syncstorage:
    image: yourusername/syncstorage-rs:latest
    container_name: syncstorage-rs
    ports:
      - "8000:8000"
    environment:
      # REQUIRED - Server Configuration
      SYNC_HOST: "0.0.0.0"
      SYNC_PORT: "8000"
      
      # REQUIRED - Must be exactly 64 characters
      # Generate with: openssl rand -hex 32
      SYNC_MASTER_SECRET: "change-this-to-64-character-secret-key-absolutely-required-here!"
      
      # REQUIRED - Database Configuration
      SYNC_SYNCSTORAGE__DATABASE_URL: "mysql://syncuser:your-secure-password@mysql:3306/syncstorage_rs"
      SYNC_SYNCSTORAGE__ENABLED: "true"
      
      # REQUIRED for multi-user setup (optional for single user)
      SYNC_TOKENSERVER__DATABASE_URL: "mysql://syncuser:your-secure-password@mysql:3306/tokenserver_rs"
      SYNC_TOKENSERVER__ENABLED: "true"
      SYNC_TOKENSERVER__RUN_MIGRATIONS: "true"
      
      # REQUIRED for tokenserver - Must be exactly 64 characters
      SYNC_TOKENSERVER__FXA_METRICS_HASH_SECRET: "change-this-to-another-64-character-secret-key-absolutely-required!"
      
      # Firefox Accounts Configuration (use production or stage)
      # Production (for real Firefox accounts):
      SYNC_TOKENSERVER__FXA_EMAIL_DOMAIN: "api.accounts.firefox.com"
      SYNC_TOKENSERVER__FXA_OAUTH_SERVER_URL: "https://oauth.accounts.firefox.com/v1"
      SYNC_TOKENSERVER__FXA_BROWSERID_AUDIENCE: "https://token.services.mozilla.com"
      SYNC_TOKENSERVER__FXA_BROWSERID_ISSUER: "api.accounts.firefox.com"
      SYNC_TOKENSERVER__FXA_BROWSERID_SERVER_URL: "https://verifier.accounts.firefox.com/v2"
      
      # Logging
      SYNC_HUMAN_LOGS: "1"
      RUST_LOG: "info"
      
    depends_on:
      mysql:
        condition: service_healthy
    restart: unless-stopped

volumes:
  mysql_data:
```

Create `init.sql`:

```sql
-- This file is automatically run by MySQL container on first start
CREATE DATABASE IF NOT EXISTS syncstorage_rs;
CREATE DATABASE IF NOT EXISTS tokenserver_rs;
GRANT ALL PRIVILEGES ON syncstorage_rs.* TO 'syncuser'@'%';
GRANT ALL PRIVILEGES ON tokenserver_rs.* TO 'syncuser'@'%';
FLUSH PRIVILEGES;
```

Then run:
```bash
docker-compose up -d
```

### Step 3: Verify Installation

```bash
# Check if server is running
curl http://localhost:8000/__heartbeat__

# Should return:
# {"version":"0.20.1","database":"Ok","quota":{"enabled":false,"size":0},"status":"Ok"}
```

## Environment Variables (All Required Unless Noted)

### Core Configuration (REQUIRED)
| Variable | Description | Example |
|----------|-------------|---------|
| `SYNC_HOST` | Server bind address | `0.0.0.0` |
| `SYNC_MASTER_SECRET` | **EXACTLY 64 characters** | Generate with `openssl rand -hex 32` |
| `SYNC_SYNCSTORAGE__DATABASE_URL` | MySQL connection string | `mysql://user:pass@host:3306/syncstorage_rs` |
| `SYNC_SYNCSTORAGE__ENABLED` | Enable sync storage | `true` |

### Tokenserver Configuration (REQUIRED for multi-user)
| Variable | Description | Example |
|----------|-------------|---------|
| `SYNC_TOKENSERVER__ENABLED` | Enable tokenserver | `true` for multi-user, `false` for single |
| `SYNC_TOKENSERVER__DATABASE_URL` | Tokenserver database | `mysql://user:pass@host:3306/tokenserver_rs` |
| `SYNC_TOKENSERVER__RUN_MIGRATIONS` | Auto-run DB migrations | `true` |
| `SYNC_TOKENSERVER__FXA_METRICS_HASH_SECRET` | **EXACTLY 64 characters** | Generate with `openssl rand -hex 32` |

### Firefox Accounts Configuration (REQUIRED if tokenserver enabled)
Use either production OR stage servers, not both:

**For Production Firefox Accounts:**
- `SYNC_TOKENSERVER__FXA_EMAIL_DOMAIN`: `api.accounts.firefox.com`
- `SYNC_TOKENSERVER__FXA_OAUTH_SERVER_URL`: `https://oauth.accounts.firefox.com/v1`
- `SYNC_TOKENSERVER__FXA_BROWSERID_AUDIENCE`: `https://token.services.mozilla.com`
- `SYNC_TOKENSERVER__FXA_BROWSERID_ISSUER`: `api.accounts.firefox.com`
- `SYNC_TOKENSERVER__FXA_BROWSERID_SERVER_URL`: `https://verifier.accounts.firefox.com/v2`

**For Stage/Testing Accounts:**
- `SYNC_TOKENSERVER__FXA_EMAIL_DOMAIN`: `api-accounts.stage.mozaws.net`
- `SYNC_TOKENSERVER__FXA_OAUTH_SERVER_URL`: `https://oauth.stage.mozaws.net`
- `SYNC_TOKENSERVER__FXA_BROWSERID_AUDIENCE`: `https://token.stage.mozaws.net`
- `SYNC_TOKENSERVER__FXA_BROWSERID_ISSUER`: `api-accounts.stage.mozaws.net`
- `SYNC_TOKENSERVER__FXA_BROWSERID_SERVER_URL`: `https://verifier.stage.mozaws.net/v2`

### Optional Configuration
| Variable | Description | Default |
|----------|-------------|---------|
| `SYNC_PORT` | Server port | `8000` |
| `SYNC_HUMAN_LOGS` | Human-readable logs | `0` |
| `RUST_LOG` | Log level | `warn` |
| `SYNC_SYNCSTORAGE__ENABLE_QUOTA` | Enable storage quotas | `false` |
| `SYNC_SYNCSTORAGE__MAX_QUOTA_LIMIT` | Max quota in bytes | `200000000` |

## Configure Firefox Clients

### For Each User:

1. Open Firefox and navigate to `about:config`
2. Search for `identity.sync.tokenserver.uri`
3. Set it to your server:
   ```
   http://YOUR_SERVER_IP:8000/tokenserver/1.0/sync/1.5
   ```
   Replace `YOUR_SERVER_IP` with your actual server IP (e.g., `192.168.1.100`)

4. Sign in to Firefox Sync:
   - Use your regular Firefox account (if using production FxA servers)
   - Use a test account from https://accounts.stage.mozaws.net (if using stage servers)

## Single User vs Multi-User Setup

### Single User (Simpler)
- Set `SYNC_TOKENSERVER__ENABLED: "false"`
- No Firefox Account integration needed
- Less secure - anyone with server access can sync

### Multi-User (Recommended for 2+ users)
- Set `SYNC_TOKENSERVER__ENABLED: "true"`
- Requires all tokenserver environment variables
- Each user needs a Firefox Account
- Data is properly isolated between users

## Troubleshooting

### ⚠️ Database User Mismatch Issues
**Problem**: "Access denied for user" or similar MySQL errors  
**Solution**: Ensure these three places have the SAME username and password:
1. `MYSQL_USER` and `MYSQL_PASSWORD` in docker-compose.yml mysql service
2. The user in `init.sql` GRANT statements
3. The connection strings in `SYNC_SYNCSTORAGE__DATABASE_URL` and `SYNC_TOKENSERVER__DATABASE_URL`

Example of correct alignment:
```yaml
# In docker-compose.yml mysql service:
MYSQL_USER: syncuser
MYSQL_PASSWORD: mypass123

# In init.sql:
GRANT ALL PRIVILEGES ON syncstorage_rs.* TO 'syncuser'@'%';

# In syncstorage service:
SYNC_SYNCSTORAGE__DATABASE_URL: "mysql://syncuser:mypass123@mysql:3306/syncstorage_rs"
```

### Server won't start
- **Check MySQL is running**: `docker-compose logs mysql`
- **Verify databases exist**: Connect to MySQL and run `SHOW DATABASES;`
- **Check secret lengths**: Both secrets must be EXACTLY 64 characters

### "ModuleNotFoundError: No module named 'fxa'"
- The tokenserver requires PyFxA. This image includes it, but if building yourself, ensure PyFxA is installed

### Firefox won't sync
- Verify server is accessible: `curl http://YOUR_SERVER_IP:8000/__heartbeat__`
- Check Firefox console for errors (Ctrl+Shift+K)
- Ensure `identity.sync.tokenserver.uri` is set correctly
- Try signing out and back in to Firefox Sync

### Database connection errors
- Verify MySQL credentials
- Ensure MySQL is accessible from the container
- Check if user has proper permissions on both databases

## Security Considerations

1. **Generate secure secrets**: 
   ```bash
   # Generate two different 64-character secrets
   openssl rand -hex 32  # For SYNC_MASTER_SECRET
   openssl rand -hex 32  # For SYNC_TOKENSERVER__FXA_METRICS_HASH_SECRET
   ```

2. **Use HTTPS in production**: Put this behind a reverse proxy (nginx/Caddy) with SSL

3. **Firewall**: Only expose port 8000 to trusted networks

4. **Regular updates**: Pull the latest image periodically for security updates

## Supported Tags

- `latest` - Latest stable version (currently 0.20.1)
- `0.20.1` - Specific version

## Source

- Upstream: https://github.com/mozilla-services/syncstorage-rs
- This Docker image: https://github.com/Oratorian/mozilla-syncstorage-rs

## License

MPL-2.0 (same as syncstorage-rs)

## Support

For issues with:
- This Docker image: Open an issue at https://github.com/Oratorian/mozilla-syncstorage-rs
- Syncstorage-rs itself: https://github.com/mozilla-services/syncstorage-rs/issues
- Firefox Sync setup: https://support.mozilla.org/
