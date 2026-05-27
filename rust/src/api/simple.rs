#[flutter_rust_bridge::frb(sync)] // Synchronous mode for simplicity of the demo
pub fn greet(name: String) -> String {
    format!("Hello, {name}!")
}

#[flutter_rust_bridge::frb(init)]
pub fn init_app() {
    // Default utilities - feel free to customize
    flutter_rust_bridge::setup_default_user_utils();
}

use futures_util::TryStreamExt;
use sqlx::mysql::{MySqlPool, MySqlPoolOptions, MySqlRow};
use sqlx::{Column, Row, TypeInfo, ValueRef};
use std::collections::HashMap;
use std::sync::OnceLock;
use tokio::sync::Mutex;

// Global pool cache: reuses authenticated connections per unique URL.
// MySqlPool::connect() pays full TCP handshake + MySQL auth on every call —
// this cache ensures that cost is paid exactly once per connection string.
static POOL_CACHE: OnceLock<Mutex<HashMap<String, MySqlPool>>> = OnceLock::new();

fn pool_cache() -> &'static Mutex<HashMap<String, MySqlPool>> {
    POOL_CACHE.get_or_init(|| Mutex::new(HashMap::new()))
}

async fn get_or_create_pool(url: &str) -> anyhow::Result<MySqlPool> {
    {
        // Fast path: pool already exists — acquire read-equivalent with short lock window.
        let cache = pool_cache().lock().await;
        if let Some(pool) = cache.get(url) {
            return Ok(pool.clone());
        }
    }
    // Slow path (first connection only): create pool, then insert.
    let pool = MySqlPoolOptions::new()
        .max_connections(5)
        .connect(url)
        .await?;
    let mut cache = pool_cache().lock().await;
    // Guard against a race where two callers both missed the fast path.
    cache.entry(url.to_string()).or_insert_with(|| pool.clone());
    Ok(pool)
}

fn mysql_url(url: &str, database: &str) -> String {
    let base = url.trim_end_matches('/');
    if database.trim().is_empty() {
        base.to_string()
    } else {
        format!("{base}/{}", database)
    }
}

pub struct QueryResult {
    pub columns: Vec<String>,
    pub rows: Vec<Vec<String>>,
}

pub struct DatabaseSchema {
    pub name: String,
    pub tables: Vec<String>,
}

pub struct SchemaOverview {
    pub databases: Vec<DatabaseSchema>,
}

pub struct TablePageResult {
    pub result: QueryResult,
    pub total_rows: i64,
}

pub async fn test_mysql_connection(url: String) -> anyhow::Result<bool> {
    match get_or_create_pool(&url).await {
        Ok(pool) => {
            let res = sqlx::query("SELECT 1").fetch_one(&pool).await;
            Ok(res.is_ok())
        }
        Err(_) => Ok(false),
    }
}

pub async fn get_mysql_schema_overview(url: String) -> anyhow::Result<SchemaOverview> {
    let pool = get_or_create_pool(&url).await?;

    let mut databases = Vec::new();
    let mut database_rows = sqlx::query(
        "SELECT SCHEMA_NAME
         FROM INFORMATION_SCHEMA.SCHEMATA
         ORDER BY SCHEMA_NAME",
    )
    .fetch(&pool);

    while let Some(row) = database_rows.try_next().await? {
        let name = row.try_get::<String, usize>(0)?;
        databases.push(DatabaseSchema {
            name,
            tables: Vec::new(),
        });
    }
    drop(database_rows);

    let mut index_by_name = HashMap::with_capacity(databases.len());
    for (index, database) in databases.iter().enumerate() {
        index_by_name.insert(database.name.clone(), index);
    }

    let mut table_rows = sqlx::query(
        "SELECT TABLE_SCHEMA, TABLE_NAME
         FROM INFORMATION_SCHEMA.TABLES
         ORDER BY TABLE_SCHEMA, TABLE_NAME",
    )
    .fetch(&pool);

    while let Some(row) = table_rows.try_next().await? {
        let schema = row.try_get::<String, usize>(0)?;
        let table = row.try_get::<String, usize>(1)?;
        if let Some(index) = index_by_name.get(&schema) {
            databases[*index].tables.push(table);
        }
    }

    Ok(SchemaOverview { databases })
}

