public without sharing class DocuSignPDFGeneratorController
{
    public Boolean HasErrors { get; set; }
    public Boolean RenderAsPdf { get; set; }

    public String OppId { get; set; }
    public Opportunity Opp { get; set; }

    public String CurrencyFormat { get; set; }
    public String CurrencyName { get; set; }
    public String CurrencySymbol { get; set; }
    public String Terms { get; set; }

    private String baseUri = null;
    private String accountId = null;
    private String userId = null;
    private String password = null;
    private String integratorsKey = null;
    private Boolean generateSigners = false;

    public DocuSignPDFGeneratorController()
    {
        DocuSign_Setting__mdt dss =
        [
            SELECT Account_ID__c, Base_URI__c, Integrator_Key__c, Password__c, User_ID__c, Generate_Signers__c
              FROM DocuSign_Setting__mdt
             WHERE MasterLabel = :Utils.IsSandbox() ? 'Test' : 'Production'
        ];

        baseUri = dss.Base_URI__c;
        accountId = dss.Account_ID__c;
        integratorsKey = dss.Integrator_Key__c;
        userId = dss.User_ID__c;
        password = dss.Password__c;
        generateSigners = dss.Generate_Signers__c;
    }

    public PageReference Execute()
    {
        OppId = ApexPages.currentPage().getParameters().get('id');
        String action = ApexPages.currentPage().getParameters().get('a');
        if (action != null && action == 'render')
        {
            Opp = GetOpportunity(OppId);
            ValidateOpportunity(Opp);
            RenderDocument();
            return null;
        }

        return GenerateTemplate(OppId);
    }

    private static Opportunity GetOpportunity(ID oppId)
    {
        return [SELECT Id, IsClosed, Amount, CurrencyIsoCode, Terms__c,
                       a.Id, a.Name, a.BillingCity, a.BillingCountry, a.BillingCountryCode, a.BillingPostalCode, a.BillingState, a.BillingStateCode, a.BillingStreet,
                       ba.Id, ba.Name, ba.BillingCity, ba.BillingCountry, ba.BillingCountryCode, ba.BillingPostalCode, ba.BillingState, ba.BillingStateCode, ba.BillingStreet,
                       bc.Id, bc.Name, bc.Email,
                       sa.Id, sa.Name, sa.ShippingCity, sa.ShippingCountry, sa.ShippingCountryCode, sa.ShippingPostalCode, sa.ShippingState, sa.ShippingStateCode, sa.ShippingStreet,
                       sc.Id, sc.Name, sc.Email,
                       rep.Id, rep.Name, rep.Email, rep.Phone,
                       (SELECT Id, Quantity, TotalPrice, UnitPrice, Service_Start_Date__c, Service_End_Date__c,
                               Product2Id, Product2.Name, Product2.ProductCode
                          FROM OpportunityLineItems)
                  FROM Opportunity o,
                       o.Account a,
                       o.Billing_Contact__r bc,
                       bc.Account ba,
                       o.Shipping_Contact__r sc,
                       sc.Account sa,
                       o.Owner rep
                 WHERE o.Id = :oppId
                 LIMIT 1];
    }

    private static void ValidateOpportunity(Opportunity opp)
    {
        String errors = ''; // Trail all error messages with a ';' to be split when being called by the generate method.
        if (opp.IsClosed)
        {
            errors += 'This opportunity has already been closed.;';
        }
        else
        {
            if (opp.OpportunityLineItems.size() == 0)
            {
                errors += 'This opportunity has no line items.;';
            }
            if (opp.Terms__c == null)
            {
                errors += 'This opportunity has no terms specified.;';
            }
            if (opp.Account == null)
            {
                errors += 'An account must be specified.;';
            }
            if (opp.Billing_Contact__r == null)
            {
                errors += 'A billing contact must be specified.;';
            }
            else
            {
                Account ba = opp.Billing_Contact__r.Account;
                if (ba == null)
                {
                    errors += 'The billing contact has no account.;';
                }
                else
                {
                    if (ba.BillingStreet == null)
                    {
                        errors += 'The billing account\'s billing street is empty.;';
                    }
                    if (ba.BillingCity == null)
                    {
                        errors += 'The billing account\'s billing city is empty.;';
                    }
                    if (ba.BillingCountryCode == null)
                    {
                        errors += 'The billing account\'s billing country is empty.;';
                    }
                    else if (ba.BillingCountryCode == 'CA' || ba.BillingCountryCode == 'US')
                    {
                        if (ba.BillingStateCode == null)
                        {
                            errors += 'The billing account\'s billing state is empty.;';
                        }
                        if (ba.BillingPostalCode == null)
                        {
                            errors += 'The billing account\'s billing postal code is empty.;';
                        }
                    }
                }
            }
            if (opp.Shipping_Contact__r == null)
            {
                errors += 'A shipping contact must be specified.;';
            }
            else
            {
                Account sa = opp.Shipping_Contact__r.Account;
                if (sa == null)
                {
                    errors += 'The shipping contact has no account.;';
                }
                else
                {
                    if (sa.ShippingStreet == null)
                    {
                        errors += 'The shipping account\'s shipping street is empty.;';
                    }
                    if (sa.ShippingCity == null)
                    {
                        errors += 'The shipping account\'s shipping city is empty.;';
                    }
                    if (sa.ShippingCountryCode == null)
                    {
                        errors += 'The shipping account\'s shipping country is empty.;';
                    }
                    else if (sa.ShippingCountryCode == 'CA' || sa.ShippingCountryCode == 'US')
                    {
                        if (sa.ShippingStateCode == null)
                        {
                            errors += 'The shipping account\'s shipping state is empty.;';
                        }
                        if (sa.ShippingPostalCode == null)
                        {
                            errors += 'The shipping account\'s shipping postal code is empty.;';
                        }
                    }
                }
            }
        }

        if (errors.length() > 0)
            throw new CustomException(errors);
    }

    private void RenderDocument()
    {
        String qsRenderAs = ApexPages.currentPage().getParameters().get('ra');
        RenderAsPdf = qsRenderAs == null || qsRenderAs == 'pdf';

        Terms = Opp.Terms__c;
        for (PicklistEntry pe :Utils.ListPicklistValues(Opportunity.Terms__c))
        {
            if (pe.getValue() == opp.Terms__c)
            {
                Terms = pe.getLabel();
                break;
            }
        }

        CurrencySymbol = '$';
        CurrencyName = 'US Dollars';
        CurrencyFormat = '#,###.00';
        if (Opp.CurrencyIsoCode == 'EUR')
        {
            CurrencySymbol = '€';
            CurrencyName = 'Euros';
        }
        else if (Opp.CurrencyIsoCode == 'GBP')
        {
            CurrencySymbol = '£';
            CurrencyName = 'Pound Sterling';
        }
        else if (Opp.CurrencyIsoCode == 'JPY')
        {
            CurrencySymbol = '¥';
            CurrencyName = 'Japanese Yen';
            CurrencyFormat = '#,###';
        }
    }

    public PageReference GenerateTemplate(String oppId)
    {
        Blob pdfBlob = null;
        try
        {
            pdfBlob = GetDocumentPdfBlob(oppId);
        }
        catch (Exception ex)
        {
            String[] splitErrors = ex.getMessage().split(';', 0);
            for (String err :splitErrors)
            {
                if (String.isNotBlank(err))
                    ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, err));
            }
            HasErrors = true;
            return null;
        }

        String templateId = PublishTemplate(oppId, pdfBlob);

        // Redirecting user to Salesforce DocuSign UI
        return new PageReference('/apex/dsfs__DocuSign_CreateEnvelope?rc=&SSB=0&DSEID=0&DST=' + templateId + (generateSigners ? '' : '&CRL=LoadDefaultContacts~0') + '&SourceID=' + oppId);
    }

    private static Blob GetDocumentPdfBlob(String oppId)
    {
        // Render the template
        System.debug('Rendering the template');
        PageReference pageRefPdfRender = new PageReference('/apex/DocuSignPDFGenerator');
        pageRefPdfRender.getParameters().put('id', oppId);
        pageRefPdfRender.getParameters().put('a', 'render');
        return Test.IsRunningTest() ? Blob.valueOf('UNIT.TEST') : pageRefPdfRender.getContent();
    }

    private String PublishTemplate(String oppId, Blob pdfBlob)
    {
        DocuSignRestAPI.TemplateCreateRequest tcReq = new DocuSignRestAPI.TemplateCreateRequest();
        tcReq.emailSubject = 'Please Complete DocuSign';
        tcReq.emailBlurb = 'Please DocuSign the attached form.\n\nSincerely,\nYour Company, Inc.';

        DocuSignRestAPI.EnvelopeDocument doc = new DocuSignRestAPI.EnvelopeDocument();
        doc.documentBase64 = EncodingUtil.base64Encode(pdfBlob);
        doc.documentId = '10';
        doc.fileExtension = 'pdf';
        doc.name = 'Opportunity ' + oppId;
        tcReq.documents = new List<DocuSignRestAPI.EnvelopeDocument>();
        tcReq.documents.add(doc);

        tcReq.envelopeTemplateDefinition = new DocuSignRestAPI.EnvelopeTemplateDefinition();
        tcReq.envelopeTemplateDefinition.name = 'Opportunity ' + oppId;
        tcReq.envelopeTemplateDefinition.shared = 'true';

        // Signer
        DocuSignRestAPI.Recipient signer = new DocuSignRestAPI.Recipient();
        signer.recipientId = '1';
        signer.roleName = 'Signer 1';
        tcReq.recipients = new DocuSignRestAPI.Recipients();
        tcReq.recipients.signers = new List<DocuSignRestAPI.Recipient>();
        tcReq.recipients.signers.add(signer);

        // Initialize Tabs
        DocuSignRestAPI.Tabs tabs = InitTabs(signer.recipientId, doc.documentId);

        System.debug('--- Calling DocuSign ---');
        // Initializing client
        DocuSignRestAPI dsClient = new DocuSignRestAPI(baseUri, accountId, integratorsKey, userId, password);

        // Creating template
        DocuSignRestAPI.TemplateCreateResponse tcr = dsClient.TemplateCreate(tcReq);
        System.debug('TEMPLATE ID: ' + tcr.templateId);
        // Creating tabs
        dsClient.TemplateTabsCreate(tcr.templateId, signer.recipientId, tabs);

        return tcr.templateId;
    }

    private static DocuSignRestAPI.Tabs InitTabs(String recipientId, String documentId)
    {
        // Tabs
        DocuSignRestAPI.Tabs tabs = new DocuSignRestAPI.Tabs();
        tabs.fullNameTabs = new List<DocuSignRestAPI.Tab>();
        tabs.checkboxTabs = new List<DocuSignRestAPI.Tab>();
        tabs.radioGroupTabs = new List<DocuSignRestAPI.RadioGroupTab>();
        tabs.signHereTabs = new List<DocuSignRestAPI.Tab>();
        tabs.textTabs = new List<DocuSignRestAPI.TextTab>();

        // Purchase Order tabs
        DocuSignRestAPI.RadioGroupTab poRadioGroupTab = new DocuSignRestAPI.RadioGroupTab();
        tabs.radioGroupTabs.add(poRadioGroupTab);
        poRadioGroupTab.documentId = documentId;
        poRadioGroupTab.recipientId = recipientId;
        poRadioGroupTab.groupName = 'IsPurchaseOrder';
        poRadioGroupTab.radios = new List<DocuSignRestAPI.RadioTab>();

        DocuSignRestAPI.RadioTab radioTabPoYes = new DocuSignRestAPI.RadioTab();
        poRadioGroupTab.radios.add(radioTabPoYes);
        radioTabPoYes.anchorString = '{yPO}';
        radioTabPoYes.anchorYOffset = '-4';
        radioTabPoYes.anchorXOffset = '0';
        radioTabPoYes.value = 'true';

        DocuSignRestAPI.RadioTab radioTabPoNo = new DocuSignRestAPI.RadioTab();
        poRadioGroupTab.radios.add(radioTabPoNo);
        radioTabPoNo.anchorString = '{nPO}';
        radioTabPoNo.anchorYOffset = '-4';
        radioTabPoNo.anchorXOffset = '0';
        radioTabPoNo.value = 'false';

        DocuSignRestAPI.TextTab poTextTab = new DocuSignRestAPI.TextTab();
        tabs.textTabs.add(poTextTab);
        poTextTab.anchorString = '{po#}';
        poTextTab.anchorYOffset = '-4';
        poTextTab.anchorXOffset = '-4';
        poTextTab.conditionalParentLabel = 'IsPurchaseOrder';
        poTextTab.conditionalParentValue = 'true';
        poTextTab.documentId = documentId;
        poTextTab.height = '15';
        poTextTab.maxLength = 25;
        poTextTab.mergeField = new DocuSignRestAPI.MergeField('Opportunity Purchase Order Number', 'Opportunity.Purchase_Order_Number__c');
        poTextTab.name = 'Purchase Order Number';
        poTextTab.recipientId = recipientId;
        poTextTab.scaleValue = '0.5';
        poTextTab.tabLabel = 'txtPONbr';
        poTextTab.width = '165';

        // SignHere tab
        DocuSignRestAPI.Tab signHereTab = new DocuSignRestAPI.Tab();
        tabs.signHereTabs.add(signHereTab);
        signHereTab.anchorString = '{AS}';
        signHereTab.anchorYOffset = '8';
        signHereTab.anchorXOffset = '0';
        signHereTab.documentId = documentId;
        signHereTab.name = 'Authorized Signature';
        signHereTab.recipientId = recipientId;
        signHereTab.scaleValue = '1';

        // Printed Name tab
        DocuSignRestAPI.Tab fullNameTab = new DocuSignRestAPI.Tab();
        tabs.fullNameTabs.add(fullNameTab);
        fullNameTab.anchorString = '{PN}';
        fullNameTab.anchorYOffset = '0';
        fullNameTab.anchorXOffset = '0';
        fullNameTab.documentId = documentId;
        fullNameTab.name = 'Printed Name';
        fullNameTab.recipientId = recipientId;
        fullNameTab.scaleValue = '0.5';

        // Billing Infomation Validated tab
        DocuSignRestAPI.RadioGroupTab bvRadioGroupTab = new DocuSignRestAPI.RadioGroupTab();
        tabs.radioGroupTabs.add(bvRadioGroupTab);
        bvRadioGroupTab.documentId = documentId;
        bvRadioGroupTab.recipientId = recipientId;
        bvRadioGroupTab.groupName = 'IsBillingValidated';
        bvRadioGroupTab.radios = new List<DocuSignRestAPI.RadioTab>();

        DocuSignRestAPI.RadioTab bvRadioTab = new DocuSignRestAPI.RadioTab();
        bvRadioGroupTab.radios.add(bvRadioTab);
        bvRadioTab.anchorString = '{BV}';
        bvRadioTab.anchorYOffset = '-4';
        bvRadioTab.anchorXOffset = '0';
        bvRadioTab.value = 'true';

        // Address Checkbox tabs
        DocuSignRestAPI.Tab saCbxTab = new DocuSignRestAPI.Tab();
        tabs.checkboxTabs.add(saCbxTab);
        saCbxTab.anchorString = '{SA}';
        saCbxTab.anchorYOffset = '-2';
        saCbxTab.anchorXOffset = '0';
        saCbxTab.documentId = documentId;
        saCbxTab.name = 'Different Shipping Address';
        saCbxTab.recipientId = recipientId;
        saCbxTab.required = 'false';
        saCbxTab.tabLabel = 'cbxSA';

        DocuSignRestAPI.Tab baCbxTab = new DocuSignRestAPI.Tab();
        tabs.checkboxTabs.add(baCbxTab);
        baCbxTab.anchorString = '{BA}';
        baCbxTab.anchorYOffset = '-2';
        baCbxTab.anchorXOffset = '0';
        baCbxTab.documentId = documentId;
        baCbxTab.name = 'Different Billing Address';
        baCbxTab.recipientId = recipientId;
        baCbxTab.required = 'false';
        baCbxTab.tabLabel = 'cbxBA';

        // Address Text tabs
        DocuSignRestAPI.TextTab saTextTab = new DocuSignRestAPI.TextTab();
        tabs.textTabs.add(saTextTab);
        saTextTab.anchorString = '{SA}';
        saTextTab.anchorYOffset = '17';
        saTextTab.anchorXOffset = '0';
        saTextTab.conditionalParentLabel = 'cbxSA';
        saTextTab.conditionalParentValue = 'on';
        saTextTab.documentId = documentId;
        saTextTab.height = '80';
        saTextTab.mergeField = new DocuSignRestAPI.MergeField('Opportunity Shipping Address Change Request', 'Opportunity.Shipping_Address_Change_Request__c');
        saTextTab.recipientId = recipientId;
        saTextTab.scaleValue = '0.5';
        saTextTab.tabLabel = 'txtSA';
        saTextTab.width = '305';

        DocuSignRestAPI.TextTab baTextTab = new DocuSignRestAPI.TextTab();
        tabs.textTabs.add(baTextTab);
        baTextTab.anchorString = '{BA}';
        baTextTab.anchorYOffset = '17';
        baTextTab.anchorXOffset = '0';
        baTextTab.conditionalParentLabel = 'cbxBA';
        baTextTab.conditionalParentValue = 'on';
        baTextTab.documentId = documentId;
        baTextTab.height = '80';
        baTextTab.mergeField = new DocuSignRestAPI.MergeField('Opportunity Billing Address Change Request', 'Opportunity.Billing_Address_Change_Requested__c');
        baTextTab.recipientId = recipientId;
        baTextTab.scaleValue = '0.5';
        baTextTab.tabLabel = 'txtBA';
        baTextTab.width = '305';

        return tabs;
    }
}