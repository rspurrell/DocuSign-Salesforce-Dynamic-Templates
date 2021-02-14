@isTest
private class DocuSignRestAPITests
{
    static String docuSignApiUrl = 'https://demo.docusign.net/restapi/v2/';
    static String accountId = '99b7bd3f-00ed-41d8-a15c-dffbfb8a55dd';
    static String integratorsKey = 'a2389e4e-3cae-4f5d-9eed-e3109676b49b';
    static String userId = 'test@example.com';
    static String password = 'Qwerty12345';

    static String templateId = '4f76aa5a-f0a0-4f11-9c1f-76fde4d92f1b';
    static MockHttpResponse mhr = new MockHttpResponse('{"loginAccounts":[{"name":"Your Company, Inc.","accountId":"1234567","baseUrl":"https://demo.docusign.net/restapi/v2/accounts/1234567","isDefault":"true","userName":"USERNAME","userId":"USERID","email":"test@example.com","siteDescription":""}]}');

    static testMethod void ShouldGetLoginAccountInformation()
    {
        Test.setMock(HttpCalloutMock.class, mhr);

        Test.startTest();

        DocuSignRestAPI dsClient = new DocuSignRestAPI(docuSignApiUrl, accountId, integratorsKey, userId, password);
        DocuSignRestAPI.LoginAccount la = dsClient.LoginAccountInformationGet();
        System.assertEquals(1234567, la.accountId, 'Login account accountId does not equal 1234567.');
        System.assertEquals('https://demo.docusign.net/restapi/v2/accounts/1234567', la.baseUrl, 'Login account name does not equal https://demo.docusign.net/restapi/v2/accounts/1234567');
        System.assertEquals('test@example.com', la.email, 'Login account email does not equal test@example.com.');
        System.assert(la.isDefault, 'Login account isDefault is not true.');
        System.assertEquals('Your Company, Inc.', la.name, 'Login account name does not equal Your Company, Inc.');
        System.assertEquals('', la.siteDescription, 'Login account siteDescription is not blank.');
        System.assertEquals('USERID', la.userId, 'Login account userId does not equal USERID.');
        System.assertEquals('USERNAME', la.userName, 'Login account userName does not equal USERNAME.');

        Test.stopTest();
    }

    static testMethod void ShouldCreateDocuSignTemplate()
    {
        mhr.AddEndpointMethodResponse(docuSignApiUrl + 'accounts/1234567/templates', 'POST', 201, 'application/json', '{"templateId":"' + templateId + '","name":"TEMPLATE NAME","uri":"/templates/' + templateId + '"}');
        Test.setMock(HttpCalloutMock.class, mhr);

        Test.startTest();

        DocuSignRestAPI.TemplateCreateRequest tcReq = new DocuSignRestAPI.TemplateCreateRequest();
        tcReq.emailSubject = 'Please Complete DocuSign';
        tcReq.emailBlurb = 'Please DocuSign the attached form.\n\nSincerely,\nYour Company, Inc.';

        DocuSignRestAPI.EnvelopeDocument doc = new DocuSignRestAPI.EnvelopeDocument();
        doc.documentBase64 = EncodingUtil.base64Encode(Blob.valueOf('UNIT.TEST'));
        doc.documentId = '10';
        doc.fileExtension = 'pdf';
        doc.name = 'TEMPLATE DOCUMENT';
        tcReq.documents = new List<DocuSignRestAPI.EnvelopeDocument>();
        tcReq.documents.add(doc);

        tcReq.envelopeTemplateDefinition = new DocuSignRestAPI.EnvelopeTemplateDefinition();
        tcReq.envelopeTemplateDefinition.name = 'TEMPLATE NAME';
        tcReq.envelopeTemplateDefinition.description = 'TEMPLATE DESCRIPTION';
        tcReq.envelopeTemplateDefinition.folderId = 'FOLDER ID';
        tcReq.envelopeTemplateDefinition.folderName = 'FOLDER NAME';
        tcReq.envelopeTemplateDefinition.templateId = templateId;

        // Signer
        DocuSignRestAPI.Recipient signer = new DocuSignRestAPI.Recipient();
        signer.recipientId = '1';
        signer.roleName = 'Signer 1';
        tcReq.recipients = new DocuSignRestAPI.Recipients();
        tcReq.recipients.signers = new List<DocuSignRestAPI.Recipient>();
        tcReq.recipients.signers.add(signer);

        DocuSignRestAPI dsClient = new DocuSignRestAPI(docuSignApiUrl, accountId, integratorsKey, userId, password);
        DocuSignRestAPI.TemplateCreateResponse tcr = dsClient.TemplateCreate(tcReq);

        System.assertEquals('TEMPLATE NAME', tcr.name, 'Template name does not equal TEMPLATE NAME.');
        System.assertEquals(templateId, tcr.templateId, 'Template templateId does not equal ' + templateId + '.');
        System.assertEquals('/templates/' + templateId + '', tcr.uri, 'Template uri does not equal /templates/' + templateId + '.');

        Test.stopTest();
    }

