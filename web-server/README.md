# Web Server Demo

## Introduction

This Rust application serves as a minimalistic web service built using the [Axum](https://github.com/tokio-rs/axum) framework.
While it's more functional than a traditional "Web Server" program, it remains straightforward and easy to understand. Let's break it down:

## Endpoints

- **Generate Password Endpoint (`/gen`)**:

  - Generates a random password consisting of alphanumeric characters.
  - Example Response:

  ```json
  {
    "password": "aBcD1234EeFgH5678"
  }
  ```

- **Print Path Endpoint (`/path`)**:

  - Reads files from the `/config` directory and returns their names and contents.
  - Example Response:

  ```json
  {
    "name": "file1.txt",
    "content": "This is the content of file1.txt.\n..."
  }
  ```

- **Print Environment Variable Endpoint (`/env/:env`)**:

  - Retrieves the value of the specified environment variable.
  - Example Response:

  ```json
  {
    "value": "your_env_value_here"
  }
  ```

## How to Run the Demo

1. **Prerequisites**:

   - kubectl.
   - sgx cluster with LAS.
   - [Rust](https://www.rust-lang.org/)
   - gcc-multilib

   ```bash
   # Fill in your credentials
   kubectl create secret docker-registry sconelsd \
       --docker-server=registry.scontain.com \
       --docker-username=$REGISTRY_USER \
       --docker-password=$REGISTRY_TOKEN
   ```

1. **Register image:**

   > If you already used `./install.sh` change `./target/debug/k8s-scone` to `k8s-scone`

   ```bash
   pushd examples/demo/web-server/

   # Build the Scone image for the demo client
   docker build -t registry.scontain.com/k8s-scone-images/web-server:native .

   # Push it to the registry
   docker push registry.scontain.com/k8s-scone-images/web-server:native

   popd

   ./targe/debug/k8s-scone register \
       --original-image registry.scontain.com/k8s-scone-images/web-server:native \
       --base-image registry.scontain.com/k8s-scone-images/web-server:native \
       --enforce ./web-server

   docker push registry.scontain.com/k8s-scone-images/web-server:native-scone
   ```

1. **Test the manifest [optional]**:

   ```bash
   kubectl apply -f examples/demo/web-server/manifest.yaml

   # Use this command in another terminal or add `&` at the end of the command to run in the background
   kubectl port-forward deployment/web-server 8000:8000

   curl http://localhost:8000/env/MY_POD_IP

   kubectl delete -f examples/demo/web-server/manifest.yaml

   # Close the port forward after the execution
   ```

1. **Convert the manifest**:
   If you want to see how the scone image was registered in k8s-scone, take a look in [register-image](../../../register-image.md) markdown.

   ```bash
   # Change the cas name to your deployed cas
   export CAS_NAME="</cas_name>"
   kubectl port-forward $CAS_NAME 8081:8081
   ./target/debug/k8s-scone apply \
       -f ./examples/demo/web-server/manifest.yaml \
       -c cas.scone-system \
       -p
   ```

1. **Deploy the new manifest**:

   ```bash
   kubectl apply -f examples/demo/web-server/manifest.cleaned.yaml
   ```

   > For the next step, it is expected that you have a Kubernetes cluster with SGX resource and the presence of a LAS

1. **Run the demo**:

   - Open port:

   > Use this command in another terminal or add `&` at the end of the command to run in the background

   ```bash
   kubectl port-forward deployment/web-server 8000:8000
   ```

   - send requests:

   > You can execute the [`./examples/demo/web-server/test.sh`](./test.sh) to run all of these tests easily

   ```bash
   # Test path
   curl http://localhost:8000/path

   # Test gen
   curl http://localhost:8000/gen

   # Test env
   curl http://localhost:8000/env/PLAYER_INITIAL_LIVES
   curl http://localhost:8000/env/UI_PROPERTIES_FILE_NAME
   curl http://localhost:8000/env/SECRET_ENV
   curl http://localhost:8000/env/SIMPLE_ENV
   curl http://localhost:8000/env/MY_POD_IP
   ```

1. **Uninstall demo**:

   ```bash
   kubectl delete -f examples/demo/web-server/manifest.cleaned.yaml
   ```

And there you have it—a simple yet functional "Web Server" web service in Rust! Feel free to explore and modify this demo to suit your needs.
If you have any questions or need further assistance, feel free to ask! 😊🚀
