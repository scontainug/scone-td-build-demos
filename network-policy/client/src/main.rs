use std::env;

use axum::Router;
use axum::routing::get;
use x509_parser::pem::Pem;
use x509_parser::x509::X509Version;

#[tokio::main]
async fn main() {
    let identity = env::var("SCONE_NETWORK_SHIELD_CLIENT_client-server-9000_IDENTITY")
        .expect("missing env variable");
    println!("raw env: {identity:?}");
    for pem in Pem::iter_from_buffer(&identity.clone().into_bytes()) {
        let pem = pem.expect("Reading next PEM block failed");
        if pem.label == "PRIVATE KEY" {
            continue;
        }
        let x509 = pem.parse_x509().expect("X.509: decoding DER failed");
        assert_eq!(x509.tbs_certificate.version, X509Version::V3);
        println!("cert extensions: {:?}", x509.tbs_certificate.extensions());
    }

    // build our application with a single route
    let server = env::var("DB").unwrap_or("localhost:9000".to_owned());
    let server = format!("http://{server}");
    println!("server is: {server}");
    let app = Router::new().route(
        "/db-query",
        get(|| async {
            println!("Got db request");
            let body = reqwest::get(server)
                .await
                .expect("didn't get response")
                .text()
                .await
                .expect("resp didn't contain body");

            println!("body = {body:?}");

            body
        }),
    );

    // run our app with hyper, listening globally on port 3000
    let listener = tokio::net::TcpListener::bind("0.0.0.0:3000").await.unwrap();
    axum::serve(listener, app).await.unwrap();
}
