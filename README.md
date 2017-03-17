# Palleto

An example data processing pipeline using GenStage to read messages from SQS, download the referenced files from S3, process those files and write the output to disk.

This is the example application I presented at Erlang & Elixir Factory SF Bay Area 2017 on 3/24/17. Slides are at [http://sillypog.com/erlang-factory-2017-genstage](http://sillypog.com/erlang-factory-2017-genstage).

I have broken the application down into various steps. Comments within the code at each step indicate what has changed and why. Each step is a separate git branch.

## Installation
The application can be run in Docker with:
```
docker build -t exmr .
```
```
docker run --ti --rm -v $(pwd):/app exmr /bin/bash
```

## sqs-step-1-basic-pipeline
No real data is being processed at this point. This stage sets up a simple GenStage pipeline with a producer and consumer. When the producer receives demand from the consumer, it makes a request to a server to fetch the required number of events - at this point, this is just a list of strings. When the consumer receives the events, it displays them.

```
Initalised SQS.Producer
SQS.Producer handling demand of 10
Asking for 10 events
Pulling 10 events from server
Received 10 events
Consumed: ho, ho, ho, ho, ho, ho, ho, ho, ho, ho
SQS.Producer handling demand of 10
Asking for 10 events
Pulling 10 events from server
Received 10 events
Consumed: ho, ho, ho, ho, ho, ho, ho, ho, ho, ho
SQS.Producer handling demand of 10
Asking for 10 events
Pulling 10 events from server
Received 10 events
Consumed: ho, ho, ho, ho, ho, ho, ho, ho, ho, ho
...
```

## sqs-step-2-asynchronous-server
The server is still returning generated strings, but it now does this within a loop running as a supervised task. The introduction of this asynchronous behaviour is the first step towards continously polling for SQS messages.
