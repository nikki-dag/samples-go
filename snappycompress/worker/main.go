package main

import (
	"log"

	"github.com/temporalio/samples-go/snappycompress"
	"go.temporal.io/sdk/client"
	"go.temporal.io/sdk/contrib/envconfig"
	"go.temporal.io/sdk/worker"
	"go.temporal.io/sdk/workflow"
)

func main() {
	// The client and worker are heavyweight objects that should be created once per process.
	opts := envconfig.MustLoadDefaultClientOptions()
	// Set DataConverter here so that workflow and activity inputs/results will
	// be compressed as required.
	opts.DataConverter = snappycompress.AlwaysCompressDataConverter
	c, err := client.Dial(opts)
	if err != nil {
		log.Fatalln("Unable to create client", err)
	}
	defer c.Close()

	w := worker.New(c, "snappycompress", worker.Options{})

	w.RegisterWorkflowWithOptions(snappycompress.Workflow, workflow.RegisterOptions{Name: "SnappyCompressWorkflow"})
	w.RegisterActivity(snappycompress.Activity)

	err = w.Run(worker.InterruptCh())
	if err != nil {
		log.Fatalln("Unable to start worker", err)
	}
}
