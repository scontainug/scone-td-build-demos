# Build Custom CVM Image

TDX clusters require a custom CVM image with the `scone_enclave` kernel driver built into the kernel. This image is created once and reused across clusters.

## Prerequisites

- An Azure subscription with quota for DC-series CVM VMs (DCesv5 or DCedsv5 for TDX)
- Azure CLI (`az`) installed and authenticated

## Clone the Required Repositories

```bash
git clone https://github.com/scontain-gmbh/kubectl-scone-azure.git
cd kubectl-scone-azure

git clone git@gitlab.scontain.com:sergey/cvm-kernel-module.git
cd cvm-kernel-module
git checkout sergei/in-tree
cd ..
```

## Run the Image Build Script

The build script compiles a custom linux-azure kernel with the `scone_enclave` driver, creates an Azure CVM from it, and publishes it as a gallery image:

```bash
./scripts/build-cvm-image.sh \
    --driver-source cvm-kernel-module/scone_enclave \
    --gallery-name sconeGallery \
    --resource-group <resource-group> \
    --subscription-id <subscription-id>
```

The script generates a signing keypair automatically. To reuse an existing keypair:

```bash
./scripts/build-cvm-image.sh \
    --driver-source cvm-kernel-module/scone_enclave \
    --signing-key kernel-signing.key \
    --signing-cert kernel-signing.der \
    --gallery-name sconeGallery \
    --resource-group <resource-group> \
    --subscription-id <subscription-id>
```

When the script finishes, it prints the gallery image ID. Save it for the next steps.

## Add the Image to Additional Regions

The gallery image is created in a single region. To deploy clusters in other regions, replicate it:

```bash
az sig image-version update \
    -g <resource-group> -r sconeGallery -i ubuntu-cvm-scone -e 1.0.0 \
    --target-regions "<region-1>" "<region-2>"
```

## Create the scone-config.json File

Create a configuration file referencing the gallery image:

```json
{
    "image": "/subscriptions/<sub-id>/resourceGroups/<rg>/providers/Microsoft.Compute/galleries/sconeGallery/images/ubuntu-cvm-scone/versions/1.0.0"
}
```

For full details on the image build pipeline, see [BUILD-CVM-IMAGE.md](https://github.com/scontain-gmbh/kubectl-scone-azure/blob/laerson/workshop/docs/BUILD-CVM-IMAGE.md).
