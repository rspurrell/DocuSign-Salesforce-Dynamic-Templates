@isTest
private class DocuSignStatusTriggerHandlerTests
{
    @testSetup
    private static void Init()
    {
        Account a = new Account
        (
            Name = name,
            BillingStreet = '123 Your Company, Inc.', BillingCity = 'Boston', BillingCountry = 'USA', BillingCountryCode = 'US', BillingStateCode = 'MA', BillingPostalCode = '02101',
            ShippingStreet = '123 Your Company, Inc.', ShippingCity = 'Boston', ShippingCountry = 'USA', ShippingCountryCode = 'US', ShippingStateCode = 'MA', ShippingPostalCode = '02101'
        );
        insert a;

        Contact c = new Contact
        (
            AccountId = a.Id,
            FirstName = 'fname',
            LastName='lname',
            Email = 'testemail@example.com',
            Phone = '1234567890',
            MailingStreet = a.BillingStreet,
            MailingCity = a.BillingCity,
            MailingCountry = a.BillingCountry,
            MailingState = a.BillingState,
            MailingPostalCode = a.BillingPostalCode
        );
        insert c;

        Opportunity o = new Opportunity
        (
            Name = 'testopp' + datetime.now(),
            Pricebook2Id = Test.getStandardPricebookId(),
            StageName = 'New',
            CloseDate = closeDate,
            AccountId = accountId,
            ContactId = c.Id,
            Billing_Contact__c = c.Id,
            Shipping_Contact__c = c.Id
        );
        insert o;

        Product2 p = new Product2(ProductCode='PROD-9876-5432', Name='Test Product');
        insert p;

        PricebookEntry pbe = new PricebookEntry(IsActive=true, Pricebook2Id=Test.getStandardPricebookId(), Product2Id=p.Id, CurrencyISOCode='USD', UnitPrice=1000.00);
        insert pbe;

        OpportunityLineItem oli = new OpportunityLineItem(OpportunityId=o.Id, PricebookEntryId=pbe.Id, Quantity=1, UnitPrice=pbe.UnitPrice);
        insert oli;
    }

    static testMethod void ShouldCreateStatusWithNoOppId()
    {
        dsfs__DocuSign_Status__c status = new dsfs__DocuSign_Status__c(dsfs__Envelope_Status__c='Sent');

        Test.startTest();
        insert status;
        Test.stopTest();
    }

    static testMethod void ShouldCreateVoidedStatusAndUpdateWithNoStageChange()
    {
        Opportunity o = [SELECT Id, StageName FROM Opportunity LIMIT 1];
        String initialStageName = o.StageName;

        dsfs__DocuSign_Status__c status = new dsfs__DocuSign_Status__c(dsfs__Opportunity__c=o.Id, dsfs__Envelope_Status__c='Voided');
        Test.startTest();
        insert status;
        update status;
        Test.stopTest();

        o = [SELECT Id, StageName FROM Opportunity WHERE Id = :o.Id];
        System.assertEquals(initialStageName, o.StageName, 'Opportunity stage should not have changed.');
    }

    static testMethod void ShouldCreateStatusAndUpdateStage()
    {
        Opportunity o = [SELECT Id FROM Opportunity LIMIT 1];
        dsfs__DocuSign_Status__c status = new dsfs__DocuSign_Status__c(dsfs__Opportunity__c=o.Id, dsfs__Envelope_Status__c='Sent');
        Test.startTest();
        insert status;
        update status;
        Test.stopTest();

        o = [SELECT Id, StageName FROM Opportunity WHERE Id = :o.Id];
        System.assertEquals(OpportunityHelper.STAGE_VALIDATE, o.StageName, 'Opportunity stage should be ' + OpportunityHelper.STAGE_VALIDATE + '.');
    }

    static testMethod void ShouldCreateStatusAndUpdateWithComplete()
    {
        ID oppId = [SELECT Id FROM Opportunity LIMIT 1].Id;
        dsfs__DocuSign_Status__c status = new dsfs__DocuSign_Status__c(dsfs__Opportunity__c=oppId, dsfs__Envelope_Status__c='Delivered');

        Test.startTest();
        insert status;
        status.dsfs__Envelope_Status__c = 'Completed';
        update status;
        Test.stopTest();

        Opportunity o = [SELECT Id, StageName FROM Opportunity WHERE Id = :oppId];

        Order ord = [SELECT Id FROM Order WHERE OpportunityId = :o.Id];
        System.assertNotEquals(null, ord, 'An order should be generated from a completed docusign.');
    }

    static testMethod void ShouldFailToUpdateStatusWithComplete()
    {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        opp.Billing_Contact__c = null;
        update opp;

        dsfs__DocuSign_Status__c status = new dsfs__DocuSign_Status__c(dsfs__Opportunity__c=opp.Id, dsfs__Envelope_Status__c='Delivered');

        Test.startTest();
        insert status;
        status.dsfs__Envelope_Status__c = 'Completed';
        update status;
        Test.stopTest();

        Opportunity o = [SELECT Id, OwnerId, StageName FROM Opportunity WHERE Id = :opp.Id]; //, Docusign_Status__c
        //System.assertEquals('Delivered', o.Docusign_Status__c, 'Docusign Status field on Opportunity should be "Delivered".');

        Task t = [SELECT ActivityDate, OwnerId, Priority, ReminderDateTime, Status, Subject, Type, WhatId FROM Task];
        System.assertEquals(o.OwnerId, t.ownerId, 'Error task owner should same as opportunity owner.');
        System.assertEquals('High', t.Priority, 'Error task priority should be "High".');
        System.assertEquals('In Progress', t.Status, 'Error task status should be "In Progress".');
        System.assertEquals('DocuSign Failed to Update Opportunity', t.Subject, 'Error task subject should be "DocuSign Failed to Update Opportunity".');
        System.assertEquals(opp.Id, t.WhatId, 'Error task does not reference correct opportunity.');
    }

    static testMethod void ShouldCreateOrderAndFlagDocusignStatusOnOpp()
    {
        Opportunity o = [SELECT Id, AccountId, Billing_Contact__c FROM Opportunity LIMIT 1];
        o.Billing_Address_Change_Requested__c = 'test';
        update o;

        Opportunity co = TestMethodUtil.createTestOpportunity('Discovery', Date.today(), o.AccountId, o.Billing_Contact__c, false);
        //co.Parent_Opportunity__c = o.Id;
        insert co;

        dsfs__DocuSign_Status__c status = new dsfs__DocuSign_Status__c(dsfs__Opportunity__c=o.Id, dsfs__Envelope_Status__c='Delivered');

        Test.startTest();
        insert status;
        status.dsfs__Envelope_Status__c = 'Completed';
        update status;
        Test.stopTest();

        o = [SELECT Id, Order_On_Hold__c FROM Opportunity WHERE Id = :o.Id]; //, Docusign_Status__c
        //System.assertEquals('Completed', o.Docusign_Status__c, 'Docusign Status field on Opportunity should be "Completed".');
        System.assert(o.Order_On_Hold__c, 'Opportunity should be placed on hold when a completed DocuSign contains an address change request.');
    }
}