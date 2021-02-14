public class DocuSignRestAPI
{
    private String originalBaseAddress = null;
    private String baseAddress = null;
    private String accountId = null;
    private String integratorKey = null;
    private String username = null;
    private String password = null;

    public DocuSignRestAPI(String baseAddress, String accountId, String integratorKey, String username, String password)
    {
        this.originalBaseAddress = baseAddress;
        this.accountId = accountId;
        this.integratorKey = integratorKey;
        this.username = username;
        this.password = password;

        LoginAccount la = LoginAccountInformationGet();
        this.baseAddress = la.baseUrl + '/';
    }

    private HttpRequest InitHttpRequest(String method, String uri)
    {
        HttpRequest req = new HttpRequest();
        req.setHeader('Accept', 'application/json');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('X-DocuSign-Authentication', '{"Username":"' + username + '","Password":"' + password + '","IntegratorKey":"' + integratorKey + '"}');
        req.setTimeout(120000);
        req.setEndpoint(baseAddress + uri);
        if (uri == 'login_information')
            req.setEndpoint(originalBaseAddress + uri);
        req.setMethod(method);
        return req;
    }

    private object Deserialize(String jsonString, System.Type type)
    {
        jsonString = jsonString.replace('"true"', 'true').replace('"false"', 'false'); // fix for apex's shortcomings with interpreting boolean values in response strings
        return JSON.deserialize(jsonString, type);
    }

    //
    // DocuSignRestAPI Methods
    //

    public LoginAccount LoginAccountInformationGet()
    {
        System.debug('ENTERING DocuSignRestAPI.LoginAccountInformationGet.');
        HttpRequest req = InitHttpRequest('GET', 'login_information');

        HttpResponse res = new Http().send(req);
        if (res.getStatusCode() != 200)
        {
            throw new CustomException('Failure to get login information. ' + res.getStatusCode() + ': ' + res.getStatus());
        }

        String resBody = res.getBody();
        System.debug(resBody);

        LoginInformation li = (LoginInformation)Deserialize(resBody, LoginInformation.class);
        System.debug('LEAVING DocuSignRestAPI.LoginAccountInformationGet. LoginInformation: ' + li);
        return li.loginAccounts[0];
    }

    public EnvelopeCreateResponse EnvelopeCreate(EnvelopeCreateRequest ecReq)
    {
        System.debug('ENTERING DocuSignRestAPI.EnvelopeCreate. Envelope: ' + ecReq);
        HttpRequest req = InitHttpRequest('POST', 'envelopes');
        req.setBody(JSON.serialize(ecReq));

        HttpResponse res = new Http().send(req);
        if (res.getStatusCode() != 201)
        {
            throw new CustomException('Failure to create envelope. ' + res.getStatusCode() + ': ' + res.getStatus());
        }

        String resBody = res.getBody();
        System.debug(resBody);

        EnvelopeCreateResponse ecr = (EnvelopeCreateResponse)Deserialize(resBody, EnvelopeCreateResponse.class);
        System.debug('LEAVING DocuSignRestAPI.EnvelopeCreate. EnvelopeCreateResponse: ' + ecr);
        return ecr;
    }

    public EnvelopeDocumentListResponse EnvelopeDocumentList(String envelopeId)
    {
        System.debug('ENTERING DocuSignRestAPI.EnvelopeDocumentList. Envelope ID: ' + envelopeId);
        HttpRequest req = InitHttpRequest('GET', 'envelopes/' + envelopeId + '/documents');

        HttpResponse res = new Http().send(req);
        if (res.getStatusCode() != 200)
        {
            throw new CustomException('Failure to retrieve envelope documents. ' + res.getStatusCode() + ': ' + res.getStatus());
        }

        String resBody = res.getBody();
        System.debug(resBody);

        EnvelopeDocumentListResponse edlr = (EnvelopeDocumentListResponse)Deserialize(resBody, EnvelopeDocumentListResponse.class);
        System.debug('LEAVING DocuSignRestAPI.EnvelopeDocumentList. EnvelopeDocumentListResponse: ' + edlr);
        return edlr;
    }

    public TemplateCreateResponse TemplateCreate(TemplateCreateRequest tcReq)
    {
        System.debug('ENTERING DocuSignRestAPI.TemplateCreate. Template: ' + tcReq);
        HttpRequest req = InitHttpRequest('POST', 'templates');
        req.setBody(JSON.serialize(tcReq));

        HttpResponse res = new Http().send(req);
        if (res.getStatusCode() != 201)
        {
            throw new CustomException('Failure to create template. ' + res.getStatusCode() + ': ' + res.getStatus());
        }

        String resBody = res.getBody();
        System.debug(resBody);

        TemplateCreateResponse tcr = (TemplateCreateResponse)Deserialize(resBody, TemplateCreateResponse.class);
        System.debug('LEAVING DocuSignRestAPI.TemplateCreate. TemplateCreateResponse: ' + tcr);
        return tcr;
    }

    public void TemplateTabsCreate(String templateId, String recipientId, Tabs tabs)
    {
        System.debug('ENTERING DocuSignRestAPI.TemplateTabsCreate. Template ID: ' + templateId + ' - Recipient ID: ' + recipientId + ' - Tabs: ' + tabs);
        HttpRequest req = InitHttpRequest('POST', 'templates/' + templateId + '/recipients/' + recipientId + '/tabs');
        req.setBody(JSON.serialize(tabs));

        System.debug(req.getBody());

        HttpResponse res = new Http().send(req);
        if (res.getStatusCode() != 201)
        {
            throw new CustomException('Failure to add template tabs. ' + res.getStatusCode() + ': ' + res.getStatus() + '\n' + res.getBody());
        }

        String resBody = res.getBody();
        System.debug(resBody);
        System.debug('LEAVING DocuSignRestAPI.TemplateTabsCreate.');
    }

    //
    // DocuSignRestAPI Model Classes
    //

    public class ErrorDetails
    {
        public String errorCode { get; set; }
        public String message { get; set; }
    }

    private class LoginInformation
    {
        public List<LoginAccount> loginAccounts { get; set; }
    }

    public class LoginAccount
    {
        public String name { get; set; }
        public Integer accountId { get; set; }
        public String baseUrl { get; set; }
        public Boolean isDefault { get; set; }
        public String userName { get; set; }
        public String userId { get; set; }
        public String email { get; set; }
        public String siteDescription { get; set; }
    }

    public virtual class EnvelopeBase
    {
        public List<EnvelopeDocument> documents { get; set; }
        public String emailBlurb { get; set; }
        public String emailSubject { get; set; }
        public String envelopeId { get; set; }
        public String purgeState { get; set; }
        public Recipients recipients { get; set; }
        public String status { get; set; }
    }

    public virtual class EnvelopeTemplate extends EnvelopeBase
    {
        public EnvelopeTemplateDefinition envelopeTemplateDefinition { get; set; }
    }

    public virtual class EnvelopeTemplateDefinition
    {
        public String description { get; set; }
        public String folderId { get; set; }
        public String folderName { get; set; }
        public String name { get; set; }
        public String shared { get; set; }
        public String templateId { get; set; }
    }

    public class EnvelopeCreateRequest extends EnvelopeBase
    {
        public String templateId { get; set; }
    }

    public class EnvelopeCreateResponse
    {
        public String envelopeId { get; set; }
        public String status { get; set; }
        public String statusDateTime { get; set; }
        public String uri { get; set; }
    }

    public class EnvelopeRecipientListResponse
    {
        public List<Signer> signers { get; set; }
    }

    public class EnvelopeDocumentListResponse
    {
        public List<EnvelopeDocument> envelopeDocuments { get; set; }
        public String envelopeId { get; set; }
    }

    public class EnvelopeDocument
    {
        public String attachmentTabId { get; set; }
        public List<AvailableDocumentType> availableDocumentTypes { get; set; }
        public Boolean containsPdfFormFields { get; set; }
        public List<DocumentField> documentFields { get; set; }
        public String documentId { get; set; }
        public String documentBase64 { get; set; }
        public ErrorDetails errorDetails { get; set; }
        public String fileExtension { get; set; }
        public String name { get; set; }
        public String order { get; set; }
        public Integer pages { get; set; }
        public String type { get; set; }
        public String uri { get; set; }
    }

    public class AvailableDocumentType
    {
        public Boolean isDefault { get; set; }
        public String type { get; set; }
    }

    public class DocumentField
    {
        public ErrorDetails errorDetails { get; set; }
        public String name { get; set; }
        public String value { get; set; }
    }

    public class TemplateCreateRequest extends EnvelopeTemplate { }

    public class TemplateCreateResponse
    {
        public String templateId { get; set; }
        public String name { get; set; }
        public String uri { get; set; }
    }

    public class Recipients
    {
        public List<Recipient> signers { get; set; }
    }

    public virtual class Recipient
    {
        public String recipientId {get; set; }
        public String recipientIdGuid { get; set; }
        public String roleName { get; set; }
    }

    public class Signer extends Recipient
    {
        public String email { get; set; }
        public String name { get; set; }
        public Tabs tabs { get; set; }
    }

    public class Tabs
    {
        public List<Tab> fullNameTabs { get; set; }
        public List<Tab> checkboxTabs { get; set; }
        public List<RadioGroupTab> radioGroupTabs { get; set; }
        public List<Tab> signHereTabs { get; set; }
        public List<TextTab> textTabs { get; set; }
    }

    public virtual class Tab
    {
        public String anchorString {get; set; }
        public String anchorYOffset {get; set; }
        public String anchorXOffset {get; set; }
        public String conditionalParentLabel { get; set; }
        public String conditionalParentValue { get; set; }
        public String documentId { get; set; }
        public MergeField mergeField { get; set; }
        public String name { get; set; }
        public String recipientId { get; set; }
        public String required { get; set; }
        public String scaleValue {get; set; }
        public String tabId { get; set; }
        public String tabLabel { get; set; }
        public String tabOrder { get; set; }
    }

    public class RadioGroupTab
    {
        public List<RadioTab> radios { get; set; }
        public String conditionalParentLabel { get; set; }
        public String conditionalParentValue { get; set; }
        public String documentId { get; set; }
        public String groupName { get; set; }
        public String recipientId { get; set; }
        public String requireAll { get; set; }
    }

    public class RadioTab
    {
        public String anchorString { get; set; }
        public String anchorUnits { get; set; }
        public String anchorXOffset { get; set; }
        public String anchorYOffset { get; set; }
        public String selected { get; set; }
        public String value { get; set; }
    }

    public class TextTab extends Tab
    {
        public String height { get; set; }
        public Integer maxLength { get; set; }
        public String width { get; set; }

        public TextTab()
        {
            maxLength = 0; // unlimited
        }
    }

    public class MergeField
    {
        public String allowSenderToEdit { get; set; }
        public String configurationType { get { return 'Salesforce'; } }
        public String name { get; set; }
        public String path { get; set; }
        public String row { get; set; }
        public String writeBack { get; set; }

        public MergeField(String name, String objectFieldPath)
        {
            allowSenderToEdit = 'false';
            this.name = name;
            path = objectFieldPath;
            writeBack = 'true';
        }
    }
}