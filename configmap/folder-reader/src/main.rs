use std::fs;

fn main() {
    let config_dir = "/config";
    println!("SCONE FILE TEST");

    match fs::read_dir(config_dir) {
        Ok(entries) => {
            for entry in entries {
                if let Ok(entry) = entry {
                    let file_name = entry.file_name();
                    let file_path = entry.path();

                    println!("filename: {:?}", file_name);
                    if let Ok(file_content) = fs::read_to_string(&file_path) {
                        println!("file content:\n{}", file_content);
                    } else {
                        println!("Error when try read the file.");
                    }
                }
            }
        }
        Err(e) => {
            println!("Error when try read folder: {}", e);
        }
    }
}
