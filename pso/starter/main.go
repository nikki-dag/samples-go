package main

import (
	"context"
	"flag"
	"log"

	"github.com/pborman/uuid"
	"go.temporal.io/sdk/client"
	"go.temporal.io/sdk/contrib/envconfig"

	"github.com/temporalio/samples-go/pso"
)

func main() {
	var functionName string
	flag.StringVar(&functionName, "f", "sphere", "One of [sphere, rosenbrock, griewank]")
	flag.Parse()

	// The client is a heavyweight object that should be created once per process.
	opts := envconfig.MustLoadDefaultClientOptions()
	opts.DataConverter = pso.NewJSONDataConverter()
	c, err := client.Dial(opts)
	if err != nil {
		log.Fatalln("Unable to create client", err)
	}
	defer c.Close()

	workflowOptions := client.StartWorkflowOptions{
		ID:        "PSO_" + uuid.New(),
		TaskQueue: "pso",
	}

	we, err := c.ExecuteWorkflow(context.Background(), workflowOptions, pso.PSOWorkflow, functionName)
	if err != nil {
		log.Fatalln("Unable to execute workflow", err)
	}
	log.Println("Started workflow", "WorkflowID", we.GetID(), "RunID", we.GetRunID())
}
