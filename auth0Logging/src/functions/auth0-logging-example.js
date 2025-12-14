const { app, output } = require("@azure/functions");

// ref. https://learn.microsoft.com/en-us/azure/azure-functions/functions-bindings-storage-blob-input?tabs=python-v2%2Cisolated-process%2Cnodejs-v4&pivots=programming-language-javascript#configuration
const blobOutput = output.storageBlob({
  // The path to the blob.
  path: "auth0-logs/{rand-guid}.json",

  // The name of a shared prefix for multiple application settings when using an identity-based connection.
  connection: "AzureWebJobsStorage",
});

app.eventGrid("auth0-logging-example", {
  extraOutputs: [blobOutput],
  handler: (event, context) => {
    context.log("Event Grid function processed event", event);

    context.extraOutputs.set(blobOutput, JSON.stringify(event, null, 2));
  },
});
