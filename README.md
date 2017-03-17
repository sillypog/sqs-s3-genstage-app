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

## sqs-step-5-multiple-consumers
There are now 3 consumer stages, each demanding 10 events. When one of these consumers processes 10 events, it will send demand for 10 more events. The producer will add this to the existing unserved demand and request these events from the server. The loop will be cancelled and a new loop started. A subset of the output is included here to show this in action:
```
...
Server #PID<0.165.0> looping: Run 17. Looking for 6 events
Casting events to producer
SQS.Producer got notified about 2 new events
Consumed by #PID<0.157.0>: hey, hey
SQS.Producer handling demand of 10
Asking for 14 events
There are currently 1 servers looping
Terminating server with pid #PID<0.165.0>
All servers terminated
Server #PID<0.166.0> looping: Run 0. Looking for 14 events
Started new server loop with pid #PID<0.166.0>
Received 0 events
Server #PID<0.166.0> looping: Run 1. Looking for 14 events
Server #PID<0.166.0> looping: Run 2. Looking for 14 events
Server #PID<0.166.0> looping: Run 3. Looking for 14 events
Server #PID<0.166.0> looping: Run 4. Looking for 14 events
Server #PID<0.166.0> looping: Run 5. Looking for 14 events
Casting events to producer
SQS.Producer got notified about 2 new events
Consumed by #PID<0.157.0>: hey, hey
Server #PID<0.166.0> looping: Run 6. Looking for 12 events
...
```

## sqs-step-6-process-messages
This is the first step that downloads data from S3. The server is using ExAws to poll the SQS queue, SweetXML to parse the SQS messages, and Poison to parse the JSON encoded S3 events within those messages. You will need to run `mix do deps.get, deps.compile` to use these.

At this point, uploading files to an S3 bucket configured to send events to the SQS queue being watched, results in the consumer displaying the location of those files in S3. However, the original messages are not being deleted from the SQS queue, so the same messages will be continually reprocessed.

ExAws attempts to read your AWS credentials from the environment. To make this easier to manage, I've included a docker-compose.yml. To use this, copy docker/development/secret/aws.env.example to docker/development/secret/aws.env and fill in the values. Then run the continer with `docker-compose run app /bin/bash`.

I have also included a cloudformation template describing the setup of the S3 bucket events and the SQS queue that receives them.

## sqs-step-7-release-messages
Messages are now being released from the queue once they are processed. Retrieving, processing, and deleting messages from SQS is now working as planned.

```
Attempting to start SQS.Server
Initializing SQS.Server supervision tree
Initalised SQS.Producer
SQS.Producer handling demand of 10
Asking for 10 events
There are currently 0 servers looping
All servers terminated
Started new server loop with pid #PID<0.192.0>
Server #PID<0.192.0> looping: Run 0. Looking for 10 events
Received 0 events
Server #PID<0.192.0> looping: Run 1. Looking for 10 events
Server #PID<0.192.0> looping: Run 2. Looking for 10 events
Server #PID<0.192.0> looping: Run 3. Looking for 10 events
Server #PID<0.192.0> looping: Run 4. Looking for 10 events
Casting events to producer
SQS.Producer got notified about 3 new events
Consumed by #PID<0.191.0>: warehouse.development/packrat/data/20160722.gz, warehouse.development/packrat/data/20160724.gz, warehouse.development/packrat/data/20160727.gz
Server #PID<0.192.0> looping: Run 5. Looking for 7 events
Casting events to producer
SQS.Producer got notified about 2 new events
Consumed by #PID<0.191.0>: warehouse.development/packrat/data/20160723.gz, warehouse.development/packrat/data/20160726.gz
Server #PID<0.192.0> looping: Run 6. Looking for 5 events
Casting events to producer
SQS.Producer got notified about 3 new events
Consumed by #PID<0.191.0>: warehouse.development/packrat/data/20160720.gz, warehouse.development/packrat/data/20160721.gz, warehouse.development/packrat/data/20160725.gz
Server #PID<0.192.0> looping: Run 7. Looking for 2 events
Casting events to producer
SQS.Producer got notified about 2 new events
Consumed by #PID<0.191.0>: warehouse.development/packrat/data/20160728.gz, warehouse.development/packrat/data/20160729.gz
SQS.Producer handling demand of 10
Asking for 10 events
There are currently 0 servers looping
All servers terminated
Server #PID<0.197.0> looping: Run 0. Looking for 10 events
Started new server loop with pid #PID<0.197.0>
Received 0 events
Casting events to producer
SQS.Producer got notified about 2 new events
Consumed by #PID<0.191.0>: warehouse.development/packrat/data/20160730.gz, warehouse.development/packrat/data/20160731.gz
Server #PID<0.197.0> looping: Run 1. Looking for 8 events
Server #PID<0.197.0> looping: Run 2. Looking for 8 events
Server #PID<0.197.0> looping: Run 3. Looking for 8 events
Server #PID<0.197.0> looping: Run 4. Looking for 8 events
Server #PID<0.197.0> looping: Run 5. Looking for 8 events
Server #PID<0.197.0> looping: Run 6. Looking for 8 events
...
```

