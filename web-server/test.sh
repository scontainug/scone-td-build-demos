#!/usr/bin/env bash

# Define the URLs
urls=(
    "http://localhost:8000/path"
    "http://localhost:8000/gen"
    "http://localhost:8000/env/PLAYER_INITIAL_LIVES"
    "http://localhost:8000/env/UI_PROPERTIES_FILE_NAME"
    "http://localhost:8000/env/SECRET_ENV"
    "http://localhost:8000/env/SIMPLE_ENV"
    "http://localhost:8000/env/MY_POD_IP"
)

# Loop through the URLs
for url in "${urls[@]}"; do
    # Execute the curl command and capture the output
    if response=$(curl -s "$url"); then
        echo "OK: $response" # Print "OK" and the response content
    else
        echo "Error" # Print "Error" for failed requests
    fi
done
