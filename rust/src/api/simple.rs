#[flutter_rust_bridge::frb(sync)] // Synchronous mode for simplicity of the demo
pub fn greet(name: String) -> String {
    format!("Hello, {name}!")
}

#[flutter_rust_bridge::frb(init)]
pub fn init_app() {
    // Default utilities - feel free to customize
    flutter_rust_bridge::setup_default_user_utils();
}

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

pub struct QueryResult {
    pub columns: Vec<String>,
    pub rows: Vec<Vec<String>>,
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

pub async fn get_mysql_databases(url: String) -> anyhow::Result<Vec<String>> {
    let pool = get_or_create_pool(&url).await?;
    let rows = sqlx::query("SHOW DATABASES").fetch_all(&pool).await?;
    let databases = rows
        .into_iter()
        .filter_map(|row| row.try_get::<String, usize>(0).ok())
        .collect();
    Ok(databases)
}

pub async fn get_mysql_tables(url: String, database: String) -> anyhow::Result<Vec<String>> {
    let connection_string = format!("{}/{}", url.trim_end_matches('/'), database);
    let pool = get_or_create_pool(&connection_string).await?;
    let rows = sqlx::query("SHOW TABLES").fetch_all(&pool).await?;
    let tables = rows
        .into_iter()
        .filter_map(|row| row.try_get::<String, usize>(0).ok())
        .collect();
    Ok(tables)
}

pub async fn run_mysql_query(url: String, database: String, query: String) -> anyhow::Result<QueryResult> {
    let connection_string = format!("{}/{}", url.trim_end_matches('/'), database);
    let pool = get_or_create_pool(&connection_string).await?;

    let rows = sqlx::query(&query).fetch_all(&pool).await?;
    
    if rows.is_empty() {
        return Ok(QueryResult { columns: vec![], rows: vec![] });
    }

    let columns: Vec<String> = rows[0]
        .columns()
        .iter()
        .map(|c| c.name().to_string())
        .collect();

    let mut result_rows = Vec::new();
    for row in rows {
        let mut row_data = Vec::new();
        for i in 0..columns.len() {
            let val = decode_mysql_cell(&row, i);
            row_data.push(val);
        }
        result_rows.push(row_data);
    }

    Ok(QueryResult { columns, rows: result_rows })
}

pub async fn get_mysql_table_data(url: String, database: String, table: String) -> anyhow::Result<QueryResult> {
    let query = format!("SELECT * FROM `{}` LIMIT 100", table);
    run_mysql_query(url, database, query).await
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
            row.try_get::<String, _>(index).unwrap_or_else(|_| "ERROR".to_string())
        }
        "JSON" => {
            row.try_get::<serde_json::Value, _>(index)
                .map(|v| v.to_string())
                .unwrap_or_else(|_| "ERROR".to_string())
        }
        "TINYINT" | "BOOLEAN" => {
            row.try_get::<i8, _>(index).map(|v| v.to_string()).unwrap_or_else(|_| "ERROR".to_string())
        }
        "TINYINT UNSIGNED" => {
            row.try_get::<u8, _>(index).map(|v| v.to_string()).unwrap_or_else(|_| "ERROR".to_string())
        }
        "SMALLINT" => {
            row.try_get::<i16, _>(index).map(|v| v.to_string()).unwrap_or_else(|_| "ERROR".to_string())
        }
        "SMALLINT UNSIGNED" => {
            row.try_get::<u16, _>(index).map(|v| v.to_string()).unwrap_or_else(|_| "ERROR".to_string())
        }
        "INT" | "MEDIUMINT" => {
            row.try_get::<i32, _>(index).map(|v| v.to_string()).unwrap_or_else(|_| "ERROR".to_string())
        }
        "INT UNSIGNED" | "MEDIUMINT UNSIGNED" => {
            row.try_get::<u32, _>(index).map(|v| v.to_string()).unwrap_or_else(|_| "ERROR".to_string())
        }
        "BIGINT" => {
            row.try_get::<i64, _>(index).map(|v| v.to_string()).unwrap_or_else(|_| "ERROR".to_string())
        }
        "BIGINT UNSIGNED" => {
            row.try_get::<u64, _>(index).map(|v| v.to_string()).unwrap_or_else(|_| "ERROR".to_string())
        }
        "FLOAT" => {
            row.try_get::<f32, _>(index).map(|v| v.to_string()).unwrap_or_else(|_| "ERROR".to_string())
        }
        "DOUBLE" => {
            row.try_get::<f64, _>(index).map(|v| v.to_string()).unwrap_or_else(|_| "ERROR".to_string())
        }
        "DECIMAL" | "NUMERIC" => {
            row.try_get::<bigdecimal::BigDecimal, _>(index)
                .map(|v| v.to_string())
                .unwrap_or_else(|_| "DECIMAL".to_string())
        }
        "DATE" | "DATETIME" | "TIMESTAMP" => {
            row.try_get::<chrono::DateTime<chrono::Utc>, _>(index)
                .map(|v| v.with_timezone(&chrono::Local).format("%Y-%m-%d %H:%M:%S").to_string())
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
                .or_else(|_| {
                    row.try_get::<String, _>(index)
                })
                .unwrap_or_else(|_| "DATE".to_string())
        }
        "TIME" => {
            row.try_get::<chrono::NaiveTime, _>(index)
                .map(|v| v.to_string())
                .unwrap_or_else(|_| "TIME".to_string())
        }
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
        _ => {
            row.try_get::<String, _>(index).unwrap_or_else(|_| format!("[{}]", type_name))
        }
    };

    val
}

pub async fn execute_mysql_action(url: String, database: String, query: String, disable_fk: bool) -> anyhow::Result<()> {
    let connection_string = format!("{}/{}", url.trim_end_matches('/'), database);
    let pool = get_or_create_pool(&connection_string).await?;
    let mut conn = pool.acquire().await?;

    if disable_fk {
        sqlx::query("SET FOREIGN_KEY_CHECKS=0").execute(&mut *conn).await?;
    }

    sqlx::query(&query).execute(&mut *conn).await?;

    if disable_fk {
        sqlx::query("SET FOREIGN_KEY_CHECKS=1").execute(&mut *conn).await?;
    }

    Ok(())
}