## sqs-step-8-download-and-process-file
A producer/consumer stage has been added to the pipeline. This downloads and unzips the S3 file referenced in the event it receives from the producer. The consumer then analyses the contents of the file passed to it from the producer/consumer, writing the number of lines in that file to disk.

```
Attempting to start SQS.Server
Initializing SQS.Server supervision tree
Initalised SQS.Producer
SQS.Producer handling demand of 1
Asking for 1 events
There are currently 0 servers looping
All servers terminated
Server #PID<0.192.0> looping: Run 0. Looking for 1 events
Started new server loop with pid #PID<0.192.0>
Received 0 events
Server #PID<0.192.0> looping: Run 1. Looking for 1 events
Server #PID<0.192.0> looping: Run 2. Looking for 1 events
Casting events to producer
SQS.Producer got notified about 1 new events
ProducerConsumer received 1 events
#ProducerConsumer downloaded packrat/data/20160721.gz
SQS.Producer handling demand of 1
Asking for 1 events
There are currently 0 servers looping
All servers terminated
Server #PID<0.200.0> looping: Run 0. Looking for 1 events
Started new server loop with pid #PID<0.200.0>
Received 0 events
Consumer processed packrat/data/20160721.gz
Casting events to producer
SQS.Producer got notified about 1 new events
ProducerConsumer received 1 events
#ProducerConsumer downloaded packrat/data/20160720.gz
SQS.Producer handling demand of 1
Asking for 1 events
There are currently 0 servers looping
All servers terminated
Server #PID<0.202.0> looping: Run 0. Looking for 1 events
Started new server loop with pid #PID<0.202.0>
Received 0 events
Consumer processed packrat/data/20160720.gz
Casting events to producer
SQS.Producer got notified about 1 new events
ProducerConsumer received 1 events
#ProducerConsumer downloaded packrat/data/20160722.gz
SQS.Producer handling demand of 1
Asking for 1 events
There are currently 0 servers looping
All servers terminated
Server #PID<0.205.0> looping: Run 0. Looking for 1 events
Started new server loop with pid #PID<0.205.0>
Received 0 events
Consumer processed packrat/data/20160722.gz
Server #PID<0.205.0> looping: Run 1. Looking for 1 events
Server #PID<0.205.0> looping: Run 2. Looking for 1 events
Server #PID<0.205.0> looping: Run 3. Looking for 1 events
...
```

