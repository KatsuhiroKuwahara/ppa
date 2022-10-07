﻿using PowerApps.Samples;
using PowerApps.Samples.Messages;
using PowerApps.Samples.Metadata.Messages;
using PowerApps.Samples.Metadata.Types;
using PowerApps.Samples.Methods;

namespace RetrieveMetadataChanges
{
    internal class Program
    {
        static async Task Main()
        {
            Config config = App.InitializeApp();

            var service = new Service(config);

            // A simple list of column definitions to represent the cache
            List<ComplexAttributeMetadata> cachedAttributes = new();
            string clientVersionStamp = string.Empty;
            // The name of a column to create when demonstrating changes
            string choiceColumnSchemaName = "sample_ChoiceColumnForSample";
            // Language code value from usersettingscollection.
            int? userLanguagePreference = await RetrieveUserUILanguageCode(service);

            #region Define query

            // Define query for all Picklist Choice columns from Contact table
            var query = new EntityQueryExpression
            {
                Properties = new MetadataPropertiesExpression("LogicalName", "Attributes"),
                Criteria = new MetadataFilterExpression(filterOperator: LogicalOperator.And)
                {
                    Conditions = new List<MetadataConditionExpression>{
                        {
                            new MetadataConditionExpression(
                                propertyName:"LogicalName",
                                conditionOperator: MetadataConditionOperator.Equals,
                                value: new PowerApps.Samples.Metadata.Types.Object{
                                        Type = ObjectType.String,
                                        Value = "contact"
                                    }
                                )
                        }
                    }
                },
                AttributeQuery = new AttributeQueryExpression
                {
                    Properties = new MetadataPropertiesExpression("LogicalName", "OptionSet", "AttributeTypeName"),
                    Criteria = new MetadataFilterExpression(filterOperator: LogicalOperator.And)
                    {
                        Conditions = new List<MetadataConditionExpression>{
                            {
                                // Only Picklist Option type
                                new MetadataConditionExpression(
                                    propertyName:"AttributeTypeName",
                                    conditionOperator:MetadataConditionOperator.Equals,
                                    value: new PowerApps.Samples.Metadata.Types.Object(
                                        type:ObjectType.AttributeTypeDisplayName,
                                        value:"PicklistType")
                                    )
                            }
                        }
                    }
                }
            };

            // Return only user language if they have a preference.
            if (userLanguagePreference.HasValue)
            {
                query.LabelQuery = new LabelQueryExpression
                {
                    FilterLanguages = new List<int>() { userLanguagePreference.Value }
                };
            }

            #endregion Define query

            #region Initialize cache

            var initialRequest = new RetrieveMetadataChangesRequest { Query = query };

            var initialResponse = await service.SendAsync<RetrieveMetadataChangesResponse>(initialRequest);

            Console.WriteLine($"Columns in initial response:{initialResponse.EntityMetadata.FirstOrDefault().Attributes.Count()}");

            // Initialize the cache
            cachedAttributes = initialResponse.EntityMetadata.FirstOrDefault().Attributes.ToList();

            // Set the client version
            clientVersionStamp = initialResponse.ServerVersionStamp;

            #endregion Initialize cache

            #region Add Choice column

            Console.WriteLine($"\nAdding a new choice column named {choiceColumnSchemaName}...");
            // Add a new Choice column
            var choiceColumn = new PicklistAttributeMetadata()
            {
                SchemaName = choiceColumnSchemaName,
                DisplayName = new Label("Choice column for sample", 1033),
                RequiredLevel = new AttributeRequiredLevelManagedProperty(AttributeRequiredLevel.None),
                Description = new Label("Description", 1033),
                OptionSet = new OptionSetMetadata
                {
                    IsGlobal = false,
                    OptionSetType = OptionSetType.Picklist,
                    Options = new List<OptionMetadata>
                    {
                        new OptionMetadata{
                            Label = new ("Choice 1", 1033)
                        },
                        new OptionMetadata{
                            Label = new ("Choice 2", 1033)
                        },
                        new OptionMetadata{
                            Label = new ("Choice 3", 1033)
                        }
                    }
                }
            };

            var createChoiceColumnRequest = new CreateAttributeRequest(
                entityLogicalName: "contact", 
                attributeMetadata: choiceColumn);

            await service.SendAsync(createChoiceColumnRequest);

            Console.WriteLine($"\nCreated Choice column: {choiceColumnSchemaName}");

            #endregion Add Choice column

            #region Detect added column

            // Detect changes
            var secondRequest = new RetrieveMetadataChangesRequest
            {
                Query = query, //Same query as before
                // This time passing client version stamp value from previous request
                ClientVersionStamp = clientVersionStamp,
                DeletedMetadataFilters = DeletedMetadataFilters.All
            };

            RetrieveMetadataChangesResponse secondResponse;

            try
            {
                secondResponse = await service.SendAsync<RetrieveMetadataChangesResponse>(secondRequest);
                // Re-set the client version stamp
                clientVersionStamp = secondResponse.ServerVersionStamp;
            }
            catch (ServiceException ex)
            {
                // Check for ErrorCodes.ExpiredVersionStamp (0x80044352)
                // Message: Version stamp associated with the client has expired. Please perform a full sync.
                // Will occur when the timestamp exceeds the Organization.ExpireSubscriptionsInDays value, which is 90 by default.
                if (ex.ODataError.Error.Code == "0x80044352")
                {
                    // TODO
                    // Add code to re-initialize cache
                    return;

                }
                else
                {
                    throw ex;
                }
            }

            // There should be only one representing the choice column just added
            Console.WriteLine($"\nColumns in second response:{secondResponse.EntityMetadata.FirstOrDefault().Attributes.Count}");

            // Update cache to add new items.
            secondResponse.EntityMetadata.FirstOrDefault().Attributes.ToList().ForEach(att =>
            {
                if (!cachedAttributes.Contains(att))
                {
                    cachedAttributes.Add(att);
                }
            });

            // List the current cached Choice columns
            Console.WriteLine($"\nThe current cached choice columns:");
            cachedAttributes
                .ForEach(att =>
                {
                    Console.WriteLine($"\t{att.LogicalName}");
                });
            #endregion Detect added column

            #region Delete Choice Column
            Console.WriteLine($"\nDeleting the choice column named {choiceColumnSchemaName}...");

            var deleteChoiceColumnRequest = new DeleteAttributeRequest(
                entityLogicalName: "contact",
                logicalName: choiceColumnSchemaName.ToLower());

            await service.SendAsync(deleteChoiceColumnRequest);

            Console.WriteLine($"\nDeleted choice column: {choiceColumnSchemaName}");

            #endregion Delete Choice Column

            #region Detect deleted column

            var thirdRequest = new RetrieveMetadataChangesRequest
            {
                Query = query,
                // This time passing client version stamp value from previous request
                ClientVersionStamp = clientVersionStamp,
                DeletedMetadataFilters = DeletedMetadataFilters.Attribute
            };


            RetrieveMetadataChangesResponse thirdResponse;
            try
            {
                thirdResponse = await service.SendAsync<RetrieveMetadataChangesResponse>(thirdRequest);
                // Re-set the client version stamp
                clientVersionStamp = thirdResponse.ServerVersionStamp;

            }
            catch (ServiceException ex)
            {
                // Check for ErrorCodes.ExpiredVersionStamp (0x80044352)
                // Message: Version stamp associated with the client has expired. Please perform a full sync.
                // Will occur when the timestamp exceeds the Organization.ExpireSubscriptionsInDays value, which is 90 by default.
                if (ex.ODataError.Error.Code == "0x80044352")
                {
                    // TODO
                    // Add code to re-initialize cache
                    return;

                }
                else
                {
                    throw ex;
                }
            }

            // Remove deleted choice column from the cache
            thirdResponse.DeletedMetadata[DeletedMetadataFilters.Attribute]
                .ToList()
                .ForEach(guidCollection =>
                {
                    guidCollection.Items.ForEach(id => {
                        cachedAttributes.RemoveAll(a => a.MetadataId == id);
                    });
                });

            // List the current cached options again.
            // The deleted choice column is no longer cached.
            Console.WriteLine($"\nThe current cached choice columns:");
            cachedAttributes
                .ForEach(att =>
                {
                    Console.WriteLine($"\t{att.LogicalName}");
                });

            Console.WriteLine($"\nNotice that '{choiceColumnSchemaName.ToLower()}' is no longer included.");

            #endregion Detect deleted column

        }
        protected static async Task<int?> RetrieveUserUILanguageCode(Service service) {

            var whoIAm = await service.SendAsync<WhoAmIResponse>(new WhoAmIRequest());

            RetrieveMultipleResponse response =
                await service.RetrieveMultiple($"usersettingscollection?" +
                $"$select=uilanguageid&$filter=systemuserid eq {whoIAm.UserId}&$top=1&$count=true");

            if (response.Count > 0) {
                return (int)response.Records[0]["uilanguageid"];
            }
            return null;        
        }
    }
}