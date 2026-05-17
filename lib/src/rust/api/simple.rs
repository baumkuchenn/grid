use sqlx::{MySqlPool, Row};

pub async fn get_mysql_databases(url: String) -> Result<Vec<String>, String> {
    // 1. Connect to your local MySQL instance
    let pool = MySqlPool::connect(&url)
        .await
        .map_err(|e| format!("Connection failed: {}", e))?;

    // 2. Query to look at all schema/database names
    let rows = sqlx::query("SHOW DATABASES;")
        .fetch_all(&pool)
        .await
        .map_err(|e| format!("Failed to fetch databases: {}", e))?;

    // 3. Extract the string from the first column of each row
    let mut db_names = Vec::new();
    for row in rows {
        if let Ok(name) = row.try_get::<String, _>(0) {
            db_names.push(name);
        }
    }

    Ok(db_names)
}