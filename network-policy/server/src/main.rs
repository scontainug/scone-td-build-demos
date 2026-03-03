use axum::Router;
use axum::routing::get;
use rand::Rng;

#[tokio::main]
async fn main() {
    let app = Router::new().route(
        "/",
        get(|| async {
            println!("got request for new password...");
            let password = generate_password();
            println!("password is: {}", password);
            password
        }),
    );

    let listener = tokio::net::TcpListener::bind("0.0.0.0:9000").await.unwrap();
    axum::serve(listener, app).await.unwrap();
}

fn generate_password() -> String {
    let rand_string: String = rand::rng()
        .sample_iter(rand::distr::Alphanumeric)
        .take(7)
        .map(char::from)
        .collect();
    rand_string
}