    static testMethod void ShouldCreateDocuSignTemplateTabs()
    {
        mhr.AddEndpointMethodResponse(docuSignApiUrl + 'accounts/1234567/templates/' + templateId + '/recipients/1/tabs', 'POST', 201, 'application/json', '');
        Test.setMock(HttpCalloutMock.class, mhr);

        string documentId = '10', recipientId = '1';

        Test.startTest();

        // Tabs
        DocuSignRestAPI.Tabs tabs = new DocuSignRestAPI.Tabs();
        tabs.fullNameTabs = new List<DocuSignRestAPI.Tab>();
        tabs.checkboxTabs = new List<DocuSignRestAPI.Tab>();
        tabs.radioGroupTabs = new List<DocuSignRestAPI.RadioGroupTab>();
        tabs.signHereTabs = new List<DocuSignRestAPI.Tab>();
        tabs.textTabs = new List<DocuSignRestAPI.TextTab>();

        // Radio tab classes coverage
        DocuSignRestAPI.RadioGroupTab radGroup = new DocuSignRestAPI.RadioGroupTab();
        tabs.radioGroupTabs.add(radGroup);
        radGroup.conditionalParentLabel = '';
        radGroup.conditionalParentValue = '';
        radGroup.documentId = documentId;
        radGroup.recipientId = recipientId;
        radGroup.groupName = 'RadioTabDataLabel';
        radGroup.radios = new List<DocuSignRestAPI.RadioTab>();
        radGroup.requireAll = 'false';

        DocuSignRestAPI.RadioTab radTab = new DocuSignRestAPI.RadioTab();
        radGroup.radios.add(radTab);
        radTab.anchorString = '{RT}';
        radTab.anchorUnits = 'pixels';
        radTab.anchorYOffset = '-3';
        radTab.anchorXOffset = '0';
        radTab.selected = 'false';
        radTab.value = 'true';

        // TextTab and Tab class coverage
        DocuSignRestAPI.TextTab textTab = new DocuSignRestAPI.TextTab();
        tabs.textTabs.add(textTab);
        textTab.anchorString = '{AS}';
        textTab.anchorYOffset = '-3';
        textTab.anchorXOffset = '-3';
        textTab.conditionalParentLabel = 'RadioTabDataLabel';
        textTab.conditionalParentValue = 'true';
        textTab.documentId = documentId;
        textTab.height = '15';
        textTab.mergeField = new DocuSignRestAPI.MergeField('MERGE FIELD NAME', 'SalesforceObject.ObjectField');
        textTab.mergeField.row = '1';
        textTab.name = 'Tab name';
        textTab.recipientId = recipientId;
        textTab.required = 'true';
        textTab.scaleValue = '0.5';
        textTab.tabId = '';
        textTab.tabLabel = 'TabDataLabel';
        textTab.tabOrder = '1';
        textTab.width = '405';

        // Creating tabs
        DocuSignRestAPI dsClient = new DocuSignRestAPI(docuSignApiUrl, accountId, integratorsKey, userId, password);
        dsClient.TemplateTabsCreate(templateId, recipientId, tabs);

        Test.stopTest();
    }

    static testMethod void ShouldCreateDocuSignEnvelope()
    {
        mhr.AddEndpointMethodResponse(docuSignApiUrl + 'accounts/1234567/envelopes', 'POST', 201, 'application/json', '{"envelopeId":"ENVELOPEID","status":"DRAFT","statusDateTime":"2016/12/12 00:00:00","uri":"/envelopes/ENVELOPEID"}');
        Test.setMock(HttpCalloutMock.class, mhr);

        Test.startTest();

        DocuSignRestAPI.EnvelopeCreateRequest ecReq = new DocuSignRestAPI.EnvelopeCreateRequest();
        ecReq.emailSubject = 'Please Complete DocuSign';
        ecReq.emailBlurb = 'Please DocuSign the attached form.\n\nSincerely,\nYour Company, Inc.';
        ecReq.templateId = templateId;

        DocuSignRestAPI.EnvelopeDocument doc = new DocuSignRestAPI.EnvelopeDocument();
        doc.documentBase64 = EncodingUtil.base64Encode(Blob.valueOf('UNIT.TEST'));
        doc.documentId = '10';
        doc.fileExtension = 'pdf';
        doc.name = 'TEMPLATE DOCUMENT';
        ecReq.documents = new List<DocuSignRestAPI.EnvelopeDocument>();
        ecReq.documents.add(doc);

        // Signer
        DocuSignRestAPI.Recipient signer = new DocuSignRestAPI.Recipient();
        signer.recipientId = '1';
        signer.roleName = 'Signer 1';
        ecReq.recipients = new DocuSignRestAPI.Recipients();
        ecReq.recipients.signers = new List<DocuSignRestAPI.Recipient>();
        ecReq.recipients.signers.add(signer);

        DocuSignRestAPI dsClient = new DocuSignRestAPI(docuSignApiUrl, accountId, integratorsKey, userId, password);
        DocuSignRestAPI.EnvelopeCreateResponse ecr = dsClient.EnvelopeCreate(ecReq);

        System.assertEquals('ENVELOPEID', ecr.envelopeId, 'Envelope ID does not equal ENVELOPEID.');
        System.assertEquals('DRAFT', ecr.status, 'Envelope status does not equal DRAFT.');
        System.assertEquals('2016/12/12 00:00:00', ecr.statusDateTime, 'Envelope statusDateTime does not equal 2016/12/12 00:00:00.');
        System.assertEquals('/envelopes/ENVELOPEID', ecr.uri, 'Envelope uri does not equal /envelopes/ENVELOPEID.');

        Test.stopTest();
    }