## sqs-step-9-concurrent-file-processing
The producer/consumer and consumer are now being managed within a supervision tree, and are launched as uniquely named processes. By increasing the number of ConsumerSupervisors, we can scale the rate of file processing independently of the rate of SQS request processing.
```
Attempting to start SQS.Server
Initializing SQS.Server supervision tree
Initalised SQS.Producer
SQS.Supervisor Pipeline1
SQS.Producer handling demand of 1
Asking for 1 events
There are currently 0 servers looping
All servers terminated
SQS.Supervisor Pipeline2
SQS.Supervisor Pipeline3
Started new server loop with pid #PID<0.191.0>
Server #PID<0.191.0> looping: Run 0. Looking for 1 events
Received 0 events
SQS.Producer handling demand of 1
Asking for 2 events
There are currently 1 servers looping
Terminating server with pid #PID<0.191.0>
All servers terminated
Server #PID<0.200.0> looping: Run 0. Looking for 2 events
Started new server loop with pid #PID<0.200.0>
Received 0 events
SQS.Producer handling demand of 1
Asking for 3 events
There are currently 1 servers looping
Terminating server with pid #PID<0.200.0>
All servers terminated
Server #PID<0.201.0> looping: Run 0. Looking for 3 events
Started new server loop with pid #PID<0.201.0>
Received 0 events
Server #PID<0.201.0> looping: Run 1. Looking for 3 events
Server #PID<0.201.0> looping: Run 2. Looking for 3 events
Server #PID<0.201.0> looping: Run 3. Looking for 3 events
Server #PID<0.201.0> looping: Run 4. Looking for 3 events
Casting events to producer
SQS.Producer got notified about 1 new events
Pipeline1 ProducerConsumer received 1 events
Pipeline1 ProducerConsumer downloaded packrat/data/20160730.gz
SQS.Producer handling demand of 1
Asking for 3 events
There are currently 1 servers looping
Terminating server with pid #PID<0.201.0>
All servers terminated
Server #PID<0.208.0> looping: Run 0. Looking for 3 events
Started new server loop with pid #PID<0.208.0>
Received 0 events
Pipeline1 Consumer processed packrat/data/20160730.gz
Casting events to producer
SQS.Producer got notified about 1 new events
Pipeline2 ProducerConsumer received 1 events
Pipeline2 ProducerConsumer downloaded packrat/data/20160728.gz
SQS.Producer handling demand of 1
Asking for 3 events
There are currently 1 servers looping
Terminating server with pid #PID<0.208.0>
All servers terminated
Server #PID<0.210.0> looping: Run 0. Looking for 3 events
Started new server loop with pid #PID<0.210.0>
Received 0 events
Pipeline2 Consumer processed packrat/data/20160728.gz
Casting events to producer
SQS.Producer got notified about 3 new events
Pipeline3 ProducerConsumer received 1 events
Pipeline3 ProducerConsumer downloaded packrat/data/20160723.gz
SQS.Producer handling demand of 1
Asking for 1 events
There are currently 0 servers looping
All servers terminated
Server #PID<0.212.0> looping: Run 0. Looking for 1 events
Started new server loop with pid #PID<0.212.0>
Received 0 events
Pipeline3 Consumer processed packrat/data/20160723.gz
Casting events to producer
SQS.Producer got notified about 1 new events
Pipeline2 ProducerConsumer received 1 events
Pipeline1 ProducerConsumer received 1 events
Pipeline2 ProducerConsumer downloaded packrat/data/20160729.gz
SQS.Producer handling demand of 1
Asking for 1 events
There are currently 0 servers looping
All servers terminated
Server #PID<0.217.0> looping: Run 0. Looking for 1 events
Started new server loop with pid #PID<0.217.0>
Received 0 events
Pipeline2 Consumer processed packrat/data/20160729.gz
Casting events to producer
SQS.Producer got notified about 1 new events
Pipeline2 ProducerConsumer received 1 events
Pipeline2 ProducerConsumer downloaded packrat/data/20160731.gz
SQS.Producer handling demand of 1
Asking for 1 events
There are currently 0 servers looping
All servers terminated
Server #PID<0.218.0> looping: Run 0. Looking for 1 events
Started new server loop with pid #PID<0.218.0>
Received 0 events
Pipeline2 Consumer processed packrat/data/20160731.gz
Casting events to producer
SQS.Producer got notified about 1 new events
Pipeline2 ProducerConsumer received 1 events
Pipeline2 ProducerConsumer downloaded packrat/data/20160721.gz
SQS.Producer handling demand of 1
Asking for 1 events
There are currently 0 servers looping
All servers terminated
Server #PID<0.221.0> looping: Run 0. Looking for 1 events
Started new server loop with pid #PID<0.221.0>
Received 0 events
Pipeline2 Consumer processed packrat/data/20160721.gz
Casting events to producer
SQS.Producer got notified about 1 new events
Pipeline2 ProducerConsumer received 1 events
Pipeline2 ProducerConsumer downloaded packrat/data/20160725.gz
SQS.Producer handling demand of 1
Asking for 1 events
There are currently 0 servers looping
All servers terminated
Server #PID<0.223.0> looping: Run 0. Looking for 1 events
Started new server loop with pid #PID<0.223.0>
Received 0 events
Pipeline2 Consumer processed packrat/data/20160725.gz
Casting events to producer
SQS.Producer got notified about 1 new events
Pipeline2 ProducerConsumer received 1 events
Pipeline2 ProducerConsumer downloaded packrat/data/20160727.gz
SQS.Producer handling demand of 1
Asking for 1 events
There are currently 0 servers looping
All servers terminated
Server #PID<0.226.0> looping: Run 0. Looking for 1 events
Started new server loop with pid #PID<0.226.0>
Received 0 events
Pipeline2 Consumer processed packrat/data/20160727.gz
Pipeline3 ProducerConsumer received 1 events
Casting events to producer
SQS.Producer got notified about 1 new events
Pipeline2 ProducerConsumer received 1 events
Pipeline3 ProducerConsumer downloaded packrat/data/20160720.gz
SQS.Producer handling demand of 1
Asking for 1 events
There are currently 0 servers looping
All servers terminated
Server #PID<0.227.0> looping: Run 0. Looking for 1 events
Started new server loop with pid #PID<0.227.0>
Received 0 events
Pipeline3 Consumer processed packrat/data/20160720.gz
Casting events to producer
SQS.Producer got notified about 1 new events
Pipeline3 ProducerConsumer received 1 events
Pipeline3 ProducerConsumer downloaded packrat/data/20160724.gz
SQS.Producer handling demand of 1
Asking for 1 events
There are currently 0 servers looping
All servers terminated
Server #PID<0.229.0> looping: Run 0. Looking for 1 events
Started new server loop with pid #PID<0.229.0>
Received 0 events
Pipeline3 Consumer processed packrat/data/20160724.gz
Pipeline1 ProducerConsumer downloaded packrat/data/20160726.gz
SQS.Producer handling demand of 1
Asking for 2 events
There are currently 1 servers looping
Terminating server with pid #PID<0.229.0>
All servers terminated
Server #PID<0.232.0> looping: Run 0. Looking for 2 events
Started new server loop with pid #PID<0.232.0>
Received 0 events
Pipeline1 Consumer processed packrat/data/20160726.gz
Pipeline2 ProducerConsumer downloaded packrat/data/20160722.gz
SQS.Producer handling demand of 1
Asking for 3 events
There are currently 1 servers looping
Terminating server with pid #PID<0.232.0>
All servers terminated
Server #PID<0.235.0> looping: Run 0. Looking for 3 events
Started new server loop with pid #PID<0.235.0>
Received 0 events
Pipeline2 Consumer processed packrat/data/20160722.gz
Server #PID<0.235.0> looping: Run 1. Looking for 3 events
Server #PID<0.235.0> looping: Run 2. Looking for 3 events
Server #PID<0.235.0> looping: Run 3. Looking for 3 events
...
```
