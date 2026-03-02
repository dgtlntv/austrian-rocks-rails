# Production Deployment with Kamal on Hetzner

This guide walks you through deploying the Boolder Rails application to production on Hetzner using Kamal.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Server Setup on Hetzner](#server-setup-on-hetzner)
3. [Local Setup](#local-setup)
4. [Container Registry Setup](#container-registry-setup)
5. [Rails Credentials Setup](#rails-credentials-setup)
6. [Secrets Configuration](#secrets-configuration)
7. [First Deployment](#first-deployment)
8. [Common Operations](#common-operations)
9. [Database Management](#database-management)
10. [Troubleshooting](#troubleshooting)
11. [Architecture Overview](#architecture-overview)

## Prerequisites

Before deploying, ensure you have:

- Ruby 3.3.5 installed locally
- Docker installed and running locally
- SSH key pair for server access
- Hetzner Cloud account or dedicated server
- Docker Hub account (or other container registry)
- Domain name with DNS configured
- 1Password account for secrets management (or alternative secret manager)

## Server Setup on Hetzner

### 1. Create a Server

#### Option A: Hetzner Cloud (Recommended for starting)

1. Log into [Hetzner Cloud Console](https://console.hetzner.cloud/)
2. Create a new project (e.g., "Boolder Production")
3. Click "Add Server"
4. Select:
   - Location: Choose closest to your users (e.g., Nuremberg, Germany)
   - Image: Ubuntu 24.04 LTS
   - Type: Minimum CPX21 (2 vCPU, 4GB RAM) for small apps
   - Recommended: CPX31 (4 vCPU, 8GB RAM) for production
5. Add your SSH key
6. Create the server and note the IP address

#### Option B: Hetzner Dedicated Server

1. Order a dedicated server from [Hetzner Robot](https://robot.hetzner.com/)
2. Install Ubuntu 24.04 LTS via the rescue system
3. Configure SSH key access

### 2. Configure Server

SSH into your new server:

```bash
ssh root@YOUR_SERVER_IP
```

#### Update the system

```bash
apt update && apt upgrade -y
```

#### Install Docker

```bash
# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh

# Start Docker service
systemctl enable docker
systemctl start docker

# Verify installation
docker --version
```

#### Configure Firewall

You can configure the firewall either through Hetzner Cloud Console or using UFW on the server.

**Option A: Hetzner Cloud Firewall (Recommended)**

1. In Hetzner Cloud Console, go to **Firewalls** in the left sidebar
2. Click **Create Firewall**
3. Add these **Inbound Rules**:
   - **SSH**: Protocol: TCP, Port: 22, Source: Any IPv4/IPv6
   - **HTTP**: Protocol: TCP, Port: 80, Source: Any IPv4/IPv6
   - **HTTPS**: Protocol: TCP, Port: 443, Source: Any IPv4/IPv6
   - **ICMP** (optional): Protocol: ICMP, Source: Any IPv4/IPv6
4. Apply the firewall to your server
5. Click **Create Firewall**

**Option B: UFW on Server**

```bash
# Install UFW if not present
apt install ufw -y

# Allow SSH
ufw allow 22/tcp

# Allow HTTP and HTTPS
ufw allow 80/tcp
ufw allow 443/tcp

# Enable firewall
ufw --force enable

# Check status
ufw status
```

**Important Notes:**
- Port 22 (SSH) - Required for deployments and server access
- Port 80 (HTTP) - Required for Let's Encrypt SSL validation
- Port 443 (HTTPS) - Your secure web traffic
- **Do NOT expose port 5432** (PostgreSQL) - Database is internal only

#### Create Deploy User (Optional but Recommended)

Instead of using root, create a deploy user:

```bash
# Create user
adduser deploy

# Add to docker group
usermod -aG docker deploy

# Set up SSH for deploy user
mkdir -p /home/deploy/.ssh
cp /root/.ssh/authorized_keys /home/deploy/.ssh/
chown -R deploy:deploy /home/deploy/.ssh
chmod 700 /home/deploy/.ssh
chmod 600 /home/deploy/.ssh/authorized_keys

# Grant sudo privileges
usermod -aG sudo deploy
```

If using a deploy user, update `config/deploy.yml`:

```yaml
ssh:
  user: deploy
```

### 3. Configure DNS

Point your domains to the server. You need to set up **three DNS records** (based on `config/brand.rb`):

1. Log into your domain registrar or DNS provider
2. Create A records for all three domains:

**Root domain:**
```
Type: A
Name: @
Value: 78.47.66.219  # Your server IP
TTL: 300
```

**WWW subdomain:**
```
Type: A
Name: www
Value: 78.47.66.219  # Same server IP
TTL: 300
```

**Assets subdomain:**
```
Type: A
Name: assets
Value: 78.47.66.219  # Same server IP
TTL: 300
```

> **Note:** The assets subdomain (`assets.austrian.rocks`) is used by Rails to serve static files (CSS, JS, images) for better browser caching and parallel downloads. It points to the same server as your main domain.

Wait for DNS propagation (can take a few minutes to 48 hours). Verify all domains with:

```bash
dig austrian.rocks
dig www.austrian.rocks
dig assets.austrian.rocks
```

## Local Setup

### 1. Install Kamal

Kamal is already in the Gemfile, so install dependencies:

```bash
bundle install
```

Verify Kamal is available:

```bash
bin/kamal version
```

### 2. Review Configuration

The main configuration is in `config/deploy.yml`. Key sections:

```yaml
service: boolder                    # Application name
image: nmondollot/boolder          # Docker Hub image name
servers:
  web:
    - YOUR_SERVER_IP               # Replace with your server IP
proxy:
  ssl: true                        # Enable Let's Encrypt SSL
  host: www.austrian.rocks,austrian.rocks,assets.austrian.rocks  # All domains from config/brand.rb
registry:
  username: nmondollot             # Your Docker Hub username
```

### 3. Update Configuration

Edit `config/deploy.yml`:

1. Update the server IP in the `servers` section
2. Update the `image` name if needed (should be `dockerhub-username/app-name`)
3. Update the `proxy.host` to include all three domains (www, root, and assets) from your `config/brand.rb`
4. Update the `registry.username` to your Docker Hub username

## Container Registry Setup

A container registry is where your Docker images are stored. Kamal builds your application into a Docker image locally, pushes it to the registry, and then your server pulls it from there during deployment.

### Why You Need a Registry

- **Distribution**: Servers pull images from the registry rather than building locally
- **Speed**: Only changed layers are downloaded
- **Versioning**: Each deployment creates a tagged image
- **Rollbacks**: Previous versions remain available

### Option 1: Docker Hub (Recommended for Starting)

Docker Hub is free for public images and easiest to set up.

#### Step 1: Create a Docker Hub Account

1. Go to [hub.docker.com](https://hub.docker.com/)
2. Click "Sign Up"
3. Create your account (remember your username!)

#### Step 2: Create an Access Token

**Important:** Never use your Docker Hub password directly. Always use access tokens.

1. Log into Docker Hub
2. Click your profile icon (top right) → **Account Settings**
3. Click **Security** in the left sidebar
4. Click **New Access Token**
5. Configure the token:
   - **Description:** `Kamal Deployment`
   - **Access permissions:** `Read, Write, Delete` (or `Read & Write`)
6. Click **Generate**
7. **COPY THE TOKEN IMMEDIATELY** - you won't see it again!

Save this token securely (you'll need it for `.kamal/secrets`).

#### Step 3: Log In Locally

Test your Docker Hub credentials:

```bash
docker login
# Username: your-dockerhub-username
# Password: [paste your access token]
```

You should see: `Login Succeeded`

#### Step 4: Update deploy.yml

Edit `config/deploy.yml`:

```yaml
# Name of the container image (format: username/image-name)
image: your-username/your-app-name

# Credentials for your image host
registry:
  # For Docker Hub, you can omit the server line (it's the default)
  # server: registry.hub.docker.com

  username: your-username

  # Password comes from .kamal/secrets
  password:
    - KAMAL_REGISTRY_PASSWORD
```

Example for a project called "malta-rocks":
```yaml
image: johndoe/malta-rocks

registry:
  username: johndoe
  password:
    - KAMAL_REGISTRY_PASSWORD
```

#### Step 5: Add Token to Secrets

The registry password should be in your `.kamal/secrets` file (see [Secrets Configuration](#secrets-configuration) section below).

For 1Password, add a field called `KAMAL_REGISTRY_PASSWORD` with your Docker Hub access token.

For environment variables:
```bash
export KAMAL_REGISTRY_PASSWORD="dckr_pat_YOUR_TOKEN_HERE"
```

#### Step 6: Test the Setup

Build and push a test image:

```bash
# Build the image
bin/kamal build

# Push to registry
bin/kamal build push
```

If successful, you should see your image at: `https://hub.docker.com/r/your-username/your-app-name`

### Option 2: GitHub Container Registry (ghcr.io)

GitHub Container Registry is free and integrates well with GitHub repositories.

#### Step 1: Create a Personal Access Token

1. Go to GitHub → Settings → Developer settings → Personal access tokens → Tokens (classic)
2. Click **Generate new token (classic)**
3. Configure:
   - **Note:** `Kamal Deploy`
   - **Expiration:** Choose duration (or no expiration)
   - **Scopes:** Check `write:packages`, `read:packages`, `delete:packages`
4. Click **Generate token**
5. Copy the token (starts with `ghp_`)

#### Step 2: Update deploy.yml

```yaml
image: ghcr.io/your-github-username/your-app-name

registry:
  server: ghcr.io
  username: your-github-username
  password:
    - KAMAL_REGISTRY_PASSWORD
```

#### Step 3: Add Token to Secrets

Add your GitHub personal access token as `KAMAL_REGISTRY_PASSWORD`.

#### Step 4: Test Login

```bash
echo $GITHUB_TOKEN | docker login ghcr.io -u your-github-username --password-stdin
```

### Option 3: GitLab Container Registry

GitLab provides free private registries.

```yaml
image: registry.gitlab.com/your-username/your-project

registry:
  server: registry.gitlab.com
  username: your-gitlab-username
  password:
    - KAMAL_REGISTRY_PASSWORD
```

Use a GitLab Personal Access Token (or Deploy Token) with `read_registry` and `write_registry` scopes.

### Option 4: Private Registries

For more control, use a private registry:

- **DigitalOcean Container Registry**
- **AWS Elastic Container Registry (ECR)**
- **Google Container Registry (GCR)**
- **Azure Container Registry (ACR)**
- **Self-hosted** (Harbor, GitLab Registry)

Example for DigitalOcean:

```yaml
image: registry.digitalocean.com/your-registry/your-app

registry:
  server: registry.digitalocean.com
  username: your-do-token-name
  password:
    - KAMAL_REGISTRY_PASSWORD
```

### Registry Comparison

| Registry | Free Tier | Private Images | Pros | Cons |
|----------|-----------|----------------|------|------|
| **Docker Hub** | 1 private repo | Limited | Easy setup, well-known | Rate limits on free tier |
| **GitHub (ghcr.io)** | Unlimited | Yes | Free private images, GitHub integration | Requires GitHub account |
| **GitLab** | Unlimited | Yes | Free private images, CI/CD integration | Requires GitLab account |
| **DigitalOcean** | $5/month | Yes | Integrated with DO infrastructure | Paid service |
| **AWS ECR** | 500MB free/month | Yes | Scalable, AWS integration | Complex pricing |

### Common Issues

#### "unauthorized: authentication required"

- Check your username is correct in `config/deploy.yml`
- Verify your access token in `.kamal/secrets`
- Make sure you're logged in: `docker login`

#### "denied: requested access to the resource is denied"

- Verify the image name matches your username: `username/image-name`
- Check your token has write permissions
- For private registries, verify you have access to that registry

#### Image name format

The image name must match this format:
- Docker Hub: `username/app-name` or `docker.io/username/app-name`
- GitHub: `ghcr.io/username/app-name`
- GitLab: `registry.gitlab.com/username/project-name`
- Custom: `registry.example.com/app-name`

### Best Practices

1. **Use access tokens**, not passwords
2. **Private images** for production apps (prevents exposure of code)
3. **Tag images** with git SHA (Kamal does this automatically)
4. **Clean up old images** periodically to save space
5. **Use .dockerignore** to keep images small

## Rails Credentials Setup

Rails uses encrypted credentials to store sensitive configuration. Since this is a forked repository, you need to generate your own credentials and master key.

### Understanding Rails Credentials

- **`config/credentials.yml.enc`** - Encrypted file containing secrets (safe to commit)
- **`config/master.key`** - Decryption key (NEVER commit, in .gitignore)
- The master key is used to decrypt credentials at runtime

### Current Situation

The repository has encrypted credentials (`config/credentials.yml.enc`) but you don't have the original `config/master.key`. This means you **cannot decrypt** the existing credentials and must generate new ones.

### What's Stored in Credentials

Based on the codebase, the credentials contain:

- **AWS S3 credentials** - For file storage (Active Storage)
- **Mapbox access token** - For displaying maps
- **Bugsnag API key** - Error tracking (optional)
- **Amazon SMTP** - Email sending (optional)
- **Admin passwords** - For admin panel access

### Step 1: Delete Old Encrypted Credentials

```bash
rm config/credentials.yml.enc
```

### Step 2: Generate New Credentials

Run this command to create new credentials and master key:

```bash
EDITOR=nano rails credentials:edit
```

This will:
1. Generate a new `config/master.key` (32-character hex string)
2. Create a new empty `config/credentials.yml.enc`
3. Open nano editor to edit the credentials

### Step 3: Add Your Credentials

In the editor, add this structure (replace with your actual values):

```yaml
# AWS S3 Storage (for Active Storage - file uploads)
aws:
  access_key_id: YOUR_AWS_ACCESS_KEY_ID
  secret_access_key: YOUR_AWS_SECRET_ACCESS_KEY

# Mapbox (for displaying maps)
mapbox:
  access_token: YOUR_MAPBOX_ACCESS_TOKEN

# Admin Panel Passwords
admin:
  nico_password: change_this_password
  emile_password: change_this_password
  gael_password: change_this_password

# Bugsnag (Error Tracking) - Optional
bugsnag:
  api_key: YOUR_BUGSNAG_API_KEY

# Amazon SMTP (Email Sending) - Optional
amazon_smtp:
  username: YOUR_SMTP_USERNAME
  password: YOUR_SMTP_PASSWORD
```

**Save and exit:** Press `Ctrl+X` → `Y` → `Enter`

### Step 4: Verify Master Key Was Created

```bash
cat config/master.key
```

You should see a 32-character hex string like: `a1b2c3d4e5f6...`

### Step 5: Back Up Your Master Key

**CRITICAL:** Save this master key to your password manager immediately!

You'll need it for:
- Production deployment (as `RAILS_MASTER_KEY` environment variable)
- Sharing with team members
- Recovery if you lose access

### Obtaining Required Credentials

Since you're forking the project, you need to obtain your own credentials for these services:

#### Required Services

**1. Mapbox (Required for Maps)**

Mapbox is used to display climbing area maps.

1. Sign up at [mapbox.com](https://www.mapbox.com/)
2. Go to your [account page](https://account.mapbox.com/)
3. Copy your default public token
4. Or create a new token with these scopes:
   - `styles:read`
   - `fonts:read`
   - `datasets:read`

Free tier: 50,000 map loads/month

**2. AWS S3 or Cloudflare R2 (Required for File Storage)**

Used for storing uploaded images (boulder photos, topos, etc.).

**Option A: Cloudflare R2 (Recommended - S3-compatible, cheaper)**

1. Log into [Cloudflare Dashboard](https://dash.cloudflare.com/)
2. Go to **R2 Object Storage**
3. Create a bucket (e.g., `boolder-production`)
4. Create API tokens:
   - Go to **Manage R2 API Tokens**
   - Create API token with "Object Read & Write" permissions
   - Save the Access Key ID and Secret Access Key

**Option B: AWS S3**

1. Log into [AWS Console](https://console.aws.amazon.com/)
2. Go to **IAM** → **Users** → Create user
3. Attach policy: `AmazonS3FullAccess` (or create custom policy)
4. Create access key
5. Save Access Key ID and Secret Access Key

Update `config/storage.yml` if needed for R2:

```yaml
amazon:
  service: S3
  endpoint: https://<ACCOUNT_ID>.r2.cloudflarestorage.com
  access_key_id: <%= Rails.application.credentials.dig(:aws, :access_key_id) %>
  secret_access_key: <%= Rails.application.credentials.dig(:aws, :secret_access_key) %>
  region: auto
  bucket: your-bucket-name
```

#### Optional Services

**3. Bugsnag (Optional - Error Tracking)**

Monitor production errors.

1. Sign up at [bugsnag.com](https://www.bugsnag.com/)
2. Create a new project
3. Copy the API key from the project settings
4. Free tier: 7,500 events/month

**4. Email Service (Optional - Only if sending emails)**

For password resets, notifications, etc.

Options:
- **Amazon SES** - Pay as you go
- **SendGrid** - 100 emails/day free
- **Postmark** - 100 emails/month free
- **Mailgun** - 5,000 emails/month free

If using an alternative to Amazon SMTP, update `config/environments/production.rb`.

### Minimal Setup for Development

If you just want to get started locally without all services:

```yaml
# Minimal credentials for local development
mapbox:
  access_token: YOUR_MAPBOX_TOKEN  # Required - get free one

admin:
  nico_password: admin123
  emile_password: admin123
  gael_password: admin123

# Dummy values for development
aws:
  access_key_id: development_key
  secret_access_key: development_secret
```

Then use `storage: :local` in development (which is likely already configured).

### For Production Deployment

Your production master key must be available as an environment variable.

The `RAILS_MASTER_KEY` will be configured in the [Secrets Configuration](#secrets-configuration) section below.

### Troubleshooting

#### "ActiveSupport::MessageEncryptor::InvalidMessage"

This means Rails can't decrypt credentials with the current master key.

- Verify `config/master.key` exists and is correct
- If you regenerated credentials, make sure you're using the new master key
- In production, verify `RAILS_MASTER_KEY` environment variable is set correctly

#### Can't edit credentials

If `rails credentials:edit` fails:

```bash
# Set your preferred editor
export EDITOR=nano

# Or use vi
export EDITOR=vi

# Or use VS Code
export EDITOR="code --wait"

# Then try again
rails credentials:edit
```

#### Viewing credentials without editing

```bash
# View current credentials (requires master.key)
rails credentials:show
```

### Security Best Practices

1. **Never commit `config/master.key`** - It's in `.gitignore`, keep it that way
2. **Use different credentials for development and production**
3. **Rotate credentials periodically** (at least annually)
4. **Store master key in password manager** with restricted access
5. **Use minimal permissions** for service credentials (principle of least privilege)
6. **Don't share credentials via chat/email** - use secure password managers

## Secrets Configuration

Kamal uses `.kamal/secrets` to manage sensitive data. This file should NEVER be committed to git.

### Option 1: Using 1Password (Current Setup)

If you're using 1Password:

```bash
# The .kamal/secrets file already has this configured
# Make sure you have 1Password CLI installed
brew install --cask 1password-cli

# Sign in to 1Password
op signin

# Kamal will automatically fetch secrets during deployment
```

Your secrets should be stored in 1Password at: `Boolder/Production` with these fields:
- `KAMAL_REGISTRY_PASSWORD` - Docker Hub access token
- `RAILS_MASTER_KEY` - Rails credentials master key
- `POSTGRES_PASSWORD` - Database password
- `S3_ACCESS_KEY_ID` - Cloudflare R2 access key
- `S3_SECRET_ACCESS_KEY` - Cloudflare R2 secret key

### Option 2: Using Environment Variables

Alternatively, edit `.kamal/secrets`:

```bash
# Option 1: Export from environment
export KAMAL_REGISTRY_PASSWORD="your-docker-hub-token"
export RAILS_MASTER_KEY="your-rails-master-key"
export POSTGRES_PASSWORD="your-db-password"
export S3_ACCESS_KEY_ID="your-s3-key"
export S3_SECRET_ACCESS_KEY="your-s3-secret"
```

Then update `.kamal/secrets`:

```bash
KAMAL_REGISTRY_PASSWORD=$KAMAL_REGISTRY_PASSWORD
RAILS_MASTER_KEY=$RAILS_MASTER_KEY
POSTGRES_PASSWORD=$POSTGRES_PASSWORD
S3_ACCESS_KEY_ID=$S3_ACCESS_KEY_ID
S3_SECRET_ACCESS_KEY=$S3_SECRET_ACCESS_KEY
```

### Option 3: Using a .env File (Not Recommended for Production)

You can also use `.kamal/secrets.env`:

```bash
KAMAL_REGISTRY_PASSWORD=your-docker-hub-token
RAILS_MASTER_KEY=your-rails-master-key
POSTGRES_PASSWORD=your-db-password
S3_ACCESS_KEY_ID=your-s3-key
S3_SECRET_ACCESS_KEY=your-s3-secret
```

Then source it in `.kamal/secrets`:

```bash
source .kamal/secrets.env 2>/dev/null || true
```

### Getting Your Secrets

#### Docker Hub Token

1. Go to [Docker Hub](https://hub.docker.com/)
2. Click your profile > Account Settings > Security
3. Click "New Access Token"
4. Give it a name (e.g., "Kamal Deploy")
5. Copy the token

#### Rails Master Key

Found in `config/master.key` (this file is gitignored):

```bash
cat config/master.key
```

If it doesn't exist, generate credentials:

```bash
EDITOR=nano rails credentials:edit
```

#### Database Password

Generate a strong password:

```bash
openssl rand -hex 32
```

#### S3/R2 Credentials

From your Cloudflare dashboard or AWS console, create an access key pair for the backup bucket.

## First Deployment

### 1. Test SSH Connection

Verify you can connect to your server:

```bash
ssh root@YOUR_SERVER_IP
# or if using deploy user:
ssh deploy@YOUR_SERVER_IP
```

### 2. Bootstrap the Server

This sets up Docker and creates necessary directories:

```bash
bin/kamal server bootstrap
```

This command:
- Installs required packages
- Sets up Docker if not already installed
- Creates the Kamal directory structure

### 3. Setup Accessories (Database)

Before deploying the app, set up the database:

```bash
bin/kamal accessory boot db
```

This will:
- Pull the PostGIS Docker image
- Start the PostgreSQL container
- Initialize the database
- Mount persistent storage in `data/` directory

Check database status:

```bash
bin/kamal accessory logs db
```

### 4. Build and Push the Docker Image

Build your application image locally and push to Docker Hub:

```bash
bin/kamal build push
```

This will:
- Build the Docker image using your `Dockerfile`
- Tag it with the git commit SHA
- Push it to Docker Hub

### 5. Deploy the Application

Deploy your application:

```bash
bin/kamal deploy
```

This command will:
1. Pull the image to the server
2. Stop old containers (if any)
3. Start new containers
4. Set up the Traefik proxy with SSL
5. Run database migrations
6. Perform health checks

The first deployment takes longer because:
- Let's Encrypt needs to provision SSL certificates
- Database needs to be migrated
- Assets need to be compiled

### 6. Verify Deployment

Check that everything is running:

```bash
# Check app status
bin/kamal app details

# View application logs
bin/kamal app logs

# Check proxy status
bin/kamal proxy details

# Check all containers
bin/kamal server exec 'docker ps'
```

Visit your domain: `https://www.austrian.rocks`

You should see your application with a valid SSL certificate!

### 7. Setup Database Backups

Once the app is running, set up automated backups:

```bash
bin/kamal accessory boot db_backup
```

This will:
- Start a container that backs up PostgreSQL daily
- Upload backups to Cloudflare R2
- Retain backups for 7 days

Verify backups are working:

```bash
bin/kamal accessory logs db_backup
```

## Common Operations

### Deploy Updates

After pushing code changes:

```bash
# Quick deploy (recommended)
bin/kamal deploy

# Or build, push, and deploy separately
bin/kamal build push
bin/kamal deploy
```

### View Logs

```bash
# Follow application logs
bin/kamal logs

# Or use the alias
bin/kamal logs

# View specific service logs
bin/kamal app logs -f
bin/kamal proxy logs -f
bin/kamal accessory logs db -f
```

### Access Rails Console

```bash
bin/kamal console

# Or explicitly
bin/kamal app exec --interactive --reuse "bin/rails console"
```

### Access Database Console

```bash
bin/kamal dbc

# Or explicitly
bin/kamal app exec --interactive --reuse "bin/rails dbconsole"
```

### SSH into Container

```bash
bin/kamal shell

# Or explicitly
bin/kamal app exec --interactive --reuse "bash"
```

### SSH into Server

```bash
bin/kamal server exec 'bash'

# Or directly
ssh root@YOUR_SERVER_IP
```

### Restart Application

```bash
# Restart web containers
bin/kamal app restart

# Restart specific accessory
bin/kamal accessory restart db
```

### Stop Everything

```bash
# Stop app
bin/kamal app stop

# Stop accessories
bin/kamal accessory stop db
bin/kamal accessory stop db_backup

# Stop proxy
bin/kamal proxy stop
```

### Remove Everything (Clean Slate)

```bash
# Remove all containers and images
bin/kamal app remove
bin/kamal accessory remove db
bin/kamal accessory remove db_backup
bin/kamal proxy remove

# Clean up on server
bin/kamal server exec 'docker system prune -af'
```

### Roll Back Deployment

If something goes wrong:

```bash
# Kamal keeps the previous container running until health checks pass
# If deployment fails, the old version stays active

# To manually roll back to a specific version:
bin/kamal app rollback [SHA]
```

### View Container Details

```bash
# App containers
bin/kamal app details

# Proxy details
bin/kamal proxy details

# Accessory details
bin/kamal accessory details db
```

## Database Management

### Initial Database Setup

The `db/production.sql` file is loaded when the database is first created (via the `accessories.db.files` config).

To create this file from your development database:

```bash
# Dump your development database
docker compose exec db pg_dump -U boolder dump-prod > db/production.sql
```

### Run Migrations

Migrations run automatically during deploy. To run manually:

```bash
bin/kamal app exec 'bin/rails db:migrate'
```

### Backup Database Manually

```bash
# Create a backup
bin/kamal server exec 'docker exec boolder-db pg_dump -U boolder boolder-production > /root/backup.sql'

# Download the backup
scp root@YOUR_SERVER_IP:/root/backup.sql ./backups/production-$(date +%Y%m%d).sql
```

### Restore Database

```bash
# Upload SQL file to server
scp backup.sql root@YOUR_SERVER_IP:/tmp/restore.sql

# Restore (careful - this will replace data!)
bin/kamal accessory exec db 'psql -U boolder boolder-production < /tmp/restore.sql'
```

### Access Database Directly

```bash
# From your local machine (if port is exposed)
psql "postgresql://boolder:PASSWORD@YOUR_SERVER_IP:3306/boolder-production"

# From the server
bin/kamal accessory exec db 'psql -U boolder boolder-production'
```

### Monitor Database

```bash
# Check database logs
bin/kamal accessory logs db

# Check database size
bin/kamal accessory exec db 'psql -U boolder -d boolder-production -c "SELECT pg_size_pretty(pg_database_size(current_database()));"'

# List all tables
bin/kamal accessory exec db 'psql -U boolder -d boolder-production -c "\dt"'
```

## Troubleshooting

### Deployment Fails with "Image not found"

Make sure you pushed the image:

```bash
bin/kamal build push
```

Check your Docker Hub credentials:

```bash
docker login
```

### SSL Certificate Issues

Let's Encrypt requires:
- All domains (root, www, assets) must point to your server IP
- Ports 80 and 443 must be open
- Server must be publicly accessible

Check DNS for all domains:

```bash
dig austrian.rocks
dig www.austrian.rocks
dig assets.austrian.rocks
```

Check if Traefik is running:

```bash
bin/kamal proxy details
```

Force SSL certificate renewal:

```bash
bin/kamal proxy reboot
```

### Database Connection Errors

Check if database is running:

```bash
bin/kamal accessory details db
```

Check database logs:

```bash
bin/kamal accessory logs db
```

Verify database container is on the same Docker network:

```bash
bin/kamal server exec 'docker network inspect kamal'
```

### Application Won't Start

Check logs:

```bash
bin/kamal app logs
```

Common issues:
- Missing environment variables (check `.kamal/secrets`)
- Database not ready (wait a bit, check `bin/kamal accessory logs db`)
- Asset precompilation failed (check build logs)

### Out of Disk Space

Check disk usage:

```bash
bin/kamal server exec 'df -h'
```

Clean up old Docker images:

```bash
bin/kamal server exec 'docker system prune -af'
```

### Container Health Check Failing

Kamal checks if your app responds on port 80. If health checks fail:

1. Check if app is listening on port 80 (Thruster handles this)
2. Check app logs for startup errors
3. Increase health check timeout in `config/deploy.yml`

### 502 Bad Gateway

Usually means the app container isn't running or isn't responding:

```bash
# Check app status
bin/kamal app details

# Check app logs
bin/kamal app logs

# Check if app is responding
bin/kamal server exec 'curl localhost:PORT'
```

### Can't SSH into Server

Check your SSH key:

```bash
ssh -v root@YOUR_SERVER_IP
```

Make sure your public key is in `/root/.ssh/authorized_keys` on the server.

### Secrets Not Loading

Test secrets loading:

```bash
# Check if secrets file is executable
chmod +x .kamal/secrets

# Test secrets
.kamal/secrets
```

For 1Password, ensure you're logged in:

```bash
op signin
eval $(op signin)
```

### Slow Deployments

Deployments can be slow due to:
- Building images locally (solution: use remote builder)
- Slow internet (solution: build on CI/CD)
- Pulling large images (solution: optimize Dockerfile)

## Architecture Overview

### Components

The production setup consists of:

1. **Application Container(s)** (`boolder-web-*`)
   - Runs your Rails application
   - Uses Puma as the app server
   - Thruster handles HTTP/2 and asset serving
   - Exposes port 80 internally

2. **Traefik Proxy** (`kamal-proxy`)
   - Reverse proxy in front of your app
   - Handles SSL termination (Let's Encrypt)
   - Routes traffic to app containers
   - Enables zero-downtime deploys

3. **PostgreSQL Database** (`boolder-db`)
   - PostGIS-enabled PostgreSQL 16
   - Persistent data in `data/` directory
   - Not exposed to internet (internal Docker network)

4. **Database Backup** (`boolder-db_backup`)
   - Runs daily at midnight
   - Uploads to Cloudflare R2
   - Retains 7 days of backups

### Networking

```
Internet
    ↓
Traefik Proxy (:443/:80)
    ↓
Application Container(s) (:80)
    ↓
PostgreSQL (:5432, internal)
```

- Only ports 80, 443, and 22 (SSH) are exposed to the internet
- Application and database communicate via internal Docker network (`kamal` network)
- Database is only accessible from app containers

### Data Persistence

- Database: `/root/data/` on host → `/var/lib/postgresql/data` in container
- Application storage: Currently ephemeral (consider adding a volume for `storage/`)

### Deployment Flow

1. Build Docker image locally
2. Push to Docker Hub
3. SSH to server
4. Pull new image
5. Start new container
6. Run health checks
7. Switch proxy to new container
8. Stop old container after successful health checks

This provides **zero-downtime deployments** - the old version keeps running until the new version is healthy.

### Environment Configuration

Environment variables are set in three places:

1. **`config/deploy.yml`** - `env.clear` for non-sensitive values
2. **`.kamal/secrets`** - `env.secret` for sensitive values
3. **Rails credentials** - Encrypted in `config/credentials.yml.enc`

### Solid Queue

Background jobs run inside the web server (Solid Queue in Puma):

```yaml
env:
  clear:
    SOLID_QUEUE_IN_PUMA: true
```

For high-traffic apps, consider dedicating separate servers for job processing:

```yaml
servers:
  web:
    - 78.47.66.219
  job:
    hosts:
      - 78.47.66.220
    cmd: bin/jobs
```

## Monitoring and Maintenance

### Set Up Monitoring

Consider setting up:

1. **Uptime monitoring**: Use UptimeRobot, Pingdom, or similar
2. **Error tracking**: Bugsnag is already configured (see `initializers/bugsnag.rb`)
3. **Log aggregation**: Consider Papertrail, Logtail, or similar
4. **Server monitoring**: Hetzner provides basic monitoring, consider Netdata or similar

### Regular Maintenance Tasks

Weekly:
- Review application logs for errors
- Check disk space usage
- Verify backups are running

Monthly:
- Update server packages: `bin/kamal server exec 'apt update && apt upgrade -y'`
- Review and remove old Docker images: `bin/kamal server exec 'docker system prune -f'`
- Test database restore process

Quarterly:
- Review SSL certificate expiration (Let's Encrypt renews automatically)
- Review and update Ruby/Rails versions
- Security audit of dependencies

### Scaling Considerations

When you need to scale:

1. **Vertical scaling**: Upgrade Hetzner server to larger size
2. **Horizontal scaling**: Add more servers to `config/deploy.yml`
3. **Database scaling**: Move database to managed PostgreSQL (Hetzner Cloud SQL)
4. **Asset serving**: Use a CDN (Cloudflare is already in front)
5. **Job processing**: Separate job workers to dedicated servers

## Security Best Practices

1. **Keep secrets secret**: Never commit `.kamal/secrets`, `config/master.key`, or `.env` files
2. **Use SSH keys**: Disable password authentication on server
3. **Firewall**: Only expose necessary ports (22, 80, 443)
4. **Updates**: Regularly update server packages and Docker images
5. **Backups**: Verify backups can be restored
6. **SSL**: Let's Encrypt handles this automatically
7. **Database**: Not exposed to internet, only accessible via app
8. **Deploy user**: Use a dedicated deploy user instead of root (optional)

## Cost Estimation (Hetzner Cloud)

Approximate monthly costs:

- CPX21 (2 vCPU, 4GB RAM): ~€7/month
- CPX31 (4 vCPU, 8GB RAM): ~€14/month - Recommended
- CPX41 (8 vCPU, 16GB RAM): ~€28/month

Plus:
- Cloudflare R2 storage: ~€0.015/GB
- Domain: ~€10/year
- Backup storage: ~€1/month

Total: **~€15-30/month** for a production Rails application.

## Additional Resources

- [Kamal Documentation](https://kamal-deploy.org/)
- [Kamal GitHub](https://github.com/basecamp/kamal)
- [Rails Deployment Guide](https://guides.rubyonrails.org/deploying.html)
- [Hetzner Cloud Docs](https://docs.hetzner.com/cloud/)
- [Docker Documentation](https://docs.docker.com/)
- [Let's Encrypt Documentation](https://letsencrypt.org/docs/)

## Getting Help

If you run into issues:

1. Check Kamal logs: `bin/kamal app logs`
2. Check server logs: `bin/kamal server exec 'journalctl -u docker -f'`
3. Kamal community: [GitHub Discussions](https://github.com/basecamp/kamal/discussions)
4. Rails community: [Rails Forum](https://discuss.rubyonrails.org/)

---

Last updated: 2025-11-14
