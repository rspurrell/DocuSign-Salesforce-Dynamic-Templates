@IsTest
private class DocuSignPDFGeneratorControllerTests
{
    static final string docuSignApiUrl = null;

    static
    {
        docuSignApiUrl = Utils.isSandbox() ? 'https://demo.docusign.net/restapi/v2/' : 'https://www.docusign.net/restapi/v2/';
    }

    @testSetup
    static void Init()
    {
        Account a = new Account(Name = 'Test Account', Terms__c = 'N30');
        insert a;

        Contact c = new Contact
        (
            AccountId = a.Id,
            FirstName = 'FirstName',
            LastName = 'LastName',
            Email = 'email@example.com'
        );
        insert c;

        Opportunity o = new Opportunity
        (
            AccountId = a.Id,
            CloseDate = Date.today(),
            Name = 'Test Opportunity',
            Pricebook2Id = Test.getStandardPricebookId(),
            Renewal_Contact__c = c.Id,
            Billing_Contact__c = c.Id,
            Shipping_Contact__c = c.Id,
            StageName = OpportunityHelper.STAGE_VALIDATE
        );
        insert o;

        Product2 prod = new Product2(Name = 'Test Product');
        insert prod;

        PricebookEntry pbe = new PricebookEntry
        (
            IsActive = true,
            Pricebook2Id = Test.getStandardPricebookId(),
            Product2Id = prod.Id,
            UnitPrice = 100
        );
        insert pbe;
    }

    static testMethod void ShouldGenerateTemplate()
    {
        MockHttpResponse mhr = new MockHttpResponse();
        mhr.AddEndpointMethodResponse(docuSignApiUrl + 'login_information', 'GET', 200, 'application/json', '{"loginAccounts":[{"name":"Ipswitch, Inc.","accountId":"2023521","baseUrl":"' + docuSignApiUrl +'accounts/2023521","isDefault":"true","userName":"Roger Spurrell","userId":"34c2517d-f641-4271-a0d4-bdabb3db04a5","email":"rspurrell@ipswitch.com","siteDescription":""}]}');
        mhr.AddEndpointMethodResponse(docuSignApiUrl + 'accounts/2023521/templates', 'POST', 201, 'application/json', '{"templateId":"c3fa66cc-c947-48fa-8150-65db2f1b3723","name":"Opportunity 006m0000007JtEp","uri":"/templates/c3fa66cc-c947-48fa-8150-65db2f1b3723"}');
        mhr.AddEndpointMethodResponse(docuSignApiUrl + 'accounts/2023521/templates/c3fa66cc-c947-48fa-8150-65db2f1b3723/recipients/1/tabs', 'POST', 201, 'application/json', '');

        ID oppId = [SELECT Id FROM Opportunity LIMIT 1].Id;

        Test.setMock(HttpCalloutMock.class, mhr);
        Test.setCurrentPage(new PageReference('/apex/DocuSignPDFGeneratorController?id=' + oppId));
        Test.startTest();

        DocuSignPDFGeneratorController dsPDFGenCont = new DocuSignPDFGeneratorController();
        PageReference result = dsPDFGenCont.Execute();

        Test.stopTest();
    }

    static testMethod void ShouldErrorWithAccountExceptions()
    {
        Opportunity o = [SELECT Id, Renewal_Contact__r.Id, Billing_Contact__r.Id, Shipping_Contact__r.Id FROM Opportunity LIMIT 1];
        //o.AccountId = null;
        o.Renewal_Contact__r.AccountId = null;
        o.Billing_Contact__r.AccountId = null;
        o.Shipping_Contact__r.AccountId = null;
        //update o;
        update new List<Contact>(new Set<Contact> { o.Renewal_Contact__r, o.Billing_Contact__r, o.Shipping_Contact__r });

        Test.setCurrentPage(new PageReference('/apex/DocuSignPDFGeneratorController?a=render&id=' + o.Id));
        Test.startTest();

        DocuSignPDFGeneratorController dsPDFGenCont = new DocuSignPDFGeneratorController();
        try
        {
            PageReference result = dsPDFGenCont.Execute();
        }
        catch (CustomException ce)
        {//An account must be specified.;
            System.assertEquals('This opportunity has no line items.;The billing contact has no account.;The shipping contact has no account.;', ce.getMessage(), 'Incorrect exception message.');
        }

        Test.stopTest();
    }