pub async fn run_mysql_query(
    url: String,
    database: String,
    query: String,
) -> anyhow::Result<QueryResult> {
    let connection_string = mysql_url(&url, &database);
    let pool = get_or_create_pool(&connection_string).await?;
    collect_query_result(&pool, &query).await
}

pub async fn run_mysql_table_page(
    url: String,
    database: String,
    data_query: String,
    count_query: String,
) -> anyhow::Result<TablePageResult> {
    let connection_string = mysql_url(&url, &database);
    let pool = get_or_create_pool(&connection_string).await?;

    let count_row = sqlx::query(&count_query).fetch_one(&pool).await?;
    let total_rows = count_row
        .try_get::<i64, usize>(0)
        .or_else(|_| count_row.try_get::<u64, usize>(0).map(|v| v as i64))
        .unwrap_or(0);

    let result = collect_query_result(&pool, &data_query).await?;
    Ok(TablePageResult { result, total_rows })
}

async fn collect_query_result(pool: &MySqlPool, query: &str) -> anyhow::Result<QueryResult> {
    let mut rows = sqlx::query(query).fetch(pool);
    let Some(first_row) = rows.try_next().await? else {
        return Ok(QueryResult {
            columns: vec![],
            rows: vec![],
        });
    };

    let columns: Vec<String> = first_row
        .columns()
        .iter()
        .map(|c| c.name().to_string())
        .collect();
    let column_count = columns.len();
    let mut result_rows = Vec::new();
    result_rows.push(decode_mysql_row(&first_row, column_count));

    while let Some(row) = rows.try_next().await? {
        result_rows.push(decode_mysql_row(&row, column_count));
    }

    Ok(QueryResult {
        columns,
        rows: result_rows,
    })
}

