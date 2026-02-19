# Service Connections & Integration Guide

This guide explains how to connect to all services deployed in your n8n stack, including databases, vector stores, and API integrations.

## Core Databases

### PostgreSQL
**Purpose**: Primary database for n8n and Langfuse data

**n8n Credentials Configuration**:
- **Host**: `postgres` (internal) or server IP/domain (external)
- **Port**: `5432`
- **Database**: `postgres` (default) or `langfuse` for Langfuse
- **User**: Value from `POSTGRES_USER` (default: `postgres`)
- **Password**: Value from `POSTGRES_PASSWORD` in `.env`
- **SSL**: Disable for internal, enable for external

**Connection String**:
```
postgresql://postgres:[password]@postgres:5432/postgres
```

### Redis (Valkey)
**Purpose**: Queue management for n8n workers and caching

**n8n Credentials Configuration**:
- **Host**: `redis` (internal) or server IP/domain (external)
- **Port**: `6379`
- **Password**: Not set by default
- **Database**: `0` (default)

**Connection String**:
```
redis://redis:6379
```

## Vector Database

### Qdrant
**Purpose**: Vector storage for AI/ML embeddings and similarity search

**n8n Credentials Configuration**:
- **Host**: `qdrant` (internal) or `https://qdrant.yourdomain.com` (external)
- **Port**: `6333`
- **API Key**: Value from `QDRANT_API_KEY` in `.env`
- **Protocol**: `http` (internal) or `https` (external via Caddy)

**API Endpoint**:
```
# Internal
http://qdrant:6333

# External (with Caddy)
https://qdrant.yourdomain.com
```

**n8n Integration**:
```javascript
// In n8n Code node
const qdrantUrl = 'http://qdrant:6333';
const apiKey = $env.QDRANT_API_KEY;

const response = await $http.request({
  method: 'GET',
  url: `${qdrantUrl}/collections`,
  headers: {
    'api-key': apiKey
  }
});
```

## Analytics & Observability

### Langfuse
**Purpose**: LLM observability, tracing, and analytics

**Web UI Access**:
- **URL**: `https://langfuse.yourdomain.com` (external via Caddy)
- **Email**: Value from `LANGFUSE_INIT_USER_EMAIL`
- **Password**: Value from `LANGFUSE_INIT_USER_PASSWORD`

**API Integration**:
- **Public Key**: Value from `LANGFUSE_INIT_PROJECT_PUBLIC_KEY`
- **Secret Key**: Value from `LANGFUSE_INIT_PROJECT_SECRET_KEY`
- **API Endpoint**: `http://langfuse-web:3000` (internal)

**n8n Integration**:
```javascript
// In n8n Code node for Langfuse tracing
const langfuseHost = 'http://langfuse-web:3000';
const publicKey = $env.LANGFUSE_INIT_PROJECT_PUBLIC_KEY;
const secretKey = $env.LANGFUSE_INIT_PROJECT_SECRET_KEY;

// Initialize Langfuse client
const trace = {
  baseURL: langfuseHost,
  publicKey: publicKey,
  secretKey: secretKey
};
```

### ClickHouse
**Purpose**: Analytics database for Langfuse events

**Connection Details** (for advanced users):
- **Host**: `clickhouse` (internal only)
- **HTTP Port**: `8123`
- **Native Port**: `9000`
- **Database**: `default`
- **User**: `clickhouse`
- **Password**: Value from `CLICKHOUSE_PASSWORD` in `.env`

**Connection String**:
```
# HTTP Interface
http://clickhouse:clickhouse_password@clickhouse:8123/default

# Native Interface
clickhouse://clickhouse:clickhouse_password@clickhouse:9000/default
```

## Storage Services

### MinIO (S3-Compatible)
**Purpose**: Object storage for Langfuse exports and media

**S3 Configuration**:
- **Endpoint**: `http://minio:9000` (internal) or `http://minio:9001` (console)
- **Access Key**: `minio`
- **Secret Key**: Value from `MINIO_ROOT_PASSWORD` in `.env`
- **Bucket**: `langfuse` (auto-created)
- **Region**: `auto`
- **Path Style**: `true` (force path-style addressing)

**n8n S3 Credentials**:
```javascript
{
  "endpoint": "http://minio:9000",
  "accessKeyId": "minio",
  "secretAccessKey": "$env.MINIO_ROOT_PASSWORD",
  "region": "us-east-1",  // MinIO ignores this but n8n requires it
  "forcePathStyle": true
}
```

## AI/ML Services

### Crawl4AI
**Purpose**: Web scraping with AI extraction capabilities

**API Endpoint**:
- **Internal URL**: `http://crawl4ai:8000`
- **Health Check**: `http://crawl4ai:8000/health`

**n8n HTTP Request Configuration**:
```javascript
// Basic crawl request
const crawlRequest = {
  method: 'POST',
  url: 'http://crawl4ai:8000/crawl',
  headers: {
    'Content-Type': 'application/json'
  },
  body: {
    url: 'https://example.com',
    extract_rules: {
      // Your extraction rules
    }
  }
};
```

**Advanced Features**:
- JavaScript execution support
- Custom extraction rules
- Screenshot capture
- PDF generation
- Session management

## Database Management Tools

### pgAdmin
**Purpose**: Web-based PostgreSQL administration and development platform

**Web UI Access**:
- **URL**: `https://pgadmin.openorbit.pro` (external via Caddy)
- **Email**: Value from `PGADMIN_DEFAULT_EMAIL` (default: `admin@openorbit.pro`)
- **Password**: Value from `PGADMIN_DEFAULT_PASSWORD` in `.env`

