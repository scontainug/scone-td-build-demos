# Basic Kubernetes Concepts

Kubernetes manages applications by describing the desired state of your
system in **YAML manifests**.\
These manifests define **resources** such as Jobs, Deployments,
ConfigMaps, and Secrets.

Each resource describes **what should run in the cluster**, and
Kubernetes ensures the system keeps running in that state.

------------------------------------------------------------------------

# 1. Job

A **Job** runs a task **once or a limited number of times** until it
finishes successfully.

Typical use cases:

-   Database migrations
-   Data processing
-   Batch tasks
-   One-time setup scripts

A Job creates one or more **Pods** and waits until they **complete
successfully**.

If a Pod fails, Kubernetes can automatically **restart it**.

### Example Job

``` yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: example-job
spec:
  template:
    spec:
      containers:
      - name: worker
        image: busybox
        command: ["sh", "-c", "echo Hello from Kubernetes Job"]
      restartPolicy: Never
```

### Key properties

  Property          Meaning
  ----------------- -----------------------------------
  `template`        Defines the Pod that runs the job
  `restartPolicy`   Usually `Never` for Jobs
  `backoffLimit`    Number of retries before failure

### Behavior

    Job
     └─ Pod
         └─ Container

Once the Pod finishes successfully, the **Job is complete**.

------------------------------------------------------------------------

# 2. Deployment

A **Deployment** manages **long-running applications** such as web
services.

Unlike Jobs, Deployments ensure that **a certain number of Pods are
always running**.

Typical use cases:

-   Web APIs
-   Microservices
-   Background services
-   Any continuously running application

### Example Deployment

``` yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webserver
spec:
  replicas: 3
  selector:
    matchLabels:
      app: webserver
  template:
    metadata:
      labels:
        app: webserver
    spec:
      containers:
      - name: nginx
        image: nginx:latest
```

### Key properties

  Property     Meaning
  ------------ -------------------------------------------------
  `replicas`   Number of Pods to run
  `selector`   Identifies which Pods belong to this Deployment
  `template`   Defines the Pod specification

### Behavior

    Deployment
     └─ ReplicaSet
         └─ Pods
             └─ Containers

If a Pod crashes, Kubernetes automatically **creates a new one**.

Deployments also support:

-   **Rolling updates**
-   **Rollback to previous versions**
-   **Scaling**

Example scaling command:

``` bash
kubectl scale deployment webserver --replicas=5
```

------------------------------------------------------------------------

# 3. ConfigMap

A **ConfigMap** stores **configuration data** that applications can
read.

This allows configuration to be **separated from the container image**.

Typical use cases:

-   Configuration files
-   Environment variables
-   Application settings

### Example ConfigMap

``` yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  APP_MODE: production
  LOG_LEVEL: info
```

### Using a ConfigMap in a Pod

``` yaml
env:
- name: APP_MODE
  valueFrom:
    configMapKeyRef:
      name: app-config
      key: APP_MODE
```

### Key properties

  Property       Meaning
  -------------- ------------------------------
  `data`         Key/value configuration data
  `binaryData`   Binary configuration values

### Important notes

-   ConfigMaps are **not encrypted**
-   They should **not store secrets**

------------------------------------------------------------------------

# 4. Secret

A **Secret** stores **sensitive information** such as:

-   passwords
-   API keys
-   tokens
-   TLS certificates

Secrets work similarly to ConfigMaps but are intended for **confidential
data**.

### Example Secret

``` yaml
apiVersion: v1
kind: Secret
metadata:
  name: db-secret
type: Opaque
data:
  password: cGFzc3dvcmQ=
```

The values are **base64 encoded**.

Example:

    password -> cGFzc3dvcmQ=

### Using a Secret in a Pod

``` yaml
env:
- name: DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: db-secret
      key: password
```

### Important notes

Secrets are:

-   stored separately from application code
-   mounted as environment variables or files

However:

-   base64 encoding **is not encryption**
-   clusters should enable **secret encryption at rest**

------------------------------------------------------------------------

# How These Resources Work Together

A typical Kubernetes application might look like this:

    Deployment
     ├─ Pods
     │   └─ Containers
     │
     ├─ ConfigMap
     │   └─ Application configuration
     │
     └─ Secret
         └─ Credentials / keys

For batch processing:

    Job
     └─ Pod
         └─ Container

------------------------------------------------------------------------

# Summary

  Resource         Purpose
  ---------------- -----------------------------
  **Job**          Run a task until completion
  **Deployment**   Run long-lived applications
  **ConfigMap**    Store configuration data
  **Secret**       Store sensitive data
