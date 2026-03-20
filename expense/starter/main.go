package main

import (
	"context"
	"log"

	"github.com/pborman/uuid"
	"go.temporal.io/sdk/client"
	"go.temporal.io/sdk/contrib/envconfig"

	"github.com/temporalio/samples-go/expense"
)

func main() {
	// The client is a heavyweight object that should be created once per process.
	c, err := client.Dial(envconfig.MustLoadDefaultClientOptions())
	if err != nil {
		log.Fatalln("Unable to create client", err)
	}
	defer c.Close()

	expenseID := uuid.New()
	workflowOptions := client.StartWorkflowOptions{
		ID:        "expense_" + expenseID,
		TaskQueue: "expense",
	}

	we, err := c.ExecuteWorkflow(context.Background(), workflowOptions, expense.SampleExpenseWorkflow, expenseID)
	if err != nil {
		log.Fatalln("Unable to execute workflow", err)
	}
	log.Println("Started workflow", "WorkflowID", we.GetID(), "RunID", we.GetRunID())

}
