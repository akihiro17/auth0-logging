# Auth0 events to Storage Account using Azure Event Grid and Azure Function

This project demonstrates how to stream Auth0 logs to Azure Functions using Event Grid, with infrastructure provisioned by Terraform.

The Azure Function processes Auth0 log events and stores them in an Azure Storage Account.

## Technologies Used

*   **Terraform:** For infrastructure as code (IaC) to provision Azure resources.
*   **Azure Functions:** Serverless compute to process log events.
*   **Auth0 Event Grid:** To stream logs from Auth0 to Azure Event Grid.
*   **Azure Storage Account:** To store processed logs.

## Usage

```sh
$ terraform init
$ auth0 login
$ env AUTH0_CLI_LOGIN=true terraform plan -var-file="terraform.tfvars"
$ env AUTH0_CLI_LOGIN=true terraform apply -var-file="terraform.tfvars"
```