    static testMethod void ShouldErrorWithContactAndTermsExceptions()
    {
        Opportunity o = [SELECT Id FROM Opportunity LIMIT 1];
        o.Terms__c = null;
        o.Renewal_Contact__c = null;
        o.Billing_Contact__c = null;
        o.Shipping_Contact__c = null;
        update o;

        Test.setCurrentPage(new PageReference('/apex/DocuSignPDFGeneratorController?a=render&id=' + o.Id));
        Test.startTest();

        DocuSignPDFGeneratorController dsPDFGenCont = new DocuSignPDFGeneratorController();
        try
        {
            PageReference result = dsPDFGenCont.Execute();
        }
        catch (CustomException ce)
        {
            System.assertEquals('This opportunity has no line items.;This opportunity has no terms specified.;A billing contact must be specified.;A shipping contact must be specified.;', ce.getMessage(), 'Incorrect exception message.');
        }

        Test.stopTest();
    }

    static testMethod void ShouldErrorWithLineItemAndAddressExceptions()
    {
        ID oppId = [SELECT Id FROM Opportunity LIMIT 1].Id;

        Test.setCurrentPage(new PageReference('/apex/DocuSignPDFGeneratorController?a=render&id=' + oppId));
        Test.startTest();

        DocuSignPDFGeneratorController dsPDFGenCont = new DocuSignPDFGeneratorController();
        try
        {
            PageReference result = dsPDFGenCont.Execute();
        }
        catch (CustomException ce)
        {
            System.assertEquals('This opportunity has no line items.;The billing account\'s billing street is empty.;The billing account\'s billing city is empty.;The billing account\'s billing country is empty.;The shipping account\'s shipping street is empty.;The shipping account\'s shipping city is empty.;The shipping account\'s shipping country is empty.;', ce.getMessage(), 'Incorrect exception message.');
        }

        Test.stopTest();
    }

    static testMethod void ShouldErrorWithQuoteUnapproved()
    {
        ID oppId = [SELECT Id FROM Opportunity LIMIT 1].Id;

        BigMachines__Configuration_Record__c site = TestMethodUtil.CreateCpqSiteConfigRecord();
        TestMethodUtil.CreateCpqQuote(site.Id, oppId, true, 0.00, 'Pending');

        Test.setCurrentPage(new PageReference('/apex/DocuSignPDFGeneratorController?a=render&id=' + oppId));
        Test.startTest();

        DocuSignPDFGeneratorController dsPDFGenCont = new DocuSignPDFGeneratorController();
        try
        {
            PageReference result = dsPDFGenCont.Execute();
        }
        catch (CustomException ce)
        {
            System.assert(ce.getMessage().contains('The primary quote on this opportunity must be approved.'), 'Exception message does not contain "The primary quote on this opportunity must be approved".');
        }

        Test.stopTest();
    }

    static testMethod void ShouldRenderDocumentSuccessfully()
    {
        Opportunity opp = [SELECT Id, Pricebook2Id, Billing_Contact__r.Account.Id FROM Opportunity LIMIT 1];
        PricebookEntry pbe = [SELECT Id, UnitPrice FROM PricebookEntry WHERE Pricebook2Id = :opp.Pricebook2Id LIMIT 1];

        OpportunityLineItem oli = new OpportunityLineItem
        (
            OpportunityId = opp.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 1,
            UnitPrice = pbe.UnitPrice
        );
        insert oli;

        Account a = opp.Billing_Contact__r.Account;
        a.BillingCity = a.ShippingCity = 'Lexington';
        a.BillingCountryCode = a.ShippingCountryCode = 'US';
        a.BillingPostalCode = a.ShippingPostalCode = '01824';
        a.BillingStateCode = a.ShippingStateCode = 'MA';
        a.BillingStreet = a.ShippingStreet = '83 Hartwell Ave.';
        update a;

        Test.setCurrentPage(new PageReference('/apex/DocuSignPDFGeneratorController?a=render&id=' + opp.Id));
        Test.startTest();

        DocuSignPDFGeneratorController dsPDFGenCont = new DocuSignPDFGeneratorController();
        PageReference result = dsPDFGenCont.Execute();

        Test.stopTest();
    }
}