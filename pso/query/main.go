package main

import (
	"context"
	"flag"
	"log"

	"go.temporal.io/sdk/client"
	"go.temporal.io/sdk/contrib/envconfig"

	"github.com/temporalio/samples-go/pso"
)

func main() {
	var workflowID, runID, queryType string
	flag.StringVar(&workflowID, "w", "", "WorkflowID")
	flag.StringVar(&runID, "r", "", "RunID")
	flag.StringVar(&queryType, "t", "__stack_trace", "Query type is one of [__stack_trace, child, __open_sessions]")
	flag.Parse()

	// The client is a heavyweight object that should be created once per process.
	opts := envconfig.MustLoadDefaultClientOptions()
	opts.DataConverter = pso.NewJSONDataConverter()
	c, err := client.Dial(opts)
	if err != nil {
		log.Fatalln("Unable to create client", err)
	}
	defer c.Close()

	resp, err := c.QueryWorkflow(context.Background(), workflowID, runID, queryType)
	if err != nil {
		log.Fatalln("Unable to query workflow", err)
	}
	var result interface{}
	if err := resp.Get(&result); err != nil {
		log.Fatalln("Unable to decode query result", err)
	}
	log.Println("Received query result", "Result", result)
}
