package main

import (
	"github.com/temporalio/samples-go/updatabletimer"
	"log"

	"go.temporal.io/sdk/client"
	"go.temporal.io/sdk/contrib/envconfig"
	"go.temporal.io/sdk/worker"
	"go.temporal.io/sdk/workflow"
)

func main() {
	// The client and worker are heavyweight objects that should be created once per process.
	c, err := client.Dial(envconfig.MustLoadDefaultClientOptions())
	if err != nil {
		log.Fatalln("Unable to create client", err)
	}
	defer c.Close()

	w := worker.New(c, updatabletimer.TaskQueue, worker.Options{})

	w.RegisterWorkflowWithOptions(updatabletimer.Workflow, workflow.RegisterOptions{Name: "UpdatableTimerWorkflow"})

	err = w.Run(worker.InterruptCh())
	if err != nil {
		log.Fatalln("Unable to start worker", err)
	}
}
