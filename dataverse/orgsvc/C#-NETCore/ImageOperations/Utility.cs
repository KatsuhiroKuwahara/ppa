﻿using Microsoft.Xrm.Sdk;
using Microsoft.Xrm.Sdk.Messages;
using Microsoft.Xrm.Sdk.Metadata;
using System.ServiceModel;

namespace PowerPlatform.Dataverse.CodeSamples
{
    public class Utility
    {

        /// <summary>
        /// Creates an image column that is the primary image column.
        /// </summary>
        /// <param name="service">The service.</param>
        /// <param name="entityLogicalName">The logical name of the table to create the image column in.</param>
        /// <param name="imageColumnSchemaName">The schema name of the image column.</param>
        public static void CreateImageColumn(IOrganizationService service, string entityLogicalName, string imageColumnSchemaName)
        {
            Console.WriteLine($"Creating image column named '{imageColumnSchemaName}' on the {entityLogicalName} table ...");

            ImageAttributeMetadata imageColumn = new()
            {
                SchemaName = imageColumnSchemaName,
                DisplayName = new Label("Sample Image Column", 1033),
                RequiredLevel = new AttributeRequiredLevelManagedProperty(
                      AttributeRequiredLevel.None),
                Description = new Label("Sample Image Column for ImageOperation samples", 1033),
                //IsPrimaryImage = true, // Overriding current primary image column?? Doesn't seem to work on Create, at least when another primary image attribute exists.
                MaxSizeInKB = 30 * 1024 // 30 MB is maximum size.

            };

            CreateAttributeRequest createfileColumnRequest = new()
            {
                EntityName = entityLogicalName,
                Attribute = imageColumn
            };

            try
            {
                service.Execute(createfileColumnRequest);
                Console.WriteLine($"Created image column named '{imageColumnSchemaName}' in the {entityLogicalName} table.");
            }
            catch (Exception ex)
            {
                if (ex is FaultException<OrganizationServiceFault> faultException)
                {
                    
                    int errorCode = faultException.Detail.ErrorCode;
                    if (errorCode == -2147192813)
                    {
                        // DuplicateAttributeSchemaName error
                        Console.WriteLine($"Column named '{imageColumnSchemaName}' already exists in the {entityLogicalName} table.");
                    }
                    else
                    {
                        throw ex;
                    }                    
                }
                else
                {
                    throw ex;
                }
            }                       
        }


        /// <summary>
        /// Deletes an image column
        /// </summary>
        /// <param name="service">The service.</param>
        /// <param name="entityLogicalName">The logical name of the table the image column exists in.</param>
        /// <param name="imageColumnSchemaName">The schema name of the image column.</param>
        public static void DeleteImageColumn(IOrganizationService service, string entityLogicalName, string imageColumnSchemaName)
        {

            Console.WriteLine($"Deleting the image column named '{imageColumnSchemaName}' on the {entityLogicalName} table ...");

            DeleteAttributeRequest deleteImageColumnRequest = new()
            {
                EntityLogicalName = entityLogicalName,
                LogicalName = imageColumnSchemaName.ToLower(),

            };

            service.Execute(deleteImageColumnRequest);

            Console.WriteLine($"Deleted the image column named '{imageColumnSchemaName}' in the {entityLogicalName} table.");

        }


        /// <summary>
        /// Update the CanStoreFullImage for a image column
        /// </summary>
        /// <param name="service">The service</param>
        /// <param name="entityLogicalName">The logical name of the table that has the column.</param>
        /// <param name="imageColumnSchemaName">The logical name of the image column.</param>
        /// <param name="canStoreFullImage">The new value for CanStoreFullImage</param>
        public static void UpdateCanStoreFullImage(IOrganizationService service, string entityLogicalName, string imageColumnSchemaName, bool canStoreFullImage)
        {

            RetrieveAttributeRequest retrieveAttributeRequest = new()
            {
                EntityLogicalName = entityLogicalName,
                LogicalName = imageColumnSchemaName.ToLower()
            };

            var retrieveAttributeResponse = (RetrieveAttributeResponse)service.Execute(retrieveAttributeRequest);

            var imageColumn = (ImageAttributeMetadata)retrieveAttributeResponse.AttributeMetadata;

            imageColumn.CanStoreFullImage = canStoreFullImage;

            UpdateAttributeRequest updateAttributeRequest = new()
            {
                EntityName = entityLogicalName,
                Attribute = imageColumn
            };

            service.Execute(updateAttributeRequest);

            Console.WriteLine($"Set the CanStoreFullImage property to {canStoreFullImage}");

        }


        /// <summary>
        /// Gets the name of the primary image column for the table
        /// </summary>
        /// <param name="service">he service</param>
        /// <param name="entityLogicalName">The logical name of the table that has the column.</param>
        /// <returns>The EntityMetadata.PrimaryImageAttribute value.</returns>
        public static string GetTablePrimaryImageName(IOrganizationService service, string entityLogicalName) {

            RetrieveEntityRequest request = new RetrieveEntityRequest { 
                EntityFilters= EntityFilters.Entity,
                LogicalName= entityLogicalName
            };

            RetrieveEntityResponse response = (RetrieveEntityResponse)service.Execute(request);

            return response.EntityMetadata.PrimaryImageAttribute;        
        }

        public static void SetTablePrimaryImageName(IOrganizationService service, string entityLogicalName, string imageAttributeName, bool isPrimaryImage)
        {

            RetrieveAttributeRequest retrieveRequest = new RetrieveAttributeRequest
            {
                EntityLogicalName= entityLogicalName,
                LogicalName = imageAttributeName
            };

            RetrieveAttributeResponse retrieveResponse = (RetrieveAttributeResponse)service.Execute(retrieveRequest);

            ImageAttributeMetadata imageColumnDefinition = (ImageAttributeMetadata)retrieveResponse.AttributeMetadata;

            imageColumnDefinition.IsPrimaryImage= isPrimaryImage;

            UpdateAttributeRequest updateAttributeRequest = new UpdateAttributeRequest() {
                EntityName = entityLogicalName,
                Attribute = imageColumnDefinition
            };

            service.Execute(updateAttributeRequest);

        }



    }
}
