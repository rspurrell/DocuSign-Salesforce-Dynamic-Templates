# Dynamic DocuSign Template Generator for Salesforce
A dynamic DocuSign template generator for Salesforce.

## Install the DocuSign Managed Package
Install the [DocuSign eSignature for Salesforce](https://appexchange.salesforce.com/appxListingDetail?listingId=a0N30000001taX4EAI) managed package in your sandbox instance. Configure the managed package with a dedicated API integration user to connect with your DocuSign demo account.

## Legacy Authentication Setup
At the time of writing this README I have discovered that DocuSign has updated their [authentication methods](https://developers.docusign.com/platform/auth/) to use OAuth 2.0 (about time). What this means for you is that going forward, with new implementations, the current authentication method will not be supported. A [JWT Grant](https://developers.docusign.com/platform/auth/jwt/) would be the appropriate choice for this application.

Regardless, here is the current legacy authentication setup steps.

Create/load the `objects/DocuSign_Setting__mdt` metadata object into your sandbox instance. Add a new metadata entry for sandbox and production.

### Sandbox
1. **Label** and **Name**: `Test` for your sandbox instance
1. **Base URI**: `https://demo.docusign.net/restapi/v2/`
1. **Account ID**: your API Account ID available at https://admindemo.docusign.com/api-integrator-key
1. **Integrator Key**: your Integration Key available at https://admindemo.docusign.com/api-integrator-key
1. **User ID**: the login name (usually email address. Not your SF username) you used create your DocuSign demo account.
1. **Password**: your DocuSign demo password.

### Production
1. **Label** and **Name**: `Production` for your production instance.
1. **Base URI**: `https://www.docusign.net/restapi/v2/`
1. **Account ID**: your API Account ID available at https://admin.docusign.com/api-integrator-key
1. **Integrator Key**: your Integration Key available at https://admin.docusign.com/api-integrator-key
1. **User ID**: the login name (usually email address. Not your SF username) you used create your DocuSign production account.
1. **Password**: your DocuSign production password.

## Object Setup
Create/load the custom opportunity fields in `objects/Opportunity/fields`.

## APEX Class Setup
Create/load the following classes, page, and trigger in order:
1. `class/MockHttpResponse.cls`
1. `class/Utils.cls`
1. `class/DocuSignRestAPI.cls`
1. `class/DocuSignRestAPITests.cls`
1. `class/DocuSignPDFGeneratorController.cls`
1. `class/DocuSignPDFGeneratorControllerTests.cls`
1. `class/DocuSignStatusTriggerHandler.cls`
1. `class/DocuSignStatusTriggerHandlerTests.cls`
1. `pages/DocuSignPDFGenerator.page`
1. `triggers/DocuSignStatus.trigger`

## Custom Send with DocuSign Setup
Create/load the button in `objects/Opportunity/webLinks`.

## Using

### Previewing the Template
To preview the template you'll need to access the Visualforce page by adding `/apex/DocuSignPDFGenerator` immediately after the `.com` of your instance URL. You'll also need to add the following query string parameters:
- `id=` followed by the ID of the opportunity.
- `a=render`
- `ra=pdf` or `ra=html`. The PDF render is what would be sent to DocuSign. The HTML render can help with debugging your template.

The end of your URI should look something like this `...force.com/apex/DocuSignPDFGenerator?id=006400000XXXABC&a=render&ra=pdf`

### Using the Template with DocuSign
Add the custom **Send with DocuSign** button to your opportunity layout. Works best in Lightning, but also works fine in classic. Click the button when on an open opportunity. If all validation checks in the `DocuSignPDFGeneratorController.ValidateOpportunity` method pass, then the PDF render of the template will be sent to DocuSign. You'll then be redirected to the DocuSign eSignature managed package application with the completed template as your document.
