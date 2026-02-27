use std::net::SocketAddr;
use std::{env, fs};

use axum::extract::Path;
use axum::http::StatusCode;
use axum::response::IntoResponse;
use axum::routing::get;
use axum::{Json, Router};
use rand::Rng;
use rand::distributions::Alphanumeric;
use serde::Deserialize;

async fn print_path() -> impl IntoResponse {
    let path = "/config";
    println!("Received path: {}", path);

    match fs::read_dir(&path) {
        Ok(entries) => {
            let mut result: String = String::new();
            for entry in entries {
                match entry {
                    Ok(entry) => {
                        let path = entry.path();
                        if path.is_file() {
                            if let Some(file_name) = path.file_name() {
                                let file_name_str = file_name.to_string_lossy();
                                if file_name_str != "." && file_name_str != ".." {
                                    if let Ok(file_content) = fs::read_to_string(&path) {
                                        println!("File: {}", file_name_str);
                                        println!("Content:\n{}", file_content);
                                        println!("------------------------");
                                        result.push_str(&format!(
                                            "name: {}\n content:\n{}\n ------",
                                            file_name_str, file_content
                                        ));
                                    } else {
                                        println!("Error reading file content: {:?}", path);
                                    }
                                }
                            }
                        }
                    }
                    Err(err) => {
                        println!("Error reading directory entry: {}", err);
                    }
                }
            }

            (StatusCode::OK, Json(result))
        }
        Err(new_error) => {
            println!("Error reading directory: {}", new_error);
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                Json("Internal server error".to_string()),
            )
        }
    }
}

async fn print_env_variable(Path(env_name): Path<String>) -> impl IntoResponse {
    if let Some(value) = env::var_os(&env_name) {
        if let Some(value_str) = value.to_str() {
            println!("{}: {}", env_name, value_str);
            return (StatusCode::OK, Json(value_str.to_string()));
        }
    }

    eprintln!("Environment variable not found: {}", env_name);
    (
        StatusCode::NOT_FOUND,
        Json("Environment variable not found".to_string()),
    )
}

async fn generate_password() -> impl IntoResponse {
    let rand_string: String = rand::thread_rng()
        .sample_iter(&Alphanumeric)
        .take(30)
        .map(char::from)
        .collect();

    let response_body = format!("{{ password: {} }}", rand_string);

    println!("Created your random password!");
    println!("{}", response_body);
    (StatusCode::OK, Json(response_body.to_string()))
}

#[tokio::main]
async fn main() {
    start_main_server().await;
}

async fn start_main_server() {
    let app = Router::new()
        .route("/gen", get(generate_password))
        .route("/path", get(print_path))
        .route("/env/:env", get(print_env_variable));

    let addr = SocketAddr::from(([0, 0, 0, 0], 8000));
    axum::Server::bind(&addr)
        .serve(app.into_make_service_with_connect_info::<SocketAddr>())
        .await
        .unwrap();
}
