package main

import (
	"log"

	"github.com/temporalio/samples-go/reqrespupdate"
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

	w := worker.New(c, "reqrespupdate", worker.Options{})

	w.RegisterWorkflowWithOptions(reqrespupdate.UppercaseWorkflow, workflow.RegisterOptions{Name: "ReqRespUpdateUppercaseWorkflow"})
	w.RegisterActivity(reqrespupdate.UppercaseActivity)

	err = w.Run(worker.InterruptCh())
	if err != nil {
		log.Fatalln("Unable to start worker", err)
	}
}
