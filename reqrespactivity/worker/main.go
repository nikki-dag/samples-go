package main

import (
	"log"

	"github.com/temporalio/samples-go/reqrespactivity"
	"go.temporal.io/sdk/client"
	"go.temporal.io/sdk/contrib/envconfig"
	"go.temporal.io/sdk/worker"
	"go.temporal.io/sdk/workflow"
)

func main() {
	c, err := client.Dial(envconfig.MustLoadDefaultClientOptions())
	if err != nil {
		log.Fatalln("Unable to create client", err)
	}
	defer c.Close()

	w := worker.New(c, "reqrespactivity", worker.Options{})

	w.RegisterWorkflowWithOptions(reqrespactivity.UppercaseWorkflow, workflow.RegisterOptions{Name: "ReqRespActivityUppercaseWorkflow"})
	w.RegisterActivity(reqrespactivity.UppercaseActivity)

	err = w.Run(worker.InterruptCh())
	if err != nil {
		log.Fatalln("Unable to start worker", err)
	}
}
