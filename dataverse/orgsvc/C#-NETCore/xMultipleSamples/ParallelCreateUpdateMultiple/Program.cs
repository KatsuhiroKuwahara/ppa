﻿using Microsoft.Extensions.Configuration;
using Microsoft.PowerPlatform.Dataverse.Client;
using Microsoft.Xrm.Sdk;
using Microsoft.Xrm.Sdk.Messages;
using System.Collections.Concurrent;
using System.Diagnostics;

namespace PowerPlatform.Dataverse.CodeSamples
{
    class Program
    {
        /// <summary>
        /// Contains the application's configuration settings. 
        /// </summary>
        IConfiguration Configuration { get; }


        /// <summary>
        /// Constructor. Loads the application configuration settings from a JSON file.
        /// </summary>
        Program()
        {

            // Get the path to the appsettings file. If the environment variable is set,
            // use that file path. Otherwise, use the runtime folder's settings file.
            string? path = Environment.GetEnvironmentVariable("DATAVERSE_APPSETTINGS");
            path ??= "appsettings.json";

            // Load the app's configuration settings from the JSON file.
            Configuration = new ConfigurationBuilder()
                .AddJsonFile(path, optional: false, reloadOnChange: true)
                .Build();
        }
        static void Main()
        {
            Program app = new();

            int numberOfRecords = Settings.NumberOfRecords; //100 by default
            string tableSchemaName = "sample_Example";
            string tableLogicalName = tableSchemaName.ToLower(); //sample_example
            int chunkSize = Settings.BatchSize; // Configurable batch size, 1000 by default

            #region Optimize Connection settings

            //Change max connections from .NET to a remote service default: 2
            System.Net.ServicePointManager.DefaultConnectionLimit = 65000;
            //Bump up the min threads reserved for this app to ramp connections faster - minWorkerThreads defaults to 4, minIOCP defaults to 4
            ThreadPool.SetMinThreads(100, 100);
            //Turn off the Expect 100 to continue message - 'true' will cause the caller to wait until it round-trip confirms a connection to the server
            System.Net.ServicePointManager.Expect100Continue = false;
            //Can decreas overall transmission overhead but can cause delay in data packet arrival
            System.Net.ServicePointManager.UseNagleAlgorithm = false;

            #endregion Optimize Connection settings

            // Create a Dataverse service client using the default connection string.
            ServiceClient serviceClient =
                new(app.Configuration.GetConnectionString("default"))
                {
                    // Disable affinity cookie for these operations.
                    EnableAffinityCookie = false,
                    // Avoids issues when working with tables created and deleted recently.
                    UseWebApi = false
                };


            // Create sample_Example table for this sample.
            Utility.CreateExampleTable(
                service: serviceClient,
                tableSchemaName: tableSchemaName);

            // Create a List of entity instances.
            Console.WriteLine($"Preparing {numberOfRecords} records to create..\n");
            List<Entity> entityList = new();
            // Populate the list with the number of records to test.
            for (int i = 0; i < numberOfRecords; i++)
            {
                entityList.Add(new Entity(tableLogicalName)
                {
                    Attributes = {
                            // Example: 'sample record 0000001'
                            { "sample_name", $"sample record {i+1:0000000}" }
                        }
                });
            }

            Console.WriteLine($"RecommendedDegreesOfParallelism:{serviceClient.RecommendedDegreesOfParallelism}");

            Console.WriteLine($"\nSending create requests in parallel...");
            Stopwatch createStopwatch = Stopwatch.StartNew();
    
            Parallel.ForEach(entityList.Chunk(chunkSize),
                new ParallelOptions()
                {
                    MaxDegreeOfParallelism = serviceClient.RecommendedDegreesOfParallelism
                },
                () =>
                {
                    //Clone the ServiceClient for each thread
                    return serviceClient.Clone();
                },
                (entities, loopState, index, threadLocalSvc) =>
                {


                    // In each thread, create entities and update the Id.
                    CreateMultipleRequest createMultipleRequest = new()
                    {
                        Targets = new(entities)
                        {
                            EntityName = tableLogicalName
                        }
                    };
                    // Add Shared Variable with request to detect in a plug-in.
                    createMultipleRequest["tag"] = "ParallelCreateUpdateMultiple";
                    if (Settings.BypassCustomPluginExecution)
                    {
#pragma warning disable CS0162 // Unreachable code detected: Configurable by setting
                        createMultipleRequest["BypassCustomPluginExecution"] = true;
#pragma warning restore CS0162 // Unreachable code detected: Configurable by setting
                    }
                    var createMultipleResponse = (CreateMultipleResponse)threadLocalSvc.Execute(createMultipleRequest);

                    // Set the id values for the entities
                    for(int i = 0; i < entities.Length; i++)
                    {
                        entities[i].Id = createMultipleResponse.Ids[i];
                    }

                    return threadLocalSvc;
                },
                (threadLocalSvc) =>
                {
                    //Dispose the cloned ServiceClient instance
                    threadLocalSvc?.Dispose();
                });
            createStopwatch.Stop();

            Console.WriteLine($"\tCreated {entityList.Count} records " +
                $"in {Math.Round(createStopwatch.Elapsed.TotalSeconds)} seconds.");

            Console.WriteLine($"\nPreparing {numberOfRecords} records to update..");

            // Update the sample_name value:
            foreach (Entity entity in entityList)
            {
                entity["sample_name"] += " Updated";
            }

            Console.WriteLine($"Sending update requests in parallel...");
            Stopwatch updateStopwatch = Stopwatch.StartNew();

            Parallel.ForEach(entityList.Chunk(chunkSize),
                new ParallelOptions()
                {
                    MaxDegreeOfParallelism = serviceClient.RecommendedDegreesOfParallelism
                },
                () =>
                {
                    //Clone the ServiceClient for each thread
                    return serviceClient.Clone();
                },
                (entities, loopState, index, threadLocalSvc) =>
                {
                    // In each thread, update the entities
                    

                    UpdateMultipleRequest updateMultipleRequest = new()
                    {
                        Targets = new EntityCollection(entities) {
                            EntityName = tableLogicalName
                        }
                    };

                    // Add Shared Variable with request to detect in a plug-in.
                    updateMultipleRequest["tag"] = "ParallelCreateUpdateMultiple";

                    if (Settings.BypassCustomPluginExecution)
                    {
#pragma warning disable CS0162 // Unreachable code detected: Configurable by setting
                        updateMultipleRequest["BypassCustomPluginExecution"] = true;
#pragma warning restore CS0162 // Unreachable code detected: Configurable by setting
                    }

                    threadLocalSvc.Execute(updateMultipleRequest);

                    return threadLocalSvc;
                },
                (threadLocalSvc) =>
                {
                    //Dispose the cloned CrmServiceClient instance
                    threadLocalSvc?.Dispose();
                });
            updateStopwatch.Stop();
            Console.WriteLine($"\tUpdated {numberOfRecords} records " +
                $"in {Math.Round(updateStopwatch.Elapsed.TotalSeconds)} seconds.");

            // Delete created rows asynchronously
            Console.WriteLine($"\nStarting asynchronous bulk delete of {numberOfRecords} created records...");

            Guid[] iDs = new Guid[entityList.Count];

            for (int i = 0; i < entityList.Count; i++)
            {
                iDs[i] = entityList.ToList()[i].Id;
            }


            string deleteJobStatus = Utility.BulkDeleteRecordsByIds(
                service: serviceClient,
                tableLogicalName: tableLogicalName,
                iDs: iDs,
                jobName: "Deleting records created by ParallelCreateUpdate Sample.");

            Console.WriteLine($"\tBulk Delete status: {deleteJobStatus}");


            // Delete sample_example table
            Utility.DeleteExampleTable(
                service: serviceClient,
                tableSchemaName: tableSchemaName);
        }
    }
}