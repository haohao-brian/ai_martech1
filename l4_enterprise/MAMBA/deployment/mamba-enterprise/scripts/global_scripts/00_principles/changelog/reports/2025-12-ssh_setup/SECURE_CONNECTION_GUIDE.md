# 🔒 MAMBA Secure Connection Guide

## Executive Summary

All hardcoded credentials have been removed from the codebase. You now need to configure environment variables to connect to MAMBA databases.

## Quick Start

### 1. Create Your .env File
```bash
# Copy the template
cp .env.template .env

# Edit with your credentials
nano .env  # or use your preferred editor
```

### 2. Set Secure Permissions
```bash
# Ensure only you can read the file
chmod 600 .env
```

### 3. Fill in Required Variables

Edit `.env` and add your actual credentials:

```env
# SSH Tunnel Settings
EBY_SSH_HOST=220.128.138.146
EBY_SSH_USER=your_actual_username
EBY_SSH_PASSWORD=your_actual_password

# SQL Server Settings
EBY_SQL_HOST=125.227.84.85
EBY_SQL_PORT=1433
EBY_SQL_DATABASE=MAMBATEK
EBY_SQL_USER=your_sql_username
EBY_SQL_PASSWORD=your_sql_password
```

## Using fn_ensure_mamba_tunnel.R

The secure connection function is located at:
`scripts/global_scripts/02_db_utils/fn_ensure_mamba_tunnel.R`

### Basic Usage

```r
# Load the function
source("scripts/global_scripts/02_db_utils/fn_ensure_mamba_tunnel.R")

# Load environment variables (if using .env file)
library(dotenv)
dotenv::load_dot_env()

# Establish tunnel and connect
conn <- fn_connect_mamba_sql(auto_tunnel = TRUE)

# Your database operations here...

# Disconnect when done
fn_disconnect_mamba_sql(conn, close_tunnel = FALSE)
```

### Manual Tunnel Setup (if preferred)

```bash
# Load environment variables
source .env

# Create SSH tunnel manually
ssh -L 1433:$EBY_SQL_HOST:1433 $EBY_SSH_USER@$EBY_SSH_HOST
```

## Security Best Practices

### ✅ DO:
- Use environment variables for all credentials
- Keep .env in .gitignore
- Use SSH keys instead of passwords when possible
- Rotate credentials regularly
- Use different credentials for dev/staging/production

### ❌ DON'T:
- Hardcode passwords in source code
- Commit .env files to git
- Share credentials in documentation
- Use the same password everywhere
- Leave default passwords unchanged

## SSH Key Authentication (More Secure)

Instead of password authentication, set up SSH keys:

```bash
# Generate SSH key
ssh-keygen -t ed25519 -C "mamba-etl"

# Copy to server
ssh-copy-id $EBY_SSH_USER@$EBY_SSH_HOST

# Remove EBY_SSH_PASSWORD from .env after key setup
```

## Troubleshooting

### Error: Missing environment variables
```
❌ Missing required environment variables: EBY_SSH_PASSWORD
```
**Solution**: Ensure all variables are set in .env

### Error: SSH tunnel failed
```
❌ Failed to establish SSH tunnel
```
**Solution**: Check SSH credentials and network connectivity

### Error: sshpass not installed
```
⚠️ sshpass not installed
```
**Solution**: Install with `brew install hudochenkov/sshpass/sshpass`

## Files Changed for Security

1. **Deleted**: `setup_mamba_tunnel.sh` (contained hardcoded password)
2. **Updated**: `MAMBA_ETL_PIPELINE_README.md` (removed credentials)
3. **Secured**: `fn_ensure_mamba_tunnel.R` (uses environment variables)
4. **Created**: `.env.template` (secure configuration template)

## Compliance with Security Principles

This implementation follows:
- **MP110**: Security Credentials Management (zero hardcoded passwords)
- **MP111**: Data Privacy Protection
- **MP113**: Secure Communication Protocols
- **MP118**: Secure Development Practices

## Next Steps

1. **Immediate**: Configure your .env file with actual credentials
2. **Soon**: Consider switching to SSH key authentication
3. **Future**: Implement centralized secret management (e.g., HashiCorp Vault)

---

**Security Notice**: All passwords have been removed from source code. Any passwords you may have seen in previous versions should be rotated immediately.