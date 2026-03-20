package main

import (
	"context"
	"log"

	codecserver "github.com/temporalio/samples-go/codec-server"
	"go.temporal.io/sdk/client"
	"go.temporal.io/sdk/contrib/envconfig"
)

func main() {
	// The client is a heavyweight object that should be created once per process.
	opts := envconfig.MustLoadDefaultClientOptions()
	// Set DataConverter here to ensure that workflow inputs and results are
	// encoded as required.
	opts.DataConverter = codecserver.DataConverter
	c, err := client.Dial(opts)
	if err != nil {
		log.Fatalln("Unable to create client", err)
	}
	defer c.Close()

	workflowOptions := client.StartWorkflowOptions{
		ID:        "codecserver_workflowID",
		TaskQueue: "codecserver",
	}

	// The workflow input "My Compressed Friend" will be encoded by the codec before being sent to Temporal
	we, err := c.ExecuteWorkflow(
		context.Background(),
		workflowOptions,
		"CodecServerWorkflow",
		"Plain text input",
	)
	if err != nil {
		log.Fatalln("Unable to execute workflow", err)
	}

	log.Println("Started workflow", "WorkflowID", we.GetID(), "RunID", we.GetRunID())

	// Synchronously wait for the workflow completion.
	var result string
	err = we.Get(context.Background(), &result)
	if err != nil {
		log.Fatalln("Unable get workflow result", err)
	}
	log.Println("Workflow result:", result)
}
