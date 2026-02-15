# README

Rails template application with SQLite, Kamal deployment, and Litestream backups.

## Ruby version

Ruby 3.4.1

## System dependencies

- SQLite 3
- Docker (for deployment)

## Configuration

Rails credentials are stored in `config/credentials.yml.enc`. Edit with:

```bash
bin/rails credentials:edit
```

## Database

This app uses SQLite for all databases:
- Primary: `storage/production.sqlite3`
- Queue: `storage/production_queue.sqlite3`
- Cache: `storage/production_cache.sqlite3`
- Cable: `storage/production_cable.sqlite3`

Setup:
```bash
bin/rails db:setup
```

## Development

```bash
bin/dev
```

## Testing

```bash
bin/rails test
```

## Deployment

This app uses Kamal 2 for deployment with Litestream for continuous SQLite backups to S3-compatible storage.

### First-time setup

1. Update `config/deploy.yml` with your server IP and domain
2. Update `config/litestream.yml` with your S3 bucket and endpoint
3. Add Litestream credentials to Rails credentials:
   ```bash
   bin/rails credentials:edit
   ```
   Add:
   ```yaml
   litestream:
     access_key_id: YOUR_S3_ACCESS_KEY
     secret_access_key: YOUR_S3_SECRET_KEY
   ```

4. Initialize the server:
   ```bash
   kamal setup
   ```

### Deploy

```bash
kamal deploy
```

### Useful commands

```bash
kamal console          # Rails console on server
kamal logs             # Tail application logs
kamal app logs         # Application logs
kamal accessory logs litestream  # Litestream backup logs
kamal shell            # SSH into the container
```

### Database Restoration from Litestream Backup

If you need to restore from a Litestream backup:

1. Install litestream locally (see https://litestream.io/install/)

2. Restore the database:
   ```bash
   litestream restore -o production.sqlite3 \
     s3://your-backups-bucket/myapp/production.sqlite3 \
     -endpoint https://nyc3.digitaloceanspaces.com
   ```
   
   Set environment variables for credentials:
   ```bash
   export LITESTREAM_ACCESS_KEY_ID=your_key
   export LITESTREAM_SECRET_ACCESS_KEY=your_secret
   ```

3. Copy to server:
   ```bash
   scp production.sqlite3 root@YOUR_SERVER_IP:/var/lib/docker/volumes/myapp_storage/_data/
   ```

4. Restart the app:
   ```bash
   kamal app restart
   ```

For other databases (queue, cache, cable), follow the same process with their respective paths.
