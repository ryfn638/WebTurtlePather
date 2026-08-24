use std::net::TcpListener;
use std::io::Write;
use std::fs;

#[path = "dbLink.rs"]
mod dblink;

#[tokio::main]
async fn main()
{
    println!("Starting Server");
    let listener = TcpListener::bind("127.0.0.1:8080").unwrap();
    println!("Server is running on port 8080!");

    match dblink::ConnectDB().await {
        Ok(_) => println!("Database has been connected"),
        Err(e) => println!("Could not connect to databases: {}", e),
    }

    for stream in listener.incoming() 
    {
        let mut stream = stream.unwrap();
        println!("Received post");


        let htmlContent = fs::read_to_string("site.html")
            .unwrap_or_else(|_| "<h1>Error: site.html not found!</h1>".to_string());

        let length = htmlContent.len();

        let response = format!(
            "HTTP/1.1 200 OK\r\n\
            Content-Type: text/html\r\n\
            Content-Length: {length}\r\n\
            \r\n\
            {htmlContent}"
        );

        stream.write_all(response.as_bytes()).unwrap();
    }
}