    static testMethod void ShouldListDocuSignEnvelopeDocuments()
    {
        mhr.AddEndpointMethodResponse(docuSignApiUrl + 'accounts/1234567/envelopes/ENVELOPEID/documents', 'GET', 200, 'application/json', '{"envelopeDocuments":[{"attachmentTabId":"ATTACHMENTTABID","availableDocumentTypes":[{"isDefault":true,"type":"ELECTRONIC"}],"containsPdfFormFields":true,"documentFields":[{"errorDetails":{"errorCode":"SUCCESS","message":""},"name":"DOCUMENT FIELD NAME","value":"DOCUMENT FIELD VALUE"}],"documentId":"DOCUMENTID","documentBase64":"BASE64TEXT","errorDetails":{"errorCode":"SUCCESS","message":""},"fileExtension":"pdf","name":"DOCUMENT NAME","order":"1","pages":2,"type":"ELECTRONIC","uri":"/envelopes/ENVELOPEID/documents/DOCUMENTID"}],"envelopeId":"ENVELOPEID"}');
        Test.setMock(HttpCalloutMock.class, mhr);

        Test.startTest();

        DocuSignRestAPI dsClient = new DocuSignRestAPI(docuSignApiUrl, accountId, integratorsKey, userId, password);
        DocuSignRestAPI.EnvelopeDocumentListResponse edlr = dsClient.EnvelopeDocumentList('ENVELOPEID');

        System.assertEquals('ENVELOPEID', edlr.envelopeId, 'Envelope ID does not equal ENVELOPEID.');

        System.assert(edlr.envelopeDocuments != null && edlr.envelopeDocuments.size() == 1, 'Envelope documents are null or empty.');
        DocuSignRestAPI.EnvelopeDocument ed = edlr.envelopeDocuments[0];
        System.assertEquals('ATTACHMENTTABID', ed.attachmentTabId, 'Envelope document attachmentTabId does not equal ATTACHMENTTABID.');

        System.assert(ed.availableDocumentTypes != null && ed.availableDocumentTypes.size() == 1, 'Envelope document availableDocumentTypes is null or empty.');
        DocuSignRestAPI.AvailableDocumentType adt = ed.availableDocumentTypes[0];
        System.assertEquals(true, adt.isDefault, 'Envelope document available document type isDefault does not equal true.');
        System.assertEquals('ELECTRONIC', adt.type, 'Envelope document available document type\'s type does not equal ELECTRONIC.');

        System.assertEquals(true, ed.containsPdfFormFields, 'Envelope document containsPdfFormFields does not equal true.');

        System.assert(ed.documentFields != null && ed.documentFields.size() == 1, 'Envelope document fields is null or empty.');
        DocuSignRestAPI.DocumentField df = ed.documentFields[0];
        System.assertEquals('SUCCESS', df.errorDetails.errorCode, 'Envelope document field errorDetails errorCode does not equal SUCCESS.');
        System.assertEquals('', df.errorDetails.message, 'Envelope document field errorDetails message is not an empty string.');
        System.assertEquals('DOCUMENT FIELD NAME', df.name, 'Envelope document field name does not equal DOCUMENT FIELD NAME.');
        System.assertEquals('DOCUMENT FIELD VALUE', df.value, 'Envelope document field value does not equal DOCUMENT FIELD VALUE.');

        System.assertEquals('DOCUMENTID', ed.documentId, 'Envelope document ID does not equal DOCUMENTID.');
        System.assertEquals('BASE64TEXT', ed.documentBase64, 'Envelope document documentBase64 does not equal BASE64TEXT.');
        System.assertEquals('SUCCESS', ed.errorDetails.errorCode, 'Envelope document errorDetails errorCode does not equal SUCCESS.');
        System.assertEquals('', ed.errorDetails.message, 'Envelope document errorDetails message is not an empty string.');
        System.assertEquals('pdf', ed.fileExtension, 'Envelope document fileExtension does not equal pdf.');
        System.assertEquals('DOCUMENT NAME', ed.name, 'Envelope document name does not equal DOCUMENT NAME.');
        System.assertEquals('1', ed.order, 'Envelope document order does not equal 1.');
        System.assertEquals(2, ed.pages, 'Envelope document pages does not equal 2.');
        System.assertEquals('ELECTRONIC', ed.type, 'Envelope document type does not equal ELECTRONIC.');
        System.assertEquals('/envelopes/ENVELOPEID/documents/DOCUMENTID', ed.uri, 'Envelope document uri does not equal /envelopes/ENVELOPEID/documents/DOCUMENTID.');

        Test.stopTest();
    }
}