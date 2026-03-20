package main

import (
	"log"

	"github.com/temporalio/samples-go/reqrespquery"
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

	w := worker.New(c, "reqrespquery", worker.Options{})

	w.RegisterWorkflowWithOptions(reqrespquery.UppercaseWorkflow, workflow.RegisterOptions{Name: "ReqRespQueryUppercaseWorkflow"})
	w.RegisterActivity(reqrespquery.UppercaseActivity)

	err = w.Run(worker.InterruptCh())
	if err != nil {
		log.Fatalln("Unable to start worker", err)
	}
}