**Container Configuration**:
- **Container Name**: `pgadmin`
- **Internal Port**: `80`
- **Image**: `dpage/pgadmin4:latest`
- **Data Volume**: `./pgadmin_data:/var/lib/pgadmin`

**Adding Database Connections in pgAdmin**:
1. Login to pgAdmin web interface
2. Right-click "Servers" → "Register" → "Server"
3. General tab:
   - Name: `n8n-postgres` (or any name you prefer)
4. Connection tab:
   - Host: `postgres` (when pgAdmin is in Docker network)
   - Port: `5432`
   - Database: `postgres` (or `n8n_production`)
   - Username: Value from `POSTGRES_USER`
   - Password: Value from `POSTGRES_PASSWORD`
   - Save password: Yes (optional)

**Security Notes**:
- pgAdmin stores server passwords encrypted
- Master password is disabled for container deployment
- Access is secured via HTTPS through Caddy
- Consider using IP whitelisting for production

## Network Architecture

### Docker Networks
- **Default Network**: `10.25.0.0/24` - Internal service communication
- **n8n-network**: External bridge network for n8n integrations

### Service Discovery
Docker's internal DNS resolves service names automatically:
- `postgres` → PostgreSQL container
- `redis` → Redis container
- `qdrant` → Qdrant vector database
- `langfuse-web` → Langfuse web interface
- `langfuse-worker` → Langfuse background worker
- `clickhouse` → ClickHouse analytics database
- `minio` → MinIO object storage
- `crawl4ai` → Crawl4AI service

## Security Considerations

### Internal Communications
- Services communicate over Docker's internal network
- No encryption needed for internal traffic
- Use service names as hostnames

### External Access
1. **Via Caddy (Recommended)**:
   - Automatic HTTPS with Let's Encrypt
   - Configure domains in `.env`
   - Services available at: `https://[service].yourdomain.com`

2. **Direct Port Exposure** (Development only):
   ```yaml
   # Add to service in docker-compose.yaml
   ports:
     - "external_port:internal_port"
   ```

3. **SSH Tunneling** (Secure remote access):
   ```bash
   # Generic format
   ssh -L local_port:container_name:container_port user@server

   # Examples
   ssh -L 6333:localhost:6333 user@server  # Qdrant
   ssh -L 9000:localhost:9000 user@server  # MinIO
   ```

## n8n Workflow Examples

### Example 1: Store Embeddings in Qdrant
```javascript
// In n8n Code node
const embedding = [0.1, 0.2, 0.3, ...]; // Your embedding vector
const qdrantUrl = 'http://qdrant:6333';

await $http.request({
  method: 'PUT',
  url: `${qdrantUrl}/collections/my_collection/points`,
  headers: {
    'api-key': $env.QDRANT_API_KEY,
    'Content-Type': 'application/json'
  },
  body: {
    points: [{
      id: 1,
      vector: embedding,
      payload: { text: "sample text" }
    }]
  }
});
```

### Example 2: Upload to MinIO
```javascript
// Using n8n S3 node
// Configure S3 credentials with MinIO endpoint
// Then use standard S3 operations
```

### Example 3: Web Scraping with Crawl4AI
```javascript
// In HTTP Request node
const response = await $http.request({
  method: 'POST',
  url: 'http://crawl4ai:8000/crawl',
  body: {
    url: 'https://example.com',
    wait_for: 'css:.content',
    extract_rules: {
      title: 'h1',
      content: '.article-body'
    }
  }
});
```

### Example 4: Trace LLM Calls with Langfuse
```javascript
// In n8n Code node
const langfuse = {
  baseURL: 'http://langfuse-web:3000',
  publicKey: $env.LANGFUSE_INIT_PROJECT_PUBLIC_KEY,
  secretKey: $env.LANGFUSE_INIT_PROJECT_SECRET_KEY
};

// Log your LLM interaction
await $http.request({
  method: 'POST',
  url: `${langfuse.baseURL}/api/public/ingestion`,
  headers: {
    'X-Langfuse-Public-Key': langfuse.publicKey,
    'X-Langfuse-Secret-Key': langfuse.secretKey,
    'Content-Type': 'application/json'
  },
  body: {
    batch: [{
      id: generateId(),
      type: 'generation-create',
      body: {
        name: 'my-llm-call',
        model: 'gpt-4',
        input: 'user prompt',
        output: 'model response'
      }
    }]
  }
});
```

## Troubleshooting

### Service Not Reachable
1. Check service status: `docker ps`
2. Verify service health: `docker-compose ps`
3. Check logs: `docker-compose logs [service-name]`
4. Verify network: `docker network inspect n8n_deploy_example_default`

### Authentication Issues
- Verify credentials in `.env` file
- Check environment variables: `docker-compose config`
- Ensure services restarted after credential changes: `docker-compose restart [service]`

### Performance Issues
- Check resource usage: `docker stats`
- Review service logs for errors
- Scale workers if needed (n8n-worker replicas)
- Monitor ClickHouse and PostgreSQL query performance

### Integration Failures
- Test internal connectivity: `docker exec n8n ping [service-name]`
- Verify API endpoints with curl from within container
- Check service-specific health endpoints
- Review n8n workflow execution logs

## Best Practices

1. **Use Internal Names**: Always use Docker service names for internal communication
2. **Secure External Access**: Use Caddy for HTTPS or SSH tunnels
3. **Monitor Resources**: Set up monitoring for production deployments
4. **Backup Data**: Regular backups of PostgreSQL and persistent volumes
5. **Update Regularly**: Keep services updated for security and features
6. **Document Changes**: Track configuration changes in version control
7. **Test Integrations**: Verify connections after deployments
8. **Use Environment Variables**: Never hardcode credentials in workflows
