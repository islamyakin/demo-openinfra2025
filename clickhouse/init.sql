CREATE DATABASE IF NOT EXISTS otel;

CREATE TABLE IF NOT EXISTS otel.otel_logs (
    Timestamp DateTime64(9),
    TraceId String,
    SpanId String,
    TraceFlags UInt32,
    SeverityText LowCardinality(String),
    SeverityNumber Int32,
    ServiceName LowCardinality(String),
    Body String,
    ResourceSchemaUrl String,
    ResourceAttributes Map(LowCardinality(String), String),
    ScopeSchemaUrl String,
    ScopeName String,
    ScopeVersion String,
    ScopeAttributes Map(LowCardinality(String), String),
    LogAttributes Map(LowCardinality(String), String)
) ENGINE = MergeTree()
PARTITION BY toDate(Timestamp)
ORDER BY (ServiceName, SeverityText, Timestamp)
TTL toDateTime(Timestamp) + INTERVAL 30 DAY
SETTINGS index_granularity = 8192, ttl_only_drop_parts = 1;

CREATE VIEW IF NOT EXISTS otel.logs_query_builder AS
SELECT 
    Timestamp,
    Body as Message,
    SeverityText as LogLevel,
    COALESCE(LogAttributes['service'], ServiceName) as Service,
    LogAttributes['component'] as Component,
    COALESCE(LogAttributes['environment'], ResourceAttributes['deployment.environment']) as Environment,
    LogAttributes['method'] as HttpMethod,
    toUInt16OrZero(LogAttributes['status']) as HttpStatus,
    LogAttributes['remote_addr'] as ClientIP,
    LogAttributes['request_uri'] as RequestURI,
    LogAttributes['http_user_agent'] as UserAgent,
    TraceId,
    SpanId
FROM otel.otel_logs;

CREATE VIEW IF NOT EXISTS otel.nginx_access_logs AS
SELECT 
    Timestamp,
    LogAttributes['remote_addr'] as client_ip,
    LogAttributes['method'] as method,
    LogAttributes['request_uri'] as url,
    LogAttributes['status'] as status_code,
    LogAttributes['body_bytes_sent'] as bytes_sent,
    LogAttributes['http_user_agent'] as user_agent,
    LogAttributes['http_referer'] as referer,
    Body as message,
    SeverityText as log_level
FROM otel.otel_logs
WHERE ServiceName = 'edge-services';