fn decode_mysql_cell(row: &MySqlRow, index: usize) -> String {
    let raw_result = row.try_get_raw(index);
    if let Ok(raw) = raw_result {
        if raw.is_null() {
            return "NULL".to_string();
        }
    } else {
        return "ERROR".to_string();
    }

    let col = row.column(index);
    let type_name = col.type_info().name();

    let val = match type_name {
        "CHAR" | "VARCHAR" | "TEXT" | "LONGTEXT" | "MEDIUMTEXT" | "TINYTEXT" | "ENUM" | "SET" => {
            row.try_get::<String, _>(index)
                .unwrap_or_else(|_| "ERROR".to_string())
        }
        "JSON" => row
            .try_get::<serde_json::Value, _>(index)
            .map(|v| v.to_string())
            .unwrap_or_else(|_| "ERROR".to_string()),
        "TINYINT" | "BOOLEAN" => row
            .try_get::<i8, _>(index)
            .map(|v| v.to_string())
            .unwrap_or_else(|_| "ERROR".to_string()),
        "TINYINT UNSIGNED" => row
            .try_get::<u8, _>(index)
            .map(|v| v.to_string())
            .unwrap_or_else(|_| "ERROR".to_string()),
        "SMALLINT" => row
            .try_get::<i16, _>(index)
            .map(|v| v.to_string())
            .unwrap_or_else(|_| "ERROR".to_string()),
        "SMALLINT UNSIGNED" => row
            .try_get::<u16, _>(index)
            .map(|v| v.to_string())
            .unwrap_or_else(|_| "ERROR".to_string()),
        "INT" | "MEDIUMINT" => row
            .try_get::<i32, _>(index)
            .map(|v| v.to_string())
            .unwrap_or_else(|_| "ERROR".to_string()),
        "INT UNSIGNED" | "MEDIUMINT UNSIGNED" => row
            .try_get::<u32, _>(index)
            .map(|v| v.to_string())
            .unwrap_or_else(|_| "ERROR".to_string()),
        "BIGINT" => row
            .try_get::<i64, _>(index)
            .map(|v| v.to_string())
            .unwrap_or_else(|_| "ERROR".to_string()),
        "BIGINT UNSIGNED" => row
            .try_get::<u64, _>(index)
            .map(|v| v.to_string())
            .unwrap_or_else(|_| "ERROR".to_string()),
        "FLOAT" => row
            .try_get::<f32, _>(index)
            .map(|v| v.to_string())
            .unwrap_or_else(|_| "ERROR".to_string()),
        "DOUBLE" => row
            .try_get::<f64, _>(index)
            .map(|v| v.to_string())
            .unwrap_or_else(|_| "ERROR".to_string()),
        "DECIMAL" | "NUMERIC" => row
            .try_get::<bigdecimal::BigDecimal, _>(index)
            .map(|v| v.to_string())
            .unwrap_or_else(|_| "DECIMAL".to_string()),
        "DATE" | "DATETIME" | "TIMESTAMP" => row
            .try_get::<chrono::DateTime<chrono::Utc>, _>(index)
            .map(|v| {
                v.with_timezone(&chrono::Local)
                    .format("%Y-%m-%d %H:%M:%S")
                    .to_string()
            })
            .or_else(|_| {
                row.try_get::<chrono::DateTime<chrono::Local>, _>(index)
                    .map(|v| v.format("%Y-%m-%d %H:%M:%S").to_string())
            })
            .or_else(|_| {
                row.try_get::<chrono::NaiveDateTime, _>(index)
                    .map(|v| v.format("%Y-%m-%d %H:%M:%S").to_string())
            })
            .or_else(|_| {
                row.try_get::<chrono::NaiveDate, _>(index)
                    .map(|v| v.format("%Y-%m-%d").to_string())
            })
            .or_else(|_| row.try_get::<String, _>(index))
            .unwrap_or_else(|_| "DATE".to_string()),
        "TIME" => row
            .try_get::<chrono::NaiveTime, _>(index)
            .map(|v| v.to_string())
            .unwrap_or_else(|_| "TIME".to_string()),
        "BLOB" | "TINYBLOB" | "MEDIUMBLOB" | "LONGBLOB" | "BINARY" | "VARBINARY" => {
            if let Ok(bytes) = row.try_get::<Vec<u8>, _>(index) {
                if let Ok(s) = String::from_utf8(bytes) {
                    s
                } else {
                    "[BLOB]".to_string()
                }
            } else {
                "[BLOB]".to_string()
            }
        }
        _ => row
            .try_get::<String, _>(index)
            .unwrap_or_else(|_| format!("[{}]", type_name)),
    };

    val
}

fn decode_mysql_row(row: &MySqlRow, column_count: usize) -> Vec<String> {
    let mut row_data = Vec::with_capacity(column_count);
    for index in 0..column_count {
        row_data.push(decode_mysql_cell(row, index));
    }
    row_data
}

pub async fn execute_mysql_action(
    url: String,
    database: String,
    query: String,
    disable_fk: bool,
) -> anyhow::Result<()> {
    let connection_string = mysql_url(&url, &database);
    let pool = get_or_create_pool(&connection_string).await?;
    let mut conn = pool.acquire().await?;

    if disable_fk {
        sqlx::query("SET FOREIGN_KEY_CHECKS=0")
            .execute(&mut *conn)
            .await?;
    }

    sqlx::query(&query).execute(&mut *conn).await?;

    if disable_fk {
        sqlx::query("SET FOREIGN_KEY_CHECKS=1")
            .execute(&mut *conn)
            .await?;
    }

    Ok(())
}
