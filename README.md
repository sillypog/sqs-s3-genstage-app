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

## sqs-step-3-send-via-client-api
This is very similar to the previous step, except the producer provides an `enqueue/1` function to make the data flow from the server more explicit than using `Kernal.send/2`.

## sqs-step-4-simulate-waiting
This is a more accurate simulation of working with SQS. The server artificially delays the return of events, as though these had not arrived in the queue yet. When it does return events, it doesn't return enough to satisfy demand in one batch. The same server loop will keep running until the requested demand is satisfied. Once those have all been consumed, another set of 10 messages will be demanded and a new server loop will start.
```
Attempting to start SQS.Server
Initializing SQS.Server supervision tree
Initalised SQS.Producer
SQS.Producer handling demand of 10
Asking for 10 events
There are currently 0 servers looping
All servers terminated
Server looping: Run 0. Looking for 10 events
Started new server loop with pid #PID<0.158.0>
Received 0 events
Server looping: Run 1. Looking for 10 events
Server looping: Run 2. Looking for 10 events
Server looping: Run 3. Looking for 10 events
Server looping: Run 4. Looking for 10 events
Server looping: Run 5. Looking for 10 events
Casting events to producer
SQS.Producer got notified about 2 new events
Consumed: hey, hey
Server looping: Run 6. Looking for 8 events
Casting events to producer
SQS.Producer got notified about 2 new events
Consumed: hey, hey
Server looping: Run 7. Looking for 6 events
Casting events to producer
SQS.Producer got notified about 2 new events
Consumed: hey, hey
Server looping: Run 8. Looking for 4 events
Casting events to producer
SQS.Producer got notified about 2 new events
Consumed: hey, hey
Server looping: Run 9. Looking for 2 events
Casting events to producer
SQS.Producer got notified about 2 new events
Consumed: hey, hey
SQS.Producer handling demand of 10
Asking for 10 events
There are currently 0 servers looping
All servers terminated
Server looping: Run 0. Looking for 10 events
Started new server loop with pid #PID<0.162.0>
Received 0 events
Server looping: Run 1. Looking for 10 events
Server looping: Run 2. Looking for 10 events
...
```
